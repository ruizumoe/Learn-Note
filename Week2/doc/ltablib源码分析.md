# ltablib源码分析

## lua栈基础

lua每个线程会创建一个虚拟机栈，用于记录即将执行的函数调用，函数参数，以及临时值的传递（如遍历时候返回的1和0）。

其中虚拟机栈会在`lua_State`结构体中保存，由stack指针指向栈的内存空间，`StkId`指针指向Lua栈的某一个位置，该指针是一个`TValue`类型的结构体指针。由于`TValue`保存了该段空间的类型`tt`以及union内存`Value`。因此其可存放多种信息，在执行过程中代码将通过`tt`判断需要跳转的位置。

由于函数可以和数据一同被被存放在虚拟机的栈中，因此在Lua中函数被看作是第一类型值，即表示和传统的类型的值具有相同的权力，即函数可以被存放在变量中，也可以被存放在table，甚至作为参数传递给其他函数。

[闭包相关内容参考](https://blog.csdn.net/maximuszhou/article/details/44280109)


## lua虚拟机栈相关源码分析

### 虚拟机初始化

虚拟机初始化主要生成了两个栈空间，分别是用于存储当前函数调用的栈空间，和虚拟机栈的数据存储空间以及初始化相关指针

> 由于在lua中函数是第一类型数据，因此函数也会被存储在虚拟机的栈帧中，但是每次Lua发现有function时都会修改ci指针相关的内容<br>
> 在lua中



```c
static void stack_init (lua_State *L1, lua_State *L) {
  /* initialize CallInfo array */
  L1->base_ci = luaM_newvector(L, BASIC_CI_SIZE, CallInfo);       // 指向保存callinfo栈帧的空间，每个callInfo栈帧保存了当前调用函数在虚拟机栈帧使用空间的指针以及其他信息
  L1->ci = L1->base_ci;                     // 当前调用的函数信息
  L1->size_ci = BASIC_CI_SIZE;              // 调用函数栈的大小
  L1->end_ci = L1->base_ci + L1->size_ci - 1;       
  /* initialize stack array */
  L1->stack = luaM_newvector(L, BASIC_STACK_SIZE + EXTRA_STACK, TValue);        // 虚拟机栈的基础空间
  L1->stacksize = BASIC_STACK_SIZE + EXTRA_STACK;                               // 虚拟机栈的总容量
  L1->top = L1->stack;                                                          // 虚拟机栈 在单个函数调用执行过程的栈顶，用于指向待使用的栈帧
  L1->stack_last = L1->stack+(L1->stacksize - EXTRA_STACK)-1;
  /* initialize first ci */
  L1->ci->func = L1->top;                   // 暂时不知道                                         
  setnilvalue(L1->top++);  /* `function' entry for this `ci' */
  L1->base = L1->ci->base = L1->top;                                            // 在单个函数调用执行过程的栈底
  L1->ci->top = L1->top + LUA_MINSTACK;     // 暂时不知道                            
}

```

### 根据idx寻址

```c
static TValue *index2adr (lua_State *L, int idx) {
  if (idx > 0) {
    TValue *o = L->base + (idx - 1);
    // 不超过函数调用栈的范围
    api_check(L, idx <= L->ci->top - L->base);  // ci->top表示在当前函数调用的栈帧的结束位置，而L->base和L->ci->base指向同一处，表示在函数调用其实位置
    if (o >= L->top) return cast(TValue *, luaO_nilobject);       // top并表示虚拟机栈的有实际值存储空间范围末尾，即idx的位置没有数据则返回nil
    else return o;
  }
  else if (idx > LUA_REGISTRYINDEX) {       // idx小于0，但是还在Lua默认的取值范围内，这里使用了栈索引 idx 的负数形式来表示栈顶位置。
    api_check(L, idx != 0 && -idx <= L->top - L->base);       // idx取绝对值，在top到base这一范围内
    return L->top + idx;
  }
  else switch (idx) {  /* pseudo-indices */         // 根据不同的伪索引值
    case LUA_REGISTRYINDEX: return registry(L);     // 返回全局注册表的地址指针
    case LUA_ENVIRONINDEX: {                        // 需要返回当前函数的环境表地址，其中存放了当前函数调用的闭包信息
      Closure *func = curr_func(L);
      sethvalue(L, &L->env, func->c.env);           
      return &L->env;
    }
    case LUA_GLOBALSINDEX: return gt(L);              // 返回全局表的地址
    default: {
      Closure *func = curr_func(L);                   // 获得当前函数
      idx = LUA_GLOBALSINDEX - idx;                   // 将伪索引转化为全局索引
      return (idx <= func->c.nupvalues)               // 返回当前函数的 upvalue（闭包中的外部局部变量）的地址指针。
                ? &func->c.upvalue[idx-1]
                : cast(TValue *, luaO_nilobject);
    }
  }
}
```


### foreachi 功能

```c
static int foreachi (lua_State *L) {
  int i;
  int n = aux_getn(L, 1);         // 1表示第一个参数，其应该是个table， 检测栈帧类型是否为期望类型（当前函数为检测是否为table类型），如果是则返回参数1对应table的大小
  luaL_checktype(L, 2, LUA_TFUNCTION);    // 检测第二个参数是否为一个函数
  for (i=1; i <= n; i++) {
    lua_pushvalue(L, 2);  /* function */    // 将当前需要执行的函数压入栈，该函数可以是自定义函数
    lua_pushinteger(L, i);  /* 1st argument */    // 将当前索引i压入栈
    lua_rawgeti(L, 1, i);  /* 2nd argument */     // 将表第i个索引的内容压入栈
    lua_call(L, 2, 1);                            // 函数有两个参数，期望返回一个结果
    if (!lua_isnil(L, -1))                      // 只要返回值不是nil那么就跳出循环，否则继续执行循环
      return 1;
    lua_pop(L, 1);  /* remove nil result */       // 返回值为Nil,移除栈顶结果，继续执行遍历
  }
  return 0;
}

```


### insert 插入功能

```c
static int tinsert (lua_State *L) {
  int e = aux_getn(L, 1) + 1;  /* first empty element */      // 先通过aux_getn(L, 1)获得表的长度，+1获得第一个为空的位置
  int pos;  /* where to insert new element */   
  switch (lua_gettop(L)) {                            // 计算top-base的长度得到参数的数量
    case 2: {  /* called with only 2 arguments */
      pos = e;  /* insert new element at the end */
      break;
    }
    case 3: {
      int i;
      pos = luaL_checkint(L, 2);  /* 2nd argument is the position */
      if (pos > e) e = pos;  /* `grow' array if necessary */
      for (i = e; i > pos; i--) {  /* move up elements */         // 向将pos以后的数据以此移动一位
        lua_rawgeti(L, 1, i-1);               // 将table[i-1]的数据存储在L-top中
        lua_rawseti(L, 1, i);  /* t[i] = t[i-1] */
      }
      break;
    }
    default: {
      return luaL_error(L, "wrong number of arguments to " LUA_QL("insert"));
    }
  }
  luaL_setn(L, 1, e);  /* new size */
  lua_rawseti(L, 1, pos);  /* t[pos] = v */
  return 0;
}

```



### 问题：
1. 在嵌套函数执行过程中，Lua虚拟机中L->top和L->base是如何移动的？是否是使用每次进行函数调用，就用callinfo记录当前函数在函数中的其实位置base和top

也就是说，每次进入一个函数top和base都会从函数的起始点同步出发，然后记载
