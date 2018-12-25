---
  title: ERC20标准说明
  date: 2018-04-15
  categories:
    - blockchain
  tags:
    - eth
---
### 概述
原文说明：https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20.md

### 函数说明
所有的ERC20代币都是按照下面这些方法来定义的。
- name
```javascript
function name() constant returns (string name)
```
返回string类型的ERC20代币的名字，例如：StatusNetwork

- symbol
```javascript
function symbol() constant returns (string symbol)
```
返回string类型的ERC20代币的符号，也就是代币的简称，例如：SNT。

- decimals
``` javascript
function decimals() constant returns (uint8 decimals)
```
支持几位小数点后几位。如果设置为3。也就是支持0.001表示。

- totalSupply
```javascript
function totalSupply() constant returns (uint256 totalSupply)
```
发行代币的总量，可以通过这个函数来获取。所有智能合约发行的代币总量是一定的，totalSupply必须设置初始值。如果不设置初始值，这个代币发行就说明有问题。

- balanceOf
```javascript
function balanceOf(address _owner) constant returns (uint256 balance)
```
输入地址，可以获取该地址代币的余额。

- transfer
```javascript
function transfer(address _to, uint256 _value) returns (bool success)
```
调用transfer函数将自己的token转账给_to地址，_value为转账个数

- approve
```javascript
function approve(address _spender, uint256 _value) returns (bool success)
```
批准_spender账户从自己的账户转移_value个token。可以分多次转移。

- transferFrom
```javascript
function transferFrom(address _from, address _to, uint256 _value) returns (bool success)
```
与approve搭配使用，approve批准之后，调用transferFrom函数来转移token。

- allowance
```javascript
function allowance(address _owner, address _spender) constant returns (uint256 remaining)
```
返回_spender还能提取token的个数。

- approve、transferFrom及allowance解释：
账户A有1000个ETH，想允许B账户随意调用100个ETH。A账户按照以下形式调用approve函数approve(B,100)。当B账户想用这100个ETH中的10个ETH给C账户时，则调用transferFrom(A, C, 10)。这时调用allowance(A, B)可以查看B账户还能够调用A账户多少个token。

### 事件
```javascript
Transfer
event Transfer(address indexed _from, address indexed _to, uint256 _value)
```
当成功转移token时，一定要触发Transfer事件

```javascript
Approval
event Approval(address indexed _owner, address indexed _spender, uint256 _value)
```
当调用approval函数成功时，一定要触发Approval事件
