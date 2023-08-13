# Xlua代码调用CS代码

Xlua调用CS也需要保证对应的CS代码加载了xlua的虚拟环境，保证lua代码能够被Unity能够被正常调用。

## 新建GameObject对象

在Lua中由于没有new方法，因此可以直接通过调用接口的方式去实例化一个GO对象。同时通过不同的构造参数，可以实例化不同的GO对象

```lua
-- 在Lua中不需要new， 可以直接调用 CS.UnityEngine.GameObject 构造GO, 且支持重载
local newGameObj = CS.UnityEngine.GameObject()      -- 无参构造
local newGameObjReload = CS.UnityEngine.GameObject("helloWorld")    -- 重载
print(newGameObj, newGameObjReload)
-- ====> LUA: New Game Object (UnityEngine.GameObject): -10026	helloWorld (UnityEngine.GameObject): -10030
```

## 访问cs代码中 类的静态属性和方法

在cs的api中，实际创建GO的api是个静态类的静态方法，为了减少查找的性能消耗，可以直接将静态类存放在Lua的变量中，然后在后续进行调用。
```lua
-- 可以先将调用静态方法的静态类保存在某个引用中然后调用
local GoStaticCls = CS.UnityEngine.GameObject
local newGoByStaticCls = GoStaticCls()
print(newGoByStaticCls)
-- ==> LUA: New Game Object (UnityEngine.GameObject): -12574
--  调用静态方法
print("Time.DeltaTime is ", CS.UnityEngine.Time.deltaTime)       -- 读静态方法
-- ==> LUA: Time.DeltaTime is 	0.019999999552965
CS.UnityEngine.Time.timeScale = 0.5         -- 写静态属性
print('helloworldGOFind', GoStaticCls.Find('helloworld')) --静态方法调用
-- ==> LUA: helloworldGOFind nil
```

## 访问CS代码中的类以及其实例化后的成员属性和方法

对于自定义的CS类需要先将这些类通过[LuaCallCSharp]进行标记，这样就可以通过Untiy菜单栏的`Xlua -> Generate Code`来生成自定生成对应的访问代码。

其中生成代码后，其在Lua侧被调用的路径可以通过项目路径`Assets\Xlua\Gen\link`找到。如果是类内部的方法或内容使用了[LuaCallCSharp]，访问路径的加号实际还是需要用'.'代替

```C#
// 基础类
[LuaCallCSharp]
public class BaseClass
{
    public int BaseNorBaseMemPro { get; set; }
    
    public static int BaseClsProp = -1; 
    
    public static void BaseClsStaticFunc()
    {
        Debug.Log("Derived Base Static Func = " + BaseClsProp);
    }

    public void BaseClsMemFunc()
    {
        Debug.Log("Derived Base Member Func = " + BaseNorBaseMemPro);
    }
}

// 子类
[LuaCallCSharp]
public class DerivedClass: BaseClass
{
    public int DerivedMemVar { get; set; }
    
    [LuaCallCSharp]
    public enum DerivedInnerEnum
    {
        E3, E4
    }

    public void DerivedMemFunc()
    {
        Debug.Log("Derived Member Func = " + DerivedMemVar);
    }
    ...
}
```

```lua
local DerivedCls = CS.Script.LuaCallCS.DerivedClass
local derivedObj = DerivedCls()
print(derivedObj.DerivedMemVar) -- 访问成员变量       ==> LUA: 0
derivedObj.DerivedMemVar = 1024
print(derivedObj.DerivedMemVar) -- 访问修改后的成员变量   ==> LUA: 1024
print(derivedObj.BaseNorBaseMemPro)     -- 访问基类成员变量      ==> LUA: 0
derivedObj.BaseNorBaseMemPro = 2048
derivedObj:BaseClsMemFunc()     -- 基类成员方法  ==> Derived Base Member Func = 2048
derivedObj:DerivedMemFunc()     -- 访问成员方法  ==>
```
```lua
-- 访问基类的属性和方法
print(DerivedCls.BaseClsProp)   -- 通过子类访问基类的静态属性    ==> LUA: -1
DerivedCls.BaseClsProp = 1      -- 修改基类的静态属性            
DerivedCls:BaseClsStaticFunc()  -- 通过子类访问基类的静态方法    ==> Derived Base Static Func = 1
derivedObj:BaseClsMemFunc()     -- 访问基类的成员函数        ==> Derived Base Member Func = 2048
```


## 调用子类继承的基类复杂方法

在Lua代码中，如果调用的CS代码较为复杂，需要满足一下规则:
+ Lua代码的返回值，基础的Lua返回值算一个，如果有Out算一个返回值，ref算一个返回值
+ 而对于lua侧的参数，普通参数和ref需要有参数，out不需要有参数

因此对于方法
```C#
public class DerivedClass: BaseClass
{
    ...
    public double ComplexFunc(Param1 p1, ref int p2, out string s3, Action luaFunc, out Action csfunc)
    {
        Debug.Log("P1 = { x = " + p1.x + "; y = " + p1.y + "} , p2 = " + p2);
        luaFunc();
        p2 *= p1.x;
        s3 = "hello world" + p2;

        csfunc = () =>
        {
            Debug.Log("cs code callback invoked!");
        };

        return 292.123d;
    }
    ...
}
```
在lua中需要有以下内容
+ 返回值: `double ret`, `int p2`, `out s3`, `out Action csfunc` 四个返回值
+ 实参参： `Param1 p1`, `ref int p2`， `Action luaFunc`

因此Lua侧的调用函数需要如下定义
```lua
local ret, p2, s3, csfunc = derivedObj:ComplexFunc({x = 10, y = 20}, 3, function()
    print('i am lua callback')      -- 被CS中的luaFun调用
end)
print("complex ret", ret, p2, s3, csfunc) -- ==> LUA: complex ret	292.123	30	hello world30	System.Action: 1326677822
csfunc()
```

## 方法重载
由于lua在数值上只支持double，其传入的数据默认为double， 因此重载时需要避免 数值型的重载

```C#
// 测试重载方法
// 
public class DerivedClass: BaseClass
{
    ...
    public void TestOverloadFunc(int i)
    {
        Debug.Log($"TestFunc(int i) {i}");
    }
    ...    
}
```

```lua
derivedObj:TestOverloadFunc(122)           -- ==> TestFunc(int i) 122
derivedObj:TestOverloadFunc("helloWord")    -- ==> TestFunc(string i) helloWord
```

## 重载操作符

支持的操作符有：+，-，*，/，==，一元-，<，<=， %，[]

```C#
public class DerivedClass: BaseClass
{
    ...
    public static DerivedClass operator +(DerivedClass a, DerivedClass b)
    {
        DerivedClass ret = new DerivedClass();
        ret.DerivedMemVar = a.DerivedMemVar + b.DerivedMemVar;
        return ret;
    }
    ...    
}
```

```lua
local TestOverloadOpFunc = DerivedCls()
TestOverloadOpFunc.DerivedMemVar = 1024 * 5
local ret = TestOverloadOpFunc + derivedObj;
print("after overload op , result = ", ret.DerivedMemVar)   -- ==> LUA: after overload op , result = 	6144
```

## 参数带默认值

如果CS代码中函数的参数带默认值，那么Lua侧如果没有使用这些参数，CS的参数将会使用这些默认值

```C#
public class DerivedClass: BaseClass
{
    ...
    public void DefaultValueFunc(int a = 100, string b = "abc", string c = null)
    {
        Debug.Log($"now DefaultVal is {a}, {b}, {c}");
    }
    ...    
}
```

```lua
derivedObj:DefaultValueFunc(15)     -- ==> now DefaultVal is 15, abc, 
derivedObj:DefaultValueFunc(80, "aabcd", "ccads")   -- ==> now DefaultVal is 80, aabcd, ccads
```

## 参数为可变参数

CS代码可以使用可变参数作为形参，但是lua侧的实参需要明确数量

但是需要注意CS侧的可变形参需要使用 `params`进行表示

```C#
public class DerivedClass: BaseClass
{
    ...
    public void VariableParamsFunc(int a, params string[] args)
    {
        string ret = "VariableParamsFunc: a =" + a;
        foreach (var arg in args)
        {
            ret += arg + ", ";
        }
        Debug.Log(ret);
    }
    ...    
}
```

```lua
derivedObj:VariableParamsFunc(123, "aabc", "ddca")      -- ==> VariableParamsFunc: a =123aabc, ddca, 
```

## 调用类的拓展方法

有时当无法直接对类本身的内容进行拓展时，可以在类的外部编写拓展方法。在CS侧需要在参数处使用(this Cls)进行标识，然后在方法内部增加对类的操作

```C#
// 对类的拓展方法
[LuaCallCSharp]
public static class DerivedClsExtensions
{
    public static int GetObjData(this DerivedClass obj)
    {
        Debug.Log("GetObjData ret" + obj.DerivedMemVar);
        return obj.DerivedMemVar;
    }

    public static int GetObjBaseData(this DerivedClass obj)
    {
        Debug.Log("GetObjBaseData ret" + obj.BaseNorBaseMemPro);
        return obj.BaseNorBaseMemPro;
    }
    
    public static void GenericMethodOfString(this DerivedClass obj)
    {
        obj.GenericMethod<string>();
    }
}

public class DerivedClass: BaseClass
{
    ...
    public void GenericMethod<T>()
    {
        Debug.Log("GenericMethod<" + typeof(T) + ">");
    }
    ...    
}
```
```lua
-- 调用类的拓展静态方法 （由于拓展方法的参数是 this 类名， 因此可以直接当方法调用）
print(derivedObj:GetObjData())      -- ==> GetObjData ret1024  LUA: 1024
print(derivedObj:GetObjBaseData())  -- ==> GetObjBaseData ret2048 LUA: 2048
derivedObj:GenericMethodOfString()      -- 通过Extension方法访问泛化方法 ==> GenericMethod<System.String>
```

## 枚举类型的调用

无论是类外还是类内部的Enum都需要使用LuaCallCS标记， 因此当生成代码后可以直接像调用静态类的静态属性一样直接调用

此时因为生成了代码，还可以使用enumType__CastFrom, 可以将字符串或int值转换为对应的enum类型。

需要注意__CastFrom接受了非Enum的数据会报错

```C#
[LuaCallCSharp()]
public enum TestEnum
{
    E1, E2
}

public class DerivedClass: BaseClass
{
    ...
    [LuaCallCSharp]
    public enum DerivedInnerEnum
    {
        E3, E4
    }

    public TestEnum EnumTestFunc(TestEnum e)
    {
        Debug.Log($"EnumTestFunc: e = {e}");
        return TestEnum.E2;
    }
    ...    
}
```

```lua
local testEnum = CS.Script.LuaCallCS.TestEnum
local ret_e = derivedObj:EnumTestFunc(testEnum.E1)  -- ==> EnumTestFunc: e = E1
print(ret_e , ret_e == testEnum.E2)     -- ==> LUA: E2: 1	true
print(testEnum.__CastFrom(1), testEnum.__CastFrom('E1'))    -- ==> LUA: E2: 1	E1: 0
-- print(testEnum.__CastFrom(3), testEnum.__CastFrom('e2'))    -- ==> error
local testInnerEnum = CS.Script.LuaCallCS.DerivedClass.DerivedInnerEnum
print(testInnerEnum.__CastFrom(0)) -- ==> LUA: E3: 0
```

## delegate的使用

在Lua中delegate的使用和CS一样，如果有默认注册的方法，可以直接调用，也可以通过"+"和"-"来添加和移除事件回调

```c#
// 在Lua代码中可以当属性一样调用，并通过操作符 + - 来添加对应的方法，来增加函数调用
// 该delegate默认有一个匿名函数调用
public Action<string> TestDelegate = (param) =>
{
    Debug.Log("TestDelegate in C#" + param);
};
```

```lua
-- 在cs代码的delegate中默认有一个返回 TestDelegate in C# str 的匿名函数，因此直接调用能够出发该匿名函数
derivedObj.TestDelegate('hello')        -- 直接调用 ==> TestDelegate in C#hello
--   生成一个新的用于注册进入事件的方法
local function lua_delegate(str)
    print('this is lua_delegate', str)
end

--   将lua定义的delegate func注册进入cs代码中的delegate中
derivedObj.TestDelegate = lua_delegate + derivedObj.TestDelegate  -- 将C#delegate作为右值，于lua函数联合
derivedObj.TestDelegate('hello')    -- 与默认匿名函数联合因此被激活两次 LUA: this is lua_delegate	hello  TestDelegate in C#hello
derivedObj.TestDelegate = derivedObj.TestDelegate - lua_delegate    -- 移除注册委托
derivedObj.TestDelegate('hello')    -- TestDelegate in C#hello
    
```

## 事件调用

```C#
// 注册事件
public event Action TestEvent;

public void CallTestEvent()
{
    TestEvent?.Invoke();
}
```

```lua
-- 和普通的事件调用一样，通过+-号将回调函数进行注册
local function lua_event_callback1()        -- 定义回调函数
    print("this is lua_event_callback1")        
end

local function lua_event_callback2()
    print("this is lua_event_callback2")
end

-- 将回调注册进CS的Action中
-- 注意不能加方法后不能加"()" 否则就是调用而不是函数地址
derivedObj:TestEvent('+', lua_event_callback1)
derivedObj:CallTestEvent()      -- invoke callback1
derivedObj:TestEvent('+', lua_event_callback2)
derivedObj:CallTestEvent()      -- invoke callback1和callback2
derivedObj:TestEvent('-', lua_event_callback1)
derivedObj:CallTestEvent()      -- invoke callback2
derivedObj:TestEvent('-', lua_event_callback2)
derivedObj:CallTestEvent()      -- 所有事件都被移除，调用将不会有任何结果
```
## 强制转化 cast

在lua中实际是没有类型概念，该方法主要是为了解决，当我们只能获取某个抽象方法或接口时，我们无法直接获取其实现方法，那么lua在检测到接口时，会通过反射去访问实现类，十分影响性能

此时就可以将对应的接口通过强转的方式添加到生成代码，并用该部分代码访问。因此需要将接口也添加[LuaCallCS]，保证接口的实现类能够自动生成到Gen文件夹中

```C#
[LuaCallCSharp]
public interface ICalc
{
    int add(int a, int b);
}


public class DerivedClass: BaseClass
{
    ...
    // 实现接口
    class InnerCalc : ICalc
    {
        public int id = 100;
        public int add(int a, int b)
        {
            return a + b;
        }
    }

    public ICalc GetCalc()
    {
        return new InnerCalc();
    }
    ...    
}
```

```lua
local calc = derivedObj:GetCalc()
print('assess instance of InnerCalc via reflection', calc:add(1, 2))
assert(calc.id == 100)      -- ==> true
cast(calc, typeof(CS.Script.LuaCallCS.ICalc))     -- 将接口进行强转，获得对应的生成代码，此时 calc 将从Gen文件中获得生成的代码
print(calc)
print('cast to interface ICalc', calc:add(1, 2))
assert(calc.id == nil)      -- ==> true

```


## 使用协程

```lua
-- 使用协程执行demo
local co = coroutine.create(function()
    print("------------")
    demo()
end)
assert(coroutine.resume(co))
```