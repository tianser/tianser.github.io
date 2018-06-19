## ipfs

### ipfs系统相关命令 (主要与ipfs在/root/.ipfs/的配置相关）

- ipfs id
- ipfs 跨域
  - `ipfs config --json API.HTTPHeaders.Access-Control-Allow-Methods '["PUT", "GET", "POST", "OPTIONS"]'`
  - `ipfs config --json API.HTTPHeaders.Access-Control-Allow-Origin '["*"]'`

### 操作相关命令

- ipfs add demo.file   &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;   //upload file and the output is hash key
- ipfs get {hash key}  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;   //download file
- ipfs add -r  {dir}   &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;   //递归添加，输出包含文件和目录的hash key
- ipfs get {dir hash key} &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;   //download dir and file
- ipfs get {not exist hash key} &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; //一直blocked
- 目录操作
  - ipfs files  mkdir  /demo         //只能是一级一级创建，不能多级创建
  - ipfs files cp /ipfs/QmXXX   /demo/file.txt
  - ipfs filess ls /    ;  ipfs files ls /demo
  - ipfs files read /demo/file.txt

#### 增加目录

- ipfs add  -r demo

		added QmZoApUnALi4oRJpGGZhgDi8cp3x65EA668nnJMrqEonPg demo/demo2.txt
	added QmWMgtnYhbEuEVRvdejoD8bEuLy5JJisD19WrJYCqQiHeP demo/ipget
	added QmefA8mR2ed2mTfaqtm7RbNAY2nMDpKkBUtKmg61kcq617 demo

-  ipfs cat  QmefA8mR2ed2mTfaqtm7RbNAY2nMDpKkBUtKmg61kcq617/demo2.txt

#### Pin （是否缓存内容在本地，缓存到本地的内容不仅可以自己使用，还能为其他节点提供资源）

&nbsp;&nbsp;IPFS的Pin是将文件长期保留在本地，不被垃圾回收；

- ipfs pin ls  //查看哪些文件在本地是持久化的，通过 add 添加的文件默认就是 pin 过的

### IPFS存储文件时，会经历以下几个步骤：

-  把单个文件拆分成若干个256KB大小的块（ block，这个就可以理解成扇区 ）；
- 逐块(block)计算block hash，hashn = hash ( blockn )；
- 把所有的block hash拼凑成一个数组，再计算一次hash，便得到了文件最终的hash，hash ( file ) = hash ( hash1……n )，并将这个 hash（file） 和block hash数组“捆绑”起来，组成一个对象，把这个对象当做一个索引结构；
- 把block、索引结构全部上传给IPFS节点，文件便同步到了IPFS网络了；
-  把 Hash（file）打印出来，读的时候用；

### 绑定节点

- ipfs name publish {dir hash key} &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;   //将该目录与ipfs node id进行绑定

### 绑定节点之后，可以通过ipns进行访问

- ipfs cat /ipns/{ipfs node id}/demo.txt &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;  //demo.txt为dir下文件

### DNS 解析

&nbsp;&nbsp;IPFS 允许用户使用现有的域名系统，这样就能用一个好记的地址来访问文件；

- ipfs cat /ipns/ipfs.b3log.org/hacpai/README.md

只需要在DNS解析加入一条TXT记录即可：

TXT	ipfs	dnslink=/ipns/{ipfs node id}

### 查看当前ipfs节点连接状态

	ipfs swarm peers

### 查看数据提供方 （这里需要深入研究）

	ipfs dht findprovs <hash>
	ipfs dht provide   <hash>
	ipfs bitswap ledger <peer ID>  #对账单

### 查找peer：

	ipfs dht findpeer <node A peerID>

### 手动连接特定节点:

	ipfs swarm connect <multiaddr>


### ipfs p2p listener ls

	[root@SJ-T1-Cloud172 .ipfs]# ipfs p2p listener ls
	Error: libp2p stream mounting not enabled
	需要修改config中Libp2pStreamMounting

### 删除local store file

	ipfs pin rm <hash>
	ipfs repo gc


### 生成hash，但不上传

	echo <data>  | ipfs add -n
	ipfs add <file> -n

### add分析：

	ipfs add alargefile  //ensure this file is larger than 256k,otherwise has no sub-tree
	ipfs ls thathash

	ipfs@earth ~> ipfs ls qms2hjwx8qejwm4nmwu7ze6ndam2sfums3x6idwz5myzbn
	qmv8ndh7ageh9b24zngaextmuhj7aiuw3scc8hkczvjkww 7866189  //称为block
	qmuvjja4s4cgyqyppozttssquvgcv2n2v8mae3gnkrxmol 7866189
	qmrgjmlhlddhvxuieveuuwkeci4ygx8z7ujunikzpfzjuk 7866189
	qmrolalcquyo5vu5v8bvqmgjcpzow16wukq3s3vrll2tdk 7866189
	qmwk51jygpchgwr3srdnmhyerheqd22qw3vvyamb3emhuw 5244129

### 查看block：

	ipfs cat <block hash>  //output to screen
	ipfs block stat <block hash> //查看block状态，大小等

	ipfs refs <block hash> //打印该block的子块
	等价于
	ipfs object links <block hash> 或 ipfs ls <block hash>

### 查看ipfs对象底层结构：

	ipfs object get <hash>


### debug模式运行

	IPFS_LOGGING=debug ipfs daemon
	//eventlog output:
	ipfs log tail
	//or
	curl http://localhost:5001/logs

ipfs blog：

https://forum.qtum.org/topic/87/%E5%A6%82%E4%BD%95%E4%BD%BF%E7%94%A8%E6%98%9F%E9%99%85%E6%96%87%E4%BB%B6%E4%BC%A0%E8%BE%93%E7%BD%91%E7%BB%9C-ipfs-%E6%90%AD%E5%BB%BA%E5%8C%BA%E5%9D%97%E9%93%BE%E6%9C%8D%E5%8A%A1-%E4%B8%80

## IPFS 内部

IPLD（ InterPlanetary Linked Data） 主要用来定义数据， 给数据建模；定义了统一的数据模型IPLD ；

    "API": "/ip4/0.0.0.0/tcp/5001",
    "Gateway": "/ip4/0.0.0.0/tcp/8080"



db 删除到某个单词的开始位置

dw 删除到某个单词的结尾位置

D 删除到某一行的结尾

d0 删至行首。

d$ 删至行尾。
