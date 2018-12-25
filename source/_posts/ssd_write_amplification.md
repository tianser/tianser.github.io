---
  title: ssd write amplification
---

### Page 和 Block

ssd中有page和block的概念，page的大小为 4k，而block的大小为512k（128个page）

### write amplification

从前一直认为SSD的写放大（Write amplification）是指SSD一次写必须写一个Block，其实不是这样的。SSD一次写的单位是page，但是SSD的Write只能写到空的page上，对于之前写过的page
必须先进行一次Erase，而Erase的单位是block,所以如果一个page的数据删掉之后，要想再写到这个page上，必须经过以下三步：

- 将同一个block的其他page读出来
- 整个block erase掉
- 将整个block数据写入

### 解决版本Trim
TRIM是现在公认的解决写放大的比较好的方案。
TRIM位于操作系统层。操作系统使用TRIM命令来通知SSD某个page的数据不需要了，可以回收了。
支持TRIM的操作系统和以往的主要区别是删除一个Page的操作不同。在磁盘时期，删除一个page，之后在文件系统的记录信息里将该page的标志位设置为可用，但是并没有将数据删除。
使用SSD且支持TRIM的操作系统，在删除一个page时，会同时通知SSD这个page的数据不需要了，SSD内部有一个空闲时刻的垃圾收集进程，在空闲时刻SSD会将一些空闲的数据集中到一起，
然后一起Erase。这样每次写操作，就在已经Erase好了的Page上写入新的数据。
