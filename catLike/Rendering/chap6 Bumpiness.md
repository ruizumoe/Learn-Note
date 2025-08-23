# 凹凸贴图

法线贴图和切线空间相关概念

切线空间是模型每个顶点上的一个局部坐标系，这个坐标系的原点是自己本身，三个轴分别是

​T (Tangent)​​：​切线方向。通常与纹理坐标的U（或X）方向对齐，表示表面延展的方向。本质上就是纹理在U方向上变化的斜率（导数）

B (Bitangent)​​：​副切线​（或双切线）方向。通常与纹理坐标的V（或Y）方向对齐。有时也记作 S。 和T类似，在贴图V方向上到下一个纹素的斜率（导数）

N (Normal)​​：​法线方向。垂直于模型表面的方向。这是整个空间定义的基石。在知道和TB垂直的方向，一般直接给出。

法线贴图存储的是一个向量，这个向量表示的是：“相对于平坦表面，当前像素点的法线应该偏移到什么方向”。

> 比如表面平坦，则法线贴图存储的就是该点正对N轴的位置
>
> 而朝向T轴凸起（U右方向）法线会向右上方倾斜
>
> 因此 法线贴图 如果在T方向上偏移较大 则越红（越偏右）


# 高度贴图

在Shader中定义一个_HeightMap 可以通过采样获得贴图的高度。

因此通过高度贴图，可以采样(当前点和下一个点的高度)/纹素大小获得切线。通过该方法，计算两个UV防线的切线以后，就能计算出当前点的法线.

```hlsl
void InitializeFragmentNormal(inout Interpolators i) {
    // 计算中心纹理
	float2 du = float2(_HeightMap_TexelSize.x * 0.5, 0);
	float u1 = tex2D(_HeightMap, i.uv - du);
	float u2 = tex2D(_HeightMap, i.uv + du);

	float2 dv = float2(0, _HeightMap_TexelSize.y * 0.5);
	float v1 = tex2D(_HeightMap, i.uv - dv);
	float v2 = tex2D(_HeightMap, i.uv + dv);

	i.normal = float3(u1 - u2, 1, v1 - v2);
	i.normal = normalize(i.normal);
}
```

## 法线贴图

将高度贴图的 Texture Type 改为 Normal Map，Unity会自动进行转化，使用三线性过滤。

> 三线性过滤是对高度图的高频信息进行过滤，保证不会有突然的巨大导数。导数过大会可能会出现摩尔纹。

### 混合法线

对于细节法线贴图和法线贴图的混合上，可以使用白化混合法，其本身是一个为了视觉效果的hack。

两个法线在混合后不再是单位向量，一定需要归一化，而如果发现差异很大时，一个长度小于1的法线向量参与光照计算（通常是点积 dot(N, L)），会导致光照变暗、凹凸感减弱，视觉效果完全错误。

其核心思想是，在混合前，先暂时忽略法线Z分量信息，基于其X,Y分量（倾斜度）重新构建一个假设的、更合理的法线。在美术效果上 倾斜度更能描述凹凸感。

忽略法线分量的信息以后，进行混合，再执行归一化，能得到更好的美术效果（物理上并不真实）

```hlsl
vec3 a_whiteout = normalize(vec3(A.xy, 1.0));
vec3 b_whiteout = normalize(vec3(B.xy, 1.0));
vec3 blended_whiteout = weight * a_whiteout + (1-weight) * b_whiteout;
vec3 final_normal = normalize(blended_whiteout);
return final_normal

// 或者自己构造就是

return normalize(half3(n1.xy + n2.xy, n1.z * n2.z));

```

