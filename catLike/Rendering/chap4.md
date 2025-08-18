# 法线
## 世界空间的法线

法线从局部空间向世界空间转化时，会因非均匀缩放而导致直接转化法线不正确。

需要乘以从局部到世界转化矩阵的逆矩阵的转置才能正确转化。

```hlsl
i.normal = mul(
    transpose((float3x3)unity_WorldToObject),
    v.normal
);
i.normal = normalize(i.normal);

// 等价于
i.normal = UnityObjectToWorldNormal(v.normal);
```

# 漫反射着色

漫反射光量正比于光线方向与表面法线之间夹角的余弦值，这一规律被称为朗伯余弦定律。可以通过计算表面法线与光线方向的点积来确定这个朗伯反射系数。

由于背向光源时，不应该能看到光，因此当点积为负时不应该有光强。因此需要使用`max(0, dot(xx,xx))`来处理。

在着色器上封装了该方法，名为` saturate `。这个标准函数会将数值限制在 0 到 1 之间。

> UnityStandardBRDF 头文件定义了便捷的 DotClamped 函数

Unity在渲染时需要知道应该应用何种光照模式，对应着色器通道的 `LightMode`标签。 其取决于场景的渲染模式（前向渲染或延迟渲染）。

## Albedo 基础色

材质的漫反射颜色被称为"反照率"(albedo)， 它描述了红、绿、蓝三个颜色通道中有多少被漫反射，其余部分则被吸收。

实际数据可以直接通过对albedo贴图经常采样获取。

## Specular Shading  镜面反射着色

当光线击中表面后未被散射，而是以与入射角相等的角度从表面反弹时，就会发生这种现象。

我们可以通过物体到世界矩阵在顶点程序中确定表面的世界坐标位置，然后将其传递给片段程序。

```hlsl

vertexProgram(){
    ...
    // 面片在世界空间中的坐标
    i.worldPos = mul(unity_ObjectToWorld, v.position);
    ...
}

FragmentProgram(i){
    ...
    float3 lightDir = _WorldSpaceLightPos0.xyz;
    // 根据相机位置和插值后的偏远位置计算出当前视线方向
    float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
    ...
}
```
可以简单通过```float3 reflectionDir = reflect(-lightDir, i.normal);```获得反射方向。

## Smoothness  平滑度

产生的高光大小取决于材质的粗糙度，光滑材质能更好地聚焦光线，因此高光区域较小

```hlsl
// Phong模型做法

return pow(
    DotClamped(viewDir, reflectionDir),
    _Smoothness * 100
);
```

## Blinn-Phong  布林-冯

采用光线方向与视线方向的中间向量， 法向量与半角向量的点积决定了镜面反射的贡献度

```hlsl
float3 halfVector = normalize(lightDir + viewDir);

return pow(
    DotClamped(halfVector, i.normal),
    _Smoothness * 100
);
```
## Specular Color  高光颜色

```hlsl
float3 halfVector = normalize(lightDir + viewDir);

// 将高光加入颜色中
float3 specular = lightColor * pow(
    DotClamped(halfVector, i.normal),
    _Smoothness * 100
);

return float4(diffuse + specular, 1);
```
高光本身需要依赖材质本身，因此还需要和材质配合采样

# 能量守恒

为了解决简单将漫反射和高光反射叠加造成过曝情况。 因此必须确保材质的漫反射和镜面反射部分总和不超过 1。

使用恒定的镜面色调，只需将反照率色调乘以(1-镜面值)即可调整

```hlsl
float3 albedo = tex2D(_MainTex, i.uv).rgb * _Tint.rgb;
albedo *= 1 - _SpecularTint.rgb;
```

当高光色调和漫反射色调不一致的时候，会显得很奇怪，因此可以采用单色能量守恒原则，也就是用高光中最强的分量来降低反照率
```hlsl
albedo *= 1 - max(_SpecularTint.r, max(_SpecularTint.g, _SpecularTint.b));
```

Unity提供了一个简单的方法
```
float oneMinusReflectivity;
albedo = EnergyConservationBetweenDiffuseAndSpecular(
    albedo, _SpecularTint.rgb, oneMinusReflectivity
);
```

## 材质工作流
高光工作流：使用强烈的镜面色调来创建金属材质，而通过使用微弱的单色镜面反射来创建电介质（非金属）材质。可控参数更多，适合美术倒腾

金属度工作流：由于金属没有漫反射率，我们可以用其颜色数据作为高光色调。而非金属本身就没有彩色高光，因此完全不需要单独的高光色调参数。 参数更少，只有颜色和金属度滑动条。需要通过反照率和金属度推到出高光色调。

```hlsl
// 计算高光数据 （金属度）
float3 specularTint = albedo * _Metallic;
// 计算反照率
float oneMinusReflectivity = 1 - _Metallic;

albedo *= oneMinusReflectivity;
```

Unity提供了DiffuseAndSpecularFromMetallic 来处理这一过程

# 基于物理的着色

Unity通过UnityPBSLighting 文件包含了对BRDF的调用
```hlsl
UnityLight light;
light.color = lightColor;
light.dir = lightDir;
light.ndotl = DotClamped(i.normal, lightDir);       // 漫反射项

return UNITY_BRDF_PBS(
    albedo, specularTint,
    oneMinusReflectivity, _Smoothness,
    i.normal, viewDir,
    light, indirectLight
);
```