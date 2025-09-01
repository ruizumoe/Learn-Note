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

