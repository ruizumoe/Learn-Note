# 语法笔记

## 变量
1. 未使用local规定的变量都是全局变量

2. 局部变量的的作用域是从声明位置开始到语句块结束。

> lua整个文件相当于一个大的语句块，如果直接在文件中定义的局部变量，则其到文件的结束都是其作用范围。

3. 除了循环语句，函数语句，do - end也是语句块的一种

4. 在赋值语句中Lua会先计算右侧所有值，然后再将右侧的值执行赋值操作，因此可以实现直接交换变量
> x, y = y, x     -- swap 'x' for 'y'

> 基于特性3，可以知道 a , b = 0 , 1;<br>
> a, b = a + 1, a + 1;   -----> 1 ， 1 <br>
> 因为Lua会优先计算右侧值，每次计算的时候a的取值均为0，然后得到1后再赋值


当左右值数量不一致时:
+ 多余变量补nil
+ 多余值被忽略

## 循环

lua有三种循环 while .. do .. end; for .. do .. end; repeat .. until;

lua没有continue，但是可以使用goto完成实现continue功能，或者多写一个if判断

for 循环语句的条件表达式有三项，分别为初始值，终止条件，步进值
+ 初始条件必须指定，不能使用外部的变量
    + 初始条件是一个外部索引，在循环体内部修改不会影响i的值
+ 终止条件是<=，即到达终止条件还需要进行一次。
    + 终止条件还可以使用函数，但函数只会在启动循环前执行一次
    + 函数的参数和for的起始条件相互隔离，即使同名，也是不同变量，且外部需要特别定义一个变量用于终止条件
+ 步进值不指定默认为1

在基础泛型遍历中有两种遍历方式pairs和ipairs
+ pairs可以遍历所有的key，直到table内容被遍历后再结束
+ ipairs只遍历key为数字的table元素，且当元素的值为nil时会直接结束遍历
    > tab = { key1 = "val1", key2 = "val2" } ipairs不会遍历<br>
    > {tab = {1,2,a= nil,nil,"d"}} 中a = nil会被跳过，且当遇到后一个nil时会推出循环，不会遍历"d"

进阶泛型遍历可以自定义迭代函数


## 条件表达式

false 和 nil 属于false 数字 0 属于 true

## Lua函数

由于Lua基于C和C++实现，函数可以作为参数进行传递

函数参数列表中，可以使用`...`表示函数有可变参数

select可以用于计算lua变长参数的数量计算，以及返回从一组参数

select(n, ...)表示从返回从第n个数往后的所有数据，返回的是单个值，而不是一个table集合

> arg = select(2, 'one', 'two', 'three', 'four', 'five')  <br>
> print(arg)  --> two

函数可以有多个返回值，当多个函数作为赋值语句的右值时，只有最后一个函数会被展开
> function add() return 1, 0 end <br>
> local b, c, d, e = add(), add() <br>
> b --> 1, c --> 1 , d --> 0, e -->nil


## 运算符

**(需要继续阅读源码 目前理解不到位)**

'#'运算符可以计算字符串和table长度，但对table进行计算时
其计算长度时根据key索引数值进行计算，且计算方法是二分查询
> a = {1, nil, 3,nil, 4} --> 5
> 此时如果 a[6] = nil #a -->

[参考] (https://www.runoob.com/w3cnote/lua-table-length-analysis.html)


## 字符串

字符串的长度检测有两种方式<br>
+ string.len(str)   : 计算ASCII字符长度
+ utf8-len(str)     : 计算UTF-8字符长度

> 对含有数字的字符串需要使用utf8-len，否则会长度计算错误


字符串字符替换函数`string.gsub() `如果规定替换次数，当次数大于实际可替换次数时，只会完成可替换的内容，并返回替换执行的次数

`string.sub()`用于裁剪目标字符串，其需要源字符串，起始位置，目标位置，配合`string.find()`可以获取目标的其实位置和目标位置。

而`string.find()`可以使用多种模式匹配规则来寻找目标。


## 数组

在Lua中，数组是通过`table`结构实现的。新建一个数组后，默认的索引从1开始，访问越界的下标不会报错，但是会返回nil,且数组的索引可以被定义为负数。
arr[-2] = 1 是合法的。

向数组添加数据可以直接添加 如arr[10] = 5

删除数组内容需要使用 `table.remove(arr, index)`

二维数组例子 {{1,2},{2,3}}


## 迭代器

迭代器是实际上是一个对象，但拥有三要素，迭代函数，终点值，控制遍历。通过迭代器可以遍历标准模板库中的元素，其是一种支持指针类型的结构（个人理解主要是在迭代函数，因此其在使用的时候会返回一个函数指针）。

在泛型for迭代器中，表达式会在一开始就被执行，然后生成for函数需要的三个值：迭代函数，状态常量（终点），控制变量（控制迭代的执行过程）

当控制变量带入迭代函数中返回的值为nil时，for循环结束

除了`ipairs`和`pairs`两个外，自定义函数也可以用于泛型for

~~~lua
function square(iteratorMaxCount,currentNumber)
   if currentNumber<iteratorMaxCount
   then
      currentNumber = currentNumber+1
   return currentNumber, currentNumber*currentNumber
   end
end

for i,n in square,3,0
do
   print(i,n)
end
~~~
在上述代码中`square`就是迭代函数， 而`3`是状态常量，`0`是控制变量，其执行步骤为
+ 计算in后的表达式内容，也就是得出for遍历需要的三要素
+ 然后循环调用迭代函数（迭代器），
  + 如果调用迭代器获取的值为nil就退出循环，
  + 如果有值，则更新控制变量，开始新的循环




而迭代器的具体函数可以表示为
~~~lua
function iter (a, i)
    i = i + 1
    local v = a[i]
    if v then
       return i, v
    end
end
 
function ipairs (a)
    return iter, a, 0
end

-- 此部分代码为自己编写，如果lua是用的是栈，则每一个栈帧都会对应一个iter函数的调用（需要阅读源码理解）。
ipairs(a) --> 系统处理

index = 控制变量
while (true)
do
    index = index + 1
    i, v = iter(a, index)
    if (!v)  -- v is nil 
    then 
        break;
end
~~~

> 在上述代码块中，如果调用ipairs函数，则会获得三要素，交由系统去调用，其中iter是一个迭代函数，在实际的操作过程中，会不断调用iter(a, i), 判断取值是否为Nil, 不如不为Nil则继续调用

**（todo 等后续观看源码理解）**

上述内容为无状态的迭代器，在很多时候还需要使用有状态的迭代器来保存状态信息，此时有两种方法
+ 使用闭包函数（简单直接）
+ 将状态信息存放于table中

~~~lua
array = {"Google", "Runoob"}

function elementIterator (collection)
   local index = 0
   local count = #collection
   -- 闭包函数
   return function ()
      index = index + 1
      if index <= count
      then
         --  返回迭代器的当前元素
         return collection[index]
      end
   end
end

for element in elementIterator(array)
do
   print(element)
end
~~~

> 在`elementIterator`代码块中，使用了闭包函数 `return function()`。该部分代码表示，处理`elementIterator`时返回一个函数，该函数能够调用`elementIterator`的局部变量`index`和`count`。且这两个变量在该闭包函数没有消失前，会一直在存在于内存中。

>因此该段代码实际只初始化了一次`index`和`count`，然后由于返回了一个闭包函数的迭代器，栈每调用一次这个函数，就会使得`index+=1`,然后返回对应的参数，直到Index越界返回Nil才退出迭代。


## table
table可以用于解决module，package，以及Object不支持的问题

table是引用变量，其将a赋值给b,此时a和b都会指向同一块内存。但如果此时将b = nil(移除引用)，当访问b的时候会得到nil，访问a不会受到影响。 直到将a也设置为Nil,lua才会进行垃圾回收，清理对应内存。
> table应该是使用了引用计数器。

**table 基础API**
+ `table.concat(tab[, sep[, start[, end]]])`
   + 使用seq将从start到end的table元素相连，且返回一个字符串
   + 如果不定义seq,则默认是直接连接，不能直接跳过seq,填写start和end。
   + 直接填写start和end, Lua会将start作为分隔符，end作为起点
   + 如果start > end 返回空
 + `table.insert(table, [pos], value)`
   + 将value插入到table的pos位置
   + 如果不指定pos，则默认为table末尾
 + `table.maxn(table)`
   + **Lua5.2以后不再使用，需要自定义实现**
   + 获得table中所有正整数key中，对应value最大的值，如果不存在正整数key, 则返回0
 + `table.remove (table [, pos])`
   + 移除table中位置为pos的元素，并返回
   + 如果不指定pos，则移除最后一个元素
 + `table.sort (table [, comp])`
   + 对table进行排序，默认为升序排序
   + 如果需要定义降序排序可以使用以下方式
   + ```table.sort(tab, function(a,b) return a > b end)```
   + table中如果含有nil元素，会报错
   + 比较函数返回true表示元素不需要被交换

> 注意无论是使用#还是table.getn都会在table索引断掉的地方停止计数，即a[1] = 1, a[10] = 20, 则#a输入为1。
>
> 因此如果要去确定的长度，需要自己编写代码


## lua的模块与包


在Lua中是通过table实现，如果想要加载一个特定模块，先需要定义一个table，为table存储常量信息或函数指针，并return该table，即可在其他文件中调用table内部定义的内容。

> 注意如果将常量和函数定义为local则无法在其他函数中调用

```lua
-- export_table.lua
module = {}

module.cont = 1      -- 全局变量可以访问

function module.fun1()
    return "this is func1"
end

local function func2()      -- 私有函数，外部不可访问
    return "this is local func2"
end

function module.func3()
    return func2()
end
return module


--test_export.
-- package.path = package.path..";E:\\Workspace\\Learning Space\\lua space\\Learn-Note\\Week1\\code\\basic_code\\?.lua"
package.path = package.path..";?.lua"
require("exportTable")

x = module.fun1()
print(x)  --> this is func1
print(module.func3())   --> this is func2

```
在上述例子中，
+ require会先从多个lib库中寻找目标模块（lua或dll），如果有则加载，没有则继续寻找
+ 当前当前运行路径的目录下是否有需要的目标文件。

根据上述的描述，如果需要的目标文件不在根目录或lib库中，就需要用户自己指定运行的位置，其中`Package.path`用于指定需要寻找的目标lua文件位置（有时需要定义绝对路径）。

> `..";?.lua"`表示在原有目标路径下加上当前运行目录下的所有Lua文件，require会将模块名去匹配？，来寻找对应的文件。

**读取C语言包**

在lua中可以通过`loadlib`来打开动态链接库。其需要两个参数（路径，初始化函数）。其不会直接打开库，而是将初始化函数作为返回值返回回来。如果加载失败或没找到初始化函数，则返回空。


## Metatable 元表
用于对两个表进行操作，而元表可以看作是一个针对于初始表的“操作指南”，即在元表中定义一系列方法，规定如何对初始表进行操作。

因此当访问表的元素的时候，如果发现表有元表，则会开始根据“操作指南”规定的方式，开始寻找进一步检索元表的内容。**因此通过该方法可以模拟继承的实现**

元表本质还是一个hash表，其可以在key中存放一些字段，这些字段的值可以是一个Table或者一个函数，而这些字段被被叫做“元方法”

元表的基础设置方法
```lua
setmetatable({},{})
```

### __index
`__index`方法规定了在索引失败的时候，如何对元表进行操作。

如果需要使用`__index`，需要在元表中设置该字段对应的值，如果不设定，即使元表中有对应的key，也会索引失败。

```lua
father = {house = 1}
son = {car = 2}
setmetatable(son, father)
-- 由于house不存在与son中，lua会进一步寻找元表内容
-- 虽然father元表存在house,但是由于没有规定__index, Lua无法找到father下的内容，因此返回nil
print(son.house)    --> nil
```

详细可以参考[index和元表如何工作的](https://blog.csdn.net/xocoder/article/details/9028347)

### __newindex
`__newindex`规定了对表设置新索引时候的行为，也就是对设置不存在的索引时候的拦截操作。
+ 当给表一个空缺的键时，如果规定了__newindex原方法，则会向__newindex定义的子表中插入对应的键值，而不会改变初始表的内容
+ 当写入的是一个已有的键，那么会直接改变初始表的内容

通过`__newindex`和`__index`可以用于模拟`const`常量

`__newindex`有两个基础规则
1. 如果`__newindex`的值是一个table，那么对初始table的不存在的key进行赋值时，会修改`__newindex`对应的table
2. 如果`__newindex`的值是一个函数，那么对初始table不存在的key进行赋值时，函数会获取三个参数(orgin table, key, value)，而因为没有table，则不会进行修改
   1.  orgin table: 初始表
   2.  key 被赋值的key
   3.  value 赋值元素

> 基于以上规则可以设计出两种处理const的方法


1. 方法一：可以初次修改const内容

  **思路**：使用`__newindex`控制一个table来，控制修改索引值对应的元素
  + 如果在table中对应的key是一个非空的key（const常量名），则不进行修改；
  + 如果table中对应的索引为空，则进行修改。

  > 每次修改都是在一个固定的表上进行修改

  然后使用`__index`来完成const字段的检索，如果初始表命名为`const`，通过key寻找对应的常量名时会以`const.变量名`的形式从`__index`设定的表（`__newindex`）修改的表中获取数据

  > 实际上是定义了一个外部的表temp，该表将作为元表中`__index`的值，供lua进行检索，以及存放`__newindex`修改表中需要修改的内容

  代码则是

  ```lua
  const = {}  -- 初始表
  temp = {}   -- 被检索的表
  metatable = {   -- 元表
    -- 修改temp子表的内容
    __newindex = function() do temp = .... end, 
    -- 出现不存在的key时，从temp中寻找
    __index = temp}   
  setmetatable(const, metatable)
  ```
  2. 方法二： 获取一个已经设定好初值的const table

  **思路**：
  1. 设定一个函数，该函数将返回设定好const的table的代理table;
  2. 将对const的修改使用函数来承接，当函数触发时，不修改任何内容(即`__newindex`的值是一个函数)
  3. 将初始的const table作为`__index`的检索对象
  4. 将23步组合形成一个元表，并作为代理表的元表
  5. 返回代理表，代理表只允许检索key（从初始table中检索），并拦截任何修改

```lua
local function readOnly(t) -- t是初始规定的常量Table，作为__index的索引表
    local proxy = {}       -- 实际常量表的代理，防止进行修改
    local metatable = {
        __index = t,       -- 实际都是从t表查询数据
        __newindex = function(t, k, v)  -- 使用函数拦截所有修改
            print("attempt update const table")
        end
    }
    setmetatable ( proxy, metatable)
    return proxy
end

local const_meth2 = readOnly { "Enum1", "Enum2" }
print(const_meth2.Enum1)  --> "Enum"
const_meth2.Enum1 = "Enum3" --> "attempt update const table
```

参考资料 
1. [菜鸟教程 笔记](https://www.runoob.com/lua/lua-metatables.html)
2. [const 模拟](https://blog.csdn.net/liu943367080/article/details/100515277)

### 表操作
为元表定义一系列的操作方式，该方式的值需要是一个函数

如果希望对两个表进行相加操作，则需要在元表中定义`__add`元方法，这样对初始表进行操作时，lua会自动去寻找`__add`方法对应的功能。然后在该函数中调用`table.insert`实现表添加内容功能。

更多功能参照 [元表操作](https://www.runoob.com/lua/lua-metatables.html)


### __call方法调用
定义该元方法以后，可以将初始表像函数一样调用，因此其元方法的值也应该是一个函数，该函数有两个参数，分别是初始表，以及调用时候的实参。

```lua
local metatable_call_origin = { 10 }
local new_call_table = { 10, 20, 30 }
local call_mt = {
    -- 定义call调用，当将初始表作为函数调用时，会走到该部分内容中
    -- origin_tab 为初始表
    -- para为调用时候的参数
    __call = function(origin_tab, para)
        local sum = 0
        for k, v in ipairs(origin_tab)
        do
            sum = sum +  v
        end

        for k, v in ipairs(para)
        do
            sum = sum + v
        end
        return sum
    end
}
setmetatable(metatable_call_origin, call_mt)
print(metatable_call_origin(new_call_table))

```

### __tostring
自定义表的内容输入结果，如果定义了该元表，直接print(table)不会返回其地址，而是返回希望返回的内容，因此该元方法的值也需要是**函数**


## Class

### 类和对象
在lua中可以使用table来描述一个类以及实例化对象，对象的属性使用table进行描述，而对象的内部方法可以通过在table中定义函数来实现。

> 对table定义函数实际也会为其增加一个项，其key为函数名，value为对应的虚拟地址

> Rectangle类 <br>
> breath  0 <br>
> new     function: 00000000006ccd80<br>
> length  0 <br>
> area    0

定义一个类的基础属性后，再定义对应的new方法，new方法中需要对对象的基础属性进行赋值，并设置`__index`保证对象table能够访问类table定义的方法。

> 访问成员变量`.`和访问成员函数`:`的最大区别在于，使用`:`调用成员函数时，会默认携带调用table本身的标识符`self`。

> 使用self.__index = self的原因是，当实例化对象的时候，会将类的作为self传入到new方法中。由于将Rectangle类作为了其所有实例化对象的元表，且该元表有`__index`元方法，因此对应的实例化对象都可以访问元表的方法（类的成员方法）。
> 同时在调用对象的方法时，由于也是使用的`:`符号，因此传入的对象本身的self，从而实现了基于对象的数据进行访问数据。

 例子
```lua
-- 定义类
Rectangle = {area = 0, length = 0, breath = 0}


function Rectangle:new (origin, length, breadth)
    origin = origin or {}

    -- 将Rectangle类本身作为origin的元表，这样origin表才能访问Rectangle定义的方法
    setmetatable(origin, self)
    self.__index = self
    origin.length = length or 0
    origin.breadth = breadth or 0
    origin.area = origin.length * origin.breadth;
    return origin
end

function Rectangle:showArea()
    return self.area
end

r = Rectangle:new(nil,60,20)
r2 = Rectangle:new(nil,40,50)

print(r.length)
print(r2.breadth)

--[[ 此时调用showArea时，由于r表中没有对应方法
    lua会在去Rectangle表中检索showArea方法
    调用的时候由于是使用的`:`，就会将r对象的self传入showArea方法
]]--
print(r:showArea())
print(r2:showArea())
```

### 继承

继承的原理是定义一个子类的table，然后将该子类的table**作为所有子类对象的元表**，从而能够访问成员函数。

定义子类table的方式是直接实例化一个父类对象作为子类。这样子类也能访问到父类的方法和其对应的属性


**实现方法：** 按照实例化父类的方式定义一个子类。该子类也需要定义其实例化方法。由于子类也需要有独立的成员方法，因此需要模仿父类的实例化方式，将子类作为子类对象的元表以访问成员函数

```lua
ChildClass = Rectangle:new()        -- 子类

function ChildClass:new(obj, para1, para2)
    obj = obj or Rectangle:new(nil, para1, para2)
    -- 将ChildClass类作为其对象Obj的元表，能够访问成员函数
    setmetatable(obj, self)
    self.__index = self
    return obj
end

child1 = ChildClass:new(nil, 20, 40)
print(child1:showArea())
```
