# 景深

景深是一个源自真实世界摄影和光学的概念。

定义：当相机镜头对焦于某个特定距离（对焦点）时，在该点前后一段距离内的景物都能保持清晰成像，这段清晰的范围就叫做景深。范围之外的景物则会变得模糊。

三种区域：

1. 前景深：对焦点之前的一段清晰范围。

2. 焦平面：对焦点所在的完美清晰平面。

3. 后景深：对焦点之后的一段清晰范围。

作用：

1. 引导视觉焦点，让观众自然而然被吸引到画面中清晰的部分
2. 增加立体感和氛围：让模糊的部分从主体中被剥离，增加三维立体感，营造出梦幻、神秘或紧张的特定氛围。
3. 提升真实感：因为计算机渲染出的都是清晰景象，这反而显得不真实。加入景深效果可以模拟真实相机的光学特性，让CG画面更具说服力。


## Unity实现景深的做法

Unity通过**深度纹理**来实现景深效果

有了深度纹理，我们就知道了画面中每一个像素点在3D空间中的深度信息。这是实现所有基于屏幕空间的后期效果（如景深、SSAO、雾效）的基础

![景深步骤](<chap5 Depth of Field/deepseek_mermaid_20250923_6d142e.png>)

### 步骤

#### 1. 生成焦散图（Circle of Confusion Map - CoC Map）

焦外弥散圆（Circle of Confusion, CoC） 指一个理想点光源在焦平面之外成像时，在传感器上形成的一个模糊光斑。

过程: 对每一个像素执行以下操作

1. 从深度纹理中得到当前像素的深度值

2. 获取用户设置的焦点距离，（可以是固定的、也可以是基于相机射线撞到物体自动对焦的）

3. 计算当前深度和焦点距离的差值

4. 根据这个差值，结合用户设置的光圈（Aperture） 和焦距（Focal Length） 参数（模拟物理相机），计算出该像素的模糊半径（Blur Radius），即CoC的大小

5. 差值 = 0（像素正好在焦平面上）：模糊半径为0，像素保持清晰。

6. 差值很大（像素远离焦平面）：模糊半径很大，像素需要强烈模糊。

输出： 生成一张新的灰度图（CoC Map），其中每个像素的亮度值代表其应有的模糊程度。


#### 2. 基于CoC图的模糊处理

接下来需要根据CoC图提供的模糊半径对原始图形进行模糊。其难点在于每个像素需要的模糊半径是不同的，传统的均匀模糊方法无法直接直接使用

Unity使用的是一种特殊的，支持可变半径的模糊算法： 散景模糊（Bokeh Blur）

实现方式：通常采用“聚集”（Gather） 的方式。对于每个像素，着色器会根据其CoC半径，在其周围一个圆形或六边形区域内采集多个样本，然后将这些样本混合起来。对于CoC半径很大的背景像素，这个采样范围会很大，混合后就更模糊。


#### 3. 混合

最后一步是将清晰的原始图像和模糊后的图像合成在一起。

简单混合：直接使用CoC图作为蒙版，将清晰图像（焦内区域）和模糊图像（焦外区域）进行线性插值混合。

前沿处理：为了避免在焦内和焦外过渡区域出现生硬的边界，高级实现会进行边缘软化处理，确保过渡平滑自然。


# CatLike实际做法 


## CoC

Coc的一个简单做法，就是在片元着色器中，根据当前采样的深度 d、对焦距离 f和对焦范围 r来计算弥散圆

$$ coc = \frac {depth - FocusDistance} {FocusRange} $$


## Bokeh 焦外成像

创造虚化有两种方法

1. 为每个纹素渲染一个精灵，以其颜色着色，并根据其弥散圆值调整尺寸和透明度。但其需要大量过度绘制，一般不使用
2. 不同于将单个片段投射到多个像素，这种方法让每个片段累积所有可能影响它的纹素颜色。该技术无需生成额外几何体，但需要进行大量纹理采样。

### 做法

#### 直接采样

一个简单的光圈效果就是采样周围点的时候计算点到到当前点的距离，超过光圈半径就丢弃。但该效果不如直接通过配置的方式去获取对应采样点。

```glsl
static const int kernelSampleCount = 16;
static const float2 kernel[kernelSampleCount] = {
    float2(0, 0),
    float2(0.54545456, 0),
    float2(0.16855472, 0.5187581),
    float2(-0.44128203, 0.3206101),
    float2(-0.44128197, -0.3206102),
    float2(0.1685548, -0.5187581),
    float2(1, 0),
    float2(0.809017, 0.58778524),
    float2(0.30901697, 0.95105654),
    float2(-0.30901703, 0.9510565),
    float2(-0.80901706, 0.5877852),
    float2(-1, 0),
    float2(-0.80901694, -0.58778536),
    float2(-0.30901664, -0.9510566),
    float2(0.30901712, -0.9510565),
    float2(0.80901694, -0.5877853),
};

half4 FragmentProgram (Interpolators i) : SV_Target {
    half3 color = 0;
    for (int k = 0; k < kernelSampleCount; k++) {
        float2 o = kernel[k];
        o *= _MainTex_TexelSize.xy * 8;     // 8为采样尺寸，可以通过传参自己设定
        color += tex2D(_MainTex, i.uv + o).rgb;
    }
    color *= 1.0 / kernelSampleCount;
    return half4(color, 1);
}
```
#### 散景模糊处理

虽然专用采样核函数优于常规网格采样，但要获得理想的散景效果仍需大量采样。为在同等采样量下扩大覆盖范围，可像处理辉光特效那样采用半分辨率渲染。虽然这会使散景略微模糊，但属于可接受的代价。

其做法是

1. 将图像绘制到半尺寸纹理上
2. 对半尺寸纹理做模糊处理（采用上一小节的直接采样方法）
3. 使用一个特殊的后处理通道，使用帐篷滤波器的 3×3 卷积核，对纹理进行高斯模糊
4. 再绘制回全分辨率



## 对焦

此时获得了CoC和模糊图像以后，就需要通过特定方式将两者混合

因为我们是以半分辨率创建散景，所以也需要半分辨率的弥散圆数据。但是常规的降采样方法是直接求平均，对弥散圆并不合理，需要自己设定新的渲染。

步骤

1. 首先对低分辨率纹素对应的四个高分辨率纹素进行采样并取平均值，将结果存储在 alpha 通道中。
```glsl
half4 FragmentProgram (Interpolators i) : SV_Target {
    float4 o = _MainTex_TexelSize.xyxy * float2(-0.5, 0.5).xxyy;
    half coc0 = tex2D(_CoCTex, i.uv + o.xy).r;
    half coc1 = tex2D(_CoCTex, i.uv + o.zy).r;
    half coc2 = tex2D(_CoCTex, i.uv + o.xw).r;
    half coc3 = tex2D(_CoCTex, i.uv + o.zw).r;
    
    half cocMin = min(min(min(coc0, coc1), coc2), coc3);
        half cocMax = max(max(max(coc0, coc1), coc2), coc3);
        half coc = cocMax >= -cocMin ? cocMax : cocMin;

    return half4(tex2D(_MainTex, i.uv).rgb, coc);
}
```
### 使用正确的景深模糊圈值

要使用正确的弥散圆半径，我们必须在第一遍计算时根据散景半径对弥散圆值进行缩放。

```glsl
float coc = (depth - _FocusDistance) / _FocusRange;
coc = clamp(coc, -1, 1) * _BokehRadius;
```
如果

核采样点对片元的散景效果有贡献，则是弥散圆的采样点与当前片元重叠。若采样点的弥散圆半径不小于其偏移向量对应的核半径，则该点的投影最终会与片元重叠。

如果重叠则证明该采样点的模糊对核采样点有影响


```glsl
half weight = 0;
half3 color = 0;
half weight = 0;
for (int k = 0; k < kernelSampleCount; k++) {
    float2 o = kernel[k] * _BokehRadius;
    half radius = length(o);
    o *= _MainTex_TexelSize.xy;
    half4 s = tex2D(_MainTex, i.uv + o);

    if (abs(s.a) >= radius) {
        color += s.rgb;
        weight += 1;
    }
}
color *= 1.0 / weight;

```

### 平滑采样效果

同一卷积核环内的样本往往具有大致相同的弥散圆直径值，这意味着它们倾向于同时被舍弃或保留。最终我们主要会得到三种情况：无环、单环和双环。我们可以通过放宽样本纳入标准来缓解这两个问题。不再完全舍弃样本，而是为其分配 0 到 1 范围内的权重值。该权重取决于弥散圆直径和偏移半径，我们可以使用独立函数进行计算。

```glsl
half Weigh (half coc, half radius) {
///    return coc >= radius;
    // 弥散圆直径减去半径的差值作为权重函数 实现更平滑的过渡效果
    return saturate((coc - radius + 2) / 2);
}

half4 FragmentProgram (Interpolators i) : SV_Target {
    half3 color = 0;
    half weight = 0;
    for (int k = 0; k < kernelSampleCount; k++) {
        …

//						if (abs(s.a) >= radius) {
//							color += s;
//							weight += 1;
//						}
        half sw = Weigh(abs(s.a), radius);
        color += s.rgb * sw;
        weight += sw;
    }
    color *= 1.0 / weight;
    return half4(color, 1);
}


```

### 保持焦点清晰

半分辨率渲染会让图形更加模糊，但处于焦平面上的片段本不应受到任何景深效果的影响。为了清晰度，因需要将半分辨率效果与全分辨率源图像相结合，并根据弥散圆半径在两者之间进行混合。

其做法是在增加一个新的渲染通道，简单做法就是根据弥散圆半径来在不同的纹理做切换

。假设绝对弥散圆半径低于 0.1 的片段完全聚焦，应使用源纹理；而绝对弥散圆半径超过 1 的片段则完全使用景深纹理。在过渡区间通过 smoothstep 函数进行混合处理。

```glsl
half4 source = tex2D(_MainTex, i.uv);
half coc = tex2D(_CoCTex, i.uv).r;
half4 dof = tex2D(_DoFTex, i.uv);

half dofStrength = smoothstep(0.1, 1, abs(coc));
half3 color = lerp(source.rgb, dof.rgb, dofStrength);
return half4(color, source.a );
```

### 前景与背景分离

对焦清晰的背景前方存在失焦前景时，与源图像进行混合会产生错误结果。这是因为前景本应部分投射在背景之上（我们的景深效果确实实现了这一点），但我们基于背景的弥散圆选择使用源图像时，却消除了这种层次关系。为解决这个问题，我们必须设法将前景和背景分离开来。



