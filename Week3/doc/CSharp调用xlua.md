# CSharp代码调用lua
## 基础调用
在C#中，如果想使用lua代码需要定义一个Lua的环境，然后再这个环境中去调用Lua

### 直接调用语句
其基本用法为
```C#
void Start()
{
    LuaEnv luaEnv = new LuaEnv();
    // 直接调用UnityEngine的方法
    luaEnv.DoString("CS.UnityEngine.Debug.log('hello world')");
    luaEnv.Dispose();
}
```
### 加载文件

由于一句一句调用过于复杂，因此可以使用`require`语句去加载lua文件

```C#
void Start()
{
    // byfile为Lua文件的文件名
    LuaEnv luaEnv = new LuaEnv();
    luaEnv.DoString("require 'byfile'");
    luaEnv.Dispose();
} 
```
> 注意上述加载代码会调用loader去`package.path`以及`package.cpath`中依次查询<br>
> 在xlua中，除了原生的Loader，还额外加载了从`Resource`目录加载数据的Loader，但是加载Lua文件时，后缀需要是`lua.txt`
>
> 因此一个可行方案就是，在`Xlua\Resources`目录下存放一个xlua调用时所需要的mainRequire.lua.txt文件，在该文件下修改原生loader的目录。使其能够访问到需要的文件。

```C#
//  加载文件
void Start()
{
    LuaEnv luaEnv = new LuaEnv();
    // 在XLua\Resources下寻找
    luaEnv.DoString("require 'requireFile.requireLuaFile'");   

    // 基于原生Loader寻找     
    luaEnv.DoString("require 'CShrap.example1.CSCallLuaByFile.luaFile.byFileLua'");     
    luaEnv.Dispose();
}
```

```lua
-- requireLuaFile.lua.txt
package.path = package.path..";Assets\\Script\\?.lua"
package.path = package.path..";Assets\\Script\\Lua\\?.lua"
```

### 自定义Loader
可以通过自己实现委托的方式，当使用`luaenv.Dostring()`函数调用require时，会将require的内容作为参数返回到委托中。

```C#
public delegate byte[] CustomLoader(ref string filepath);
public void LuaEnv.AddLoader(CustomLoader loader)
```

实际代码
```c#
private delegate byte[] Loader(ref string fileName);
private LuaEnv luaEnv;
private void Start()
{
    luaEnv = new LuaEnv();
    
    luaEnv.AddLoader(compenteString);   // 为luaEnv增加loader
    // 当lua虚拟机调用require的时候，会将require中的字符串传入compenteString中，返回文件的字节码，交给Lua虚拟机执行。
    luaEnv.DoString("require 'Lua.requireLua.TestRequire1'");
}

private static byte[] compenteString(ref string fileName)
{
    string replace = fileName.Replace(".", "\\");
    StringBuilder sb = new StringBuilder();
    sb.Append("Assets\\Script\\").Append(replace).Append(".lua");
    Debug.Log(sb.ToString());
    if (File.Exists(sb.ToString()))
        return File.ReadAllBytes(sb.ToString());
    return null;
}
```

## CS获取lua元素

### 加载代码

通过DoString调用require后可以直接将文件通过懒加载的方式存入xlua的虚拟机中，供后续调用
```c#
_luaEnv = new LuaEnv();
    _luaEnv.DoString("require 'requireFile.requireLuaFile'");
    _luaEnv.DoString("require 'CShrap.CSCallLua.CSCallLua'");

```
### 基本元素获取

获取代码段中的全局标量，可以直接通过将lua的值与c#的类型进行对应的方式，将值映射到对应类型的变量上

```c#
// 1.获得基本元素
// 值映射
var a = _luaEnv.Global.Get<int>("a");
var b = _luaEnv.Global.Get<string>("b");
var c = _luaEnv.Global.Get<bool>("c");
Debug.Log($"GlobalData a = {a}");
Debug.Log($"GlobalData b = {b}");
Debug.Log($"GlobalData c = {c}");
```

### 将table进行映射

table的数据可以多余或少于映射到的class或struct中

两者的区别在于是值映射还是会创建一个实例并获取其应用

```C#
var D = _luaEnv.Global.Get<DClass>("d");
Debug.Log($"class D info ::: {D.f1} :: {D.f2}");
```

### 轻量级映射，仅获取table内部的特定类型数据

该方式只会获得table中特定类型的数据，比如dictional, list等, 均为值映射

```c#
var dDict = _luaEnv.Global.Get<Dictionary<string, double>>("d");
Debug.Log($"dict D info ::: {dDict["f1"]} :: {dDict["f2"]} :: {dDict.Count}");

// 获得数组内容
var dList = _luaEnv.Global.Get<List<int>>("d");
Debug.Log($"list D info ::: {dList.Count}");
```

### 基于代码生成的interface映射

该方法会将table映射到一个interface的实例中，即引用类型

与class相同，映射属性可多可少，但是区别在于interface上必须标注[CSharpCallLua]即将接口写入生成代码的列表，并手动生成代码。

```C#
var t2C = _luaEnv.Global.Get<ItableToClass>("d");
t2C.f2 = 30123;
// --> interface D info ::: 10 :: 30123 :: 92 ::: XLua.CSObjectWrap.ScriptCShrapCSCallLuaCSCallLuaItableToClassBridge
Debug.Log($"interface D info ::: {t2C.f1} :: {t2C.f2} :: {t2C.add(33, 59)} ::: {t2C.GetType()}");
```

### 将table映射到专门的LuaTbale中

获得内部内容的方法，需要通过get<Type>(key)的方式去访问值， 也是引用类型

```c#
LuaTable lt = _luaEnv.Global.Get<LuaTable>("d");
Debug.Log($"luaTable D info :::{lt.Get<int>("f1")}");
```

### 获得全局funcion的多个方法

#### 将方法映射到一个delegate中

该方法会将lua的函数映射到C#的一个委托中，可以直接执行委托从而调用该函数，因为委托类似于函数指针，可以方便进行调用。

该方法需要标记[CSharpCallLua]，并生代码。

+ delegate可以自己定义，如果自己定义，则每个function的参数需要对应到delegate的输入参数

+ 如果table的function有多个返回值，就需要从左往右映射到c#的输出参数，输出参数包括返回值，out参数，ref参数

```C#
// 使用默认Action接受函数
Action luaFunctionE = _luaEnv.Global.Get<Action>("e");
luaFunctionE();

// 自定义delegate接受function数据
FDelegateFunction fFun = _luaEnv.Global.Get<FDelegateFunction>("f");
DClass f_ret_class;
int f_retNum = fFun(100, "Tom", out f_ret_class);
Debug.Log($"f delegate info ::: {f_retNum}, {f_ret_class.f1} , {f_ret_class.f2}");
// ==> f delegate info ::: 1, 1024 , 0  如果类的结果不匹配，则返回默认值

// 返回值同样是一个delegate, 即返回了另一个function
GetEFunction ret_e = _luaEnv.Global.Get<GetEFunction>("ret_e");
Action e = ret_e();
e();
// ===> ret_e called
// ===> this is function e
```
#### 将方法映射到LuaFunction中

该方法同样需要手动调用，优缺点于delegate完全相反，不推荐使用

```c#
LuaFunction luaFunction_e = _luaEnv.Global.Get<LuaFunction>("e");
luaFunction_e.Call();
// ===> this is function e
```

## 源码分析


## 问题记录

### InvalidCastException: This delegate must add to CSharpCallLua: System.Action

造成原因：代码没有生成出来

解决方案：在Unity项目的菜单栏`Xlua -> Ganerate Code`

解决方案2： 将需要使用的类手动添加到CSharpCallLua编译列表中
