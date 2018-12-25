---
title: ceph log
date: 2018-04-10
categories:
    - ceph
tags:
    - ceph 
---

## dout

```c++
#define dout(v) ldout((g_ceph_context), v)

#define ldout(cct, v) dout_impl(cct, dout_subsys, v) dout_prefix

```