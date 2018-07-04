---
  title: solidity入门之一
---

### 概述
solidity 编译的方式生产evm字节,广泛用于投票、众筹，封闭，拍卖，多重签名钱包等合约中；

- 外部帐户地址是由公钥决定的;
- 合约帐户：被存储在帐户中的代码控制，在创建合约时候确定的；（这个地址由合约创建者的地址和该地址发出过的交易数量计算得到，地址发出过的交易数量也被称作为"nonce"）

合约帐户存储了合约代码，而外部帐户则没有

### 合约的结构
- 状态变量： 在合约存储器中永久存储的值；
- 函数： 合约中可执行单元的代码；
- 函数修饰符： 在声明的方式中补充函数的语义；
- 事件： 和EVM日志设施的接口
- 结构体：一组用户定义的变量
- 枚举： 创建一个特定值的集合的类型；


### 特殊的数据类型

- int/uint：是有符号和无符号的整数；
- int/uint: 分别是int256 和uint256 的别名；

- 地址address：

  1、地址属性：balance 和 发送（send）<br/>
  若查询到有资产余额的地址，然后发送 Ether（以wei为单位）到send函数的地址上
```solidity
  address x = 0x123；
  x.send(10)
```
  2、call 和 callcode（调用和调用码）<br/>
  call和callcode是非常低级的函数，它可以作为打破Solidity的类型安全的最后手段。
```
  address nameReg = 0x123;
  nameReg.call("register", "MyName");
  nameReg.call(bytes4(sha3("fun(uint256)")), a)
```
  函数调用返回了一个布尔值，表示函数是否正常调用结束或EVM异常（false）
  callcode：只使用给定地址的编码

- bytes1, bytes2, bytes3, ..., bytes32; byte 是bytes1的别名

- 枚举：
```
  enum Choices{GoLeft, GORight, GoStraight, SitStill}
  Choices constant defaultChoice = Choices.GoStraight;
```

- 字符串常量

  字符串常量可以隐式换成bytes

- 引用类型

  复杂类型，例如类型并不总是256为，因为拷贝他们相当消耗存储和时间，我们必须考虑把它们存储在内存或者存储器（状态变量存放的地方）

- 数据位置：
  - 内存
  - 存储器
  - calldata： 一个无法改变的，非持久的 存储函数参数的地方
  - 每一个复杂类型,即数组和结构体,有一个额外的注解,“数据位置”,不管它是存储在内存中，还是存储在存储器上。根据上下文,总是有一个默认的,但它可以通过附加存储或内存覆盖类型。函数参数的默认值(包括返回参数)是在内存上,局部变量的默认存储位置是在存储器上。存储器上存有状态变量(很明显)。
  - 赋值过程：
    - 在存储和内存以及状态变量之间赋值总需要创建一个独立的副本；赋值只分配一个本地存储变量引用，这总是指向状态变量的引用，后者同时改变，
    -  从一个内存存储引用类型，赋值到另一个内存存储引用类型，并不创建一个副本；

- 数组：
  - 数组可以长度固定，也可以动态（类似切片）
  - 存储器数组，成员类型是任意的（映射，结构体)
  - 内存数组， 成员类型不能是映射
  - bytes 和 string是特殊类型的数组， bytes byte[], string  bytes


- 函数可见性和访问限制：
  - external: 外部函数是合约接口的一部分，可能从其他合约调用；也通过食物调用；不能在被内部调用（即f()不执行，但是this.f()执行）
  - public: default
  - internal： 只能在内部访问（当前合约或它派生的合约），而不使用(关键字) this
  - private： 私有函数和状态变量仅仅在定义该合约中可见，在派生的合约中不可见；

- interface
  -接口内没有任何函数是已实现的，并限制如下：
  - 不能继承其他合约，或接口
  - 不能定义构造器
  - 不能定义变量、结构体、枚举等

```
  interface Token{
    function transfer(address recipient, uint amount);
  }
```

继承：

```
  contract owned{
    address public owner;
    function owned(){
      owner = msg.sender;
    }
  }

  contract base1{
      addresss public owner2;
      function base1(){
        owner2 = msg.sender;
      }
  }

 // is 关键字
  contract mortal is owned{

    function kill(){
      if(msg.sender == owner)
        selfdestruct(owner);
    }
  }

 //继承顺序，从“最基本”到“最近派生”
  contract Final is owned, base1{

  }

```
优秀solidity文章：
https://steemit.com/cn/@speeding/smart-contract-development8
建议熟读Solidity全局变量、全局函数，要抄代码，首先去OpenZeppelin，然后是Consensys的项目里去抄，有现成的 ERC20、ERC721合约模版和mock，


this在合约中表示当前合约地址；

payable 标识的函数：【重点】

- 函数上增加payable标识，即可接收ether，并会把ether存在当前合约地址

```
   contract Pay{
     //存入一些ether到合约帐户中
     function deposit() payable{
     }

     //查询当前的余额
     function getBalance() constant returns(uint){
       return this.balance;
     }
   }
```

合约要接收通过send()函数发送的ether，有如下限制：

- 必须定义fallback函数，否则抛异常
- fallback函数必须增加payable关键字，否则send()执行结果始终未false；

```
  pragma solidity ^0.4.0;
  contract SendAndReceiveBycontract{
    //fallback函数对应记录事件
    event fallbackTrigged(bytes data);

    //合约接收send()的ether时，必须存在
    function() payable{fallbackTrigged(msg.data);}
  }

  function deposit () payable{
  }

  function getBalance() constant returns (uint){
    return this.balance;
  }
  event SendEvent(address to, uint value, bool result);

  //使用send()发送ether
  function sendEther(){
    // this.send(msg.value) : 向当前合约转账；
    bool result = this.send(1);
    SendEvent(this, 1, result);
  }
```
代

```
  modifier notThis(address _address){
    require(_address != address(this))
    _;
  }
```
```go
  type Account struct{
    Address common.Address `json:"address"`
    URL URL                `json:"url"`
  }

  const (
    HashLength = 32 //32 bytes [256bit]
    AddressLength = 20 // 20 bytes
  )

  type URL struct{
    Scheme string
    Path   string
  }

  type Address [AddressLength]byte  //20 bytes

  type Wallet interface{
    URL() URL
    Status() (string, error)
    ...
  }

  type KeyStore struct{
    storage keyStore
    cache *accountCache
    changes chan struct{}
    unlocked map[common.Address]*unlocked

    ....

  }
  4.576b shard 528: soid 62df576b/rbd_data.742c2250945ff8.0000000000009896/118//4 size 0 != known size 8388608
```














- xx
