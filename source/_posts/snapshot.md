---
  title: snapshot
---
### snapshot

快照分全量快照和增量快照

#### 全量快照
- 镜像分离

#### 增量快照

- copy on write(写时拷贝)
假如有一个卷8个物理块，分别为1~8， 在某一个时刻做了快照，这时候生成了一个快照卷，快照卷也有8个块，和原始卷一样指向相同的物理块。这时候有一个新的io，修改原始卷的第8个物理块，对COW 而言，会依次做如下几步：

  - 分配一个新的物理块。我们称为第9个物理块
  - 读取第8个物理块
  - 新读取的第8个物理块数据写入到第9个物理块
  - 更新快照卷map,指向第9个物理块
  - 更新第8个物理块

COW缺点：

  - 写放大，本来一个写，变成1读3写。

COW优势：

  - 原始卷物理块连续。没有碎片。
  - 节省空间

- rediect on first write (写时重定向)
假如有一个卷8个物理块，分别为1~8， 在某一个时刻做了快照，这时候生成了一个快照卷，快照卷也有8个块，和原始卷一样指向相同的物理块。这时候有一个新的io，修改原始卷的第8个物理块，对ROW 而言，会依次做如下几步：

  - 分配一个新的物理块。我们称为第9个物理块
  - 数据写入到第9个物理块。
  - 更新原始卷map,指向第9个物理块