# XLua调用CSharp

由于Lua代码是基于C编写的，因此通过lua本身就携带了与C/C++的通信机制，即lua的虚拟机栈。lua可以通过Push/Pull等接口来从虚拟机中获取数据，而Xlua则是对这些接口进行了封装，让我们可以将CS的对象Push到lua虚拟机上，从而实现了相互通信。


## LuaEnv实例化

如果要在CS代码中执行lua代码，则需要先实例化LuaEnv环境，这个环境加载了所有要读取和访问Lua代码的方法。其中最主要的两个为实例化`ObjectTranslator`转化类，以及lua访问CS内容初始化代码`init_xlua`

在LuaEnv.cs中，LuaEnv的实例化步骤如下

1. 实例化主线程使用的luaState(L->state)
```C#
// LuaEnv.cs
rawL = LuaAPI.luaL_newstate();
```
2. 注册xlua的c方法库（通过C实现CS和xlua的通信）、uint64库（5.2之前的Lua不支持原生int64）
```CS
// LuaEnv.cs
LuaAPI.luaopen_xlua(rawL);// 注册xlua的c方法库
LuaAPI.luaopen_i64lib(rawL);// 注册uint64库
```

3. 实例化Lua和CS的类型转化工具`ObjectTranslator`，并创建函数、数组、委托的元表，枚举迭代的函数

```C#
// LuaEnv.cs
translator = new ObjectTranslator(this, rawL);// 用于lua与c#之间传值
translator.createFunctionMetatable(rawL);// 创建LuaCSFunction的元表

translator.OpenLib(rawL);// 注册xlua的cs方法库
ObjectTranslatorPool.Instance.Add(rawL, translator);
```

4. 设置异常处理函数以及print函数

```C#
// LuaEnv.cs
LuaAPI.lua_atpanic(rawL, StaticLuaCallbacks.Panic);// 设置lua异常处理函数
LuaAPI.lua_pushstdcallcfunction(rawL, StaticLuaCallbacks.Print);// 设置print函数
if (0 != LuaAPI.xlua_setglobal(rawL, "print"))
{
    throw new Exception("call xlua_setglobal fail!");
}
```

5. 添加require时查找lua文件的查找器(就是lua原生的查找路径package-path等, 以及xlua额外的resource包)

```C#
// LuaEnv.cs
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
// LuaEnv.cs
DoString(init_xlua, "Init");
init_xlua = null;
```

7. 构建基于CS表的元表，`LuaIndexs`、`LuaNewIndexs`、`LuaClassIndexs`、`LuaClassNewIndexs`，用于建立lua和C#的各种类型的映射关系。

```C#
// LuaEnv.cs
// 构造
AddBuildin("CS", StaticLuaCallbacks.LoadCS);

/* local mt = {__index = StaticLuaCallbacks.MetaFuncIndex}
为rawL生成新的表，并将该表作为cs表的metaTable */
LuaAPI.lua_newtable(rawL); //metatable of indexs and newindexs functions    // 生成一个新表newtable1
LuaAPI.xlua_pushasciistring(rawL, "__index");       // 设置__index
LuaAPI.lua_pushstdcallcfunction(rawL, StaticLuaCallbacks.MetaFuncIndex);
LuaAPI.lua_rawset(rawL, -3); // newtable1["__index"] = MetaFuncIndex
```

```CS
// LuaEnv.cs
/* register[Utils.LuaIndexsFieldName] = setmetatable({}, mt)
为注册表设置LuaIndexs的 metatable */
LuaAPI.xlua_pushasciistring(rawL, Utils.LuaIndexsFieldName);
LuaAPI.lua_newtable(rawL);  // 创建一个空表 newtable2
LuaAPI.lua_pushvalue(rawL, -3);     // 将newtable2压入栈
LuaAPI.lua_setmetatable(rawL, -2);  // 将newtable2设置为newtable1的元表
LuaAPI.lua_rawset(rawL, LuaIndexes.LUA_REGISTRYINDEX); // 注册表["LuaIndexs"] = newtable2
```
> 后续多个表的处理过程和该段代码相同

8. 调用所有初始化器，记录C#的type与创建对应table的函数的映射关系，后续首次访问某个类型时，就会调用函数构造出table给lua层使用。这些函数均由xlua的general code生成的。

```CS
// LuaEnv.cs
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

## Lua数据和CS数据的转化类`ObjectTranslator`的初始化
ObjectTranslator主要作用是作为lua和CS的桥梁，将Lua虚拟机栈中的值转化为CS类型，以及将CS类型值压入lua的虚拟机栈中。

1. 记录需要使用的CS程序集，用于后续通过名称对应的程序DLL中寻找类型
```C#
// ObjectTranslator.cs
assemblies = new List<Assembly>();
...
addAssemblieByName(assemblies_usorted, "mscorlib,");
addAssemblieByName(assemblies_usorted, "System,");
addAssemblieByName(assemblies_usorted, "System.Core,");
foreach (Assembly assembly in assemblies_usorted)
{
    if (!assemblies.Contains(assembly))
    {
        assemblies.Add(assembly);
    }
}
...
```

2. 绑定lua虚拟机，实例化Lua和CS类型相互转化的对象，其中包含了一类转化函数的集合
```C#
// ObjectTranslator.cs
this.luaEnv = luaenv;
// 将lua数据栈上的值转换为c#类型的函数集合
objectCasters = new ObjectCasters(this);
// 检查lua数据栈上的值是否是c#类型的函数集合
objectCheckers = new ObjectCheckers(this);
// 用于生成和缓存methodWraps
methodWrapsCache = new MethodWrapsCache(this, objectCheckers, objectCasters);
// 某些类型通用元表用的方法，例如gc、tostring等。
metaFunctions = new StaticLuaCallbacks();
// c#的类型转换为table的方法
importTypeFunction = new LuaCSFunction(StaticLuaCallbacks.ImportType);
loadAssemblyFunction = new LuaCSFunction(StaticLuaCallbacks.LoadAssembly);
castFunction = new LuaCSFunction(StaticLuaCallbacks.Cast);
```

3. 创建一个弱引用的表，该表会被缓存在注册表上，返回的cacheRef用于获取这个表
当有引用类型传入lua时，就会缓存在这个表中
```c#
// ObjectTranslator.cs
LuaAPI.lua_newtable(L);  // 创建缓存表
LuaAPI.lua_newtable(L);  // 创建元表
LuaAPI.xlua_pushasciistring(L, "__mode");
LuaAPI.xlua_pushasciistring(L, "v");
LuaAPI.lua_rawset(L, -3);  // 元表[__mode] = v，表示这张表的所有值皆为弱引用
LuaAPI.lua_setmetatable(L, -2);  // 为缓存表设置元表
cacheRef = LuaAPI.luaL_ref(L, LuaIndexes.LUA_REGISTRYINDEX);
```

## 初始化CS表 `init_xlua`

CS表是Lua代码访问CS内容的核心



该部分代码的主要目的是为lua代码调用CS代码内容准备好环境，因此其主要做了三件事
1. 初始化CS表，并准使用`__index`创建了访问CS类型时才会生成的类型table(懒加载)
2. 创建多个全局函数`typeof`、`cast` 、`setfenv`、 `getfenv`、 `base`
3. 添加xlua特有的库函数`hotfix`、`getmetatable`、`setmetatable`、`setclass`


1. 初始化CS表

CS表为Xlua封装的一个全局Table，相应的CS.UnityEngine则为去查询CS表中名为UnityEngine的值。其通过`_index`来实现。

```lua
-- init_lua
function metatable:__index(key)
    -- fqn实际就是UnityEngine字符串
    -- 查询自己key为'.fqn'的值
    local fqn = rawget(self,'.fqn')
    -- 如果fqn存在，则在字符串后添加.；如果fqn不存在则直接以空字符串处理；然后添加当前查询的key在fqn后方
    fqn = ((fqn and fqn .. '.') or '') .. key

    -- 尝试查询是否有对应的CS类型
    local obj = import_type(fqn)

    if obj == nil then
        -- It might be an assembly, so we load it too.
        --如果为空,有可能这个字段还是类名的一部分,那么创建一个table记录,然后缓存返回.
        obj = { ['.fqn'] = fqn }
        setmetatable(obj, metatable)
    elseif obj == true then
        return rawget(self, key)
    end

    -- Cache this lookup
    rawset(self, key, obj)
    return obj
end

...
-- 省略内容为__newindex和__call的定义
-- 其中不允许使用__newindex, 而__call定义为调用对应的方法，然后将其存入gt中
...
CS = CS or {}
setmetatable(CS, metatable)
```

2. 创建全局函数

```lua
typeof = function(t) return t.UnderlyingSystemType end
cast = xlua.cast
...     -- setEnv 和getEnv
```

3. 加载xlua特有库函数
```lua
xlua.hotfix = function(cs, field, func)
...
end
...
base = function(csobj)
    return setmetatable({__csobj = csobj}, base_mt)
end
```

**小结** ：

可以看到在LuaEnv的只是为CS表进行了初始化，并没有实际将CS需要使用的所有方法和库函数注册进CS表中，只有当调用对应的内容时，CS表才会将对应的内容缓存为元表。

## xlua调用CS代码的方法

> XLua中有两种方式来实现Lua调用CS中的方法,一种是反射来调用,一种是生成适配的代码。

### 调用`CS.UnityEngine.xx`的实际过程

在获取对应类的Lua表时候,使用的是import_type方法，也是在创建LuaEnv实例时候进行注册的代码如下:

```cs
// ObjectTranslator.cs
public void OpenLib(RealStatePtr L) {
// 确保xlua变量以及被注册进入全局表中，
if (0 != LuaAPI.xlua_getglobal(L, "xlua")){  throw new Exception("call xlua_getglobal fail!" + LuaAPI.lua_tostring(L, -1));} 
LuaAPI.xlua_pushasciistring(L, "import_type");
// 将importTypeFunction注册为一个C#的委托，当lua调用Import_type，就会触发
LuaAPI.lua_pushstdcallcfunction(L,importTypeFunction);
LuaAPI.lua_rawset(L, -3); 
...
}
```
当Lua中是调用import_type时候Lua会调用对应的C方法，最后会调用到对应的C#委托上来。

其中`"xlua"`实际为注册进入LuaEnv的一个C函数，存在于xlua.dll中。当LuaEnv被实例化后就可以进行调用。在`ObjectTranslator`可以通过`"import_type"=C#委托`的形式在Lua代码中调用Import_type方法。

### Lua查找指定Type

在C#的importType方法可以获取`ObjectTranslator`缓存对应的Type,如果Type为空，那么说明是第一次尝试引用对应的Type，代码就会判断是时使用生成适配代码还是反射模式，来生成对应的表。

其中`import_type`实际是LuaEnv中的`XLua.StaticLuaCallbacks.ImportType`方法，其和新在于判断我们期望调用的类型是否是CS代码中存在的。比如当fqn是`UnityEngine.GameObject`，就会去CS中查找该类的存在情况。

```C#
// 找到fqn对应的转化器
ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
string className = LuaAPI.lua_tostring(L, 1);
Type type = translator.FindType(className);     // 转化器中是否有注册的类型
if (type != null){
    if (translator.GetTypeId(L, type) >= 0) {
        LuaAPI.lua_pushboolean(L, true);
    }
    else{
        return LuaAPI.luaL_error(L, "can not load type " + type);
    }
}
else {
    LuaAPI.lua_pushnil(L);
}
return 1;
```

`FindType`用于确定我们的要调用的内容是否是一个类，不是则返回nil, `GetTypeId`用于获取我们需要的table的。

当我们的table是一个数组或者委托时，则直接返回对应的原表，如果不是，则需要进行创建。
```cs
// 是数组或者委托则直接返回对应的元表
if (type.IsArray)
{
    if (common_array_meta == -1) throw new Exception("Fatal Exception! Array Metatable not inited!");
    return common_array_meta;
}
if (typeof(MulticastDelegate).IsAssignableFrom(type))
{
    if (common_delegate_meta == -1) throw new Exception("Fatal Exception! Delegate Metatable not inited!");
    TryDelayWrapLoader(L, type);
    return common_delegate_meta;
}

// 如果不是则生成走表的创建流程
is_first = true;
Type alias_type = null;
aliasCfg.TryGetValue(type, out alias_type);
LuaAPI.luaL_getmetatable(L, alias_type == null ? type.FullName : alias_type.FullName);

if (LuaAPI.lua_isnil(L, -1)) //no meta yet, try to use reflection meta
{
    LuaAPI.lua_pop(L, 1);

    if (TryDelayWrapLoader(L, alias_type == null ? type : alias_type))
    {
        LuaAPI.luaL_getmetatable(L, alias_type == null ? type.FullName : alias_type.FullName);
    }
    else
    {
        throw new Exception("Fatal: can not load metatable of type:" + type);
    }
}
```

表的创建流程是通过`TryDelayWrapLoader()`函数执行的，该函数将看需要使用的表究竟是直接通过Loader函数生成还是走反射生成。

```C#
public bool TryDelayWrapLoader(RealStatePtr L, Type type)
{
    if (loaded_types.ContainsKey(type)) return true;
    loaded_types.Add(type, true);

    LuaAPI.luaL_newmetatable(L, type.FullName); //先建一个metatable，因为加载过程可能会需要用到
    LuaAPI.lua_pop(L, 1);

    Action<RealStatePtr> loader;
    int top = LuaAPI.lua_gettop(L);
    if (delayWrap.TryGetValue(type, out loader))
    {
        // 通过Loader直接生成将查询的类型的表（自己生成的代码）
        delayWrap.Remove(type);
        loader(L);
    }
    else
    {
        // 由于Loader中没有，因此要通过反射
        ......
        Utils.ReflectionWrap(L, type, privateAccessibleFlags.Contains(type));
        ......
    }
    ......

    return true;
}
```

### 设置Type对应的Table以辅助调用

在生成完Type对应的Lua表后还需要设置到Lua上去，`SetCSTable`方法把cls_table设置到CS.UnityEngine.GameObject和CS[type]下。

这也是为什么能够在前面local obj = import_type(fqn)，结果为true的时，能直接rawget(self, key)得到table的原因。

```cs
// 以UnityEngine.Debug为例
public static void SetCSTable(RealStatePtr L, Type type, int cls_table)
{
    int oldTop = LuaAPI.lua_gettop(L);
    cls_table = abs_idx(oldTop, cls_table);
    LuaAPI.xlua_pushasciistring(L, LuaEnv.CSHARP_NAMESPACE);
    LuaAPI.lua_rawget(L, LuaIndexes.LUA_REGISTRYINDEX);
    // path = {`UnityEngine`, `Debug`}
    List<string> path = getPathOfType(type);
    // 检查除最后一个table外的其他table是否存在，不存在则创建
    for (int i = 0; i < path.Count - 1; ++i)
    {
        // 栈顶压入对应的path[i]
        LuaAPI.xlua_pushasciistring(L, path[i]);
        if (0 != LuaAPI.xlua_pgettable(L, -2))
        {
            LuaAPI.lua_settop(L, oldTop);
            throw new Exception("SetCSTable for [" + type + "] error: " + LuaAPI.lua_tostring(L, -1));
        }
        if (LuaAPI.lua_isnil(L, -1))
        {
            LuaAPI.lua_pop(L, 1);
            LuaAPI.lua_createtable(L, 0, 0);
            LuaAPI.xlua_pushasciistring(L, path[i]);
            LuaAPI.lua_pushvalue(L, -2);
            LuaAPI.lua_rawset(L, -4);
        }
        else if (!LuaAPI.lua_istable(L, -1))
        {
            LuaAPI.lua_settop(L, oldTop);
            throw new Exception("SetCSTable for [" + type + "] error: ancestors is not a table!");
        }
        LuaAPI.lua_remove(L, -2);
    }
    // 设置CS.UnityEngine.Debug = cls_table
    LuaAPI.xlua_pushasciistring(L, path[path.Count - 1]);
    LuaAPI.lua_pushvalue(L, cls_table);
    LuaAPI.lua_rawset(L, -3);
    LuaAPI.lua_pop(L, 1);
    // 设置CS[type] = cls_table
    LuaAPI.xlua_pushasciistring(L, LuaEnv.CSHARP_NAMESPACE);
    LuaAPI.lua_rawget(L, LuaIndexes.LUA_REGISTRYINDEX);
    ObjectTranslatorPool.Instance.Find(L).PushAny(L, type);
    LuaAPI.lua_pushvalue(L, cls_table);
    LuaAPI.lua_rawset(L, -3);
    LuaAPI.lua_pop(L, 1);
}
```
此时当调用`CS.UnityEngine.Debug`时就会去cls_table去调用的对应的方法。

> 该方法只是静态调用（静态类），对象内容的调用不是走该函数。


## Xlua是如何调用CS代码


