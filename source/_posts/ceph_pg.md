---
  title: pg
---

### pg概述

- ReplicatedPG::do_request
  |- ReplicatedPG::do_op  //仅仅分析请求类型为"CEPH_MSG_OSD_OP"
        |- ReplicatedPG::find_object_context
              |-ReplicatedPG::execute_ctx    |- ReplicatedPG::get_object_context
                    |- ReplicatedPG::prepare_transaction
                          |- ReplicatedPG::complete_read_ctx
                          |- ReplicatedPG::start_async_reads
                          |- ReplicatedPG::calc_trim_to
                          |- ReplicatedPG::issue_repop  //向副本发送同步请求op
                          |- ReplicatedPG::eval_repop   //检查发向各个副本的同步操作是否reply成功
  ReplicatedPG::issue_repop
    |-ReplicatedBackend::submit_transaction
      |- ReplicatedBackend::issue_op               |- ReplicatedBackend::parent_transactions
         |- OSDService::send_message_osd_cluster          |- ReplicatedPG::queue_transactions
                                                              |- FileStore


- acting set
  pg对应副本所在的OSD列表，列表是有序的，第一个osd 为 primary. 在通常情况下，up set和acting set 相同

- up set
  假设:acting set [0, 1, 2], 此时osd.0故障，导致monitor重新分配pg的acting set为[3, 1, 2], 此时osd.3不能承载pg的读io，所以向monitor申请一个临时的pg的osd.1 为主osd来承载读写，此时acting set为[0, 1, 2], up set [1, 3, 2]; acting set 与 up set不一致;
  当osd.3 backfill完成之后, up set, acting set 均为[0, 1, 2]

### PGBackend
PGBackend定义了逻辑上处理IO和副本

- 处理client 操作
- 处理对象恢复
- 处理对象访问
- 处理scrub, deep-scrub, repair

 ```c++
// osd/PGBackend.h
class PGBackend{
protected:
  ObjectStore *store;
  const coll_t coll;
  ObjectStore::CollectionHandle &ch;

//PGBackend 回调接口
public:
  class Listener{
  public:
      // Recovery
  ......
    struct RecoveryHandle{
        .....
    }
  }
}

struct PG_SendMessageOnConn: public Context{
  PGBackend::Listener *pg;
  ...
}

struct PG_RecoveryQueueAsync : public Context{
  PGBackend::Listener *pg;
  ...
}
 ```

### ReplicatedBackend(多副本后端)

 ```c++
// osd/ReplicatedBackend.h
class ReplicatedBackend : public PGBackend{
  // RPGHandle: replicated PG handle
  struct RPGHandle : public PGBackend::RecoveryHandle{
    map<pg_shard_t, vector<PushOp> pushes;
    map<pg_shard_t, vector<PullOp> pulls;
  }

  class RPCReadPred : public IsPGReadablePredicate{

  }

  class RPCReadPred : public IsPGReadablePredicate{

  }

private:
  struct PushInfo {
    ......
  };
  map<hobject_t, map<pg_shard_t, PushInfo>, hobject_t::BitwiseComparator> pushing;

  struct PullInfo{
    ......
  };

  map<hobject_t, PullInfo, hobject_t::BitwiseComparator> pulling;

}
```

```c++
// osd/ReplicatedPG.h

class ReplicatedPG : public PG, public PGBackend::Listener{
  friend class OSD;
  .......


}

```c++
//monitor向OSD端推送OSDMAP更新信息：
OSD::_dispatch()
  |- OSD::handle_osd_map()
      |- OSD::consume_map()
  |- PG::queue_null()
      |- PG::queue_peering_event()
          |- peering_queue.push_back(evt)   //CephPeeringEvtRef evt; 加入peering队列
          |- osd->queue_for_peering(this)   //osd进行peering处理流程
                  |- OSDService::queue_for_peering(PG *pg)
                      |- peering_wq.queue(pg)     //ThreadPool::BatchWorkQueue<PG> &peering_wq;

  OSD::_dispatch()函数是消息处理的路由函数，根据消息类型调用具体的处理函数。对于处理Monitor节点发送过来的OSDMap消息，则由handle_osd_map()函数进行处理。在handle_osd_map()函数中首先对OSDMap消息进行解析且得到OSDMap且保存，之后调用consume_map()做进一步处理。在consume_map()函数中遍历该OSD节点上已有的PGs且统计出primary/replicas/stray的数量，其次唤醒等待OSDMap的PGs，最后遍历当前OSD节点上所有PGs且调用PG::queue_null()函数将OSD节点上所有PGs添加到peering队列中。

//线程池工作队列开始工作, 入口
void PG::handle_peering_event(CephPeeringEvtRef evt, RecoveryCtx *rctx){
  ...
  recovery_state.handle_event(evt, rctx);
}

void handle_event(const boost::statechart::event_base &evt, RecoveryCtx *rctx)
{
  start_handle(rctx);
  machine.process_event(evt);
  end_handle();
}

void PG::RecoveryState::start_handle(RecoveryCtx *new_ctx){
  ...
}

class RecoveryState{
  void start_handle(RecoveryCtx *new_ctx);
  void end_handle();

private:
  class RecoveryMachine : public boost::statechart::state_machine<RecoveryMachine, Inital> {
    RecoveryState *state;
    ...
  }
}
```


```c++
struct C_OnMapCommit : public Context{
  OSD *osd;
  epoch_t first, last;
  MOSDMap *msg;
  C_OnMapCommit(OSD *o, epoch_t f, epoch_t l, MOSDMap *m)
    : osd(o), first(f), last(l), msg(m) { }
  void finish(int r){
    osd -> _committed_osd_maps(first, last, msg) ;
  }
}

/*
 * Context - abstract callback class
 */
 class Context{
   Context(const Context& other);
   const Context& operator=(const Context& other);
  protected:
    virtual void finish(int r) = 0;
  public:
    Context() {}
    virtual ~Context() {}
    virtual void complete(int r){
      finish(r);
      delete this;
    }
 };
```

ObjectStore
