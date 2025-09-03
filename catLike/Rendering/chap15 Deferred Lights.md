# 延迟光照

之前的章节只有非直接光，该节将自己来实现不同光源的延迟渲染光照通道

## 自定义延迟光照着色器 

在光照通道中，顶点着色器处理的顶点不是场景中的原始几何顶点，而是专门为光照计算设计的代理几何体（Proxy Geometry）的顶点。（光照体积几何体）

有三种代理几何体

+ 全屏四边形 (方向光（Directional Light）、环境光)
```hlsl
struct appdata {
    float4 vertex : POSITION;  // 通常是 [-1,1] 的NDC坐标
    float2 uv : TEXCOORD0;     // 全屏UV (0,0)到(1,1)
};
```
顶点着色的任务就是直接输出裁剪空间位置，以及传递uv

+ 光源体积几何体（Light Volume）​

```hlsl
struct appdata {
    float3 vertex : POSITION;  // 光源体积的局部坐标
};
```
来源： 点光源（球体）、聚光灯（椎体）、区域光（自定义图形、矩形）

​顶点着色器任务​：
1. 将参数中的光源顶点转化到世界空间 o.worldPos
2. 在将对应的世界空间数据转化到裁剪空间 o.pos

+ 平铺网格
    + ​用于Tile-Based延迟渲染​（如Unity的TBDR）
    + ​顶点结构​：将屏幕分割为N×N的瓦片网格
    + 顶点着色器​：计算瓦片ID和边界


### 两次渲染

使用自定义的延迟光照着色器需要有两个Pass, 当 HDR 被禁用时，光线数据是以对数方式编码的。需要最后一遍渲染来反转这种编码。这就是第二遍渲染的目的。

第二个通道就是需要将第一个通道的结果，采样后重新解码

```hlsl
float4 FragmentProgram (Interpolators i) : SV_Target {
    return -log2(tex2D(_LightBuffer, i.uv));
}
```
## 定向光源

在光照通道中，定向光源通常会使用一个覆盖屏幕的四边形来模拟

为了为图像添加光照，必须确保不擦除已渲染的内容。为此，我们可以通过更改混合模式， `Blend One One`

为了呈现实时光照，应用BRDF，需要获得物体本身的材质属性，物体信息，和对应位置的光照信息（法线，光照信息）。材质属性和光照信息可以通过UV去采样G-Buffer数据。物体信息需要通过从相机发射的光线进行计算。


### 采样G-buffer UV坐标

由于定向光源着色器输入是一个屏幕大小的四边形，因此其只会输入四个顶点信息。如果要进行绘制，需要手动增加uv字段，进行插值计算。
```hlsl
struct Interpolators {
	float4 pos : SV_POSITION;
	float4 uv : TEXCOORD0;
};

Interpolators VertexProgram (VertexData v) {
	Interpolators i;
	i.pos = UnityObjectToClipPos(v.vertex);     // 将插值出的顶点转化到裁剪空间
	i.uv = ComputeScreenPos(i.pos);         // 将裁剪空间数据，转化为屏幕空间坐标（此时不是标准屏幕空间uv 0-1)
	return i;
}

float4 FragmentProgram (Interpolators i) : SV_Target {
	float2 uv = i.uv.xy / i.uv.w;           // 透视除法得到真实UV
	return 0;
}
```

### 获得世界坐标

如果要获得世界坐标，方法和延迟雾效类似：从摄像机发射射线穿过每个片段抵达远平面，再根据片段的深度值进行缩放。

在定向光源中，每个顶点是一个平面，且就是相机平面，因此顶点着色器的输入增加normal，其本身就是平面的方向。

```hlsl
struct VertexData {
    ...
	float3 normal : NORMAL;
};

struct Interpolators {
    ...
    float3 ray : TEXCOORD1;
};

Interpolators VertexProgram (VertexData v) {
    ...
	i.ray = v.normal;
	return i;
}
```

采样相机深度纹理中，每个uv的深度，然后乘以每个片元的光线的方向，就可以获得每个片元物体的实际深度。


#### 重建视图空间位置
由于i.ray是没有归一化的向量，_ProjectionParams.z（farClipPlane）为远平面距离，此时 i.ray / i.ray.z 得到一个归一化的方向向量。x和y向量表现屏幕比例关系。 乘以farClipPlane得到实际在在远裁剪屏幕上的空间位置**方向**。

乘以深度，得到这个光线到达片元的实际光线数据。最后将这个从相机视角的位置转化到世界空间位置。

```hlsl
float4 FragmentProgram (Interpolators i) : SV_Target {
    ...
    float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv);
	depth = Linear01Depth(depth);
    float3 rayToFarPlane = i.ray * _ProjectionParams.z / i.ray.z;
    float3 viewPos = rayToFarPlane * depth;     // 获得顶点距离相机
    float3 worldPos = mul(unity_CameraToWorld, float4(viewPos, 1)).xyz;     //将相机位置转化为屏幕位置
}
```
### 读取G-buffer内容, 计算光照

G-buffer中存储片元对应物体的数据，可以直接通过对这些G-buffer使用UV采样获得需要的反照率、高光色调、平滑度和法线信息。获得这些信息后，就可以计算BRDF所需要的内容

```hlsl
UnityLight CreateLight () {
	UnityLight light;
	light.dir = -_LightDir;
	light.color = _LightColor.rgb;
	return light;
}

float4 FragmentProgram (Interpolators i) : SV_Target {
    ...
    float3 worldPos = mul(unity_CameraToWorld, float4(viewPos, 1)).xyz;
    float3 viewDir = normalize(_WorldSpaceCameraPos - worldPos);

    // 材质属性
    float3 albedo = tex2D(_CameraGBufferTexture0, uv).rgb;
	float3 specularTint = tex2D(_CameraGBufferTexture1, uv).rgb;
	float3 smoothness = tex2D(_CameraGBufferTexture1, uv).a;
	float3 normal = tex2D(_CameraGBufferTexture2, uv).rgb * 2 - 1;
    float oneMinusReflectivity = 1 - SpecularStrength(specularTint);

    // 光照信息
    UnityLight light = CreateLight();;
    UnityIndirect indirectLight;
	indirectLight.diffuse = 0;
	indirectLight.specular = 0;


    float4 color = UNITY_BRDF_PBS(
    	albedo, specularTint, oneMinusReflectivity, smoothness,
    	normal, viewDir, light, indirectLight
    );
    return color;
}
```

### 阴影

通过采样阴影贴图的内容，可以获得阴影的衰减程度。然后乘以光源得到的color即可。

```hlsl
UnityLight CreateLight (float2 uv) {
    float shadowAttenuation = tex2D(_ShadowMapTexture, uv).r;
	light.color = _LightColor.rgb * shadowAttenuation;
}
```

#### 阴影距离，渐隐

由于阴影贴图分辨率优先，因此Unity设置了最大阴影显示距离，超过这个距离就不显示实时阴影。当前的阴影着色器会让阴影突然消失，因此需要进行修改。

修改的核心点在于，在计算阴影衰减度时，举要根据片元的实际世界坐标，和当前视角的深度来获得最后的阴影衰减量

```hlsl
// 
// viewZ 通常是从摄像机到该点的距离
UnityLight CreateLight (float2 uv, float3 worldPos, float viewZ) {
    ...
    shadowAttenuation = tex2D(_ShadowMapTexture, uv).r;

    // 结合了阴影距离（Shadow Distance）的设置（在Unity的Quality Settings中配置）和当前像素的距离信息,
    // 返回当前像素距离阴影淡出区域的距离
    float shadowFadeDistance =
			UnityComputeShadowFadeDistance(worldPos, viewZ);

    // 传入的距离值计算阴影的淡入淡出因子
    float shadowFade = UnityComputeShadowFade(shadowFadeDistance);


    // 最简单的处理淡化因子的方法，好一点使用lerp
    shadowAttenuation = saturate(shadowAttenuation + shadowFade);
    ...
}

```

### 光照遮罩

光照遮罩存储在对应的光照纹理中，需要通过矩阵将世界坐标转换为光照空间坐标，然后利用这个坐标采样遮光纹理。

当投影区域在屏幕上覆盖较小时（如远处投影）Unity 的自动 Mipmap 选择会使用高层级 Mipmap​（低分辨率）导致投影边缘模糊失真。要解决问题，需要对采样的光照遮罩应用偏移量。


```hlsl
UnityLight CreateLight (float2 uv, float3 worldPos, float viewZ)
    float attenuation = 1;
	float shadowAttenuation = 1;
	
	#if defined(DIRECTIONAL_COOKIE)
		float2 uvCookie = mul(unity_WorldToLight, float4(worldPos, 1)).xy;
        // 应用偏移，采样光照遮罩 采样参数的z = 0表示使用默认自动选择的 Mipmap 层级， -8为使用最大负偏移 → ​强制锁定 Mip0， 该方法会让边缘更加锐利
		attenuation *= tex2Dbias(_LightTexture0, float4(uvCookie, 0, -8)).w;
	#endif

    ...

    // 
    light.color = _LightColor.rgb * (attenuation * shadowAttenuation);
}
```

### 支持LDR

LDR 色彩必须与光照缓冲区相乘而非相加，但是会影响HDR, 因此要使用Blend [_SrcBlend] [_DstBlend]。然后再使用HDR的情况下转化颜色。

## 聚光灯

聚光灯的光照体积是一个锥形形状，为了支持聚光灯，需要在创建光源时，进行分类，且将阴影相关代码提取出来

非定向光源具有位置属性，该属性通过 _LightPos 提供。

Unity 通过 _LightAsQuad 变量告知我们当前处理的光源几何体还是四边形




```hlsl
float4 _LightColor, _LightDir, _LightPos;
float _LightAsQuad;     // 是否是四边形


Interpolators VertexProgram (VertexData v) {
    // 由于不同光源的法线不同，需要进行处理
    i.ray = lerp(
		UnityObjectToViewPos(v.vertex) * float3(-1, -1, 1),
		v.normal,
		_LightAsQuad
	);
}


UnityLight CreateLight (float2 uv, float3 worldPos, float viewZ)
    #else
		float3 lightVec = _LightPos.xyz - worldPos;
		light.dir = normalize(lightVec);

        // 获得光源遮罩
        float4 uvCookie = mul(unity_WorldToLight, float4(worldPos, 1));
        // 然而，聚光灯的 cookie 会随着距离光源位置越远而变得越大。这是通过透视变换实现的，得到合适的2D位置，需要将 X 和 Y 除以 W
		uvCookie.xy /= uvCookie.w;
		attenuation *= tex2Dbias(_LightTexture0, float4(uvCookie.xy, 0, -8)).w;
        // 保证聚光灯的方向始终向着负方向
        // bool值被隐式转化为了true 1; false 0;
        attenuation *= uvCookie.w < 0; ()

	#endif
}

```
#### 聚光灯衰减

聚光灯的阴影衰减同样使用采样阴影贴图的方式实现。


## 点光源

点光源虽然是一个球体，但点光源使用与聚光灯相同的光向量、方向和距离衰减。因此它们可以共享该代码。其余聚光灯代码仅在定义了 SPOT 关键字时使用。

### 点光源阴影

点光源阴影存放在一个立方体贴图中，因此采样的判断需要改变
#if defined(SHADOWS_CUBE)
    shadowed = true;
    shadowAttenuation = UnitySampleShadowmap(-lightVec);
#endif

### 点光源遮罩

点光源的遮罩同样在一个立方体贴图下，因此需要淡出采样


## 优化

超出阴影渐变距离的片段将不会被阴影覆盖。然而，我们仍在采样它们的阴影，这可能非常耗费资源。

可以在阴影Fade因子超过阈值1后就跳过不再采样后续阴影


> UNITY_FAST_COHERENT_DYNAMIC_BRANCHING
> + 确保同一线程组内所有线程执行相同分支路径
> + 优先执行更可能发生的分支

```hlsl
// 将不同的分支分类处理，提升判断，并保证只有在使用软阴影的时候使用
#if defined(UNITY_FAST_COHERENT_DYNAMIC_BRANCHING) && defined(SHADOWS_SOFT)
    UNITY_BRANCH
    if (shadowFade > 0.99) {
        shadowAttenuation = 1;
    }
#endif
```
