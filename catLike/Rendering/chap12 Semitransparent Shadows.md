# 镂空阴影

阴影着色器如果不进行特殊处理，那么着色器会将镂空的整个贴图视作一个完全的贴图。

因此要处理镂空阴影需要采样原始贴图上的alph值，然后基于alpha值裁剪阴影。

```hlsl
Interpolators MyShadowVertexProgram (VertexData v) {
	…

	#if SHADOWS_NEED_UV
        // 将顶点上的原始uv应用贴图的 tiling\offset配置后得到新的展开uv
		i.uv = TRANSFORM_TEX(v.uv, _MainTex);
	#endif
	return i;
}

float GetAlpha (Interpolators i) {
	float alpha = _Tint.a;
	#if SHADOWS_NEED_UV
		alpha *= tex2D(_MainTex, i.uv.xy).a;
	#endif
	return alpha;
}

float4 MyShadowFragmentProgram (Interpolators i) : SV_TARGET {
	float alpha = GetAlpha(i);
	#if defined(_RENDERING_CUTOUT)
		clip(alpha - _AlphaCutoff);
	#endif  
	…
}
```

# 部分阴影

Fade 和 Transprant 渲染模式不同于镂空阴影，其半透明的特性导致阴影不是二值（不是0就是1）。因此不能直接对阴影贴图进行采样获得。

> catLike描述
> 
> 但不同于基于阈值进行裁剪，我们可以采用均匀裁剪片段的方式。例如，若某个表面允许半数光线透过，便可使用棋盘格图案间隔裁剪片段。整体而言，这样产生的阴影强度将呈现为完整阴影的一半。
>
> 我们不必始终使用相同图案。根据 alpha 值的不同，可以采用孔洞密度各异的图案。若将这些图案进行混合，便能实现阴影浓度的平滑过渡。本质上，我们仅用两种状态就实现了渐变效果的模拟。这种技术被称为抖动处理。

抖动描述： 抖动是通过规律的排列不同颜色的像素，来欺骗人的眼睛（比如报纸的图片，就是通过控制黑色小点的数量来形成的灰色阴影）

既然我们不能让一个像素“半在阴影中”，那我们就在空间上（相邻像素）和时间上（连续帧）进行分布，让一些像素在阴影中，另一些不在，从而在宏观上形成一种“部分阴影”的视觉平均效果。​

步骤：
1. 生成抖动图案，其包含一系列从小到大，有规律分布的灰度值小型纹理
2. 应用抖动：
    + 计算片元的深度，获得其阴影结果
    + 获得物体当前位置的透明度
    + 根据当前像素的屏幕坐标，从抖动贴图的采样一个噪声值（Dither Value) 
    + 概率裁剪，将物体和抖动值比较进行概率裁剪

> unity 包含了一个16中不同的4x4的抖动像素贴图供我们使用，从空白开始，每个后续模式会多填充一个像素，直到填充七个像素。随后模式会反转并逆向填充，直到所有像素都被填满。
>

采样阴影结果，不能使用网格的UV坐标，需要使用片元的屏幕空间坐标，这样才能保证阴影贴图和都抖动模式对齐。

```hlsl
float4 MyShadowFragmentProgram (Interpolators i) : SV_TARGET {
	#if SHADOWS_SEMITRANSPARENT
    
		tex3D(_DitherMaskLOD, float3(i.vpos.xy * _DitherScale, alpha * 0.9375));
	#endif
	…
}
```
> 注意采样_DitherMaskLOD使用3D的原因是，如果使用2D贴图，那么每一帧采样的阴影会是完全相同的，在移动的时候会有明显闪烁。
> 因此第三个维度是时间维度，保证阴影每一帧不同
> Unity的第三个维度总共有16种模式第一个模式的 Z 坐标为 0，第二个模式坐标为 0.0625，第三个为 0.128。
>
> _DitherScale是抖动图案在屏幕空间中的缩放比例，越小噪声纹理会在屏幕上更频繁地重复。结果是噪声颗粒变得更细、更密集，抖动效果看起来更“精细”。

在实际使用中可以通过应用alpha来得到第三个维度

为了让效果更好，可以在应用后处理，使用空间滤波来让抖动片段无法察觉