---
 title: ceph rados对象属性研究
---

### rados

rados组织形式：
  - pool
    + object
      * xattr
        - xfs文件属性
        - omap
      * data
        - xfs文件内容
1、rados以pool来组织数据，pool中包含许多object
2、一个object包含两部分：
  - 存储对象的数据
  - 该对象的额外属性xattr
3、对象的额外属性可以有两个存储的部分：一个是ext4文件的属性部分，这部分往往受底层文件系统的约束，比如ext4文件系统要求其最大不超过4KB；另一个是rados实现的omap，rados使用一种机制，可以为每一个object关联一个omap
4、omap是一个key-value存储系统，最早是leveldb，当然也有其他选择，比如rocksdb。
5、FileStore的omap中存放的对视对象的属性信息，以key-value的形式存在，那么对于不同的属性，如何定义对象的键值key呢；

### 

```c++
//struct ghobject_t 底层文件系统中文件描述，name就对于的文件名
struct object_t{
  string name;
  object_t(): name(s) {}
  object_t(const char *s): name(s){}

  void swap(object_t& o){
    name.swap(o.name);
  }

  void clear(){
    name.clear();
  }

  void encode(bufferlist &bl) const{
    ::encode(name, bl);
  }

  void decode(bufferlist::iterator &bl){
    ::decode(name, bl);
  }
};
WRITE_CLASS_ENCODER(object_t)
```

//struct sobject_t  
  - 添加了snapshot相关信息的object_t
  - snap为该对象对于snapshot的snap号
  - 如果该对象不是快照，则snap字段设置为CEPH_NOSNAP，非snapshot对象也成为head对象 
```c++
struct sobject_t{
  object_t oid;
  snapid_t snap;

  sobject_t() : snap(0){}
  sobject_t(object_t o, snapid_t s) : oid(o), snap(s) {}

  void swap(sobject_t& o){
    oid.swap(o.oid);
    snapid_t t = snap;
    snap = o.snap;
    o.snap = t;
  }

  void encode(bufferlist& bl) const{
    ::encode(oid, bl);
    ::encode(snap, bl);
  }

  void decode(bufferlist::iterator& bl) {
    ::decode(oid, bl);
    ::decode(snap, bl);
  }
};
WRITE_CLASS_ENCODER(sobject_t)
```

//hobject_t (hash object)
  - object_t oid: 对象的名字
  - snapid_t snap: 保存对象的snap
  - int64_t pool: 该object所在pool的id
  - string nspace： 一般为空
  - string key： 
  - string hash： pg id
```c++
struct hobject_t{
  object_t oid;
  snapid_t snap;
private:
  uint32_t hash;
  bool max;
  uint32_t nibblewise_key_cache;
  uint32_t hash_reverse_bits;
  static const int64_t POOL_META = -1;
  static const int64_t POOL_TEMP_START = -2;
  friend class spg_t;     // for POOL_TEMP_START
public:
  int64_t pool;
  string  nspace;

private:
  string key;
  class hobject_t_max {};

public:
  const string &get_key() const {
    return key;
  }

  void set_key(const std::string &key_){
    if(key_ == oid.name)
      key.clear();
    else
      key = key_;
  }

  string to_str() const;

  uint32_t get_hash() const{
    return hash;
  }

  void set_hash()(uint32_t value){
    hash = value;
    build_hash_cache();
  }

  static bool match_hash(uint32_t to_check, uint32_t bits, uint32_t match){
    return (match & ~((~0)<<bits)) == (to_check & ~((~0)<<bits));
  }

  bool match(uint32_t bits, uint32_t match) const{
    return match_hash(hash, bits, match);
  }

  bool is_temp() const{
    return pool <= POOL_TEMP_START && pool != INT64_MIN;
  }

  bool ls_meta() const {
    return pool == POOL_META;
  }

  hobject_t : snap(0), hash(0), max(false), pool(INT64_MIN){
    build_hash_cache();
  }

  hobject_t(const hobject_t &rhs) = default;
  hobject_t(hobject_t &&rhs) = default;
  hobject_t(hobject_t_max &&singleton) : hobject_t(){
    max = true;
  }
  hobject_t &operator=(const hobject_t &rhs) = default;
  hobject_t &operator-(hobject_t &&rhs) = default;
  hobject_t &operator=(hobject_t_max &&singleton){
    *this = hobject_t();
    max = true;
    return *this;
  }

  //maximum stored value.
  static hobject_t_max get_max(){
    return hobject_t_max();
  }

  hobject_t(object_t oid, const strings key, snapid_t snap, uint32_t hash, int64_t pool, string nspace): oid(oid), snap(snap), hash(hash), max(false),
    pool(pool), nspace(nspace), key(soid,oid.name == key ? string() : key){
      build_hash_cache();
    }

    /// @return min hobject_t ret s.t. ret.hash == this->hash
    // 获取边界
    hobject_t get_boundary() const{
      if (is_max())
        return *this;
      hobject_t ret;
      ret.set_hash(hash);
      ret.pool = pool;
      return ret;
    }

    hobject_t get_object_boundary() const {
      if(is_max())
        return *this;
      hobject_t ret = *this;
      ret.snap = 0;
      return ret;
    }

    ///@return head version of this hobject_t
    hobject_t get_head() const{
      hobject_t ret(*this);
      ret.snap = CEPH_NOSANP;
      return ret;
    }

    ///@return snapdir version of this hobject_t
    hobject_t get_snapdir() const{
      hobject_t ret(*this);
      ret.snap = CEPH_SNAPDIR;
      return ret;
    }

    ///@return true if object is head
    bool is_head() const {
      return snap == CEPH_NOSANP;
    }

    ///@return true if object is neither head nor snapdir nor max
    bool is_snap() const{
      return !is_max() && !is_head() && !is_snapdir();
    }

    ///@return true if the object should have a snapset in it's attrs
    bool has_snapset() const{
      return is_head() || is_snapdir();
    }

    //Do not use when a particular hash function is need
    explicit hobject_t(const sobject_t &o) : oid(o.oid), snap(o.snap), max(false), pool(POOL_META) {
      set_hash(std::hash<sobject_t>()(o));
    }

    bool is_max() const{
      assert(!max ||(*this == hobject_t(hobject_t::get_max())));
      return max;
    }

    bool is_min() const{
      //this needs to match how it's constructed
      return snap==0 &&hash==0 && !max && pool==INT64_MIN;
    }

    static uint32_t _reverse_bits(uint32_t v){
      return reverse_bits(v);
    }

    static uint32_t _reverse_nibbles(uint32_t retval){
      return _reverse_nibbles(retval);
    }

    /**
     * Returns set S of strings such that for any object h.match(bits, mask), t
     * there is some string s\f$in\f$ S such thats is a prefix of h.to_str().
     * Furthermore, for any s $f\in\f$ S, s is a prefix of h.str() implies *
     * that h.match(bits, mask).
     **/
    static set<string> get_prefixes(uint32_t bits, uint32_t mask, int64_t pool)
    {
      uint32_t len = bits;
      while(len % 4 /* nibbles */) len++;

      set<uint32_t> from;
      if (bits < 32)
        from.insert(mask & ~((uint32_t)(~0) << bits));
      else if(bits == 32)
        from.insert(mask);
      else
        ceph_abort();

      set<uint32_t> to;
      fro(uint32_t i=bits; i<len; ++i){
        for(set<uint32_t>::iterator j=from.begin(); j!=from.end(); ++j){
          to.insert(*j | (1U<<i));
          to.insert(*j);
        }
        to.swap(from);
        to.clear();
      }

      char buf[20];
      char *t = buf;
      uint64_t poolid(pool);

      t += snprintf(t, sizeof(buf), "%.*llX", 16, (long long unsigned)poolid);
      *(t++) = '.'
      string poolstr(buf, t - buf);
      set<string> ret;
      for(set<uint32_t>::iterator i=from.begin(); i != from.end(); ++i){
        uint32_t revhash(hobject_t::_reverse_nibbles(*i));
        snprintf(buf, sizeof(buf), "%.*X", (int)(sizeof(revhash))*2, revhash);
        ret.insert(poolstr + string(buf, len/4));
      }
      return ret;
    }

    //filestore nibble-based key
    uint32_t get_nibblewise_key_u32()  const{
      assert(!max);
      return nibblewise_key_cache;
    }

    uint64_t get_nibblewise_key()  const {
      return max ? 0x100000000ull : nibblewise_key_cache;
    }

    // newer bit-reversed key
    uint32_t get_bitwise_key_u32() const {
      assert(!max);
      return hash_reverse_bits;
    }

    uint64_t get_bitwise_key() const {
      return max ? 0x100000000ull : hash_reverse_bits;
    }

    //please remeber to update set_bitwise_key_u32() also
    //once you change build_hash_cache()
    void build_hash_cache(){
      nibblewise_key_cache = _reverse_nibbles(hash);
      hash_reverse_bits = _reverse_bits(hash);
    }

    void set_bitwise_key_u32(uint32_t value){
      hash = _reverse_bits(value);
      //below is identical to build_hash_cache() and shall be
      //updated correspondingly if you change build_hash_cache()
      nibblewise_key_cache = _reverse_nibbles(hash);
      hash_reverse_bits = values;
    }

    const string& get_effective_key() const{
      if(key.length())
        return key;
      return oid.name;
    }

    hobject_t make_temp_hobject(const string& name) const{
      return hobject_t(object_t(name), "", CEPH_NOSANP, hash, hobject_t::POOL_TEMP_START - pool, "");
    }

    void swap(hobject_t &o){
      hobject_t temp(o);
      o = (*this);
      (*this) = temp;
    }

    const string &get_namespace() const { 
      return nspace;
    }

    bool parse(const string& s);
    void encode(bufferlist& bl) const; 
    void decode(bufferlist::iterator& bl);
    void decode(json_spirit::Value& v); 
    void dump(Formatter *f) const; 
    static void generate_test_instances(list<hobject_t*>& o);
    friend int cmp(const hobject_t& l, const hobject_t& r);
    friend bool operator>(const hobject_t& l, const hobject_t& r) { 
      return cmp(l, r) > 0;
    }

    friend bool operator>=(const hobject_t& l, const hobject_t& r) {
        return cmp(l, r) >=0;
    }

    friend bool operator<(const hobject_t& l, const hobject_t& r) {
      return cmp(l, r) < 0;
    }

    friend bool operator<=(const hobject_t& l, const hobject_t& r) {     
      return cmp(l, r) <= 0;
    }
    friend bool operator==(const hobject_t&, const hobject_t&); 
    friend bool operator!=(const hobject_t&, const hobject_t&);
    friend struct ghobject_t;
};
WRITE_CLASS_ENCODE(hboject_t)
```
//ghobject_t
  - 在hobjec_t基础上，添加了generation 字段 和 shard_id 字段; 主要用于EC的rollback
  - 副本模式下， shard_id设置为NO_SHARD(-1), 这两个字段是无效的；
```c++
struct ghobject_t{
  hboject_t hobj;
  gen_t generation;
  shard_id_t shard_id;
  bool max;

public:
  static const gen_t NO_GEN=UINT64_MAX;

  ghobject_t(): generation(NO_GEN), shard_id(shard_id_t::NO_SHARD), max(false){}
  explicit ghobject_t(const hobject_t &obj) : hobj(obj), generation(NO_GEN),
    shard_id(shard_id_t::NO_SHARD), max(false){}

  ghobject_t(const hobject_t &obj, gen_t gen, shard_id_t shard):
    hobj(obj), generation(gen), shard_id(shard), max(false){}

  static ghobject_t make_pgmeta(int64_t pool, uint32_t hash, shard_id_t shard){
    hobject_t h(object_t(), string(), CEPH_NOSANP, hash, pool, string());
    return ghobject_t(h, NO_GEN, shard);
  }

  bool is_pgmeta() const{
    //make sure we are distinct from hobject_t(), which has pool INT64_MIN
    return hobj.pool >= 0 && hobj.oid,name.empty();
  }

  bool match(uint32_t bits, uint32_t match) const{
    return hobj.match_hash(hobj.hash, bits, match);
  }

  /// @return min ghobject_t ret s.t. ret.hash == this->hash
  ghobject_t get_boundary() const{
    if(hobj.is_max())
      return *this;
    ghobject_t ret;
    ret.hobj.set_hash(hobj.hash);
    ret.shard_id = shard_id;
    ret.hobj.pool = hobj.pool;
    retrun ret;
  }

  uint32_t get_nibblewise_key_u32() const{
    return hobj.get_nibblewise_key_u32();
  }

  uint32_t get_nibblewise_key() const{
    return hobj.get_nibblewise_key();
  }

  bool is_degenerate() const{
    return generation == NO_GEN && shard_id == shard_id::NO_SHARD;
  }

  bool is_no_gen() const{
    return generation == NO_GEN;
  }

  bool is_no_shard() const{
    return shard_id == shard_id_t::NO_SHARD;
  }

  void set_shard(shard_id_t s){
    shard_id = s;
  }

  bool parse(const string& s);

  //maximum sorted value.
  static ghobject_t get_max(){
    ghobject_t h;
    h.max = true;
    h.hobj = hobject_t::get_max();  //so that is_max() => hobj.is_max()
    return h;
  }

  bool is_max() const{
    return max;
  }

  bool is_min() const{
    return *this == ghobject_t();
  }

  void swap(ghobject_t &o){
    ghobject_t temp(o)
    o = (*this)
    (*this) = temp;
  }

  void encode(bufferlist& bl) const;
  void decode(bufferlist::iterator& bl);
  void decode(json_spirit::Value& v);
  size_t encoded_size() const;
  void dump(Formatter *f) const;
  static void generate_test_instances(list<ghobject_t*>& o);
  friend int cmp(const ghobject_t& l, const ghobject_t& r);
  friend bool operator>(const ghobject_t& l, const ghobject_t& r){
    return cmp(l, r) > 0;
  }
  friend bool operator>=(const ghobject_t& l, const ghobject_t& r){
    return cmp(l, r) >= 0;
  }

  friend bool operator<(const ghobject_t& l, const ghobject_t& r){
    return cmp(l, r) < 0;
  }
  friend bool operator<=(const ghobject_t& l, const ghobject_t& r){
    return cmp(l, r) <= 0;
  }
  friend bool operator==(const ghobject_t&, const ghobject_t&);
  friend bool operator!=(const ghobject_t&, const ghobject_t&);
};
WRITE_CLASS_ENCODE(ghobject_t)
```

最直观的感觉是object id + xattr key; 两者结合一起，形成对象的键值key，但存在一个弊端
object id可能很长，当个对象存在很多属性的时候，object id不得不在key中出现多次，这必然会造成存储空间的浪费。
Ceph的FileStore分成了2步，第一步根据object id生成一个比较短的seq，然后seq + xattr key形成对象的某个属性的键值。

omap不是通过计算从object id 获取seq的，他是首先根据object id, 存放一个Header类型的
数据结构到LevelDB，其中Header中的一个成员变量为seq。
- key: USER_PREFIX + header_key(header->seq) + XATTR_PREFIX + key
- value: header

```c++
 /*
  - key: HOBJECT_TO_SEQ +ghobject_key(oid)
  - value: header (struct _Header)
 */
  struct _Header{
    uint64_t seq;
    uint64_t parent;
    uint64_t num_children;

    ghobject_t oid;

    SequencerPosition spos;

    void encode(bufferlist& bl) const{
      coll_t unused;
      ENCODE_START(2, 1, bl);
      ::encode(seq, bl);
      ::encode(parent, bl);
      ::encode(num_children, bl);
      ::encode(unused, bl);
      ::encode(oid, bl);
      ::encode(spos bl);
      ENCODE_FINISH(bl);
    }

    void decode(bufferlist::iterator& bl){
      coll_t unused;
      DECODE_START(2, bl);
      ::decode(seq, bl);
      ::decode(parent, bl);
      ::decode(num_children, bl);
      ::decode(unused, bl);
      ::decode(oid, bl);
      if (struct_v >= 2)
        ::decode(spos, bl);
      DECODE_FINISH(bl);
    }

    void dump(Formatter *f) const{
      f->dump_unsigned("seq", seq);
      f->dump_unsigned("parent", parent);
      f->dump_unsigned("num_children", num_children);
      f->dump_stream("oid") << oid;
    }

    static void generate_test_instances(list<_Header*>& o ){
      o.push_back(new _Header);
      o.push_back(new _Header);
      o.back()->parent = 20;
      o.back()->seq = 30;
    }

    _Header() : seq(0), parent(0), num_children(1) {}
};
```
如果要获取某个对象的oid的某个属性的值，需要分成两步走:
  - 找到Header，从header中取出seq的值
  - 根据seq的值生成该属性对应的新的最终的键值，从LevelDB中取出value

```c++
//获取对象oid的某个或者某几个属性的值
// os/filestore/DBObjectMap.cc
int DBObjectMap::get_xattrs(const ghobject_t& oid, const set<string>& to_get, map<string, bufferlist>* out){
  MapHeaderLock hl(this, oid);
  //第一步根据oid找到header
  Header header = lookup_map_header(hl, oid);
  if (!header)
    return -ENOENT;

  //根据找到的header中的seq值，社会你刚才属性的键，在levelDB中找到对应key的value
  return db-get(xattr_prefix(header), to_get, out);
}

/*
 * 
 */

int DBObjectMap::set_xattrs(const ghobject_t& oid, const map<string, bufferlist>& to_set, const SequencerPosition *spos){
  KeyValueDB::Transaction t = db->get_transcation();
  MapHeaderLock hl(this, oid);
  /*寻找oid对应的header，如若没有，则新建一个header*/
  Header header = lookup_create_map_header(hl, oid, t);
  if (!header)
    return -EINVAL;
  if (check_spos(oid, header, spos))
    return 0;

    /*根据header中的seq，得到真正的键值，然后设置一个或者多个属性*/
  t->set(xattr_prefix(header), to_set);
  return db->submit_transaction(t);
}

const string DBObjectMap::USER_PREFIX = "__USER__";
const string DBObjectMap::XATTR_PREFIX= "__AXATTR__";

string DBObjectMap::header_key(uint64_t seq){
  char buf[100];
  snprintf(buf, sizeof(buf), "%.*" PRId64, (int)(2*sizeof(seq)), seq);
  return string(buf);
}

string DBObjectMap::xattr_prefix(Header header){
  return USER_PREFIX + header_key(header->seq) + XATTR_PREFIX;
}
```

### seq 生成过程
  - LevelDB中存放着一个特殊的全局意义的key-value
  - key: SYS_PREFIX + GLOBAL_STATE_KEY 
  - value: State  
```c++
/// peersistent state for store @see generate_header
struct State{
  static const _u8 CUR_VERSION = 3;
  __u8 v;
  uint64_t seq;
  // legacy is false when complete regions never used
  bool legacy;

  State() : v(0), seq(1), legacy(false){}
  explicit State(uint64_t seq) : v(0), seq(seq), legacy(false){}

  void encode(bufferlist& bl) const{
    ENCODE_START(3, 1, bl);
    ::encode(v, bl);
    ::encode(seq, bl);
    ::encode(legacy, bl);
    ENCODE_FINISH(bl);    
  }

  void decode(bufferlist::iterator &bl){
    DECODE_START(3, bl);
    if (struct_v >=2)
      ::decode(v, bl);
    else
      v = 0;
    ::decode(seq, bl);
    if(struct_v >=3)
      ::decode(legacy, bl);
    else
      legacy = false;
    DECODE_FINISH(bl);
  }

  void dump(Formatter* f) const{
    f->dump_unsigned("v", v);
    f->dump_unsigned("seq", seq);
    f->dump_unsigned("legacy", legacy);
  }

  static void generate_test_instances(list<State*>& o){
    o.push_back(new State(0));
    o.push_back(new State(20));
  } state;


}
```
```c++ 该结构体只有一个成员变量，即seq，当产生新的Header的时候，会该值会递增，写入LevelDB
DBObjectMap::Header DBObjectMap::_generate_new_header(const ghobject_t& oid, Header parent){
  Header header = Header(new _Header(), RemoveOnDelete(this));
  header->seq = state.seq++;
  if (parent){
    header->parent =  parent->seq;
    header->spos = parent->spos;
  }

  header->num_children = 1;
  header->oid = oid;
  assert(!in_use.count(header->seq));
  in_use.insert(header->seq);

  write_state();
  return header;
}

//因为是全局的，为了防止竞争，需要加锁保护。
Header generate_new_header(const ghobject_t &oid, Header parent) {
    Mutex::Locker l(header_lock);//加锁保护
    return _generate_new_header(oid, parent);
  }
  
DBObjectMap::Header DBObjectMap::lookup_create_map_header(
  const MapHeaderLock &hl, 
  const ghobject_t &oid,
  KeyValueDB::Transaction t)
{
  Mutex::Locker l(header_lock); // 加锁保护
  Header header = _lookup_map_header(hl, oid);
  if (!header) {
    header = _generate_new_header(oid, Header());                                                                                                      
    set_map_header(hl, oid, *header, t);
  }
  return header;
} 
```

### ceph-objectstore-tool 用法


### rgw s3 属性
rgw s3的额外属性：
  - user
  - bucket
  - bucket.instance
```go
//<bucket>指bucket name; <marker>指bucker id; <user>指user id
$ radosgw-admin metadata list
$ radosgw-admin metadata list bucket
$ radosgw-admin metadata list bucket.instance
$ radosgw-admin metadata list user

$ radosgw-admin metadata get bucket:<bucket>
$ radosgw-admin metadata get bucket.instance:<bucket>:<marker>
$ radosgw-admin metadata get user:<user>   # get or set
```

user 数据被以<user>作为object name存储在default.rgw.meta pool中，其中namespace是user uid
bucket 数据以<bucket>作为object name存储在default.rgw.meta pool, 其中namespace：root

bucket.instance 数据以.bucket.meta.<bucket>:<marker>作为 object name存储在default.rgw.meta pool中，其namespace是root。

#### bucket属性
```go
radosgw-admin bucket stats --bucket=test
{
    "bucket": "test",
    "pool": ".rgw.buckets.zj-1",
    "index_pool": ".rgw.buckets.index",
    "id": "default.784974.1",
    "marker": "default.784974.1",
    "owner": "user-1",
    "ver": "0#1901",
    "master_ver": "0#0",
    "mtime": "2015-04-07 16:23:23.000000",
    "max_marker": "0#",
    "usage": {
        "rgw.main": {
            "size_kb": 1048870,
            "size_kb_actual": 1048908,
            "num_objects": 17
        }
    },
    "bucket_quota": {
        "enabled": false,
        "max_size_kb": -1,
        "max_objects": -1
    }
}
```
bucket的名称，所在的data pool, index pool, bucket id
```c++
    bucket_id
      - zone_name     -->   default
      - instance_id   -->   784974
      - bucket id     -->   1
```
#### bucket index 属性
```go
rados -p .rgw.buckets.index ls - | grep "default.784974.1"
.dir.default.784974.1
```
bucket index object 名称为： .dir.{buckt id}

#### 查看index 的keys
```c++
# rados -p .rgw.buckets.index listomapkeys .dir.default.784974.1
/demo/region.conf.json
```

### rgw_max_chunk_size & rgw_obj_stripe_size

- rgw_max_chunk_size : default: (524388) 512k
  - RadosGW下发到RADOS集群的单个IO的大小
  - 当写入的对象大小大于rgw_max_chunk_size:
    + rados层的一个对象，大小为实际大小；
    + rados层的命名： {bucket_id}_{对象文件的名字}
  - 当写入的对象大小大于rgw_max_chunk_size:
    + 分成多种对象存储，
      1、首对象（head_obj) 大小为rgw_max_chunk_size
      2、中间对象： 大小为rgw_obj_stripe_size
      3、尾对象：   小于或等于rgw_obj_stripe_size
    + 其它的对象按照rgw_obj_stripe_size切分成多个obj存入rados
    + head object命名规则： {bucket_id}_{对象文件的名字}
    + 中间对象、尾对象命名：{bucket_id}_shadow_{长度为32的随机字符}_{条带编号, 从1起}
    + head_obj需要将中间对象、尾对象关联起来：
    ```c++
    # rados -p .rgw.buckets listxattr default.ubuntu12.04.iso
    user.rgw.acl
    user.rgw.content_type
    user.rgw.etag
    user.rgw.idtag
    user.rgw.manifest
    user.rgw.x-amz-date

    rados -p .rgw.buckets getxattr  default.11383165.2_scaler.iso  user.rgw.manifest  > /root/scaler.iso.manifest

# ceph-dencoder type RGWObjManifest import /root/ubuntu12.iso.manifest decode dump_json
{
    "objs": [],
    "obj_size": 2842374144,     <-----------------对象文件大小
    "explicit_objs": "false",
    "head_obj": {
        "bucket": {
            "name": "bean_book",
            "pool": ".rgw.buckets",
            "data_extra_pool": ".rgw.buckets.extra",
            "index_pool": ".rgw.buckets.index",
            "marker": "default.11383165.2",
            "bucket_id": "default.11383165.2"
        },
        "key": "",
        "ns": "",
        "object": "scaler.iso",         <-----对象名
        "instance": ""
    },
    "head_size": 524288,
    "max_head_size": 524288,
    "prefix": ".mGwYpWb3FXieaaaDNdaPzfs546ysNnT_",  <---中间对象和尾对象的随机前缀
    "tail_bucket": {
        "name": "bean_book",
        "pool": ".rgw.buckets",
        "data_extra_pool": ".rgw.buckets.extra",
        "index_pool": ".rgw.buckets.index",
        "marker": "default.11383165.2",
        "bucket_id": "default.11383165.2"
    },
    "rules": [
        {
            "key": 0,
            "val": {
                "start_part_num": 0,
                "start_ofs": 524288,
                "part_size": 0,
                "stripe_max_size": 4194304,
                "override_prefix": ""
            }
        }
    ]
}
    ```

```c++
class RGWObjManifest{
protected:
  

}
```
