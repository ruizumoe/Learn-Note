# FXAA

FXAA是一种基于后处理的抗锯齿技术，抗锯齿本身源于显示器的物理极限，未与像素网格对齐的图像特征会出现锯齿现象。斜线与曲线会呈现阶梯状外观，即常见的"锯齿"问题。

常见的抗锯齿方案

1. SSAA： 该方法至少需要将场景渲染至两倍于最终分辨率的缓冲区，再对四个像素组成的区块取平均值来生成最终图像。

2. MSAA：在图形边缘增加采样数量，比如4xMSAA就是在边缘像素点上，将像素点划分为4份，根据采样的结果来确定前景和背景的权重，（比如有三个采样点是前景，一个是背景则像素混合就是 75% * 前景 + 25% * 背景）。


## FXAA介绍

FXAA是一种单通道、屏幕空间的抗锯齿算法，不依赖于几何信息，而是直接对最终渲染图像进行处理。

FXAA三个阶段

1. 亮度检测（Luminance Calculation）

将RGB转化为亮度值

```glsl
float3 rgb = tex2D(_MainTex, uv).rgb;
float luma = dot(rgb, float3(0.299, 0.587, 0.114));
```

2. 边缘检测（Edge Detection）

    + 分析当前像素与周围像素的亮度差异
    + 确定边缘方向和强度


> 采样区域:
>
> NW  N  NE
> 
>  W  C  E
>
> SW  S  SE

> 计算水平/垂直梯度:
>
> float edgeHorz = abs((NW + 2*N + NE) - (SW + 2*S + SE));
>
> float edgeVert = abs((NW + 2*W + SW) - (NE + 2*E + SE));

边缘方向判断
```glsl
bool isHorizontal = edgeHorz >= edgeVert;
float edgeStrength = max(edgeHorz, edgeVert);

```

3. 边缘混合（Edge Blending）
    + 沿着边缘方向进行亮度混合
        + 沿着方向向两侧衍生
        + 计算混合长度和权重
    + 使用预计算的混合权重 




