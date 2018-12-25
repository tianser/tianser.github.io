---
 title: c++11基础整理
---

### 关键字：
- override： 确保成员函数为虚并覆盖基类的虚函数
    + 用于标注在派生类函数中
    + 该函数必须和基类的函数有相同的签名(即参数，返回值，const等一致)
    + 在基类中，该函数必须声明为virtual
    
- final: 一旦成员虚函数被声明为final，派生类不能再覆盖它
    + 表面它的派生类不能再覆盖写该成员函数；
    + 该函数在其基类声明必须为virutal

```c++
struct A
{
    virtual void foo();
    void bar();
    void foo2();
};
 
struct B : A
{
    void foo() const override; // 错误： B::foo 不覆写 A::foo
                               // （签名不匹配）
    void foo() override;       // OK ： B::foo 覆写 A::foo
    void bar() override;       // 错误： A::bar 非虚
    void foo2();               // OK, 运行多态时不能覆盖基类函数
};
```
```c++
    struct Base
    {
        virtual void foo();
    };
     
    struct A : Base
    {
        void foo() final; // A::foo 被覆写且是最终覆写
        void bar() final; // 错误：非虚函数不能被覆写或是 final
    };
     
    struct B final : A // struct B 为 final
    {
        void foo() override; // 错误： foo 不能被覆写，因为它在 A 中是 final
    };
     
    struct C : B // 错误： B 为 final
    {
    };
```

### NULL 与 nullptr

- NULL是一个宏，值为0；
- typedef decltype(nullptr) nullptr_t;

```c++
void foo(int);      // (1)
void foo(void*);    // (2)

foo(NULL);      //期望调用（2），但实际上模板推断为（1）
foo(nullptr);   //模板推断为（2）
```


关联关系(人与气候)，聚合关系（人与人群）、组合关系（人和脑袋），依赖关系（人和空气）

