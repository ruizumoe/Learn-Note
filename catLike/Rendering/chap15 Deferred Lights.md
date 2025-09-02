# 延迟光照

之前的章节只有非直接光，该节将自己来实现不同光源的延迟渲染光照通道

## 自定义延迟光照着色器 

在光照通道中，顶点着色器处理的顶点不是场景中的原始几何顶点，而是专门为光照计算设计的代理几何体（Proxy Geometry）的顶点。（光照体积几何体）

有三种代理几何体
+ 全屏四边形 (方向光（Directional Light）、环境光)
```hlsl
struct appdata {
    float4 vertex : POSITION;  // 通常是 [-1,1] 的NDC坐标
    float2 uv : TEXCOORD0;     // 全屏UV (0,0)到(1,1)
};
```
顶点着色的任务就是直接输出裁剪空间位置，以及传递uv

+ 光源体积几何体（Light Volume）​

```hlsl
struct appdata {
    float3 vertex : POSITION;  // 光源体积的局部坐标
};
```
来源： 点光源（球体）、聚光灯（椎体）、区域光（自定义图形、矩形）

​顶点着色器任务​：
1. 将参数中的光源顶点转化到世界空间 o.worldPos
2. 在将对应的世界空间数据转化到裁剪空间 o.pos



### 两次渲染

使用自定义的延迟光照着色器需要有两个Pass, 当 HDR 被禁用时，光线数据是以对数方式编码的。需要最后一遍渲染来反转这种编码。这就是第二遍渲染的目的。

第二个通道就是需要将第一个通道的结果，采样后重新解码

```hlsl
float4 FragmentProgram (Interpolators i) : SV_Target {
    return -log2(tex2D(_LightBuffer, i.uv));
}
```
## 定向光源

为了为图像添加光照，必须确保不擦除已渲染的内容。为此，我们可以通过更改混合模式， `Blend One One`

### 采样G-buffer UV坐标

