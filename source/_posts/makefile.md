---
  title:golang中使用makefile
---

Makefile必须以tab来进行缩进

```
  target: prerequisites
    recipe
```

- make 变量

  VAR := value  //声明变量
```
  FILE := abc
  $(FILE): xyz
    echo $(FILE) > "something"

  xyz:
    echo "xyz" > xyz
```
https://sahilm.com/makefiles-for-golang/

make描述了如何构建我们的项目，那些可运行的测试以及项目中依赖的额外的工具；
PHONY 目标并非实际的文件名： 只是显示请求时执行命令的名字；优势有以下两点：

- 避免和同名文件冲突
  如果编写一个规则，并不产生目标文件，则其命令在每次make该目标时都执行：
 ```
  clean:
    rm *.o temp
 ```
   因为" rm "  并不生成" clean "文件，则每次执行" make clean " 的时候，该命令都会执行；
   如果目录中出现了 " clean "文件，则规则失效了：没有依赖文件，文件"clean"始终是最新的， 命令永远不会执行； 为了避免这个问题，可使用" .PHONY "指明该目标。
```
  .PHONY: clean
  clean:
    rm *.0 temp
```
  这样执行" make clean "会无视" clean "文件存在与否；
  已知phony 目标并非是由其它文件生成的实际文件，make 会跳过隐含规则搜索。这就是声明phony 目标会改善性能的原因，即使你并不担心实际文件存在与否。

- 改善性能
  phony 目标可以有依赖关系。当一个目录中有多个程序，将其放在一个makefile 中会更方便。因为缺省目标是makefile 中的第一个目标，通常将这个phony 目标叫做"all"，其依赖文件为各个程序：

```
all : prog1 prog2 prog3
.PHONY : all
prog1 : prog1.o utils.o
  cc -o prog1 prog1.o utils.o
prog2 : prog2.o
  cc -o prog2 prog2.o
prog3 : prog3.o sort.o utils.o
  cc -o prog3 prog3.o sort.o utils.o
```
一个项目最后需要产生两个可执行文件。主要目标是产生两个可执行文件，但这两个文件是相互独立的——如果一个文件需要重建，并不影响另一个。使用“假象目的”来 达到这种效果。一个假象目的跟一个正常的目的几乎是一样的， 只是这个目的文件是不存在的。因此， make 总是会假设它需要 被生成，当把它的依赖文件更新后，就会执行它的规则里的命令行。
