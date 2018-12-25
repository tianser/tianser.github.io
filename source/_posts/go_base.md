---
title: go之基础重温
date: 2018-04-15
categories:
  - golang
tags:
  - golang
---
- 值语义
     -  大多数类型基于值语义，包括基本类型：byte, int, bool, float32, float64 和string
     - 复合类型： array, struct, pointer

- 引用语义
变量存储的是一个地址，这个地址存储最终的值。内存通常在堆上分配。通过GC回收。
获取指针类型所指向的值，使用：" * " 取值符号 。

    - 数组切片slice
    - map
    - channel
    - interface
    - 指针

- new 和 make 区别
    - new 用于值类型和用户自定义的类型（如struct）
   ```go
   new 内建函数原型：func new(Type)  *Type
   new 返回指向类型的指针。
```
    -   make 用于内置（slice，map 和channel)
    ```go
   make内建函数原型： func make(t Type, size ...IntegerType) Type
   make返回引用类型
  ```

在golang中，nil只能赋值给指针、channel、func、interface、map或slice类型的变量；
不能直接使用nil值的slice 和map

- Go中的struct与其他语言的类(class)有同等地位，Go中放弃了包括继承在内的大量面向对象特性，只保留了组合composition这个基础特性；
- Go中未被初始化的值都被初始化为该类型的零值；

```go
type Rect struct{
  x int
  y int
}
//初始化
rect := new(Rect)
rect := &Rect{}
rect := &Rect{1,  2}
rect := &Rect{
  x: 1,
  y: 2,
}

//约定俗成的规矩，而非强制
/* 对象的创建通常由一个全局的创建函数完成，NewXXX来命名，表示构造函数 */
func NewRect(x, y, width, height int) *Rect{
  return &Rect{
    x: x,
    y: y,
  }
}
```

- 匿名组合
```go
type Foo struct{
    Rect
    z int
}

func NewFoo(x, y, z) *Foo{
  return &Foo{
    Base: Base{x: x, y: y},
    z: z,
  }

  //形式2， y后面的逗号
  return &Foo{
        Base: Base{
            X: x,
            Y: y,
        },
        z: z,
    }
}
var  f *Foo
f.Base.Bfunc()
f.Bfunc()
```

- 可见性

  需要使某个符号对其他包可见，需要将该符号定义为以大写字母开头

- interface 接口 
- interface 赋值 
```go
func (this *Foo)add(size int){
  this.X += size
}

func (this Foo)less(m int) bool {
  return Foo.X > m
}

type Add interface{
  add(s int)
  less(m int) bool
}

var f = Foo{Base{X: 1, Y: 2}, 3}
var a Add = &foo        //pointer      (1)
var a Add = foo         // error       (2)

 应该用语句(1)。原因在于，Go语言可以根据下面的函数：
func (this Foo) less(m int) bool
自动生成一个新的Less()方法：
func (this *Foo) less(m int) bool {
return (*this).less(m)
}

这样，类型*Foo就既存在less()方法，也存在add()方法，满足Add接口。而从另一方面来说，根据
func (this *Foo) add(size int)
这个函数无法自动生成以下这个成员方法：
func (this Foo) add(size int) {
  (&this).add(size)
}
因为(&this).add()改变的只是函数参数a，对外部实际要操作的对象并无影响，这不符合用
户的预期。所以，Go语言不会自动为其生成该函数。因此，类型Foo只存在less()方法，
缺少add()方法，不满足Add接口，故此上面的语句(2)不能赋值。
```

- 接口查询:

```go
var f = Foo{Base{X:1, Y: 2}, 3}
if f_, ok := f.(Add); ok{
    ...
}

var v1 interface{} = ...
switch v := v1.(type){
case int:
case string:
default:
...
}
```
