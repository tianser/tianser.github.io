---
  title: ceph log
---

## dout

```c++
#define dout(v) ldout((g_ceph_context), v)

#define ldout(cct, v) dout_impl(cct, dout_subsys, v) dout_prefix


```