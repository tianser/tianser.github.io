---
  title: 以太坊交易签名
  date: 2018-04-15
  categories:
    - blockchain
  tags:
    - eth
---
### 以太坊的Transaction结构
```go
//交易本身数据信息
accountNonce  UInt64
price         BigInt
gasLimit      BigInt
recipient     Address
amount        BigUInt
payload       Data

//签名信息
V             BigInt
R             BigInt
S             BigInt
```
对交易签名步骤:
- 对交易本身进行rlp编码，再对rlp编码进行keccak256哈希
- 对第一步的结果进行椭圆曲线ecdsa的签名
- 对第二步的结果进行拆解，分别赋值到V R S中
对第二步的结果进行拆解，分别赋值到V R S中

```javascript
var Tx = require('ethereumjs-tx')
var privateKey = new Buffer('e331b6d69882b4cb4ea581d88e0b604039a3de5967688d3dcffdd2270c0fd109', 'hex')

var rawTx = {
  nonce: '0x00',
  gasPrice: '0x09184e72a000',
  gasLimit: '0x2710',
  to: '0x0000000000000000000000000000000000000000',   //转入地址
  value: '0x00',
  data: '0x7f7465737432000000000000000000000000000000000000000000000000000000600057'
}

var tx = new Tx(rawTx);
tx.sign(privateKey);

var serializedTx = tx.serialize();

web3.eth.sendRawTransaction(serializedTx.toString('hex'), function(err, hash){
  if(!err)
    console.log(hash);
})

```
2、熟悉Linux系统内核，包括IO系统、文件系统、内存管理；
3、有参与过云平台或大型互联网系统底层平台开发设计者优先；参与过ceph等开源代码项目贡献的优先；
4、深入理解分布式存储系统相关原理，包括分布式对象、分布式事务、集群等；
5、熟悉数据归档、备份、恢复、快照、压缩、删重、自动分层等相关技术；
6、熟练掌握C/C++语言，能看懂java或Python代码，有实际的项目开发经验；
- paxos golang实现


- 确保raid卡型号可以在raid卡工具(必须由厂商提供)配合下，查找到磁盘槽位；
- 对数据存储disk 和journal ssd disk进行log监控、报警机制；
- io sheduler 参数测试；
