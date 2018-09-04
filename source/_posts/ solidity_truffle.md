---
  title: solidity truffle
---

### solidity语法：

写Solidity最大的不同在于，我们要随时计算好我们的gas消耗，方法的复杂度，变量类型的存储位置（memory，storage等等）都会决定gas的消耗量。

以上编写合约在vim，编译在Remix，运行端在geth console。过程十分繁复，不适合大规模工程开发，需要通过Truffle来整合以上操作；

一、环境配置：

​	truffle依赖于nodejs，可能存在版本之间的兼容性问题，首先删除自带的nodejs和npm，再进行全安装；

```
sudo apt-get remove nodejs
sudo apt-get remove npm
sudo apt-get update
which node
wget https://nodejs.org/dist/v8.8.0/node-v8.8.0-linux-x64.tar.gz
sudo tar -xf node-v8.8.0-linux-x64.tar.gz --directory /usr/local --strip-components 1
node --version
npm --version
sudo npm install -g truffle
```

二、

```
1. block.blockhash(uint blockNumber) returns (bytes32): 返回参数区块编号的hash值。（范围仅限于最近256块，还不包含当然块）
2. block.coinbase (address): 当前区块矿工地址
3. block.difficulty (uint): 当前区块难度
4. block.gaslimit (uint): 当前区块的gaslimit
5. block.number (uint): 当前区块编号
6. block.timestamp (uint): 当前区块的timestamp，使用UNIX时间秒
7. msg.data (bytes): 完整的calldata
8. msg.gas (uint): 剩余的gas
9. msg.sender (address): 信息的发送方 (当前调用)
10. msg.sig (bytes4): calldata的前四个字节 (i.e. 函数标识符)
11. msg.value (uint): 消息发送的wei的数量
12. now (uint): 当前区块的timestamp (block.timestamp别名)
13. tx.gasprice (uint): 交易的gas单价
14. tx.origin (address): 交易发送方地址(完全的链调用)
```

### 三、发币

使用truffle init 来初始化项目；但truffle推出Boxes功能之后，我们可以直接套用react-box的样板，节省时间；

```
root@keke:~/truffle-project/coin# truffle  unbox react-box
Downloading...
Unpacking...
Setting up...
Unbox successful. Sweet!

Commands:

  Compile:              truffle compile
  Migrate:              truffle migrate
  Test contracts:       truffle test
  Test dapp:            npm test
  Run dev server:       npm run start
  Build for production: npm run build
```

编译自带的智能合约：

```
root@keke:~/truffle-project/coin# truffle  compile
Compiling ./contracts/Migrations.sol...
Compiling ./contracts/SimpleStorage.sol...

Compilation warnings encountered:

/root/truffle-project/coin/contracts/Migrations.sol:11:3: Warning: Defining constructors as functions with the same name as the contract is deprecated. Use "constructor(...) { ... }" instead.
  function Migrations() public {
  ^ (Relevant source part starts here and spans across multiple lines).

Writing artifacts to ./build/contracts

```

3、安装OpenZeppelin来简化加密钱包开发过程；

`OpenZeppelin`是一套能够给我们方便提供编写加密合约的函数库，同时里面也提供了兼容`ERC20`的智能合约。

```
npm install zeppelin-solidity
```

4、创建代币合约

```
pragma solidity ^0.4.0;

import "../node_modules/zeppelin-solidity/contracts/token/ERC20/StandardToken.sol";

contract NewCoin is StandardToken{
    string public name = "NewCoin";
    string public symbol = "NC";
    uint8 public decimals = 8;
    uint256 public INITIAL_SUPPLY = 21000000;

    function NewCoin(){
        totalSupply_ = INITIAL_SUPPLY;
        balances[msg.sender] = INITIAL_SUPPLY;
    }
}
```

5、编译、部署和验证

在`migrations/`目录下建立一个`3_deploy_contracts.js`文件，内容如下：

```
var NenmoCoin = artifacts.require("./NenmoCoin.sol");

module.exports = function(deployer) {
  deployer.deploy(NenmoCoin);
};
```

部署：

```
truffle develop			//进入开发环境
compile				    //编译
migrate					//部署在truffle环境上
```

测试：

```
truffle(develop)> var c
undefined
truffle(develop)> c = NenmoCoin.deployed().then(instance => contract = instance)
TruffleContract {
  constructor:
......
  allEvents: [Function: bound ],
  address: '0x8f0483125fcb9aaaefa9209d8e9d7b9c8b9fb90f',
  transactionHash: null }

truffle(develop)> contract.balanceOf(web3.eth.coinbase)
BigNumber { s: 1, e: 7, c: [ 21000000 ] }
truffle(develop)> contract.balanceOf(web3.eth.accounts[1])
BigNumber { s: 1, e: 0, c: [ 0 ] }
truffle(develop)> contract.transfer(web3.eth.accounts[1], 100)
{ tx: '0x6d31007768fc72ed31aa574c0af0f24f9e5fea05d31e8e8c0464df4d88276dfc',
  receipt:
   { transactionHash: '0x6d31007768fc72ed31aa574c0af0f24f9e5fea05d31e8e8c0464df4d88276dfc',
     transactionIndex: 0,
     blockHash: '0xeb9546c74c6a897e05ecfe223238cfa80b3db4f37a567f02b5c1d20ffec7b6c3',
     blockNumber: 7,
     gasUsed: 51569,
     cumulativeGasUsed: 51569,
     contractAddress: null,
     logs: [ [Object] ],
     status: '0x01',
     logsBloom: '0x00000000000000000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000010000008000000000008000000000000000080000000000000000000000000000000000000000000000000000000000000000010000000000000000000010000000000000000400000000000000000000000010000000002000000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000' },
  logs:
   [ { logIndex: 0,
       transactionIndex: 0,
       transactionHash: '0x6d31007768fc72ed31aa574c0af0f24f9e5fea05d31e8e8c0464df4d88276dfc',
       blockHash: '0xeb9546c74c6a897e05ecfe223238cfa80b3db4f37a567f02b5c1d20ffec7b6c3',
       blockNumber: 7,
       address: '0x8f0483125fcb9aaaefa9209d8e9d7b9c8b9fb90f',
       type: 'mined',
       event: 'Transfer',
       args: [Object] } ] }
truffle(develop)> contract.balanceOf(web3.eth.coinbase)
BigNumber { s: 1, e: 7, c: [ 20999900 ] }
truffle(develop)> contract.balanceOf(web3.eth.accounts[1])
BigNumber { s: 1, e: 2, c: [ 100 ] }
truffle(develop)> contract.name.call()
'NenmoCoin'
truffle(develop)> contract.symbol.call()
'NMB'
```

### 部署到geth私链：

 attach 进入console：

```
geth  attach ipc:/root/goproject/private-chain/geth.ipc
```

查看帐户：

```
>personal
>personal.newAccount("some-key")
>personal
//此时我们应该看到两个帐户，我们使用帐户进行部署合约
>miner.start()
>eth.sendTransaction({from:eth.coinbase, to:eth.accounts[1], value: web3.toWei(10000, "ether")})
>personal.unlockAccount(eth.accounts[1])  //部署合约之前，必须把帐户进行解锁
```

查看truffle.js：

```
module.exports = {
     networks: {
         development: {
               host: "192.168.116.56",
               port: 8989,
               network_id: "123",
               from: "0x528abd58142fbf77d4e648cd43458625297fa059",  //此处为解锁的帐户
               gas: 3000000,
               gasPrice: 100,
             }
      }
};
```

truffle migrate //部署到geth

【truffle migrate】问题汇总：

- Error: exceeds block gas limit undefined

当前合约所需的gas超过了区块的最大gas。这可能是由于创世区块的配置文件`genesis.json`中的参数`gasLimit`设置过小有关，

解决方案：
    重置truffle.js中gas参数的大小；

```
//再次进入ipc
geth  attach ipc:/root/goproject/private-chain/geth.ipc
```

### 在geth中查找已部署的合约

从truffle 项目目录下，build/contracts/NewCoin.json获取abi；并由[http://www.bejson.com](http://www.bejson.com/jsonviewernew/) 转成字符串；

```
var abi = JSON.parse($abi)
var address = "0x8d014d58bfdc56408b2af6ef8e7b09eba1c8b940"; //truffle migrate 生成的address
var newcoin = web3.eth.contract(abi).at(address)
```

### 调用合约中的方法：

- call() 直接返回结果，不会写入区块链
- sendTransaction() 发送一笔交易，会写入区块链中，返回值是交易的哈希值。

### ERC20 Token
ERC20是以太坊定义的一个代币标准。是一种发行代币合约必须要遵守的协议，该协议规定了几个参数：
- 发行货币的名称
- 简称
- 发行量
- 支持的函数

只有支持了该协议才会被以太坊所认同；

erc20 标准

```go
  // https://github.com/ethereum/EIPs/issues/20
  contract ERC20 {
      function totalSupply() constant returns (uint totalSupply);
      function balanceOf(address _owner) constant returns (uint balance);
      function transfer(address _to, uint _value) returns (bool success);
      function transferFrom(address _from, address _to, uint _value) returns (bool success);
      function approve(address _spender, uint _value) returns (bool success);
      function allowance(address _owner, address _spender) constant returns (uint remaining);
      event Transfer(address indexed _from, address indexed _to, uint _value);
      event Approval(address indexed _owner, address indexed _spender, uint _value);
    }
```

solidity：
- address
 - 属性：balances
 - 函数: send(), call(), delegatecall(), callcode()

solidity 语法
```
https://www.jianshu.com/p/e8113bfa7694
```

对tx.data进行Keccak256（）编码；

以太坊交易的类型：

- 转账的交易
- 创建合约的交易
- 执行合约的交易

参数是一个对象，在发送交易的时候指定不同的字段，区块链及链根据参数识别出对应类型的交易；

转账交易：
转账是最简单的一种交易，从一个帐户向另一个帐户发送以太币
```
  web3.eth.sendTransaction({
      from: "0x....",
      to:   "0x....",
      value: 100000
  })
```

创建合约的交易：
将合约部署到区块链节点上，通过发送交易来实现。

```
  web3.eth.sendTransaction({
      from: "交易的发送者也是合约的创建者",
      data: "指定合约的abi"
  })
```
to字段留空不填

执行合约的交易：调用合约中的方法，需要将交易的to字段指定为调用的合约的地址， 通过data字段指定要调用的方法以及向该方法传递的参数
```
  web3.eth.sendTransaction({
      from: "sender's address",
      to: " contract address",
      data: "目标方法和传递的参数"
  })
```
data字段需要特殊的编码规则，一般使用SDK(web3.js)

### web3.eth
包含以太坊区块链相关的方法
 - web3.eth.gasprice  //gas当前单价
 - web3.eth.accounts  //当前节点的帐户列表
 - web3.eth.getBalance()
 - web3.eth.getTransaction()
 创建帐户

gas limit: 这个交易的执行最都被允许使用的计算步骤
gas price: 交易发送者愿意支付的gas费用，一个单位的gas表示了执行一个基本指令；
