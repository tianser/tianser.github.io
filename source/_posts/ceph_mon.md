---
  title: ceph-mon
---

mon->preinit()
messenger->start()
mon->init()

```c++
// mon/Monitor.cc
int Monitor::preinit()
{
    lock.Lock();
    dout(1) << "preinit fsid " << monmap->fsid << dendl;

    assert(!logger);
    {
        PerfCountersBuilder pcb(g_ceph_context, "mon", l_mon_first, l_mon_last);
        logger = pcb.create_perf_counters();
        cct->get_perfcounters_collection()->add(logger);
    }
    assert(!cluster_logger);  
    {
    PerfCountersBuilder pcb(g_ceph_context, "cluster", l_cluster_first, l_cluster_last);
    pcb.add_u64(l_cluster_num_mon, "num_mon");
    // ......
    cluster_logger = pcb.create_perf_counters();
  }
  paxos->init_logger();

  // verify cluster_uuid
  {
    int r = check_fsid()
    if (r == -ENOENT)
        r = write_fsid();
    if (r<0){
        lock.Unlock();
        return r;
    }
  }

  //open compatset
  read_features();

  // have we ever joined a quorum ?
  has_ever_joined = (store->get(MONITOR_NAME, "joined") != 0);
  dout(10) << "has_ever_joined = "<< (int)has_ever_joined << dendl;

  if(!has_ever_joined){
    // impose initial quorum restructions ?
    list<string> initial_members;
    get_str_list(g_conf->mon_initial_members, initial_members);

    if (!initial_members.empty()){
        dout(1) << " initial_members " << initial_members << ", filtering seed monmap" << dendl;
        monmap->set_inital_members(g_ceph_context, initial_members, name, messenger->get_myaddr(), &extra_probe_peers);
        dout(10) << " monmap is " << *monmap << dendl;
        dout(10) << " extra probe peers " << extra_probe_peers << dendl;
    }
   } else if ( !monmap->contains(name)) {
        derr << " not in monmap and have been in a quorum before; " << "must have been removed " << dendl;
        if (g_conf->mon_force_quorum_join) {
            dout(0)  << " we should have died but "
                << " mon_force_quorum_join is set -- allowing boot" << dendl;
        }else{
            derr << "commit suicide!" << dendl;
            return -ENOENT;
        }
   }

   {
        // we have a potentially inconsistent store state in hands. Get rid of 
        // it and start fresh
        bool clear_store = false;
        if(store->exists("mon_sync", "in_sync")){
            dout(1) << __func__ << "clean up potentially inconsistent store state " << dendl;
            clear_store = true;
        } 

        if (store->get("mon_sync", "force_sync") > 0){
            dout(1) << __func__ << " force sync by clearing store state " << dendl;
            clear_store = true;
        }
        if(clear_store) {
            set<string> sync_prefixes = get_sync_targets_names();
            store->clear(sync_prefixes);
        }
   }

   sync_last_commited_floor = store->get("mon_sync", "last_commited_floor");
   dout(10)  << "sync_last_commited_floor "<< sync_last_commited_floor << dendl;

   init_paxos();  //pasox 初始化
   health_monitor->init();

   ....
}
```

```c++
// mon/Monitor.cc
void Monitor::init_paxos() {
    dout(10) << __func__ << dendl;
    paxos->init(); 

    // init services
    // paxos_service 在Monitor构建时，加入了6个派生类
    - MDSMonitor
    - MonmapMonitor
    - OSDMonitor
    - PGMonitor
    - LogMonitor
    - AuthMonitor
    for(int i=0; i<PAXOS_NUM; ++i){
        paxos_service[i]->init(); 
    }
    refresh_from_paxos(NULL);
}
```

- last_pn: 上次当选为leader后生成的PN（proposal number)
- accepted_pn: 当前节点接受过的PN，可能是别的leader提议的PN 
- last_committed: 本节点记录的最后被commit版本
- first_committed: 本节点记录的第一被commit版本
```c++
void Paxos::init(){
    // load paxos variables from stable storage
    last_pn = get_store()->get(get_name(), "last_pn");
    accepted_pn = get_store()->get(get_name(), "accepted_pn");
    last_committed = get_store()->get(get_name(), "last_committed");
    first_commited = get_store()->get(get_name(), "first_committed");

    dout(10) << __func__ << " last_pn: " << last_pn << " accepted_pn: " 
        << accepted_pn << " last_commited: " << last_commited 
        << " first_committed: " << first_committed << dendl;
    dout(10) << "init" << dendl;
    assert(is_consistent());
}
```

//refresh_from_paxos(NULL)
```c++
void Monitor::refresh_from_paxos(bool * need_bootstrap){
    // ....
    for(int i=0; i<PAXOS_NUM; ++i){
        paxos_service[i]->refresh(need_boostrap);
    }
    for(int i=0; i<PAXOS_NUM; ++i){ //主要是处理PGMonitor
        paxos_service[i]->post_paxos_update();
    }
}
```
//paxos_service vector中的对象都没有派生refresh(), 都调用基类refresh方法
```c++
void PaxosService::refresh(bool *need_boostrap){
    // ...
    update_from_paxos(need_boostrap);
}

// update_from_paxos 均被paxos_service vector中的对象进行了派生
// 这里仅仅列出MonmapMonitor 对象方法
void MonmapMonitor:;update_from_paxos(bool *need_boostrap){
    version_t  version = get_last_committed();
    if(version <= mon->monmap->get_epoch())
        return 
    dout(10) << __func__ << " version " << version
        << ", my v " << mon->monmap->epoch << dendl;
    .....
}
```

//post_paxos_update() 方法，
- 只有PGMonitor覆盖写了post_paxos_update
- 其他5个类均没有使用基类
```c++
void PGMonitor:;post_paxos_update(){
    if(mon->osdmon()->osdmap.get_epoch()){
        map_pg_creates();
        send_pg_creates();
    }
}
```

```c++
// mon/Monitor.cc
int Monitor::init()
{
    dout(2) << "init" << dendl;
    lock.Lock()

    //start ticker
    timer.init()
    new_tick()

    //i'm ready!
    messenger->add_dispatcher_tail(this);

    bootstrap();

    // encode command sets
    const MonCommand *cmds;
    int cmdsize;
    get_locally_supported_monitor_commands(&cmds, &cmdsize);
    MonCommand::encode_array(cmds, cmdsize, supported_commands_bl);
    get_classic_monitor_commands(&cmds, &cmdsize);
    MonCommand::encode_array(cmds, cmdsize, classic_commands_bl);

    lock.Unlock();
    return 0;
}
```

// bootstrap() ; 接下去我们需要看peer如何处理OP_PROBE消息
```c++
void Monitor::bootstrap()
{
   // ....
   state = STATE_PROBING;
   _reset();

  // singleton monitor?
  if(monmap->size() == 1 && rank == 0){
    win_standalone_election();
    return;
  }  
  // ....
  dout(10) << "probing other monitors" <<dendl;
  for (unsigned i = 0; i < monmap->size(); i++) {
     if((int)i != rank){
        messenger->send_message(new MMonProbe(monmap->fsid, MMonProbe::OP_PROBE, name, has_ever_joined), monmap->get_inst(i));
     }
  }

  for(set<entity_addr_t>::iterator p = extra_probe_peers.begin(); p != extra_probe_peers.end(); ++p){
    if (*p != messenger->get_addr()){
        entity_inst_t i;
        i.name = entity_name_t::MON(-1);
        i.addr = *p;
        messenger->send_message(new MMonProbe(monmap->fsid, MMonProbe::OP_PROBE, name, has_ever_joined), i);
    }
  }
}
```

//handle_probe() 用来处理OP_PROBE消息
```c++
void Monitor::handle_probe(MonOpRequestRef op){
    MMonProbe *m = static_cast<MMonProbe*>(op->get_req());
    dout(10) << "handle_probe "  << *m << dendl;

    if(m->fsid != monmap->fsid){
        dout(0) << "handle_probe ignoring fsid "  << m->fsid << " != " << monmap->fsid << dendl;
        return;
    }

    switch (m->op){
    case MMonProbe::OP_PROBE:
        handle_probe_probe(op);     // <-- 处理OP_PROBE请求
        break;

    case MMonProbe::OP_REPLY:
        handle_probe_reply(op);
        break;

    case MMonProbe::OP_MISSING_FEATURES:
        derr << __func__ << " missing features, have " << CEPH_FEATURES_ALL 
        << ", required " << m->required_features
        << ", missing " << (m->required_features & ~CEPH_FEATURES_ALL)
        << dendl; 
        break;
    }
}
```

//handle_probe_probe 处理流程
```c++
void Monitor::handle_probe_probe(MonOpRequestRef op){
    MMonProbe *m = static_cast<MMonProbe*>(op->get_req());

    dout(10) << "handle_probe_probe " << m->get_source_inst() << *m
        << " features " << m->get_connection()->get_features() << dendl;

    uint_64 missing = required_features & ~m->get_connection()->get_features();
    // ......
    if (!is_probing() && !is_synchronizing()) {
        if(paxos->get_version() + 1 < m->paxos_first_version){
            dout(1) << " peer " << m->get_source_addr() << " has 
            first_committed " << " ahead of us, re-bootstrapping " << dendl;
            bootstrap();
            goto out;
        }
    }
    MMonProbe *r;
    r = new MMonProbe(monmap->fsid, MMonProbe::OP_REPLY, name, has_ever_joined);
    r->name = name;
    r->quorum = quorum;
    monmap->encode(r->monmap_bl, m->get_connection()->get_features());
    r->paxos_first_version = paxos->get_first_committed();
    r->paxos_last_version = paxos->get_version();
    m->get_connection()->send_message(r);

    // did we discover a peer here?
    if(!monmap->contains(m->get_source_addr())){
        dout(1) << " adding peer "<< m->get_source_addr() 
        << " to list of hints "<< dendl;
        extra_probe_peers.insert(m->get_source_addr());
    }

   out:
        return;
}
```

//handle_probe_reply()
void Monitor::handle_probe_reply(MonOpRequestRef op){
    MMonProbe *m = static_cast<MMonProbe*>(op->get_req());
    dout(10) << "handle_probe_reply " << m->get_source_inst() << *m <<dendl;
    dout(10) << " monmap is " << *monmap << dendl; 

    //discover name and addrs during probing or electing states.
    if(!is_probing() && !is_electing()){
        return;
    }
    //newer map, or they've joined a quorum and we haven't?
}

