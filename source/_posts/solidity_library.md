---
  title: solidity Library
---

在Solidity中，与合约有些不同，Library不能处理ether。你可以把它当作一个EVM中的单例，又或者是一个部署一次后不再部署，然后能被做任意其它合约调用的公共代码。

这带来的一个显然好处是节省大量的gas（当然也可以减少重复代码对区块链带来的污染），因为代码不用一而再，再而三的部署，不同的合约可以依赖于同一个已部署的合约。

库是一个特殊的合约，不允许payable的函数，不允许fallback函数（这些限制是在编译期间强制执行的，由此我们不能使用库来操作ether）。库通过关键字library定义，如library C{}，与合约定义类似contract A{}。

调用库函数时，将使用一个特殊的指令（DELEGATECAL)，这会将调用时的上下文信息传入到library中，就好像代码在合约自身中执行一样。 “库可以被看作是使用它的合约中的一个隐式父类”

```
  library C{
    function a() returns(address){
      return address(this);
    }
  }

  contract A{
    function a() constant returns(address){
      return C.a();
    }
  }
```

- using 结构体和方法

尽管库并没有storage，他们可以使用关联合约的storage。当传递一个库调用，库所进行的修改，将会保存在合约中的storage中。这有点类似于向函数中传递了C语言一样的指针，只有通过这种方式，库才可能是一个已经被部署过的，或已经存在于区块链上了。

使用using提供的语法糖，可以让这一切实现得简洁和好懂。
```
library CounterLib {
    struct Counter { uint i; }

    function incremented(Counter storage self) returns (uint) {
        return ++self.i;
    }
}

contract CounterContract {
    using CounterLib for CounterLib.Counter;

    CounterLib.Counter counter;

    function increment() returns (uint) {
        return counter.incremented();
    }
}
```
using关键字，在CounterLib数据结构Counter上附着了CounterLib库中定义的方法。CounterLib.Counter的实例在使用时，就好像它自己有了incremented()，调用方法时，会直接把这个实例作为第一个参数传入了函数。

- 事件和库

  库中不止没有storage，也没有event。但他们类似storage这样，转发事件；
  如之前所述，一个库可以被认为是被调用合约的隐式的基类。如果在基类合约中触发一个事件，它也会出现在主合约中事件日志中，同样的，库函数也是如此，当合约调用的库函数中的事件触发函数时，日志事件也会出现在合约的日志中。

  当前的问题是，合约的ABI定义不能反映库中可能会触发的事件。这将导致客户端如web3，不知道如何解析事件，以及不知道如何解析参数。

  这里有一个缓解的办法，是在合约和库中都定义同样的事件，这将让客户端认为合约触发对应的事件（而实际是库函数触发的）。

  下面是一个简单的例子来说明这一切，尽管Emit事件由库触发，通过监听EventEmitterContract.Emit，我们可以监听事件。而相对来说，监听EventEmitterLib.Emit，反而不会得到什么事件。

```
library EventEmitterLib {
    function emit(string s) {
        Emit(s);
    }

    event Emit(string s);
}

contract EventEmitterContract {
    using EventEmitterLib for string;

    function emit(string s) {
        s.emit();
    }

    event Emit(string s);
}
```
