# 新增第二光源

在设置主平行光的情况下，自定义的shader 需要新增一个ListMode = "ForwarAdd"的Pass才能渲染非主光源的灯光。且混合模式为 Blend One One。

在前向渲染中，GPU会对三角形光栅化的片段进行深度检测，深度要少于深度缓存中的深度，才能进行渲染，并写入深度。因此对于光纤叠加Pass，不需要写入深度，ZWrite Off。

# 点光源

在关闭主平行光的情况下，仅使用点光源的话，仍会得到一张没有光照渲染的图，因为基础通道始终会渲染一遍。而且第二遍再执行加法通道，执行点光源的渲染。

## 光线方向

对于平行光来说，它实际上存储的是朝向光源的方向
点光源需要通过减去片段的世界坐标位置并对结果进行归一化处理
```hlsl
    light.dir = normalize(_WorldSpaceLightPos0.xyz - i.worldPos);
```

## 光线衰减

点光源可以看做一个球形不断向外扩散光子的物质，球表面距离球心越大，则球表面积增大，但是光子数量一定，因此光子密度也降低。但是过于近的时候，为了保证光线不会突变，一般使用
```hlsl
    float attenuation = 1 / (1 + dot(lightVec, lightVec));
```

## 光照范围

在设定光照范围以后，超过光照范围的片段很可能会在边界处产生突变。因此要用合适的自定义光照强度衰减。
在自定义SRP中使用的方法是 
`强度 * （1 - (distance / range)²）² / distance² `


# 混合光源

直接在叠加Pass中使用点光源的方向会导致平行光出现问题，因此可以使用着色器变体来区分平行光和点光`#pragma multi_compile DIRECTIONAL POINT`

然后在获得光源方向的时候 使用
```hlsl
#if defined(POINT)
    light.dir = normalize(_WorldSpaceLightPos0.xyz - worldPos);
#else
    light.dir = _WorldSpaceLightPos0.xyz;
#endif
```

> 在SRP中 采用的是在C#中将不同光源的数据预先计算好，包括光源信息位置，方向，等数据，存放在不同的数组中，传递给着色器调用