---
 title: 部署以太坊私链：
---
帐号准备：
​ 部署合约需要外部帐户，进入交互界面；
```javascript
> eth.accounts  //分配给开发者的帐户
["0x7b30423838ac0bccccfcbb9d9b494b834a76f847"]
```

创建新帐户
```javascript
> personal.newAccount("test")
"0xa7287e272e3814f59025ece844665e6a30e4d296"
```

查看帐户列表
```
> personal.listAccounts
["0x7b30423838ac0bccccfcbb9d9b494b834a76f847", "0xa7287e272e3814f59025ece844665e6a30e4d296"]
```

查看帐号余额			//新建的帐户此时余额为0
```
> eth.getBalance("0xa7287e272e3814f59025ece844665e6a30e4d296")
0
```

转账				// 没有余额的帐户无法部署合约，从默认帐户转账给新帐户
```
> eth.sendTransaction({from:eth.accounts[0], to: eth.accounts[2], value: web3.toWei(1, "ether")})
"0x5f2c80f25b83b3b5b04f89cee37b8a4fe3950f8f66e81f8169c4719a0f37e584"
```

### 部署合约
1、解锁帐户 			//只有解锁帐户之后，才能进行合约的部署；
```javascript
> personal.unlockAccount(eth.accounts[2], "test")
true
```
2、编写合约
3、部署合约 		//https://ethereum.github.io/browser-solidity/
4、部署合约之后查看余额
> ```
> eth.getBalance(eth.accounts[2])
> 999999999999603541
> ```

5、运行合约：

> ```
> > hello
> {
> abi: [{
>     constant: true,
>     inputs: [],
>     name: "say",
>     outputs: [{...}],
>     payable: false,
>     stateMutability: "view",
>     type: "function"
> }, {
>     inputs: [{...}],
>     payable: false,
>     stateMutability: "nonpayable",
>     type: "constructor"
> }],
> address: "0xd81c0b77218fda9037ae5df48f6e75a6b3e6ffd0",
> transactionHash: "0x1cc62a197d92a2ab848e55deaae9c1fe5c19be18c3b17c33b00fc6173e1c52a4",
> allEvents: function(),
> say: function()
> }
> > hello.say()
> "Hello World"
> ```

Q&A:
- 在节点1上创建的帐户，在节点2上是没有办法看到的；
  在节点1上创建的帐户，保存出该帐户的密钥文件，需要将密钥文件导入到节点2中，才能在节点2上操作该帐户；
