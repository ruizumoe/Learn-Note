# 反射

明确概念：

在图像学中的直接光照和间接光照不同，在图形学中

1. 直接光照是指光线直接从光源​（如Directional Light, Point Light, Spot Light）发出，​未经任何反射或反弹，直接照射到物体表面的光照。

2. 指光线从光源发出后，​经过一次或多次物体表面的反射，最终才照射到另一个物体表面的光照。它是“被反弹的光”。

图形学直接光照，其实在物理学中属于反射了。

通常直接间接光照由于消耗性能高，通常使用预计算的（通过光照烘焙），或者通过Light Probe和Reflection Probe来近似模拟。

因此菲涅尔反射是一种间接光照，其是光源的光打到外界环境，然后再反射到物体表面。因此间接光照也不受光源阴影的影响。而物体的金属度越高，表面越光滑，菲涅尔反射效应越强烈。

 > 在SRP中，我们在BRDF项中计算出菲涅尔反射的强度
 ```hlsl

 brdf.fresnel = saturate(surface.smoothness + 1.0 - oneMinusReflectivity);       // 表面光滑度与反射率相加（上限为 1）来获得最终颜色
 
 ```

> 然后将环境光相关光源进行综合计算，得到当前片元实际的环境光照RGB
> 
```hlsl
// 获得高光全局光照
float3 IndirectBRDF(Surface surfaceWS, BRDF brdf, float3 diffuse, float3 specular)
{
    // diffuse来自于对环境贴图和光照探针的采样
    float fresnelStrength = surfaceWS.fresnelStrength * Pow4(1. - saturate(dot(surfaceWS.normal, surfaceWS.viewDirection)));
    float3 reflection = specular * lerp(brdf.specular, brdf.fresnel, fresnelStrength);
    reflection /= brdf.roughness * brdf.roughness + 1;  // 用粗糙度来减少反射效果，但用平方来削弱减少比例 + 1来保证非0    
    return (diffuse * brdf.diffuse + reflection) * surfaceWS.occlusion;     // 环境光只作用于漫反射，因此在此数理
}
```
```hlsl
GI GetGI(float2 lightMapUV, Surface surfaceWS, BRDF brdf)
{
    GI gi;
    gi.diffuse = SampleLightmap(lightMapUV) + SampleLightProbe(surfaceWS);
    ...
}

```


## 采集环境光照

采集环境光照需要根据视线方向和法线来进行采样，才能得到根据采样获得跟随视野的环境光照

在SRP中
```hlsl
float3 uvw = reflect(-surfaceWS.viewDirection, surfaceWS.normal);

```

## 采集反射探针

1. 反射探针通过渲染立方体贴图来捕捉环境，且只捕捉静态几何体的内容。

2. 通常反射探针的类型为Baked模式，但是也可以自己设定为Realtime模式，需要自己控制什么频率进行更新。

3. 实时探针在编辑模式下不会更新，而烘焙探针会在其自身或静态几何体被编辑时更新。

4. 反射探针如果渲染完成后，选用Reflection Probe Static 。则可以保持原本渲染的内容，此时修改外部静态物体也不会更新探针内容。

5. 反射模糊可以通过使用不同程度的mipmap去实现。

```hlsl
float3 SampleEnvironment(Surface surfaceWS, BRDF brdf)
{
    ...
    float mip = PerceptualRoughnessToMipmapLevel(brdf.perceptualRoughness);         // 计算细节等级（LOD），根据表面粗糙度确定采样的细节等级
}

```
> 粗糙度和mipmap通常不是线性的，Unity5的公式是 `roughness *= 1.7 - 0.7 * roughness;`


## 盒式反射探针

当只有一个球形反射探针的时候，所有反射物体都会采样单个反射探针的内容。但实际上由于物体位置不同，应该采样不同环境贴图。此时就需要使用盒状反射探针。

要对盒状反射探针进行采样，需要通过物体射线与反射盒进行AABB求交，找到反射方向。该反射方向的不再是那个指向无限远的原始反射向量 direction，而是一个新的向量。这个新向量的起点是探针中心 cubemapPosition，终点是上面计算出的边界盒交点。

> 渲染章节的代码
```hlsl
float3 BoxProjection (
	float3 direction, float3 position,
	float3 cubemapPosition, float3 boxMin, float3 boxMax
) {
    // 获得position点，沿着反射方向，到包围盒每一个包围面的距离系数t   position + t * dir = targetPos
	float3 factors = ((direction > 0 ? boxMax : boxMin) - position) / direction;
    // 找出最快到的的平面的factor
	float scalar = min(min(factors.x, factors.y), factors.z);

    // 化简后本质上是 在平面上的targetPost - cubemapPoition, 也就是反射探针中心到射线与包围盒的交点
	return direction * scalar + (position - cubemapPosition);
}
```

## 混合反射探针
当有多个盒型反射探针时，就需要编写代码对两个探测框进行混合，且保证探测框有重叠


## 多次反射
一般情况下Unity不会再环境贴图中包含反射，但是，可以对光照设置进行更改，Environment Settings 部分包含 Reflection Bounces 滑块，默认设置为 1。我们将其改为 任意值。该值最大为5。

通过该方法，可以让两个反射探针互相反射。


## 更多的反射实现

除了使用反射探针，还有其他方法可以实现反射功能。

1. 从虚拟观察者的视角渲染场景，并将其用作镜面纹理

2. 镜像场景几何体

3. 屏幕空间反射技术（需要延迟渲染）