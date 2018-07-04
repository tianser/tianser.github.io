---
    title: goroutine
---

### 协程
协程（Coroutine）本质上是一种用户态线程，不需要操作系统来进行抢占式调度，且在真正的实现中寄存于线程中，因此，系统开销极小，可以有效提高线程的任务并发性，而避免多线程的缺点。使用协程的优点是编程简单，结构清晰；缺点是需要语言的支持，如果不支持，则需要用户在程序中自行实现调度器；目前，原生支持协程的语言还很少；

### 并发通信
- 两种最常用的并发通信模式：消息和共享数据
```go
var ch map[string] chan bool
```

### 单向channel
对channel的限制使用：<br/>
一个channel变量传递到一个函数时，可以通过将其指定为单向channel变量，从而限制该函数中可以对此channel的操作，比如只能往这个channel写，或者只能从这个channel读。

- 使用多核心CPU:
```go
  runtime.GOMAXPROCS(16)
```
- 出让时间片
  使用runtime包中的Gosched()函数实现
  实际上，需要精细地控制goroutine的行为，就必须深入地了解GO语言开发包中的runtime包所提供的具体功能；

### go 网络编程
- 标准库中的net包
- 使用net.Dial()封装了socket(), bind(), listen(), connect(),accept(), receive(), send()函数；
```go
func handleMsg(conn net.Conn) ([]byte, error) {
    defer conn.Close()

    result := bytes.NewBuffer(nil)  //这里需要用循环buf来提高效率
    var buf [512]byte
    for {
        size, err := conn.Read(buf[0:])
        result.Write(buf[0:size])
        if err != nil {
            if err == io.EOF {
                break
            }
            return nil, err
        }
    }
    return result.Bytes(), nil
}
```

### http
- net/http包


### 工程管理
- 命名<br/>
  驼峰命名命名法doSometing<br/>
  c/c++则是下划线命名法
- 目录结构
```sh
<calcproj>
  ├─README
  ├─AUTHORS
  |─LICENSE
  ├─<bin>
    ├─calc
  ├─<pkg>
    └─<linux_amd64>
      └─simplemath.a
  ├─<src>
    ├─<calc>
      └─calc.go
    ├─<simplemath>
      ├─add.go
      ├─add_test.go
      ├─sqrt.go
      ├─sqrt_test.go
```
