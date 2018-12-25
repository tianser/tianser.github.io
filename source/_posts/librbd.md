---
  title: librbd分析
  date: 2018-04-15
  categories:
  - ceph
  tags:
    - librbd
    - ceph
---

//通过lib形式调用，所以不走main函数
```cpp
//创建rbd块  -- librbd/librbd.cc
int RBD::create(IoCtx& io_ctx, const char *name, uint64_t size, int *order)
{
  int r = librbd::create(io_ctx, name, size, order);
  return r
}

//调用librbd::create --librbd/internal.cc
int create(librados::IoCtx& io_ctx, const char *imgname, uint64_t size, int *order)
{
    ...
    return create(io_ctx, imgname, size, old_format, features, order, 0, 0);
}

//调用create  --librbd/internal.cc
int create(IoCtx& io_ctx, const char *imgname, uint64_t size, bool old_format, uint64_t features, int *order,  uint64_t stripe_unit, uint64_t stripe_count)
{
  ...   //ImageOptions opts
  r = create(io_ctx, imgname, size, opts, "", "")
  ...
}

//调用create  -- librbd/internal.cc
int create(IoCtx& io_ctx, const char *imgname, uint64_t size, ImageOptions& opts, const std::string &non_primary_global_image_id,
  const std::string &primary_mirror_uuid)
{
  ...
  r = create_v1(io_ctx, imgname, bid, size, order);
  ...
  r = create_v2(io_ctx, imgname, bid, size, order, features, stripe_unit, stripe_count, journal_order, journal_splay_width, journal_pool,
    non_primary_global_image_id, primary_mirror_uuid);
}

//调用create_v2  --librbd/internal.cc
int create_v2(IoCtx& io_ctx, const char *imgname, uint64_t bid, uint64_t size, int order,
  uint64_t features, uint64_t stripe_unit, uint64_t stripe_count, uint8_t journal_order,
  uint8_t journal_splay_width, const std::string &journal_pool,const std::string &non_primary_global_image_id,
  const std::string &primary_mirror_uuid)
{
  ...
  id_obj = util::id_obj_name(imgname)   //rbd_id.{imagname}
  r = io_ctx.create(id_obj, true);      //创建object; 对象名为rbd_id.{imgname}

  //setting image id
  r = cls_client::set_id(&io_ctx, id_obj, id);

  //adding rbd image to directory
  r = cls_client::dir_add_image(&io_ctx, RBD_DIRECTORY, imgname, id);

  header_osd = util::header_name(id);
  r = cls_client::create_image(&io_ctx, header_oid, size, order, features, oss.str());

  //关于feature设定
}

//cls_client::create_image()  -- cls/rbd/cls_rbd_client.cc
int create_image(librados::IoCtx *ioctx, const std::string &oid, uint64_t size, uint8_t order, uint64_t features
  const std::string &object_prefix)
{
    return ioctx->exec(oid, "rbd", "create", bl, bl2);
}

//librados::IoCtx::exec()    -- librados/librados.cc
int librados::IoCtx::exec(const std::string& oid, const char *cls, const char* method, bufferlist& inbl, bufferlist& outbl)
{
  object_t obj(oid);
  return io_ctx_impl->exec(obj, cls, method, inbl, outbl);
}

//io_ctx_impl->exec()  --librados/IoCtxImpl.cc
int librados::IoCtxImpl::exec(const object_t& oid, const char *cls, const char *method, bufferlist& inbl, bufferlist& outbl)
{
    ::ObjectOperation rd;
    prepare_assert_ops(&rd);
    rd.call(cls, method, inbl);
    return operate_read(oid, &rd, &outbl);
}
```
