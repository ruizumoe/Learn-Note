# 雾效
## 前向雾效

之前都是模拟光线在真空中传播。但实际上，光线需要穿过大气或液体，光线不仅会在撞击固体表面时被吸收、散射和反射，还可能在空间中的任何位置发生这些现象。

精确渲染大气干扰代价昂贵，因此实际一般采用一种依赖少量恒定雾效参数的近似方案。

### 标准雾效

Unity的*Lighting*窗口有一个Fog组件可以用于模拟基本雾效。

#### 线性雾效

可以设置雾效开始产生影响的起始距离以及完全浓密的终止距离，在此区间内雾效浓度呈线性增长。

雾效起始点之前视野清晰，超过该距离后物体逐渐被雾气遮蔽，超过终止距离后则只能看到雾的颜色。

线性雾因子,
$$
    f = clamp(\frac{end - c} {end - start })
$$
> + c：当前片段到相机的距离（雾坐标）
> + start：雾效开始的距离
> + end：雾效完全覆盖的距离
>
> f = 0：完全被雾覆盖（物体不可见） f = 1：无雾（物体完全清晰）

![线性雾](<chap14 Fog/image-2.png>)


#### 指数雾

$$
f = \frac{1}{2^{cd}} = 2 ^{-cd}
$$
其中 d 表示雾的密度系数

![指数雾](<chap14 Fog/image-1.png>)

#### 平方指数雾
$$
f = \frac{1}{2^{(cd)^2}} = 2 ^{(-cd)^2}
$$

![平方指数雾](<chap14 Fog/image.png>)

### 自己添加雾效

要自己添加雾效，其需要再光照阶段执行雾效计算
```hlsl
float4 ApplyFog (float4 color, Interpolators i) {
	...
	return color;
}
```

+ 计算片段距离相机的位置 
+ 将片段和雾进行插值

#### 基于深度的雾效

Unity标准着色器使用了基于深度的雾效，也就是裁剪空间的深度值，其优势在于无需计算平方根。虽然会导致真实性较差，但是性能更优。

在自己的着色器中，如果开启了雾效，可以在顶点着色器中，就将片段的深度存放在worldPos的w通道中，并在片元着色器中取出，来计算和相机的距离。

```hlsl
vertext(VertexData v){
    ...
    #if FOG_DEPTH
		i.worldPos.w = i.pos.z;
	#endif
    ...
}

frag(){
    ...
    #if FOG_DEPTH
		viewDistance = i.worldPos.w;
	#endif
    ...
}
```
#### 多个光源
当有多个光源时，在之前的前向渲染中，每个光源都会增加一次雾效。最好的办法是，只有基础通道会使用雾效，其他通道的雾效颜色都是黑色

```hlsl
float3 fogColor = 0;
#if defined(FORWARD_BASE_PASS)
	fogColor = unity_FogColor.rgb;
#endif
color.rgb = lerp(fogColor, color.rgb, saturate(unityFogFactor));
```

## 延迟雾效

要实现雾效延迟渲染，需要所有光源全部渲染完毕以后，再加入一个通道来融入雾气。其类似于渲染一个定向光源

### 获取相机纹理

一般简单的添加雾效通道的方法是在相机上添加自定义组件，添加`OnRenderImage`方法，该方法是Unity后处理（Post-Processing）​​ 设计的事件函数，其在在摄像机完成场景渲染后、最终图像输出到屏幕前被调用。

> 该方法必须挂在到Camera对象上才有效，Unity会遍历场景中的Camera组件，检查是否有OnRenderImage方法，且只有正在渲染的相机才会除法

```cs
// source 摄像机渲染完成的原始图像
// destination 处理后图像的目标位置
void OnRenderImage (RenderTexture source, RenderTexture destination) {
    // 
    Graphics.Blit(source, destination);
}
```

**该方法是Built-in Render Pipeline​自带方法**，URP (Universal Render Pipeline)​​：需改用 RenderPipelineManager 的 endCameraRendering 事件。（RenderFeature）


### 雾效着色器

编写一个雾效着色器，将相机渲染的问题在雾效着色器中重新执行。需要绘制一个覆盖整个屏幕的四边形来覆盖所有内容。

在有了着色器以后，需要得到应用该着色器的材质，因此在CSharp中生成对应的材质

```cs
[ImageEffectOpaque]     // 在透明物体绘制前执行
void OnRenderImage (RenderTexture source, RenderTexture destination) {
		if (fogMaterial == null) {
			fogMaterial = new Material(deferredFog);
		}
		Graphics.Blit(source, destination, fogMaterial);
}
```

着色器的顶点着色器输入内容为四边形纹理的顶点数据和UV数据

```hlsl
Interpolators VertexProgram (VertexData v) {
    Interpolators i;
    i.pos = UnityObjectToClipPos(v.vertex);
    i.uv = v.uv;
    return i;
}

float4 FragmentProgram (Interpolators i) : SV_Target {
    float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv);
    depth = Linear01Depth(depth);       /

    float3 sourceColor = tex2D(_MainTex, i.uv).rgb;
    return float4(sourceColor, 1);
}
```
注意虽然没在同一个着色器中，Unity还是可以采样到这个相机贴图中每个片元在世界空间中的原始深度，然后再转化到0-1的裁剪空间（Linear01Depth）

在depth的基础上 乘以远裁剪平面的深度，就可以获得实际的深度视距
```float viewDistance = depth * _ProjectionParams.z - _ProjectionParams.y;```

此时基于该depth执行雾效处理，就可以获得雾效结果。


### 基于距离的雾效

在前向雾效中，默认是使用基于距离的雾效，然后增加对基于深度的雾效的支持。在延迟雾效中，由于本身就有深度信息，因此天生支持基于深度的雾效。此时就需要增加基于距离的雾效。

其原理是从近平面发射光线，如果被物体遮挡，就能得到一个定长光线。使用该定长光线向量叠加相机近平面位置，就能得到渲染表面世界空间中的位置。**但实际我们只需要这个光线的长度。**

在得到光线后，可以通过对每一个像素进行插值的方法，找到每一个像素光线的长度。

一个简单的办法是，基于相机的远平面及其视场角来构建光线。只需要四边各一条光线，得到光线的距离。

>  Camera.CalculateFrustumCorners 方法可以为我们完成这一任务。该方法包含四个参数：第一个是使用的矩形区域，本例中即整个图像；第二个是光线投射的远距离，必须与远平面匹配；第三个参数涉及立体渲染，我们只需使用当前活动的眼睛视角；最后，该方法需要一个三维向量数组来存储光线。因此我们需要同时缓存相机引用和向量数组。
>
>  CalculateFrustumCorners 的顺序是左下、左上、右上、右下

获得光线距离后，将数据传递给着色器，就可以开始准备通过纹理的深度来插值得到各个像素光线的长度。

```hlsl
Interpolators VertexProgram (VertexData v) {
    ...
    #if defined(FOG_DISTANCE)
        i.ray = _FrustumCorners[v.uv.x + 2 * v.uv.y];
    #endif
}

float4 FragmentProgram (Interpolators i) : SV_Target {
    ...
    #if defined(FOG_DISTANCE)
    	viewDistance = length(i.ray * depth);
    #endif
}
```

### 天空盒和无雾情况

延迟渲染由于是对整个相机渲染的纹理起作用，因此也会影响天空盒。解决方法就是，当深度接近1时，就将雾效系数设置为1，不处理雾效。

当不开启雾效的是时候默认也需要将雾效系数设置为1。