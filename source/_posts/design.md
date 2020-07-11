---
  title: design model 之 subcribe/publish 
  date: 2018-08-10
  categories:
    - 设计模式
  tags:
    - golang
---
### 简单工厂模式
```go
type sayer interface {
    say()
}

type man struct{

}

func (m *man)say(){
    fmt.Printf("I am man")
}

type woman struct{

}

func (w *woman)say(){
    fmt.Printf("I am woman")
}

func factory(t string) sayer{
    if t=="man" {
        return &man{}
    }else{
        return &woman{}
    }
}

func main(){
    s := factory("man")
    s.say()
}
```