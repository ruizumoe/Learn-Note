# Lua中"."和":"的区别

## 主要区别
在lua中`.`和`:`主要差别：
1. 只能通过`.`去调用table中的元素，`:`只能调用table中的方法
2. `.`和`:`均能调用table中的方法，但是使用`:`调用方法时，lua会默认将使用该方法的table以self的形式传入函数中。
3. 在一定程度上 `table.function(table) = table:function()`，但是在子类调用父类方法时会出现一定的问题。


## 基础例子


```lua
local Car = { Name = "Byd", Price = 12 }

print(Car)          -- table: 00AC9B70

--- 测试1 参数均不带self
function Car.find1(self)
    print(". 定义的函数并且使用 . 调用时 self 的地址--->", self)
end

function Car:find2()
    print(": 定义函数并且使用 : 调用时 self的地址 ----->", self)
end

Car.find1()      -- nil
Car:find2()      -- table: 00AC9B70

function Car:find3()
    print("使用:定义函数, 但使用.调用函数，self地址为 ----->", self)
end

function Car.find4()
    print("使用.定义函数，但使用:调用函数，self地址为 ----->", self)
end

Car.find3()       -- nil
Car:find4()       -- nil

print(string.rep("*", 30))


--- 测试2 参数均带self

function Car:find5(self)
    print(": 定义的函数并且使用 : 调用时 self 的地址--->", self)
end

function Car.find6(self)
    print(". 定义的函数并且使用 . 调用时 self 的地址--->", self)
end

function Car:find7(self)
    print(": 定义的函数并且使用 . 调用时 self 的地址--->", self)
end

function Car.find8(self)
    print("使用.定义函数，但使用:调用函数，self地址为 ----->", self)
end

Car:find5()       -- nil
Car.find6()       -- nil
Car.find7()       -- nil
Car:find8()       -- table: 00AC9B70
```

从上面的例子可以看到`Car.find8(self)`和`Car:find()`中获取的`self`是一样的, 均为Car这一table的地址。


## 类和对象的应用

如果将该方法应用在类的定义和对象的创建中, 此时`.`一般适用于类方法的定义，`:`偏向于面向对象的方式调用


### 类方法定义

```lua

local classA = {}

print(classA)       -- table classA的地址

function classA.new(cls, ...) --定义类方法时使用"."号，不适用隐式传参
    print(cls)          -- 输出基类的地址
    this = {}
    print("new childClass ----> ", this)
    setmetatable(this, cls)
    cls.__index = cls      --将元表的__index设为自身，访问this表的属性不存在时会搜索元表
    cls.init(this, ...)     -- 后续需要为classA设置初始化函数，
    return this             -- 返回对象
end

function classA.init(self, name)
    print("classA.init  --->  ", self)
    self.name = name
end

function classA:getName()
    print("classA.getName ----> ", self)
    return self.name
end


classB = classA:new("newClassB")
print(classB:getName())


--[[ 
    输出结果:
    table: 00CE96F8
    table: 00CE96F8
    new childClass ---->    table: 00CE9D10
    classA.init  --->       table: 00CE9D10
    classA.getName ---->    table: 00CE9D10
    newClassB
]]

```


### 面向对象的思想

使用lua的冒号来完成类的实例化和继承

```lua
local classC = {}

print("classC's address is ", classC)

function classC:getObject(name)
    print("ClassC is ctor , classC's self address is , ", self)
    local object = {}
    setmetatable(object, self)          -- 此处的self是classC这个类
    self.__index = self     -- 保证参数和方法能够被对象调用
    self.name = name        -- 此时的self是classC
    return object
end

function classC:getSelf()
    print("ClassC is use method, classC's self address is , ", self)
    return self
end

o1 = classC:getObject("object1")
o2 = classC:getObject("object2")
print(o1:getSelf().name)        -- object2  因为o1和o2的元表都是classC,而o2将classC的name定义为了obejct2
print(o2:getSelf().name)        -- obejct2

print("obejct1's address is ", o1)
print("obejct2's address is ", o2)


------ 继承 ------
print("before classD, the classC's name is ", classC.name)
local classD = classC:getObject("classD")       -- 此时classC类的name被设置为了classD
print("after classD, the classC's name is ", classC.name)

function classD:getNew(name)
    local object = classC:getObject(name)       -- 将classC的name设置为childObject1
    print("childObject name is ", object:getSelf().name)
    setmetatable(object, self)      -- 此处的self是调用getObject方法的classD这个类
    self.__index = self     -- 保证object对象能够访问classD定义的方法和参数
    return object
end

local childO1 = classD:getNew("childObject1")
print(childO1.name)         -- 会去找classC的name
print("now classC's name is ", classC.name)

print("childObject1's address is ", childO1)

--[[ 输出结果
classC's address is     table: 00BB9DD8
ClassC is ctor , classC's self address is ,     table: 00BB9DD8
ClassC is ctor , classC's self address is ,     table: 00BB9DD8
ClassC is use method, classC's self address is ,        table: 00BB9E78
object2
ClassC is use method, classC's self address is ,        table: 00BB9E50
object2
obejct1's address is    table: 00BB9E78
obejct2's address is    table: 00BB9E50
before classD, the classC's name is     object2
ClassC is ctor , classC's self address is ,     table: 00BB9DD8
after classD, the classC's name is      classD
ClassC is ctor , classC's self address is ,     table: 00BB9DD8
ClassC is use method, classC's self address is ,        table: 027315C0
childObject name is     childObject1
childObject1
now classC's name is    childObject1
childObject1's address is       table: 027315C0
    
]]

```

### 总结

通过上面两种情况可以看出，如果期望使用类方法，则使用`.`调用方法，这样就可以将特定的self传入类方法，从而对self进行操作；而如果使用`:`则默认是将调用该方法的table作为self传入方法中

在一般情况下两者可以等同，但是在特殊情况下，会有所差别，主要在于连环调用或调用父类方法的时候。

如下：
```lua
local BaseShowScene = require "System.ShowScenes.BaseShowScene"
local FleetShowMgr = class.Class("FleetShowMgr",BaseShowScene)

function FleetShowMgr:ctor()
    BaseShowScene.ctor(self)
end

function FleetShowMgr:init()
    BaseShowScene.init(self, self.sceneType.SLG_Fleet)
    return true
end

function FleetShowMgr:dispose(callback)
    if callback then
        BaseShowScene.hide(self)
        game.sceneMgr:unLoadSceneAsync(self.tarSceneName, callback)
    end
    ...
end
```

在上述代码中`BaseShowScene.hide(self)`就不能使用`BaseShowScene:hide()`,因为此处`BaseShowScene:hide()`默认传递的self实际是`BaseShowScene`，而不是FleetShowMgr。

此处的BaseShowScene想到于从外部引入了一个工具类，并使用了其中的类方法，而不是调用的继承的方法。如果要使用父类的dispose方法，需要在FleetShowMgs的函数中使用`self.super.hide(self)`

