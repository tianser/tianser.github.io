---
  title: paxos
  date: 2018-04-15
  categories:
    - ceph
  tags:
    - paxos 
---

### 这个leader节点是怎么确定的？
答案：zookeeper系统自己选举出来的，所有server节点（observer除外），都参与这个选举。这样做的好处是：当现在leader挂掉了之后，系统可以重新选举一个节点做leader。
Zookeeper的选举算法能保证：只要超过半数节点还活着，就一定能选举出唯一个一个节点作为leader。

- 选举发生时机
   - 当任何一个节点进入looking状态时，选举开始，进入looking状态有如下原因：
   1、节点刚启动，使自己进入选举状态
   2、发现leader节点挂掉了
   Zookeeper中的leader怎么知道follower还活着？follower怎么知道leader还活着？leader会定时向follower发ping消息；follower会定时向leader发ping消息。当发现无法ping通leader时，就会将自己的状态改为LOOKING，并发起新一轮选举。处于选举模式时，zookeeper服务不可用。
- 一个节点成为leader条件
    一个节点要成为leader，必须得到至少n/2+1（即半数以上节点）投票，实际上，在实现时，还可以考虑其它规则，比如节点权重。
    为什么要保证至少n/2+1的节点同意？因为这样能保证本节点得到多数派的支持。因为每一个节点，只能支持一个节点成为leader，因此，只要一个节点获得至少n/2+1选票，就一定会比其它任何节点得到的选票多。
    这个规则意味着，如果超过半数以上的节点挂掉，zookeeper是选举不出leader节点的，因此，zookeeper集群最多允许n/2节点故障。

### 选举leader中涉及到的问题
  选举算法目标是确保一定要选出一个唯一的leader节点。这有两层含义：
    - 一定要选出一个节点作为leader
    - 这个leader一定要唯一
    为此，要解决如下问题：
      1、在一次选举中，节点应该把票投给谁？
      规则：每个节点有一个唯一id，在选举中，节点总是把票投给id最大的那个节点，这样，id大的节点更有可能成为leader，天生就是做领导的料。
      2、在一次选举过程中，有些节点由于没有启动而没参加（有些人去国外了，没有赶上这次大选，当他回国后，进入looking状态，要发起选举，怎么办？），后来这个节点启动了，此时要求选举，怎么解决？
      3、运行过程中，leader节点挂掉了，怎么办？
        此时其它节点会发现leader挂了，会发起新一轮选举，最后选出新leader。

### 尝试解决方案
    1、直接指定一个节点做leader，例如，永远都让id最大节点当leader，这个想法最简单。问题：这个节点挂了怎么办？这会出现单点问题。
    2、每次选举中，让活着节点中，id最大节点当leader。问题：1、其它节点怎么知道活着节点中，谁id最大？

### 选举算法流程
    选举开始时，每个节点为自己生成一张投票，推荐自己成为leader，并把投票发送给其它节点，这相当于paxos算法中的proposer角色。接下来，节点启动一个接收线程接收其它节点发送过来的投票，并对选票进行处理，这相当于paxos中的acceptor角色。简单说，节点之间通过这种消息发送（投票），最终选举出leader。

    当收到其他它节点的选票之后，会和自己的投票比较，如果比自己的投票好（比如推荐的leader的id更大，选举轮数更新），则更新自己的选票，接下来把收到的选票放在选票列表里（该列表存储了所有节点的投票，是一个key-value结构，key为节点的id，value为该节点的投票）。并再次把自己的投票发送给其它节点。

    接下来节点会统计选票列表中每个节点获得的票数，如果有一个节点获得超过半数的选票，则认为该节点是leader。如果本节点就是，则将自身的状态置为leading，表明自己是leader；否则将自己的状态置为following，表明自己是follower。

    通过若干轮的消息交换，最终，会有一个节点获得超过一半的选票而成为leader。这种方法的精髓在于，每个节点在不需要获得所有节点的信息（投票结果）的前提下，达成一致意见，选出leader

### 运行机制
    选举leader之后，只有leader节点才能发起提案，其他节点(Peon角色)根据本地历史选择接受或拒绝Leader的提案，并向Leader回复结果。Leader统计并提交超过半数Paxos节点接受的提案。

### 常规过程（Normal Case）
常规服务状态下存在一个唯一的Leader以及一个已经确认的大多数节点Quorum，Leader将每个写请求被封装成一个新的提案发送给Quorum中的每个节点，其过程如下，注意这里的Quorum固定：
- Leader将提案追加在本地Log，并向Quorum中的所有节点发送begin消息，消息中携带提案值、Pn及指向前一条提案version的last_commit；
- Peon收到begin消息，如果accept过更高的pn则忽略，否则提案写入本地Log并返回accept消息。同时Peon会将当前的lease过期掉，在下一次收到lease前不再提供服务；
- Leader收到全部Quorum的accept后进行commit。将Log项在本地DB执行，返回调用方并向所有Quorum节点发送commit消息；
- Peon收到commit消息同样在本地DB执行，完成commit；
- Leader追加lease消息将整个集群带入到active状态。

### 选主（Leader Election）
Peon的Lease超时或Leader任何消息超时都会将整个集群带回到Probing状态，整个集群确定新的Members并最终进入Election状态进行选主。每个节点会在本地维护并在通信中交互选主轮次编号election_epoch，election_epoch单调递增，会在开始选主和选主结束时都加一，因此可以根据其奇偶来判断是否在选主轮次，选主过程如下：

将election_epoch加1，向Monmap中的所有其他节点发送Propose消息；
收到Propose消息的节点进入election状态并仅对更新的election_epoch且Rank值大于自己的消息答复Ack。这里的Rank简单的由ip大小决定。每个节点在每个election_epoch仅做一次Ack，这就保证最终的Leader一定获得了大多数节点的支持；
发送Propose的节点统计收到的Ack数，超时时间内收到Monmap中大多数的ack后可进入victory过程，这些发送ack的节点形成Quorum，election_epoch加1，结束Election阶段并向Quorum中所有节点发送Victory消息，并告知自己的epoch及当前Quorum，之后进入Leader状态；

收到VICTORY消息的节点完成Election，进入Peon状态；
