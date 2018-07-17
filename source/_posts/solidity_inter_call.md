---
  title: solidity合约之间的调用
---

### solidity合约相互调用

```javascript
pragma solidity ^0.4.18;

contract Deployed{
    function setA(uint) public returns (uint) {}
    function a() public pure returns(uint) {}
}

contract Existing{
    Deployed dc;
    function Existing(address _t) public{
        dc = Deployed(_t);
    }

    function getA() public view returns(uint result){
        return dc.a();
    }

    function setA(uint _val) public returns(uint result){
        dc.setA(_val);
        return _val;
    }
}

/**
* We do not need the full implementation of the “Deployed” contract
* but rather just the function signatures as required by the ABI.
* Since we have the address of the "Deployed" contract,
* we could initialised the “Existing” contract with  the address
* and interact with the "Deployed" contract using the existing setA and getA functions accordingly
* 简单的说：没有被调用合约的地址，我们无法初始化生成该合约(无法执行构造函数)
*/

//或者这样，也是可以的

contract ExistingWithoutABI{
    address dc;
    function ExistingWithoutABI(address _t) public{
        dc = _t;
    }

    /*
    * 因为调用(delegatecall)方法只是将值传递给合约的地址，不会获得任何返回值
    * 我们不知道调用是否成功了,除非我们调用底层的合约
    */
function setA_Signature(uint _val) public returns(bool success){
    //固定格式进行调用, 参数传递
    require(dc.call(bytes4(keccak256("setA(uint256)")), _val));
    return true;
}
}

/*
*  那我们有没有办法来获取函数的返回值呢，很不幸;
*  我们需要使用solidity汇编才能做到这一点
*/

contract ExistingWithOutABIRt{
address dc;
function ExistingWithOutABIRt(address _t) public{
    dc = _t;
}

function setA_ASM(uint _val) public returns(uint answer){
   bytes4 sig = bytes4(keccak256("setA(uint256)"));

   //汇编代码
   assembly{
        // move pointer to free memory spot
        // 可用内存为64个字节；也就是(0x40)
        // 移动内存指针到这里
        let ptr := mload(0x40)
        // put function sig at memory spot
        // 将函数签名载入到这里
        mstore(ptr,sig)
        // append argument after function sig
        mstore(add(ptr,0x04), _val)

        // 函数签名为4字节(0x04), 参数是32字节(0x20)
        // 所以总共为36字节(0x24)
        //输出为32字节(0x20)
        let result := call(
          15000, // gas limit
          sload(dc_slot),  // to addr. append var to _slot to access storage variable
          0, // not transfer any ether
          ptr, // Inputs are stored at location ptr
          0x24, // Inputs are 36 bytes long
          ptr,  //Store output over input
          0x20) //Outputs are 32 bytes long

        //执行失败，则进行回滚操作
        if eq(result, 0) {
            revert(0, 0)
        }

        // 赋值返回给answer
        answer := mload(ptr) // Assign output to answer var
        mstore(0x40,add(ptr,0x24)) // Set storage pointer to new space
   }
}
}
```
