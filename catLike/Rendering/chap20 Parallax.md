# 视差

由于透视的原因，当我们调整观察视角时，所看到的事物的相对位置会发生变化。这种视觉现象被称为视差。近处的事物显得很大且快速移动，而远处的背景则显得较小且移动较慢。

用法线贴图能让表面获得一个相对简单的凹凸效果，但是近距离查看，其本质上还是一个平坦表面的视差。而加强发现效果，反正会让光照显得不自然。

要获得真实的深度感，需要高度图。借助高度图，我们就能像伪造坡度那样伪造视差效果。高度图，采用灰度表示，黑色代表最低点，白色代表最高点。


## 定义着色器

在偏远着色器中，传入当前像素内容， 基于该像素的数据来采样高度图信息


### 沿视线方向偏移
视差是由透视投影引起的，这与观察者相对位置有关。因此我们必须基于这个原理来偏移纹理坐标。

要获得偏移，还需要知道切线空间中的视角方向，我们可以在顶点程序中创建一个从对象空间到切线空间的变换矩阵。

```glsl
InterpolatorsVertex MyVertexProgram (VertexData v) {
    #if defined (_PARALLAX_MAP)
        float3x3 objectToTangent = float3x3(
            v.tangent.xyz,
            cross(v.normal, v.tangent.xyz) * v.tangent.w,
            v.normal
        );
        i.tangentViewDir = mul(objectToTangent, ObjSpaceViewDir(v.vertex));
    #endif
}

void ApplyParallax (inout Interpolators i) {
	#if defined(_PARALLAX_MAP)
		i.tangentViewDir = normalize(i.tangentViewDir);
		i.uv.xy += i.tangentViewDir.xy * _ParallaxStrength;
	#endif
}

```

### 基于高度的滑动

此时需要采样高度图来作为表面UV的偏移数据量，且为了保证低洼地区和高地区的分离，需要手动增加一个阈值
```glsl

void ApplyParallax (inout Interpolators i) {

    i.tangentViewDir = normalize(i.tangentViewDir);
    float height = tex2D(_ParallaxMap, i.uv.xy).g;
    height -= 0.5;
    height *= _ParallaxStrength;
    i.uv.xy += i.tangentViewDir.xy * height;
}

```

## 正确的投影偏移量

上述使用的视差映射技术被称为带偏移限制的视差映射。我们仅使用观察方向的 XY 分量，其最大长度为 1，因此纹理偏移受到限制。这种方法能产生不错的效果，但并不能代表正确的透视投影。

