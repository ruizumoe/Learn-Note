# 静态光照

## 光照贴图

光照贴图是为了降低实时光照的消耗，其会把光照数据存放到贴图中。该贴图只会存放漫反射光照的信息，且只有物体被标记为静态物体，才能被光照贴图烘焙。

光照贴图是包含了直接光照和间接光照的数据

> 灯光不用被标记为静态

+ 直接光照：光第一次打到物体表面上并返回给摄像机的光线
+ 间接光照：光第一次打到其他物体上，然后再打到目标物体上，最后返回给摄像机的光线


> 光照贴图的结果比使用实时照明时要暗一些。这是因为缺少了镜面反射光照，只有漫反射光照。镜面反射光照依赖于视角，因此与摄像机的位置有关。通常情况下，摄像机是移动的，所以无法将其包含在光照贴图中。这一限制意味着光照贴图适用于柔和的光线和暗淡的表面，但不适用于强烈的直射光或闪亮的表面。如果你需要镜面反射光照，就必须使用实时灯光。因此，最终往往会结合使用烘焙光和实时光。


### 技术组件

而全局GI就是模拟光线在场景中多次反弹的技术。其核心组成为

├─ Enlighten（实时GI）

├─ Progressive（烘焙GI）

├─ Path Tracer（影视级）

└─ DXR Ray Tracing（硬件加速）

### 数组构成

全局GI数据存储

├─ 光照贴图（静态物体）

├─ 光照探针（动态物体）

├─ 反射探针（镜面反射）

└─ 光照体积（3D GI）

### 片元的颜色构成

![片元颜色构成](<chap16 Static Lighting/image.png>)

#### 基础数据

1. 表面颜色(Albedo、Diffuse)
```glsl
// 从纹理采样基础颜色
vec4 albedo = texture2D(_MainTex, uv) * _Color;

// 金属工作流中的基础色
vec3 baseColor = texture2D(_BaseColorMap, uv).rgb;
```
2. 法线信息

```glsl
// 从法线贴图获取切线空间法线
vec3 normalTS = UnpackNormal(texture2D(_BumpMap, uv));

vec3 normalWS = TransformTangentToWorld(normalTS, tangent, bitangent, normal);
```

3. 表面特性 (粗糙度、光滑度、AO)

```glsl
// 粗糙度/光滑度
float roughness = texture2D(_RoughnessMap, uv).r * _Roughness;

// 金属度
float metallic = texture2D(_MetallicMap, uv).r * _Metallic;

// 环境遮蔽
float ao = texture2D(_OcclusionMap, uv).r;

```

#### 直接光照贡献

直接光的贡献主要直接光的漫反射和直接光的镜面反射

```glsl

// 漫反射颜色主要来源于  直接光和法线的cos值 对反照率和光线颜色的作用之
vec3 lightDir = normalize(_WorldSpaceLightPos0.xyz);
float NdotL = max(dot(normalWS, lightDir), 0.0);
vec3 diffuse = NdotL * _LightColor0.rgb * albedo.rgb;


// 镜面反射的颜色主要来源于 法线，视野方向以及光线 对直接光的作用
vec3 viewDir = normalize(_WorldSpaceCameraPos - worldPos);
vec3 halfVec = normalize(lightDir + viewDir);
float D = DistributionGGX(normalWS, halfVec, roughness);
float G = GeometrySmith(normalWS, viewDir, lightDir, roughness);
vec3 F = FresnelSchlick(max(dot(halfVec, viewDir), 0.0), F0);
vec3 specular = (D * G * F) / (4.0 * max(dot(normalWS, viewDir), 0.0) * max(dot(normalWS, lightDir), 0.0) + 0.001);
specular *= _LightColor0.rgb * NdotL;
```

#### 间接光照贡献

间接光的主要由漫反射的全局光照和镜面反射的全局光照组成


```glsl
// 漫反射全局光照 主要通过采样光照贴图或者光照探针获得

// 从光照贴图采样
vec3 bakedGI = texture2D(unity_Lightmap, lightmapUV).rgb * unity_Lightmap_HDR.rgb;

// 或从光照探针采样
vec3 shGI = ShadeSH9(float4(normalWS, 1.0));


// 镜面反射的全局光照，一般从反射探针采样

// 反射探针采样
vec3 reflectionDir = reflect(-viewDir, normalWS);
vec3 specularGI = textureCubeLod(_GlossyEnvironmentCube, reflectionDir, roughness * 8.0).rgb;
```

#### 自发光效果

自发光效果一般是自发光贴图中采样得到， 在HDR中，由于光照强度较大，可能会影响周围元素，通常被归类到镜面全局光照

```glsl
// 基础自发光
vec3 emission = _EmissionColor.rgb * texture2D(_EmissionMap, uv).rgb;

// 自发光应用HDR
emission *= _EmissionIntensity;

// 在PBR中影响周围环境
specularGI += emission * _EmissionInfluence;
```

#### 环境光贡献

包括环境光和环境反射

```glsl
// 环境光
vec3 ambient = unity_AmbientSky.rgb * albedo.rgb;

// 环境反射
vec3 envReflection = textureCube(_Skybox, reflectionDir).rgb;
```
#### 最终合成公式

最终颜色中 直接光会受到阴影影响，间接受环境遮蔽和本身材质、反射、折射等影响。 最后加上自发光和环境光

```glsl
vec3 color = vec3(0.0);

// 直接光照贡献
color += (diffuse + specular) * shadow;

// 间接光照贡献
vec3 indirectDiffuse = bakedGI * albedo.rgb * ao;
vec3 indirectSpecular = specularGI * F * ao;

// 能量守恒（金属工作流）
vec3 kS = F; // 反射部分
vec3 kD = (vec3(1.0) - kS) * (1.0 - metallic); // 折射部分

color += kD * indirectDiffuse + indirectSpecular;

// 自发光
color += emission;

// 环境基础
color += ambient * ao;
```
#### 后处理

泛光，雾效、调色等后处理效果是基于最终的渲染图执行的，虽然也会影响颜色。但是着色器传入的内容不是世界空间下的顶点，而且当前渲染图的顶点。


#### 注意

```glsl
vec3 bakedGI = texture2D(unity_Lightmap, lightmapUV).rgb * unity_Lightmap_HDR.rgb;
```
这段代码被称为漫反射全局光照，说是间接光照贡献。但实际上包含了**直接光照和间接光照**。在Unity中，其通过在RGB通道存放漫反射值，A通道存放直接光照值来存储相关信息。还有ShadowMask来存放直接光照阴影信息，来记录表面是否被静态物体遮挡。

在着色阶段计算试试光的时候，为了避免双重光照。如果一个静态物体被标记为Baked或者Mixed，这时需要Shader从光照贴图的Alpha通道或的ShadowMask中采样值，来削弱实时计算的直接光照。

如果一个静态物体被完全烘焙（Baked），并且处于完全被烘焙光源照亮的区域，那么从光照贴图 Alpha 通道采样的值可能是 1（表示该点已被直接光照完全照亮），而从 Shadowmask 采样的遮挡值可能是 0（表示被静态物体完全遮挡）。这时，着色器会对实时直接光照的贡献乘以 0，从而完全“排除”了实时直接光照的影响，只留下光照贴图中烘焙的间接光（RGB通道）和直接光（Alpha通道提供的强度信息）的合成结果。


最终颜色 = (实时直接光 * Shadowmask衰减) + 光照贴图中的烘焙间接光 + 自发光 + ...


> 如果关闭静态物体的接受阴影选项，那么很有可能出现双重光照问题。


### 光照贴图模式

光照贴图有两种模式`Enlighten`和`Progressive`

+ `Enlighten`是实时全局光照，其烘焙速度快，但是质量一般，Unity早期使用的
+ `Progressive`是高质量烘焙光照，烘焙速度慢，但是质量更高

现行更加`Progressive`，其使用Path Tracing方法去渲染光源。

它的原理是模拟无数条光线从摄像机出发，在场景中随机反弹，最后回溯到光源的过程。通过统计这些光线的路径来计算出每个点的颜色和亮度。

“渐进（Progressive）”意味着它从一张充满噪点的图开始，然后持续发射更多光线样本，逐渐消除噪点，使图像变得越来越清晰、平滑。


## 自定义光照贴图

自定义Shader采样光照贴图时，需要把UV信息作为顶点着色器参数（或者Unity自己的参数`GI_ATTRIBUTE_DATA`）
传入着色器，记录参数用于片元着色器插值。然后在片段着色器中采样贴图。

在片元着色器中，动态物体和静态物体采样光照贴图的代码都是统一的。Unity其实是将静态物体和动态物体分为不同的渲染批次中进行渲染，这样在采样动态物体光照贴图的时候，Unity不会传入有效的光照贴图数据

```glsl

v2f vert (appdata v) {
    o.uv2 = v.texcoord1.xy * unity_LightmapST.xy + unity_LightmapST.zw; // 计算光照贴图UV！
    // 实际值是 o.uv2 = v.texcoord1.xy * (0,0) + (0,0) = (0,0) 
    return o;
}
```

采样光照贴图的时候，该光照贴图实际上是一个1*1的纯白色贴图，这样采样的光照不会影响其他光照信息。

```glsl
fixed4 frag (v2f i) : SV_Target {
    
    // 采样光照贴图（如果有的话）
    fixed4 bakedColor = tex2D(unity_Lightmap, i.uv2);
    return col;
}
```


### 半透明静态物体阴影

静态物体是透明物体时，不能通过采样光照贴图的alpha值来获取光源，实际要通过一个单独的颜色属性，来得到对应物体的alpha值。


## 元通道

元通道是专门为光照贴图烘焙服务的一个特殊通道。是为了帮助 Unity 的光照贴图器（如 Progressive 或 Enlighten）计算出物体表面之间精确的间接光照（全局光照）。

元通道主要提供“ albedo（漫反射） 和 自发光（Emission）” 信息。


其主要是防止双重烘焙的错误，Meta Pass 通过只输出原始的、未经光照的 albedo 和 emission。

元通道（Meta Pass）的顶点着色器输入的确实是静态物体的顶点数据。但更精确的说法是：它处理的是那些参与了光照烘焙（Lightmapping）** 的物体的顶点数据。

元通道不会再游戏运行时执行，其只会在编辑器上点击“Generate Lighting” （或 “Bake”）按钮时被执行。点击按钮时，光照贴图器会模拟光线在场景中的反弹。

在烘焙过程中，Unity 的光照贴图器（Lightmapper）会遍历场景中所有被标记为 Contribute GI （贡献全局光照）的静态物体。对于这些物体的每一个渲染器（Renderer），光照贴图器都会“召唤”其材质上所挂载的 Shader，并专门执行其中的 LightMode="Meta" 的 Pass。

注意元通道绘制出来的不是光照贴图，而是光照贴图的原材料。


+ 准备阶段 (烘焙开始)：你点击“Generate Lighting”。

+ 数据收集 (元通道的工作)：光照贴图器遍历所有静态物体。对每个物体，它执行其Shader中的Meta Pass。Meta Pass输出该物体表面每个点的原始Albedo和Emission数据。这个输出是一份临时的、中间的数据，不会被保存为一张最终的纹理。

+ 计算阶段 (光照贴图器的工作)：光照贴图器拿到整个场景所有表面的Albedo和Emission数据后，开始核心计算。它模拟数以亿计的光线从光源发出，撞击到物体表面（表面颜色来自Meta Pass提供的Albedo），然后反射到其他表面，再次反弹……这个庞大的物理模拟过程最终会计算出每个表面接收到的间接光的总能量。

+ 输出阶段：光照贴图器将第3步计算出的间接光照结果（也就是光能分布信息）打包、压缩，并存储到一张或多张纹理中——这才是最终生成的光照贴图。

#### 自定义元通道

在自定义光照贴图Shder中，如果发现静态物体之间没有颜色混合，很可能就是没添加默认元通道，或者没有自己写元通道，导致贴光照贴图的反照贴图和自发光没有被其他物体接收。

一般来说Unity自带元通道的方法

```glsl
// 这两个pragma是预定义好的，包含了标准的Meta Pass顶点和片元着色器逻辑
#include "UnityStandardMeta.cginc" 

// 如果需要重写元通道，就在下方自己写
float4 frag_meta (v2f_meta i): SV_Target{
    FragmentCommonData data = UNITY_SETUP_BRDF_INPUT (i.uv);
    UnityMetaInput o;
    ...
    // 采样albebo和emission和其他数据存放到 o变量中

    return UnityMetaFragment(o);    
}

```

## 定向光照贴图

光照贴图仅考虑几何体的顶点数据，不会考虑法线贴图，当光照贴图的分辨率较低时，也无法捕捉法线贴图提供的细节。

因此将Lighting Setting中的光照setting设置Directional (方向性)配合烘焙光照使用，形成定向光照贴图，其会生成两张贴图。
+ 光照强度贴图
+ 方向性贴图

通过采样方向性贴图，并进行处理，就可以让静态物体也有法线纹理。

方向性光照贴图（Directional Lightmaps）通过保留主要的入射光方向信息，让法线贴图能够基于这个方向信息进行正确的光照计算，从而恢复表面细节的明暗变化。

唯一缺点是，需要内存存两张贴图



## 光照探针

光照贴图只适用于静态物体，如果需要在动态物体上使用预计算的光照，就需要使用光照探针，其会把光照信息存储在一个球谐函数中，然后通过插值让物体进行采样获得。

在Bake光照的时候，会同时进行光照贴图和光照探针信息的生成。

默认情况下，一个动态物体的所有三角形都会使用同一组（通常是最近的一组）探针数据，这会导致您描述的“一个明亮一个较暗”的光照不匹配问题。而解决方案就是使用“光照探针代理体积（Light Probe Proxy Volume, LPPV）”。

默认情况下Untiy是通过渲染器边界框的中心点来找探针组，因此找到的探针是物体内部，光照平均的组。而球谐函数的结果也会应用到物体的所有面片上。

为了解决不同面片用同一个探针组的问题，可以使用**光照探针代理体积 (LPPV)**

LPPV是个包裹住整个大型物体的、隐形的、内部充满微型探针的盒子，在渲染阶段，会找这个顶点最近的8个微型探针，然后基于这些探针来进行插值。

因此LPPV性能消耗很大，一般在物体体积巨大；物体会跨越明显的光照边界：才使用LPPV
