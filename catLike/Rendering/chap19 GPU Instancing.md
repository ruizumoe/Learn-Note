# GPU Instance

GPU Instance的核心在于，通过一条指令绘制**相同**的物体，减少CPU到GPU的通信

因此在实际绘制中，Shader会给每个物体分配对应的InstanceId，通过这个instanceId，Shader允许当前的着色器从实例化缓冲区中获取当前实例的的属性值。（注意实例缓冲区也需要定义）


GPU instance的具体过程

CPU: 收集实例数据 → 填充实例化缓冲区 → 调用一次Draw Call

GPU:
+ 顶点着色器(处理每个顶点):
    1. 获取当前实例ID
    2. 计算顶点位置（使用统一的网格数据）
    3. 传递实例ID到片元着色器

+ 片元着色器(处理每个像素):
    1. 获取当前实例ID
    2. 从实例化缓冲区读取实例属性
    3. 输出颜色



## 实例

### 持有instanceId
要获得instanceId，要在顶点着色器和片元着色器都增加对instanceId的持有。

```glsl
// 顶点着色器输入结构体
struct Attributes 
{
    ...
    UNITY_VERTEX_INPUT_INSTANCE_ID              // 为了能够GPU实例化，需要将对象索引作为定点属性   声明实例ID的输入   每个顶点会携带该顶点所属实例的ID。这个ID在渲染时由Unity引擎自动填充。
};


// 片元着色器的输入
struct Varyings
{
    ...
    UNITY_VERTEX_INPUT_INSTANCE_ID   // 将实例ID传递到片元着色器
};


Varyings LitPassVertex(Attributes input)
{
    UNITY_SETUP_INSTANCE_ID(input);             // 该宏会提取接口体中的索引，并存入一个全局静态变量中
    UNITY_TRANSFER_INSTANCE_ID(input, output);      // 将当前实例ID传递到输出，以便片元着色器使用
    ....
}
```
通过该方法，就可以使得每个着色器对应的每个实例获得唯一的整数ID（从0开始递增）

+ 自动管理：GPU驱动为每个实例自动分配和管理这些ID
+ 连续分配：在同一绘制调用中，ID是连续分配的

对于没有使用GPU实例化的物体

+ unity_InstanceID 仍然存在：但值总是0
+ 一致性保证：Unity确保所有物体都有这个变量，无论是否使用实例化
+ 向后兼容：这样现有的Shader代码不会因为缺少这个变量而崩溃

### 属性采样

在获取ID以后，着色器代码就可以通过这个id访问到在一个实例属性缓存池中的数据

```glsl
UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
    UNITY_DEFINE_INSTANCED_PROP(float4, _BaseMap_ST)
    UNITY_DEFINE_INSTANCED_PROP(float, _Cutoff)
    UNITY_DEFINE_INSTANCED_PROP(float, _ZWrite)
    ...
UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)
```

在定义以上缓存池以后，就可以通过`UNITY_ACCESS_INSTANCED_PROP(缓存池名称, 属性名称)`来获取对应的实例在缓存池中的数据。

`UNITY_SETUP_INSTANCE_ID`和`UNITY_ACCESS_INSTANCED_PROP`自动处理了实例ID的传递和访问 

`UNITY_SETUP_INSTANCE_ID`实际上定义了一个局部变量unity_InstanceID，在使用`UNITY_ACCESS_INSTANCED_PROP`的时候就会在内部使用这个局部变量，从实例缓存数值中取出对应ID缓存的属性。


### 不同采样变体

一般来说，一个Shader要同时支持是否开启GPU Instance的物体，因此只能变体来让不同的实例调用不同的采样命令。

```glsl
#ifdef UNITY_INSTANCING_ENABLED
    // 实例化路径：从实例化缓冲区获取
    float4 color = UNITY_ACCESS_INSTANCED_PROP(Props, _Color);
#else
    // 非实例化路径：使用材质属性
    float4 color = _Color;
#endif
```

在SRP项目中，并没有使用这样的变体，其原因在于`UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)`中的UnityPerMaterial缓冲区被Unity进行了特殊处理
+ 对于实例化变体：
```glsl
// 实例化变体中，UnityPerMaterial是实例化缓冲区
UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
UNITY_DEFINE_INSTANCED_PROP(float4, _BaseColor)

// ... 其他属性
UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)
```

使用宏读取属性
```glsl
// 通过实例ID访问特定实例的属性
#define INPUT_PROP(name) UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, name)

// 展开为：UnityPerMaterialArray[unity_InstanceID].name
```

+ 对于非实例化变体：

Unity会自动将UnityPerMaterial缓冲区转换为常规的uniform常量缓冲区：

```glsl
// 非实例化变体中，UnityPerMaterial变为常规uniform缓冲区

CBUFFER_START(UnityPerMaterial)
    float4 _BaseColor;
    // ... 其他属性
CBUFFER_END
```

使用宏读取属性

```glsl
// 直接访问uniform变量
#define INPUT_PROP(name) name

// 展开为：_BaseColor（直接访问）

```

Shader实质上是自动进行了回退机制

1. 检测到使用UnityPerMaterial缓冲区
2. 自动为非实例化变体创建对应的uniform变量
3. 重写UNITY_ACCESS_INSTANCED_PROP宏以直接访问这些变量
4. 确保两种变体都能正确编译和运行


虽然UnityPerMaterial很强大，但是最好还是显式的使用两种变体来完成。


## GPU instance 缓冲区大小限制

GPU instance的常量缓冲区CBuffer实际上有数量限制，每一个缓冲区只有64KB。

你在Shader中通过 UNITY_INSTANCING_BUFFER_START 和 UNITY_DEFINE_INSTANCED_PROP 定义的每个实例属性都会占用这块空间。属性越多、越复杂（如多个float4或矩阵），每个实例所需的数据量就越大，导致每批次（Draw Call）能渲染的实例数量相应减少。

一个批次，一次性大概能处理500个对没有属性需求的物体。

每个物体的位置矩阵有16个浮点数，每个浮点值4字节，因此单个矩阵64字节。

单个实例需要两个矩阵，从对象空间到世界空间、从世界到对象空间，也就是128个字节。

因此最大处理批次
$$
\frac{64 * 1000} {128} = 500  (和内存实际空间不一样)
$$

> unity内部定义UNITY_INSTANCED_ARRAY_SIZE 默认定义为 500

但是对于移动端设备，常量空间大小就是16k了

### 优化方案

1. 使用指令指定批次大小：通过Shader中的 #pragma instancing_options forcemaxcount: 或 maxcount: 来指定Unity尝试每批次绘制的最大实例数 (设置的值最终仍受制于底层图形API的缓冲区大小限制。不能超过511)

2. 减少每实例数据：优化定义在 UNITY_INSTANCING_BUFFER_START 中的属性，只保留必需的。例如，如果所有实例缩放一致，可使用 assumeuniformscaling 选项来减少数据量。

3. 利用MaterialPropertyBlock：对于需要通过脚本频繁修改的每实例属性，MaterialPropertyBlock 是更好的选择，因为它不会破坏实例化合批。

4. 考虑替代方案：对于需要远超1024个实例的场景，或数据量非常大的情况，可以考虑使用 Graphics.DrawMeshInstancedIndirect 配合Compute Shader和ComputeBuffer。这种方法能提供更大的灵活性和数量控制，但实现也更复杂。