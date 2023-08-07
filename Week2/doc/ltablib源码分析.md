# ltablib源码分析

## lua栈基础

lua每个线程会创建一个虚拟机栈，用于记录即将执行的函数调用，函数参数，以及临时值的传递（如遍历时候返回的1和0）。

其中虚拟机栈会在`lua_State`结构体中保存，由stack指针指向栈的内存空间，`StkId`指针指向Lua栈的某一个位置，该指针是一个`TValue`类型的结构体指针。由于`TValue`保存了该段空间的类型`tt`以及union内存`Value`。因此其可存放多种信息，在执行过程中代码将通过`tt`判断需要跳转的位置。

由于函数可以和数据一同被被存放在虚拟机的栈中，因此在Lua中函数被看作是第一类型值，即表示和传统的类型的值具有相同的权力，即函数可以被存放在变量中，也可以被存放在table，甚至作为参数传递给其他函数。

[闭包相关内容参考](https://blog.csdn.net/maximuszhou/article/details/44280109)


## lua虚拟机栈相关源码分析

> 下文解析部分中所有`t->top`均表示为**栈顶元素**，而栈顶元素的实际位置为`L->top-1`， 此处为便于理解使用`t->top`来表示

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

在虚拟机栈中，每次使用函数时，都会在stack栈中使用t->base作为当前函数的栈底，t->top用于指示当前函数可用的存储数据位置。
由于函数可能有多个参数，调用参数的方式不一定是顺序的，因此需要通过t->base + idx或t->top - idx的方式去获取不同的参数内容。

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

该函数为`table.foreachi`, 有两个参数，分别是table和function，因此每次遍历时都需要将function压入栈中作为参数使用

该函数建议不再使用，因为可以使用`ipairs`和`pairs`进行替代，但整体思路将function和table元素的key/value作为参数压入栈中，由于检测到了function，lua会创建callinfo结构体，记录新的function的起始位置等；此时table的key和value由于比函数本身靠近栈顶，因此其会被作为函数的参数进行调用。

该函数由于使用了`Lua_call`, 会通知有该函数两个参数，一个返回值，因此会根据参数的数量获取到函数对应的栈帧(top - 2)，该栈帧被调用的时候因为类型为闭包fun，因此在lua虚拟机中会走到`case OP_TAILCALL`这一分支，从而执行函数调用的相关工作。详细内容需要查看 `lvm.c  607行`


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
        lua_rawgeti(L, 1, i-1);               // 获取当前函数的参数1（table)，并将i-1对应的值存放到栈帧L->top中
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

与insert相关的几个底层函数源码

```c
// get函数
LUA_API void lua_rawgeti (lua_State *L, int idx, int n) {
  StkId o;
  lua_lock(L);
  o = index2adr(L, idx);
  api_check(L, ttistable(o));
  setobj2s(L, L->top, luaH_getnum(hvalue(o), n));         // 获取table中下表为n的数据，然后将其放置在top中
  api_incr_top(L);      // 移动L->top指针
  lua_unlock(L);
}

// set函数
LUA_API void lua_rawseti (lua_State *L, int idx, int n) {
  StkId o;
  lua_lock(L);
  api_checknelems(L, 1);            // 检查这段函数调用所占用的栈空间中至少含有一个元素，因为要将这个元素存入表中
  o = index2adr(L, idx);            // 获取idx对应的栈空间地址，即获得指向表的指针
  api_check(L, ttistable(o));       // 检查当前内容是否为表
  setobj2t(L, luaH_setnum(L, hvalue(o), n), L->top-1);      // 将栈顶的值设置到表对应n下标
  luaC_barriert(L, hvalue(o), L->top-1);                    // 标记table中的值被修改
  L->top--;
  lua_unlock(L);
}
```

### remove 删除函数

将L-top作为中间桥梁，将Pos记为待覆盖元素，每次将Pos+1的值取出存至栈顶，然后将栈顶元素赋值给top，从而实现从后往前的覆盖。最后将nil赋值给数组原本的最后一个元素，完成table元素的消去

```c
// table.remove函数，第一个参数为待删除数据的表, 第二个参数为待删除元素位置
static int tremove (lua_State *L) {
  int e = aux_getn(L, 1);         // 获得第一个参数，表的长度
  int pos = luaL_optint(L, 2, e);         // 获得待删除的元素的位置,如果没有第二个参数，则默认为e
  if (!(1 <= pos && pos <= e))  /* position is outside bounds? */
   return 0;  /* nothing to remove */
  luaL_setn(L, 1, e - 1);  /* t.n = n-1 */              // 由于要删除一个元素，因此表的长度需要减少1
  lua_rawgeti(L, 1, pos);  /* result = t[pos] */        // 获取待删除元素的内容
  for ( ;pos<e; pos++) {        // 从Pos开始，将后一个元素的值覆盖到当前位置，
    lua_rawgeti(L, 1, pos+1);
    lua_rawseti(L, 1, pos);  /* t[pos] = t[pos+1] */
  }
  lua_pushnil(L);
  lua_rawseti(L, 1, e);  /* t[e] = nil */         // 将最末尾的值设置为栈顶元素(nil)
  return 1;
}

```

### concat函数

该函数用于将table中起始位置到目标位置的内容通过连接符相连，形成一段字符串。该部分内容的核心在于一个字符串Buffer，每次遍历table时都将数据存至L->top中，然后从L->top中取出元素存至buffer对应的空间中，当Buffer存满时，将buffer的数据取出形成一个字符串存放至栈中，然后buffer的cur指针回到起始位置，这样就不用重复创建缓存区，减少了分配内存的情况。当遍历完成，则将栈中存储的Buffer字符串全部取出然后进行链接。

该过程重复利用了buffer空间，避免了多次分配空间的情况。但是每次超过buffer的容量时，都会执行字符串的哈希，然后构成一段新的字符串空间。因此链接字符串时应该尽可能避免字符过长的问题。

在该过程中还涉及字符串的哈希，在Lua源码中对字符串哈希的处理时，当字符串长度过长时，则从字符串末尾开始每隔step步长取一位char，计算哈希值，使用计算得到的哈希值，在全局字符串表中查找相应哈希槽（slot）。
+ 如果哈希槽对应的字符串与当前字符串长度相同，且内容也相同（使用memcmp函数进行比较），那么就说明找到对应的字符串，返回即可。
+ 如果遍历完成都没有找到对应的字符串，就将当前字符串写入全局字符串表中。


> 目前concat函数的解析遇到一些问题，主要在`ltablib.c 157行的 addfield(L, &b, i);`函数，当第一次发现buffer的剩余空间不足时，会对buffer空间进行清空，并将buffer的数据转化为字符串存入栈中，但此时发现栈中原本要插入数据并没有进行处理，就被跳过了，这段代码没有太理解，需要后续继续研究代码才行
>
> 上述问题解答： 不需要将要插入的数据存入buffer中，因此buffer中的数据最终是要放在栈上的，其如果有多个buffer顺序，那么一定是自底而上的顺序进行连接。因此直接将new value存储栈帧中，后续遍历完成，进行一次遍历即可将所有数据连接成一个字符串，或者当下一次需要调整buffer空间的时候，会自动将此时单独的new value和buffer空间进行连接。

```C
// table.concat
static int tconcat (lua_State *L) {
  luaL_Buffer b;    // 用于构建连接后的字符串
  size_t lsep;      // 连接符长度
  int i, last;      // 用于指示起始位置和终止位置
  const char *sep = luaL_optlstring(L, 2, "", &lsep);       // table.concat函数如果要指定起始位置和终止位置，则一定需要连接符， 此时将获取连接符
  luaL_checktype(L, 1, LUA_TTABLE);
  i = luaL_optint(L, 3, 1);           // 获取起始位置，其为函数的第三个参数，如果没有第三个参数，则默认其实位置为1
  last = luaL_opt(L, luaL_checkint, 4, luaL_getn(L, 1));           // 获取终止位置，其为函数的第四个参数，如果没有第四个参数，则默认终止位置为table表的长度
  luaL_buffinit(L, &b);            // 初始化字符串的内容，使内部字符串的cur指针指向char数组开头，并且保证luaL_Buffer空间指向当前虚拟机栈 ,因为需要从l->top中取得table中的元素
  
  // 把table从起始点到终点对应索引的值取出来，并放到buff里面，buff大小为BUFSIZ(8192)
  // 每当写满一个Buffer则将其中的数据提取出来，形成一个TString放到栈上，然后将buffer的cur指针归零，相当于重新生成了一个buffer
  for (; i < last; i++) {
    addfield(L, &b, i);
    luaL_addlstring(&b, sep, lsep);
  }
  if (i == last)  /* add last value (if interval was not empty) */
    addfield(L, &b, i);
  luaL_pushresult(&b);
  return 1;
}


// 获取待连接的数据
static void addfield (lua_State *L, luaL_Buffer *b, int i) {
  lua_rawgeti(L, 1, i);
  if (!lua_isstring(L, -1))         // 栈顶元素是string 或者number
    luaL_error(L, "invalid value (%s) at index %d in table for "
                  LUA_QL("concat"), luaL_typename(L, -1), i);
    luaL_addvalue(b);   // 将栈顶元素拷贝到缓冲区
}

// 实际添加数据
LUALIB_API void luaL_addvalue (luaL_Buffer *B) {
  lua_State *L = B->L;
  size_t vl;
  const char *s = lua_tolstring(L, -1, &vl);
  if (vl <= bufffree(B)) {  /* fit into buffer? */
    memcpy(B->p, s, vl);  /* put it there */
    B->p += vl;
    lua_pop(L, 1);  /* remove from stack */     // 将栈顶元素弹出，
  }
  else {
    if (emptybuffer(B))         // 将当前buffer中所有字符串的数据存放至栈顶元素指针指向的空间
      lua_insert(L, -2);  /* put buffer before new value */        // 将-2位置的值，调到栈顶-1位置， 也就是栈顶为待插入元素，-2下一个为当前已经构成的字符串
    B->lvl++;  /* add new value into B stack */       // 由于增加了缓冲区，判断当前缓冲区是否需要压缩
    adjuststack(B);
  }
}

// 将buffer中的数据压到stack上，清空buffer,更新B->lvl
static int emptybuffer (luaL_Buffer *B) {
  size_t l = bufflen(B);
  if (l == 0) return 0;  /* put nothing on stack */
  else {
    lua_pushlstring(B->L, B->buffer, l);
    B->p = B->buffer;
    B->lvl++;
    return 1;
  }
}

/* 此处理解有问题，toplen为new value的长度, 而l为一整个buffer的长度， toplen 一定是小于 l ,导致无法进入判断体中
   而toget不自加 在Lua_concat也无法将数据进行连接
 */

 /* 上述问题解答，不需要将新的值存入buffer, 因为最后连接字符串的时候，一定会从底往上将所有栈中的字符串连接起来，最后形成一个完整的string 并放入栈中。
 因此toplen > l对应的情况就是 某一个栈帧是一个单独需要被连接的value，该value由于超过了buffer的剩余空间，直接被存入的栈帧中，当下一次要重新调整buffer空间时，会判断是否需要进行压缩，这样才需要从top到base进行连接 */
 
// 合并从top-1到-(B-level)之间符合条件的字符串到栈顶 
static void adjuststack (luaL_Buffer *B) {
  if (B->lvl > 1) {
    lua_State *L = B->L;
    int toget = 1;  /* number of levels to concat */  //需要合并的缓冲区数量
    size_t toplen = lua_strlen(L, -1);       // 获得栈顶元素的长度
    do {
      size_t l = lua_strlen(L, -(toget+1));     // 获得第toget个缓存区转化的字符串大小
      if (B->lvl - toget + 1 >= LIMIT || toplen > l) {
        toplen += l;
        toget++;
      }
      else break;
    } while (toget < B->lvl);
    lua_concat(L, toget);
    B->lvl = B->lvl - toget + 1;
  }
}
```





### 问题：
1. 在嵌套函数执行过程中，Lua虚拟机中L->top和L->base是如何移动的？是否是使用每次进行函数调用，就用callinfo记录当前函数在函数中的其实位置base和top

也就是说，每次进入一个函数top和base都会从函数的起始点同步出发，然后记载

