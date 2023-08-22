# XLua调用CSharp

由于Lua代码是基于C编写的，因此通过lua本身就携带了与C/C++的通信机制，即lua的虚拟机栈。lua可以通过Push/Pull等接口来从虚拟机中获取数据，而Xlua则是对这些接口进行了封装，让我们可以将CS的对象Push到lua虚拟机上，从而实现了相互通信。


## LuaEnv实例化

如果要在CS代码中执行lua代码，则需要先实例化LuaEnv环境，这个环境加载了所有要读取和访问Lua代码的方法。其中最主要的两个为实例化`ObjectTranslator`转化类，以及lua访问CS内容初始化代码`init_xlua`

在LuaEnv.cs中，LuaEnv的实例化步骤如下

1. 实例化主线程使用的luaState(L->state)
```C#
rawL = LuaAPI.luaL_newstate();
```
2. 注册xlua的c方法库（通过C实现CS和xlua的通信）、uint64库（5.2之前的Lua不支持原生int64）
```CS
LuaAPI.luaopen_xlua(rawL);// 注册xlua的c方法库
LuaAPI.luaopen_i64lib(rawL);// 注册uint64库
```

3. 实例化Lua和CS的类型转化工具`ObjectTranslator`，并创建函数、数组、委托的元表，枚举迭代的函数

```C#
translator = new ObjectTranslator(this, rawL);// 用于lua与c#之间传值
translator.createFunctionMetatable(rawL);// 创建LuaCSFunction的元表

translator.OpenLib(rawL);// 注册xlua的cs方法库
ObjectTranslatorPool.Instance.Add(rawL, translator);
```

4. 设置异常处理函数以及print函数

```C#
LuaAPI.lua_atpanic(rawL, StaticLuaCallbacks.Panic);// 设置lua异常处理函数
LuaAPI.lua_pushstdcallcfunction(rawL, StaticLuaCallbacks.Print);// 设置print函数
if (0 != LuaAPI.xlua_setglobal(rawL, "print"))
{
    throw new Exception("call xlua_setglobal fail!");
}
```

5. 添加require时查找lua文件的查找器(就是lua原生的查找路径package-path等, 以及xlua额外的resource包)

```C#
 TemplateEngine.LuaTemplate.OpenLib(rawL);// 注册template库
// 添加require时用到的查找器
AddSearcher(StaticLuaCallbacks.LoadBuiltinLib, 2); // just after the preload searcher
AddSearcher(StaticLuaCallbacks.LoadFromCustomLoaders, 3);
#if !XLUA_GENERAL
AddSearcher(StaticLuaCallbacks.LoadFromResource, 4);
AddSearcher(StaticLuaCallbacks.LoadFromStreamingAssetsPath, -1);
```

6. 调用初始化代码`init_xlua`，初始化CS全局表的内容，绑定Lua和CS的转化处理方法
```C#
DoString(init_xlua, "Init");
init_xlua = null;
```

7. 构建基于CS表的元表，`LuaIndexs`、`LuaNewIndexs`、`LuaClassIndexs`、`LuaClassNewIndexs`，用于建立lua和C#的各种类型的映射关系。

```C#
// 构造
AddBuildin("CS", StaticLuaCallbacks.LoadCS);

/* local mt = {__index = StaticLuaCallbacks.MetaFuncIndex}
为rawL生成新的表，并将该表作为cs表的metaTable */
LuaAPI.lua_newtable(rawL); //metatable of indexs and newindexs functions    // 生成metatable
LuaAPI.xlua_pushasciistring(rawL, "__index");       // 设置__index
LuaAPI.lua_pushstdcallcfunction(rawL, StaticLuaCallbacks.MetaFuncIndex);
LuaAPI.lua_rawset(rawL, -3);
```

```CS
/* register[Utils.LuaIndexsFieldName] = setmetatable({}, mt)
为注册表设置LuaIndexs的 metatable */
LuaAPI.xlua_pushasciistring(rawL, Utils.LuaIndexsFieldName);
LuaAPI.lua_newtable(rawL);
LuaAPI.lua_pushvalue(rawL, -3);
LuaAPI.lua_setmetatable(rawL, -2);
LuaAPI.lua_rawset(rawL, LuaIndexes.LUA_REGISTRYINDEX);
```
> 后续多个表的处理过程和该段代码相同

8. 调用所有初始化器，记录C#的type与创建对应table的函数的映射关系，后续首次访问某个类型时，就会调用函数构造出table给lua层使用。这些函数均由xlua的general code生成的。

```CS
// 调用所有初始化器,绑定类型与构造table的方法
if (initers != null)
{
    for (int i = 0; i < initers.Count; i++)
    {
        initers[i](this, translator);
    }
}

// 用于lua调用C#特有功能的方法映射表。
translator.CreateArrayMetatable(rawL);
translator.CreateDelegateMetatable(rawL);
translator.CreateEnumerablePairs(rawL);
```

##   


## Xlua是如何调用CS代码

Xlua可以通过以下方式调用CS代码, 如

```lua
CS.UnityEngine.Debug.Log('hello world')
```

其中CS为Xlua封装的一个全局Table，相应的CS.UnityEngine则为去查询CS表中名为UnityEngine的值。其通过`_index`来实现。

而初始话CS表将在创建LuaEnv时调用。该函数放在XLua项目中的`xLua/Assets/XLua/Src/LuaEnv.cs`中，源码将整个初始化的Lua代码作为字符串进行储存，并在后续通过DoString()进行调用。

```lua
-- init_lua
function metatable:__index(key)
    -- fqn实际就是UnityEngine字符串
    local fqn = rawget(self,'.fqn')
    fqn = ((fqn and fqn .. '.') or '') .. key

    local obj = import_type(fqn)

    if obj == nil then
        -- It might be an assembly, so we load it too.
        obj = { ['.fqn'] = fqn }
        setmetatable(obj, metatable)
    elseif obj == true then
        return rawget(self, key)
    end

    -- Cache this lookup
    rawset(self, key, obj)
    return obj
end

```