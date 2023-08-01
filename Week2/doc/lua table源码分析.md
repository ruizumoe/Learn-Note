# table源码分析
Lua的table数据结构主要由`ltable.c`和`ltablib.c`构成，其中`ltable.c`主要定义了table的基础存取方法（包括创建，存取值，free等）；`ltablib.c`提供了table常用的辅助接口（遍历，插入，移除，排序等）

> `ltablib.c`主要实现功能
```c
static const luaL_Reg tab_funcs[] = {
  {"concat", tconcat},
  {"foreach", foreach},
  {"foreachi", foreachi},
  {"getn", getn},
  {"maxn", maxn},
  {"insert", tinsert},
  {"remove", tremove},
  {"setn", setn},
  {"sort", sort},
  {NULL, NULL}
};
```
## table基础元素

Lua的基础数据结构，包括GCobj, table等数据都是存储在`lobject.h`中

```c
typedef struct Table {
  CommonHeader;
  lu_byte flags;  /* 1<<p means tagmethod(p) is not present */ 
  lu_byte lsizenode;  /* log2 of size of `node' array */
  struct Table *metatable;
  TValue *array;  /* array part */
  Node *node;
  Node *lastfree;  /* any free position is before this position */
  GCObject *gclist;
  int sizearray;  /* size of `array' array */
} Table;

```


其中`lu_byte`实际上是`typedef unsigned char lu_byte;` 其中 `unsigned char`是一个无符号字符，范围从0~255，用以表示一个字节 

`CommonHeader`是一个标记头，用以标记所有可用于回收的资源。任何需要进行GC操作的Lua数据类型，都会有一个 CommonHeader宏定义的成员，且定义在结构体的最开始部分。

`TValue`是一个结构体，存放了名为`TValuefields`的宏定义，该定义中包含了一个类型为`Value`的值和Value对应的类型`tt`

```c
#define TValuefields    Value value; int tt
```

其中`Value`是一组类型的union
```c
typedef union {
  GCObject *gc;
  void *p;
  lua_Number n;
  int b;
} Value;
```

`Node`存储了table中的每一个键值对
```c
typedef struct lua_TValue {
  TValuefields;
} TValue;

typedef union TKey {
  struct {
    TValuefields;
    struct Node *next;  /* for chaining */
  } nk;
  TValue tvk;
} TKey;

typedef struct Node {
  TValue i_val;
  TKey i_key;
} Node;

```
上述代码表示了在table中，每一个node都有key和value，其中key有两种情况，分别是只有单个TValue内容和存储Value内容，并通过next指向下一个node的指针。



## ltable.c源码分析