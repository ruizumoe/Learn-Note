# 曲面细分：细分三角形

在现代着色器工业流水线中，分为几个阶段

1. 顶点着色节点
2. 曲面细分阶段（可选）
    + 外壳着色器
        + 常量外壳着色器，（对整个三角形图元进行操作）， 决定曲面细分的程度。其输出一个“细分因子”。这个因子决定了原始三角形将被分成多少个小三角形。可以根据摄像机距离等因素动态计算这个因子，从而实现动态细节层次（LOD）
        + 控制点外壳着色器，每个控制点（通常是原始三角形的顶点） 进行操作。可以对从顶点着色器传来的控制点数据进行处理或修改，然后输出给下一个阶段。
    + 曲面细分器
        + 接收来自外壳着色器的“细分因子”，并根据这个因子，在GPU内部将原始的图元（如一个三角形或四边形）分割成大量更小的三角形网格。
        + 无法用 HLSL 代码直接编写它，但可以在着色器中配置它。
    + 域着色器
        + 根据曲面细分器生成的新顶点，配置其世界坐标数据，法线等属性。
        + 域着色器为每一个新生成的顶点调用一次。
            + 来自常量外壳着色器的细分因子。
            + 来自控制点外壳着色器的控制点数据。
            + 曲面细分器生成的顶点参数（如重心坐标）。
        + 通过上述内容插值计算出最终属性。例如，你可以采样一张高度图来置换顶点，实现凹凸不平的地形或海浪效果。
3. 几何着色器阶段（可选）
4. 裁剪与屏幕映射
5. 片元着色器

曲面细分将原始存在的面片进行细化或者放大，根据你的设置（细分因子）将其复印成由无数小点（小三角形）组成的高清大图

而几何着色器是针对给的点，凭空画出一个完全不同的、更复杂的图案（如一个三角形、一条线甚至多个三角形）。

因此现在要喜欢原本的面片，需要通过配置曲线细分阶段来实现。


## 外壳着色器


### 控制点外壳
通过外壳着色器，告知Unity具体细分的参数

```glsl

// 输入参数

// 返回一个顶点给细分阶段，程序会对面片中的每个顶点调用一次该函数，并通过附加参数指定应处理哪个控制点（顶点）
[UNITY_domain("tri")]  // 告诉编辑器需要处理的是三角形
[UNITY_outputcontrolpoints(3)]      // 指定每个面片输出三个控制点
[UNITY_outputtopology("triangle_cw")]       // 当 GPU 创建新三角形时，按顺时针方向处理三角形
[UNITY_partitioning("integer")]         // 如何分割面片
[UNITY_patchconstantfunc("MyPatchConstantFunction")]        // 通过自定义函数告诉面片被分割为多少部分
VertexData MyHullProgram (

    // 处理的最小单位是一个面片，其顶点数量为3
	InputPatch<VertexData, 3> patch,

    // 具体的控制点id, 
	uint id : SV_OutputControlPointID
) {

    // 给细分阶段传递单个控制点
    return patch[id];
}
```

### 常量外壳着色器

```glsl

// 用于切丁如何细分三角形
struct TessellationFactors {
    // 三角形每一个边都有一个对应的细分因子
    float edge[3] : SV_TessFactor;      

    // 三角形内部的细分因子
    float inside : SV_InsideTessFactor;
};


TessellationFactors MyPatchConstantFunction (InputPatch<VertexData, 3> patch) {
	TessellationFactors f;
    f.edge[0] = 1;
    f.edge[1] = 1;
    f.edge[2] = 1;
	f.inside = 1;
	return f;
}

```

## 域着色器

当使用外壳着色器确定面片如何细分以后，需要域着色器对结果进行评估并生成最终三角形的顶点。

```glsl



// 这个阶段后，数据就会发往几何着色器或者插值器。
[UNITY_domain("tri")]       // 外壳着色器与域着色器作用于相同的域（即三角形）
InterpolatorsVertex MyDomainProgram (
    // 当前面片的细分参数
    TessellationFactors factors,
    // 原始面片算数据
	OutputPatch<VertexData, 3> patch,

    // 虽然曲面细分阶段决定了面片的细分方式，但是并没有直生成新的顶点，而且给出这些新顶点的重心坐标
    // 因此域着色器的一个核心工作为利用这些坐标计算出最终顶点位置
    // 每一个新顶点都会调用一次域函数
	float3 barycentricCoordinates : SV_DomainLocation
) {
    // 需要被返回的顶点数据
    VertexData data;


    // 利用重心心坐标在原始三角形内进行插值
    // 定义宏来减少工作量
    #define MY_DOMAIN_PROGRAM_INTERPOLATE(fieldName) data.fieldName = \
		patch[0].fieldName * barycentricCoordinates.x + \
		patch[1].fieldName * barycentricCoordinates.y + \
		patch[2].fieldName * barycentricCoordinates.z;

    // 计算出
	MY_DOMAIN_PROGRAM_INTERPOLATE(vertex)
	MY_DOMAIN_PROGRAM_INTERPOLATE(normal)
	MY_DOMAIN_PROGRAM_INTERPOLATE(tangent)
	MY_DOMAIN_PROGRAM_INTERPOLATE(uv)
	MY_DOMAIN_PROGRAM_INTERPOLATE(uv1)
	MY_DOMAIN_PROGRAM_INTERPOLATE(uv2)

    // 让域着色器接管几何着色器的功能，把重心坐标相关内容加入
    return return MyVertexProgram(data);

}
```

此后就可以在着色器通道中定义我们的曲面着色器和域着色器

```glsl
pass{
    ....

    #pragma hull MyHullProgram
    #pragma domain MyDomainProgram

}

```


#### 曲面细分和GPU Instance的细节

> 注意Unity原始Build-in渲染管线中不支持一个Shader同时使用GPU实例化和曲面细分。如果非要一起使用，就只能使用LOD技术，在LOD0的时候使用支持曲面细分的Shader, 其他LOD使用GPU实例化的Shader; 或者使用Graphics.DrawMeshInstancedIndirect而不使用细分曲面, 但需要手动控制GPU裁剪和LOD。
> 
> 但是SRP中可以使用 SRP Batcher 来合批你的曲面细分对象，而不是纠结于传统的 GPU Instancing
>
> 注意Graphics.DrawMeshInstancedIndirect 是属于 GPU Instancing 技术体系下的一个高级接口。
>
> GPU Instancing 就像一辆巴士，一次把所有去同一目的地（相同网格和材质）的乘客（实例） 全都送过去。（减少Draw Call）
> 
> SRP Batcher 就像修建了一条从CPU到GPU的高速公路，让每一辆小汽车（单个Draw Call） 都能跑得非常快，不管车里坐的是谁（不同的网格/材质）。（优化Per Draw Call成本）


##