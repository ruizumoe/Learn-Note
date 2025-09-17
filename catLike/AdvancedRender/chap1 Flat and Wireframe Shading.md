# 平面着色与线框着色的导数与几何应用

有时候如果希望实现风格化的渲染，可能需要明显的观察到网格样式，此时就需要通过一定方法去获取三角形面片的一些内容（如法向量）等来直接渲染面片

## 平面着色

一个简单的做法就是，让每个三角形的片元获得该三角形的法向量，而不是用顶点的法向量去插值。

在片元着色器中获得三角形法向量的方法就是通过采样当前点的X分量和Y分量的叉积。因为三角形面片一定是平坦的，因此他的方向导数一定能得到一个相同的法向量。

## 几何着色器

第二种方式就是通过几何着色器，其是位于顶点着色器和片元着色器之间的一个着色器，属于可选着色器。

### 几何着色器介绍

> 定义：
> 
> 几何着色器是图形渲染管线中的一个可编程阶段，它能够处理完整的图元（点、线、三角形），并可以生成新的图元或修改现有的图元。

主要用途

1. 动态几何生成 
    + 将每个店货站成一个四边形（粒子系统 常用于毛发、粒子系统
2. 几何细化与简化
    + 将三角形细分为更多三角形
3. 程序化几何变形
    + 基于高度图变形表面
4. 高级剔除和LOD
    + 基于距离的细节级别控制， 只渲染近的三角形，

实例
```glsl
// 将每个顶点扩展为多个毛发/草叶
[maxvertexcount(18)]
void geom(point v2g input[1], inout TriangleStream<g2f> stream)
{
    // 为每个点生成3根草，每根草2个三角形
    for(int i = 0; i < 3; i++)
    {
        GenerateBlade(input[0].vertex, stream);
    }
}
```

上述几何着色器的两个参数分别是

1. 图元信息，例子中point表示一个点图元，每个点一个顶点
> + point	input[1]	点图元（每个点一个顶点）
> + line	input[2]	线段图元（两个顶点）
> + triangle	input[3]	三角形图元（三个顶点）
> + lineadj	input[4]	带邻接信息的线段
> + triangleadj	input[6]	带邻接信息的三角形

`v2g`顶点着色器输出到几何着色器输入的结构体

```glsl
struct v2g  // vertex-to-geometry 的缩写
{
    float4 vertex : POSITION;     // 顶点位置
    float2 uv : TEXCOORD0;        // UV坐标
    float3 normal : NORMAL;       // 法线
    // 可以添加其他需要传递的数据
};

```


2. TriangleStream 模板化的输出流，用于输出特定类型的图元：

> + PointStream `<g2f>`	点	生成点云、粒子
> + LineStream`<g2f>`	线段	生成线框、轮廓线
> + TriangleStream`<g2f>`	三角形	生成三角形网格

`<g2f>` 是输出结构体

```glsl
struct g2f  // geometry-to-fragment 的缩写
{
    float4 vertex : SV_POSITION;  // 裁剪空间位置（必须）
    float2 uv : TEXCOORD0;        // UV坐标
    float3 normal : NORMAL;       // 法线
    // 可以添加其他需要传递的数据
};
```

在tinyRender中没有明确划分这一阶段，但是可以间接对应了着色器将顶点进行着色，获得的三角形面片这一过程

```c++
for (int i = 0; i < model->nfaces(); i++){
    for (int j = 0; j < 3; j++){
        screen_coords[j] = depthShader.vertex(i, j);
    }
    // 间接对应几何着色 （但是实际流程不一样
    triangle(screen_coords, depthShader, depthMap, shadowbuffer);
}

```

流程可视化

顶点着色器

↓

(v2g结构体) × 3个顶点 → 几何着色器输入 `input[3]`

↓

几何着色器处理（可以修改、添加、删除几何）

↓

通过 `stream.Append()` 输出新的顶点 → TriangleStream

↓

片段着色器

↓

(g2f结构体) → 最终像素颜色

### 面片着色做法

在几何着色器中，由于我们知道每个顶点的数据，可以直接通过顶点相减，再求叉积找到对应的法线，然后替换原有的normal。

虽然在片元着色器阶段，该法线会被用重心坐标插值，但是由于三个点都是相同法线，因此插值出来也是相同法线。


# 渲染线框

通过几何着色器获取顶点数据以后，可以通过为顶点数据规定其所述重心坐标，从而在片元着色器中知道当前片元和顶点坐标的位置

## 为每个顶点添加重心坐标

由于网格本身不提供重心坐标，因此需要修改输出结构体，让其能获得重心坐标数据，且该结构体必须包含`InterpolatorsVertex`。

```glsl
struct InterpolatorsGeometry {
	InterpolatorsVertex data;
    // 重心坐标 
    float2 barycentricCoordinates : TEXCOORD9;
};


// 处理数据
void MyGeometryProgram (
	triangle InterpolatorsVertex i[3],
	inout TriangleStream<InterpolatorsGeometry> stream
) {
	…

	InterpolatorsGeometry g0, g1, g2;
	g0.data = i[0];
	g1.data = i[1];
	g2.data = i[2];

    // 通过重心坐标相加恒等于1来处理第三个重心坐标的值
    g0.barycentricCoordinates = float2(1, 0);
	g1.barycentricCoordinates = float2(0, 1);
	g2.barycentricCoordinates = float2(0, 0);


	stream.Append(g0);
	stream.Append(g1);
	stream.Append(g2);
}
```
注意此时并不能让片元着色器正确插值我们的坐标，因此还需要自己编写处理方法。（此处略过）

## 创建线框效果

通过该方法，我们就可以获得每个片元的在三角形的重心, 通过重新改写反照率贴图的采样，就可以处理线框颜色

```glsl
float3 GetAlbedoWithWireframe (Interpolators i) {
	float3 albedo = GetAlbedo(i);
	float3 barys;

    // 获得当前点的重心坐标
	barys.xy = i.barycentricCoordinates;
	barys.z = 1 - barys.x - barys.y;

    // 固定线框宽度度
    float delta = fwidth(barys);

    // 缩小线框宽度
    barys = smoothstep(deltas, 2 * deltas, barys);

    // 找到当前点距离边缘的最小距离
    float minBary = min(barys.x, min(barys.y, barys.z));

    // 如果在边缘，minBary为0
	return albedo * minBary;;
}
```




