---
  title: ceph_rbd_snap
---

对克隆块的写操作流程：//从这里明白多重克隆降低性能

- 客户端（librbd）向对应的OSD发送正常的写请求；
- OSD返回客户端(librbd)应答，表明该OSD上对应的对象不存在；
- 客户端(librbd)发送读请求给克隆块的父块，读取对应snap1上的数据返回给客户端；
- 客户端(librbd)把该快照数据写入克隆image中；
- 客户端(librbd)把克隆image发送写操作，写入实际数据；

由以上过程可知，克隆的拷贝操作由客户端控制完成，OSD 端是无感知的；

### snap核心数据结构：

- head object：对象的原始对象，可读、可写
- snap object: 对某个对象做快照后，通过cow机制copy出来的快照对象只能读，不能写；
- snap_seq: 快照序号，每次做快照，系统分配一个相应快照序号，主要是应用于写操作；
- sanpdir object：当head对象被删除后，仍然有 snap 和 clone 对象，系统自动创建一个snapdir对象来保存SnapSet信息。head对象和snapdir对象只能存在一个，其属性保存了快照的相关信息；


```c++
//common/snap_types.h
  struct SnapContext{
    snapid_t seq;   //最新的快照序号
    vector<snapid_t> snaps; //当前存在的快照序号，降序排列
    ...
  }
```
SnapContext在客户端(librbd)保存了snap相关信息, 该结构 持久化存储在RBD的元数据中；
而用户写操作必须自己提供SnapContext信息；

```c++
struct librados::IoCtxImpl{
  ...
  snapid_t snap_seq;
  ::SnapContext snapc;
  ...
}
```
在librados::IoCtxImpl里，当打开一个image时候，需要读取块的元数据去构建该结构（初始化一下），
如果打开的是卷的快照，那么snap_seq的值就是该snap对应的快照序号，
否则snap_seq就为CEPH_NOSNAP(-2),表示操作的不是快照，而是卷本身；

SnapSet用于保存Server端（OSD）与快照相关的信息：
```c++
struct SnapSet{
  snapid_t seq;     //最新的快照序号
  bool head_exists;
  vector<snapid_t> snaps;   //所有的快照序号列表（降序排列）
  vector<snapid_t> clones;  //所有的clone对象序号列表 （升序排列）
  map<snapid_t, interval_set<uint64_t> > clone_overlap;
  map<snapid_t, uint64> clone_size;
}
```

clone_overlap: 保存本次clone对象和上次clone对象（有可能是head对象）的overlap（重叠）的部分。
clone操作后，每次写操作，都要维护这个信息； 这个信息用于数据恢复阶段对象恢复的优化；

在Head对象的xattr中保存key为snapset， value为SnapSet结构序列化后的值；
在Sanp对象的xattr中保存key为user.cephos.seq的snap_seq值；

### RBD快照创建

- 向Monitor发送请求，获取一个最新的快照序号snap_seq的值；
- 把该次快照的snap_name和snap_seq的值保存到RBD的元数据中；
在RBD的元数据里保存了所有快照的名字和对应的snap_seq号，并不会触发OSD端的数据操作，所以很快；


### 快照的写操作

  客户端的每次写操作，消息中必须带数据结构SnapContext信息，包含了客户端认为的最新快照序列号seq, 以及该对象的所有序号snaps的列表。
在OSD端，对象的Snap相关信息则在SnapSet数据结构中，当有写操作时，处理过程按照如下规则进行：

- 情景一： librbd(SnapContext)的seq < OSD(SnapSet)的seq：</br>
  直接返回-EOLDSNAP错误;   <br>
  一般而言，客户端（librbd）始终保持最新的快照序号；如果客户端不是最新的快照序号，则可能是：

    - 多个客户端情况下，其他客户端创建了快照，本客户端没有获取到最新的快照序号
  原理：Ceph rbd有一套Watcher回调通知机制来实现快照序号的更新，如果其他客户端对一个卷作了快照，会产生了一个最新的快照序号。OSD端接收到最新快照序号变化后，通知相应的连接客户端更新最新的快照序号。如果客户端没有及时更新，也没有太大问题，OSD端会返回客户端-EOLDSNAP，客户端会主动更新为最新的快照序号，重新发起写操作；

- 情景二：如果head对象不存在，创建该对象并写入数据，用SnapContext相应的信息更新SnapSet的信息；
- 情景三：如果librbd的seq = OSD的seq：做正常的读写
- 情景四：librbd的seq > OSD的seq：<br>
    - 对当前head对象做copy操作，clone出一个新的快照对象，该快照对象的snap序号为最新的序号，并把clone操作记录在clones列表里；也就是把最新的快照序号加入到clones列表里；
    - 用SnapContext的 seq 和 snaps 值更新SnapSet的seq 和 snaps值；
    - 写入最新的数据到head对象中；

```c++
//注释：捕获与正在进行的读写相关联的所有对象状态。
// osd/ReplicatedPG.h
struct OpContext{
  OpRequestRef op;
  osd_reqid_t reqid;
  vector<OSDOp> &ops;

  const ObjectState *obs;   //old ObjectState
  const SnapSet *snapset;   //old snapset, OSD端保存的快照信息

  SnapContext snapc;           // writer snap context， 写操作自带的，也就是librbd的SnapContext信息；
  ObjectState new_obs;  //resulting ObjectState 新的SnapSet
  SnapSet     new_snapset;  //resulting SnapSet(in case of a write)
  object_stat_sum_t delta_stats;

  bool modify;          // (force) modification (even if op_t is empty)
  bool user_modify;     // user-visible modification
  bool undirty;         // user explicitly un-dirtying this object
  bool cache_evict;     ///< true if this is a cache eviction
  bool ignore_cache;    ///< true if IGNORE_CACHE flag is set
  bool ignore_log_op_stats;  // don't log op stats

  // side effects
  list<pair<watch_info_t,bool> > watch_connects; ///< new watch + will_ping flag
  list<watch_disconnect_t> watch_disconnects; ///< old watch + send_discon
  list<notify_info_t> notifies;
  struct NotifyAck {
    boost::optional<uint64_t> watch_cookie;
    uint64_t notify_id;
    bufferlist reply_bl;
    explicit NotifyAck(uint64_t notify_id) : notify_id(notify_id) {}
    NotifyAck(uint64_t notify_id, uint64_t cookie, bufferlist& rbl)
  : watch_cookie(cookie), notify_id(notify_id) {
  reply_bl.claim(rbl);
    }
  };
  list<NotifyAck> notify_acks;

  uint64_t bytes_written, bytes_read;

  utime_t mtime;

  eversion_t at_version;       // pg's current version pointer
  version_t user_at_version;   // pg's current user version pointer

  int current_osd_subop_num;

  PGBackend::PGTransactionUPtr op_t;
  vector<pg_log_entry_t> log;
  boost::optional<pg_hit_set_history_t> updated_hset_history;

  interval_set<uint64_t> modified_ranges;
  ObjectContextRef obc;
  map<hobject_t,ObjectContextRef, hobject_t::BitwiseComparator> src_obc;
  ObjectContextRef clone_obc;    // if we created a clone
  ObjectContextRef snapset_obc;  // if we created/deleted a snapdir

  int data_off;        // FIXME: we may want to kill this msgr hint off at some point!

  MOSDOpReply *reply;
  utime_t readable_stamp;  // when applied on all replicas
  ReplicatedPG *pg;

  int num_read;    ///< count read ops
  int num_write;   ///< count update ops

  vector<pair<osd_reqid_t, version_t> > extra_reqids;

  CopyFromCallback *copy_cb;

  hobject_t new_temp_oid, discard_temp_oid;  ///< temp objects we should start/stop tracking

  // pending xattr updates
  map<ObjectContextRef,
  map<string, boost::optional<bufferlist> > > pending_attrs;

  list<std::function<void()>> on_applied;
  list<std::function<void()>> on_committed;
  list<std::function<void()>> on_finish;
  list<std::function<void()>> on_success;
  bool sent_ack;
  bool sent_disk;
  ......
}
```
- OSD端的写操作流程中， ReplicatedPG::execute_ctx中，把客户端消息中的SnapContext信息保存在OpContext的snapc中：

```c++
ctx->snapc.seq = m->get_snap_seq();
ctx->snapc.snaps = m->get_snaps();
```
- 在ReplicatedPG::prepare_transaction里调用了函数ReplicatedPG::make_writeable来完成快照相关的操作：

### 快照的读操作

快照读取数据时，输入参数为RBd的名字和快照的名字，RBD客户端通过访问RBD的元数据，来获取快照对应的snap_id,也就是快照对应的snap_seq值；
在OSD端，获取head对象保存的SnapSet数据结构，然后根据SnapSet中的snaps和clones值来计算快照所对应的正确的快照对象的ObjectContext；

- clinet(librbd)对象快照oid.snap > osd 端快照序号 ssc->snapset.seq, 获取head对象就是该快照对应的时间数据对象。
- 计算oid.snap首次大于ssc->snapset。clones列表中的克隆对象，就是oid对应的克隆对象；













//
