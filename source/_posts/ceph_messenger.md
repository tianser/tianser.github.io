---
title: ceph messager 分析
date: 2018-04-10
categories:
  - ceph
tags:
  - ceph
---

### Messenger
```cpp
// file: msg/Messenger.h
class Messenger{
private:
  list<Dispatcher*> dispatchers;
  list<Dispatcher*> fast_dispatchers;

protected:
  entity_inst_t my_inst;
  int default_send_priority;  //默认发送优先级
  ///  set to true once the Messenger has started, and set to false on shutdown
  bool started;
  uint32_t magic;
  int socket_priority;

public:
  CephContext *cct;
}

```
