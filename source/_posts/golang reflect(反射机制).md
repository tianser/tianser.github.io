---
  title: Golang反射包的实现原理（The Laws of Reflection)
---

### 类型和接口(Types and interfaces)

因为反射是建立在类型系统(type system)上的。所以我们从Go的类型入手
- Go是静态类型化的。每个变量都有一个静态类型
```go
type MyInt int

var i int
var j MyInt
```
i的类型就是int，而j的类型就是MyInt；这里的变量i和j具有不同的静态变量，虽然他们拥有相同的底层类型(underlying type),如果不显示的进行强制类型转换他们是不能相互赋值的；

类型(type)中非常重要的一类(category)就是接口类型(interface type); 一个接口就表示一组确定的方法（method）集合。一个接口变量能存储任意的具体值（这里的具体concrete就是指非接口的non-interface)，只要这个具体值所属的类型实现了这个接口的所有方法。

一个大家都很熟悉的例子是io.Reader和io.Writer，类型Reader和类型Writer来自io包:
```go
type Reader interface{
  Read(p []byte) (n int, err error)
}

type Writer interface{
  Write(p []byte)(n int, err error)
}
```
实现了上面的Read方法（或Write方法）的任意类型都可以说实现了io.Reader接口（或io.Writer接口)。 这就意味着io.Reader接口变量能够保存任意Read方法的类型所定义的值；

```go
var r io.Reader
r = os.Stdin
r = bufio.NewReader(r)
r = new(bytes.Buffer)
```
明确r到底保存了什么样的具体值非常重要，但是这里r的类型却总是io.Reader：注意Go是静态类型化的，而r的静态类型是io.Reader。

一个非常非常重要的接口类型例子就是空接口:
```go
interface{}
```
空接口表示方法集合为空并且可以保存任意值，因为任意值都有0个或者更多方法。
- 有些人说Go的接口是动态类型化的，但这是一种误导。
- Go的接口都是静态类型化的：一个接口类型变量总是保持同一个静态类型，即使在运行时它【接口类型变量】保存的值类型发生变化，这些值总是满足这个接口。

### 接口的表示(The representation of an interface)

- 一个接口类型变量存储了一个pair：
  - 赋值给这个接口变量的具体值
  - 该值的类型描述符
- 更进一步的说：
  - 这个" 值 "是实现了这个接口的底层具体数据项(underlying concrete data item)
  - 这个" 类型 "是描述了那个接口底层具体数据项(item)的全类型(full type)
```go
var r io.Reader
tty, err := os.OpenFile("/dev/tty", os.O_RDWR, 0)
if err != nil{
  return nil, err
}
r = tty
```
- 分析
  - 接口变量r 包含了（value, type) 对，即（tty, os.File) //(底层具体数据项, 描述底层具体数据项的全类型)
  - 除了Read方法以外，类型os.File也实现了其它方法；即使这个接口值仅仅提供了对Read方法的访问，这个接口值内部仍然带有关于这个值的全部类型信息。这就是为什么我们能干下面这些事儿：
```go
var w io.Writer
w = r.(io.Writer)
```
赋值操作中的表达式是一个类型断言（type assertion）；它所断言的是r中存储的项（item）也实现了io.Writer接口，所以我们可以把它赋值给w。<br>
赋值操作完毕以后，w将会包含 (tty, *os.File)对;w中的pair跟r中的pair是同样的。
接口的静态类型决定了能用接口变量调用哪些方法，即使接口里存的具体值内部可能还有一堆其它方法；

接口定义的方法集合是该种接口变量所保存的具体值所含有的方法集合的一个子集，通过这个接口变量只能调用这个接口定义过的方法，没法通过这个接口变量调用其它任何方法；
```go
var empty interface{}
empty = w
```
empty，也能包含同样的pair即(tty, *os.File)。这样的话就很方便了，一个空接口可以保存任意值和我们所需要的关于所保存值的全部信息。
- 一个接口中的pair总有（值，具体类型）这样的格式，而不能有（值，接口类型）这样的格式。
- 接口不能保存接口值（也就是说，你没法把一个接口变量值存储到一个接口变量中，只能把一个具体类型的值存储到一个接口变量中。）

### 反射
####  第一反射定律(the first law of reflection)
- 从接口值到反射对象的反射
  反射是一种检查存储在接口变量中的（类型，值）对的机制。
```go
var x float64 = 3.4
fmt.Println("type:", reflect.TypeOf(x))   //type: float64
fmt.Println("value:", reflect.ValueOf(x)) //Valueof方法会返回一个Value类型的对象

//TypeOf函数原型
func TypeOf(i interface{}) Type
```
当我们调用reflect.Typeof(x)的时候，x首先被保存到一个空接口中，这个空接口然后被作为参数传递。reflect.Typeof 会把这个空接口拆包（unpack）恢复出类型信息。

```go
var x float64 = 3.4
v := reflect.ValueOf(x)
fmt.Println("type:", v.Type())  //返回值的静态类型；就是说如果定义了type MyInt int64，那么这个函数返回的是MyInt类型而不是int64，
fmt.Println("kind is float64:", v.kind() == reflect.Float64) //返回值的底层类型，是说如果定义了type MyInt int64，那么这个函数返回的是int64类型而不是MyInt类型，
fmt.Println("value:", v.Float())

type: float64
kind is float64: true
value: 3.4
```

反射库有两特殊性质：
  - 为了保持API简单，Value的”setter”和“getter”类型的方法操作的是可以包含某个值的最大类型；
    - 比如，所有的有符号整型，只有针对int64类型的方法，因为它是所有的有符号整型中最大的一个类型。也就是说，Value的Int方法返回的是一个int64，同时SetInt的参数类型采用的是一个int64；
```go
var x uint8 = 'x'
v := reflect.ValueOf(x)
fmt.Println("type:", v.Type()) // uint8.
fmt.Println("kind is uint8: ", v.Kind() == reflect.Uint8) // true.
x = uint8(v.Uint())// v.Uint returns a uint64.看到啦嘛？这个地方必须进行强制类型转换！
```
  - 反射对象（reflection object）的Kind描述的是底层类型（underlying type），而不是静态类型（static type）

### 第二反射定律（The second law of reflection）
#### 从反射队形到接口值的反射

给定一个reflect.Value，我们能用Interface方法把它恢复成一个接口值；效果上就是这个Interface方法把类型和值的信息打包成一个接口表示并且返回结果：
```go
// func (v Value) Interface() interface{}

y := v.Interface().(float64)
fmt.Println(y)
```
我们甚至可以做得更好一些，fmt.Println等方法的参数是一个空接口类型的值，所以我们可以让fmt包自己在内部完成我们在上面代码中做的工作。因此，为了正确打印一个reflect.Value，我们只需把Interface方法的返回值直接传递给这个格式化输出例程：
```go
fmt.Preintln(v.Interface())
fmt.Printf("value is %7.1e\n", v.Interface())
```
我们不需要对v.Interface方法的结果调用类型断言（type-assert)为float64；空接口类型值内部包含有具体值的类型信息，并且Printf方法会把它恢复出来。

Interface方法是Valueof函数的逆，除了它的返回值的类型总是interface{}静态类型。

### 第三反射定律
#### 为了修改一个反射对象，值必须是settable的
```go
var x float64 = 3.4
v := reflect.ValueOf(x)
v.SetFloat(7.1) // Error: will panic

//panic: reflect.Value.SetFloat using unaddressable value
```
问题不是出在值7.1不是可以寻址的，而是出在v不是settable的。Settability是Value的一条性质，而且，不是所有的Value都具备这条性质;
Value的CanSet方法用与测试一个Value的settablity；
```go
var  x float64 = 3.4
v := reflect.ValueOf(x)
fmt.Println("settability of v:", v.CanSet())

//
settability of v: false
```
传递了x的一个副本给reflect.Valueof函数，所以作为reflect.Valueof参数被创造出来的接口值只是x的一个副本，而不是x本身。
```go
var x float64 = 3.4
p := reflect.ValueOf(&x)
fmt.Println("type of p:", p.Type())
fmt.Println("settability of p:", p.CanSet())
//
type of p: *float64
settability of p: false
```
反射对象p不是settable的，但是我们想要设置的不是p，而是（效果上来说）*p。为了得到p指向的东西，我们调用Value的Elem方法;这样就能迂回绕过指针，同时把结果保存在叫v的Value中.
```go
v := p.Elem()
fmt.Println("settability of v:", v.CanSet())
v.SetFloat(7.1)
fmt.Println(v.Interface())
fmt.Println(x)

//
settability of v: true
7.1
7.1
```
反射理解起来有点困难，但是它确实正在做编程语言要做的，尽管是通过掩盖了所发生的一切的反射Types和Vlues来实现的。这样好了，你就直接记住反射Values为了修改它们所表示的东西必须要有这些东西的地址。

### structs
v本身不是一个指针，它只是从一个指针派生来的。出现这种情况的一个常见的方法是当使用反射来修改一个structure的各个域的时候。只要我们有这个structure的地址，我们就能修改它的各个域。
```go
type T struct{
  A int
  B string
}

t := T{23, "skidoo"}
s := reflect.ValueOf(&t).Elem()
typeOfT := s.Type()   //把s.Type()返回的Type对象复制给typeofT，typeofT也是一个反射

for i:=0; i<s.NumField(); i++{
  f := s.Field(i)   //迭代s的各个域，注意每个域仍然是反射。
  fmt.Printf("%d: %s %s = %v\n", i, typeOfT.Field(i).Name, f.Type(), f.Interface())//提取了每个域的名字
}

s.Field(0).SetInt(77)
s.Field(1).SetString("Sunset Strip")
fmt.Println("t is now", t)

//
0: A int = 23
1: B string = skidoo
t is now {77 Sunset Strip}
```
