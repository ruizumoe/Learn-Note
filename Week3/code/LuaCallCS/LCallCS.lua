function demo()
    -- 新建GO对象
    -- 在Lua中不需要new， 可以直接调用 CS.UnityEngine.GameObject 构造GO, 且支持重载
    local newGameObj = CS.UnityEngine.GameObject()      -- 无参构造
    local newGameObjReload = CS.UnityEngine.GameObject("helloWorld")    -- 重载
    print(newGameObj, newGameObjReload)
    -- ====> LUA: New Game Object (UnityEngine.GameObject): -10026	helloWorld (UnityEngine.GameObject): -10030

    -- 访问cs中的静态属性和方法，
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

    -- 访问CS代码中的类和其成员属性、方法
    -- 访问前需要将要访问的类 标记[LuaCallCSharp]， 同时需要手动生成代码
    -- 生成代码后，类的调用路径可以通过 文件路径 XLua -> Gen -> link 找到
    -- 如果是类内部的方法或内容使用了[LuaCallCSharp]，访问路径的加号实际还是需要用'.'代替
    -- 注意访问成员方法依旧需要使用 :
    local DerivedCls = CS.Script.LuaCallCS.DerivedClass
    local derivedObj = DerivedCls()
    print(derivedObj.DerivedMemVar) -- 访问成员变量       ==> LUA: 0
    derivedObj.DerivedMemVar = 1024
    print(derivedObj.DerivedMemVar) -- 访问修改后的成员变量   ==> LUA: 1024
    print(derivedObj.BaseNorBaseMemPro)     -- 访问基类成员变量      ==> LUA: 0
    derivedObj.BaseNorBaseMemPro = 2048
    derivedObj:BaseClsMemFunc()     -- 基类成员方法  ==> Derived Base Member Func = 2048
    derivedObj:DerivedMemFunc()     -- 访问成员方法  ==>

    -- 访问基类的属性和方法
    print(DerivedCls.BaseClsProp)   -- 通过子类访问基类的静态属性    ==> LUA: -1
    DerivedCls.BaseClsProp = 1      -- 修改基类的静态属性            
    DerivedCls:BaseClsStaticFunc()  -- 通过子类访问基类的静态方法    ==> Derived Base Static Func = 1
    derivedObj:BaseClsMemFunc()     -- 访问基类的成员函数        ==> Derived Base Member Func = 2048

    -- 调用子类继承的基类复杂方法
    -- 在Lua代码中，如果调用的CS代码较为复杂，需要满足一下规则
    -- Lua代码的返回值，基础的Lua返回值算一个，如果有Out算一个返回值，ref算一个返回值
    -- 因此 `double ComplexFunc(Param1 p1, ref int p2, out string s3, Action luaFunc, out Action csfunc)`
    -- 上述方法需要有 double, int p2, out s3, out Action csfunc 四个返回值
    -- 而对于lua侧的参数，普通参数和ref需要有参数，out不需要有参数
    -- 因此上述方法中需要有 Param1 p1, ref int p2， Action luaFunc三个实参

    local ret, p2, s3, csfunc = derivedObj:ComplexFunc({x = 10, y = 20}, 3, function()
        print('i am lua callback')      -- 被CS中的luaFun调用
    end)
    print("complex ret", ret, p2, s3, csfunc) -- ==> LUA: complex ret	292.123	30	hello world30	System.Action: 1326677822
    csfunc()

    -- 重载方法
    -- 由于lua只支持double，其传入的数据默认为double， 因此重载时需要避免 数值型的重载
    derivedObj:TestOverloadFunc(122)           -- ==> TestFunc(int i) 122
    derivedObj:TestOverloadFunc("helloWord")    -- ==> TestFunc(string i) helloWord

    -- 重载操作符
    local TestOverloadOpFunc = DerivedCls()
    TestOverloadOpFunc.DerivedMemVar = 1024 * 5
    local ret = TestOverloadOpFunc + derivedObj;
    print("after overload op , result = ", ret.DerivedMemVar)   -- ==> LUA: after overload op , result = 	6144

    -- 参数带默认值
    derivedObj:DefaultValueFunc(15)     -- ==> now DefaultVal is 15, abc, 
    derivedObj:DefaultValueFunc(80, "aabcd", "ccads")   -- ==> now DefaultVal is 80, aabcd, ccads

    -- 调用可变参数的方法
    -- 注意可变参数需要在参数前加 params标识
    derivedObj:VariableParamsFunc(123, "aabc", "ddca")      -- ==> VariableParamsFunc: a =123aabc, ddca, 

    -- 调用类的拓展静态方法 （由于拓展方法的参数是 this 类名， 因此可以直接当方法调用）
    print(derivedObj:GetObjData())      -- ==> GetObjData ret1024  LUA: 1024
    print(derivedObj:GetObjBaseData())  -- ==> GetObjBaseData ret2048 LUA: 2048
    derivedObj:GenericMethodOfString()      -- 通过Extension方法访问泛化方法 ==> GenericMethod<System.String>

    -- 枚举类型
    -- 无论是类外还是类内部的Enum都需要使用LuaCallCS标记
    -- 因此当生成代码后可以直接像调用静态类的静态属性一样直接调用
    -- 此时因为生成了代码，还可以使用enumType__CastFrom, 可以将字符串或int值转换为对应的enum类型
    -- 需要注意__CastFrom接受了非Enum的数据会报错
    local testEnum = CS.Script.LuaCallCS.TestEnum
    local ret_e = derivedObj:EnumTestFunc(testEnum.E1)  -- ==> EnumTestFunc: e = E1
    print(ret_e , ret_e == testEnum.E2)     -- ==> LUA: E2: 1	true
    print(testEnum.__CastFrom(1), testEnum.__CastFrom('E1'))    -- ==> LUA: E2: 1	E1: 0
    -- print(testEnum.__CastFrom(3), testEnum.__CastFrom('e2'))    -- ==> error
    local testInnerEnum = CS.Script.LuaCallCS.DerivedClass.DerivedInnerEnum
    print(testInnerEnum.__CastFrom(0))
    
    
    -- delegate使用
    -- 在Lua中delegate的使用和CS一样，如果有默认注册的方法，可以直接调用，也可以通过"+"和"-"来添加和移除事件回调
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
    
    
    
    -- 事件的使用
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
    
    
    -- 64位支持
    -- lua5.3支持了64位(long, ulong)映射到原生64位整数，但是luajit支持的Lua5.1并不支持
    -- 因此需要使用拓展库将64位数据进行支持
    local l = derivedObj:TestLong(50)
    print(type(l), l + 1, l+100) -- ==> LUA: number	52	151
    
    
    -- 位C#的类添加特定类型
    newGameObj:AddComponent(typeof(CS.UnityEngine.ParticleSystem))
    
    -- 强制转化
    -- 在lua中实际是没有类型概念，该方法主要是为了解决，当我们只能获取某个抽象方法或接口时
    -- 我们无法直接获取其实现方法，那么lua在检测到接口时，会通过反射去访问实现类，十分影响性能
    -- 此时就可以将对应的接口通过强转的方式添加到生成代码，并用该部分代码访问
    -- 因此需要将接口也添加[LuaCallCS]，保证接口的实现类能够自动生成到Gen文件夹中
    local calc = derivedObj:GetCalc()
    print('assess instance of InnerCalc via reflection', calc:add(1, 2))
    assert(calc.id == 100)
    cast(calc, typeof(CS.Script.LuaCallCS.ICalc))     -- 将接口进行强转，获得对应的生成代码，此时 calc 将从Gen文件中获得生成的代码
    print(calc)
    print('cast to interface ICalc', calc:add(1, 2))
    assert(calc.id == nil)
    
end

-- 执行代码
demo()


-- 使用协程执行demo
local co = coroutine.create(function()
    print("------------")
    demo()
end)
assert(coroutine.resume(co))