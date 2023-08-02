# 项目框架Class类阅读笔记

使用class.Class("className")定义一个类，此后就可以对该类进行成员变量和成员函数的定义。

```lua
local class = require("Core.Framework.Class")
local Queue = class.Class("Queue")      -- 定义一个队列类
```

在定义ClassBase的过程中需要定义以下几个内容
+ 类相关的数据（类型名，Component列表，父类类型，继承关系等）
+ 类的实例化方法（使用原表来模拟虚表实现访问父类的成员函数和变量）
+ 构造元表作为虚表，来为类写入属性和方法（在原表中使用`__index`实现查询虚表中的属性，`__newindex`实现向类的虚表中加入自定义方法，`__call`实现类的初始化等）

