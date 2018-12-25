---
title: solidity代码优化
date: 2018-04-15
categories:
  - blockchain
tags:
  - solidity 
  - eth
---

```javascript
contract BadFailEarly {
  uint constant DEFAULT_SALARY = 50000;
  mapping(string => uint) nameToSalary;
  function getSalary(string name) constant returns (uint) {
      if (bytes(name).length != 0 && nameToSalary[name] != 0) {
            return nameToSalary[name];
          } else {
                return DEFAULT_SALARY;
              }
    }
}

contract GoodFailEarly {
  mapping(string => uint) nameToSalary;

  function getSalary(string name) constant returns (uint) {
      if (bytes(name).length == 0) throw;
      if (nameToSalary[name] == 0) throw;

      return nameToSalary[name];
    }
}

contract BadPushPayments {
  address highestBidder;
  uint highestBid;

  function bid() {
      if (msg.value < highestBid) throw;
      if (highestBidder != 0) {
            // return bid to previous winner
            if (!highestBidder.send(highestBid)) {
                    throw;
            }
      }
      highestBidder = msg.sender;
      highestBid = msg.value;
    }
}

/*when sending ether, favor pull over push payments. 发送以太坊，支付推动付款 */
contract GoodPullPayments {
  address highestBidder;
  uint highestBid;
mapping(address => uint) refunds; //refund 退款

function bid() external {
    if (msg.value < highestBid) throw;

    if (highestBidder != 0) {
          refunds[highestBidder] += highestBid;
        }

    highestBidder = msg.sender;
    highestBid = msg.value;
  }

function withdrawBid() external {
    uint refund = refunds[msg.sender];
    refunds[msg.sender] = 0;
    if (!msg.sender.send(refund)) {
          refunds[msg.sender] = refund;
        }
  }
}

/**
*  顺序化代码
   - condition, 条件
   - actions,   动作
   - interaction, 影响
*
*/

function auctionEnd() {
// 1. Conditions
if (now <= auctionStart + biddingTime)
  throw; // auction did not yet end
if (ended)
  throw; // this function has already been called

// 2. Effects
ended = true;
AuctionEnded(highestBidder, highestBid);

// 3. Interaction
if (!beneficiary.send(highestBid))
  throw;
}
}

contract BadArrayUse {
address[] employees;
mapping(address => uint) bonuses;

function payBonus() {
    //@ i : uint8(0~255)
    for (var i = 0; i < employees.length; i++) {
          address employee = employees[i];
          uint bonus = calculateBonus(employee);
          employee.send(bonus);
        }
  }

  //循环中执行的函数，必须很清楚每个循环消耗多少gas，否则导致gas不足，进行回滚
  function calculateBonus(address employee) returns (uint) {
    // some expensive computation ...
    bonuses[employee] = bonus;
  }
}


// PullPayment.sol 在zeppelin包中
import './PullPayment.sol';
contract GoodArrayUse is PullPayment {
address[] employees;
mapping(address => uint) bonuses;

function payBonus() {
    for (uint i = 0; i < employees.length; i++) {
          address employee = employees[i];
          uint bonus = bonuses[employee];
          //******
          asyncSend(employee, bonus);
        }
  }
function calculateBonus(address employee) returns (uint) {
    uint bonus = 0;
    // some expensive computation...

    bonuses[employee] = bonus;
  }
}

import './PullPayment.sol';
import './Token.sol';
contract Bounty is PullPayment {
bool public claimed;
mapping(address => address) public researchers;

function() {
    if (claimed) throw;
  }

function createTarget() returns(Token) {
    Token target = new Token(0);
    researchers[target] = msg.sender;
    return target;
  }

function claim(Token target) {
    address researcher = researchers[target];
    if (researcher == 0) throw;

    // check Token contract invariants
    if (target.totalSupply() == target.balance) {
          throw;
        }
    asyncSend(researcher, this.balance);
    claimed = true;
  }
}

//紧急停止合约
contract Stoppable{
  address public curator;
  bool public stopped;

  modifier stopInEmergency {if (!stopped) _;}
  modifier onlyInEmergency {if (stopped) _;}

  function Stoppable(address _curator){
      if(_curator == 0) throw;
      curator = _curator;
  }

  function emergencyStop() external{
      if(msg.sender != curator) throw;
      stopped = true;
  }
}

import './PullPayment.sol';
import './Stoppable.sol';
contract StoppableBid is Stoppable, PullPayment {
address public highestBidder;
uint public highestBid;

function StoppableBid(address _curator)
  Stoppable(_curator)
  PullPayment() {}

function bid() external stopInEmergency {
    if (msg.value <= highestBid) throw;

    if (highestBidder != 0) {
          asyncSend(highestBidder, highestBid);
    }

    highestBidder = msg.sender;
    highestBid = msg.value;
}

function withdraw() onlyInEmergency {
    suicide(curator);
  }
}
```
