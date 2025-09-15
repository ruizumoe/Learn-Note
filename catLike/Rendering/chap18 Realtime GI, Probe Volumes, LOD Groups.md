# 实时全局光照

早期Unity采用Enlighten模式来支持实时全局光照，目前已经被正式弃用。现代实时GI的核心思路已经从“预计算”转向了“屏幕空间”和“硬件光追”。

首选方案是 屏幕空间技术 (Screen Space)

针对屏幕可见像素，通过深度和法线纹理来估算光线在屏幕场景中的反弹。

优势：
+ 性能好，无需预计算
+ 在不支持硬件光追的平台上也能运行。
+ 对于大多数游戏场景，它能提供足够逼真的漫反射反弹和光泽反射效果。

缺点：

+ 屏幕空间限制：只能处理屏幕内看到的信息。如果光线来源或反弹目标不在屏幕内，就无法计算，导致效果出错（例如，镜头对着地面时，天空的颜色无法贡献GI）。

+ 可能存在噪点和瑕疵。


终极解决方案是 硬件光线追踪 (Hardware Ray Tracing)

直接使用GPU的专用硬件（RT Core）发射物理准确的光线，模拟光线在场景中的反弹。这是效果最逼真、最“正确”的实时GI技术。

优点是逼真，确定也是消耗大。在Unity中必须在HDRP管线中使用。


使用混合方案是 实用混合方案：烘焙GI + 实时直接光

使用Baked Indirect模式烘焙高质量的静态间接光，同时保留实时光源的直接光照和实时阴影。

优点：

+ 性能极高：运行时GI计算开销几乎为零。

+ 效果高质量：烘焙的间接光质量可以非常高（因为可以长时间计算）。

+ 支持动态光影：直接光可以是动态的（如昼夜循环），静态间接光作为基底，两者结合效果很好。

缺点：

+ 不是真正的“全动态”。场景的几何结构（如墙壁位置）不能变，否则需要重新烘焙。

+ 动态物体与静态间接光的交互需要依靠光照探针（Light Probes） 和 LPPV，配置稍复杂。

# 光照探针组

具体内容请看 chap16 光照探针内容

# LOD Group

## LOD切换原理

在Unity中，LOD实际使用的是物体在屏幕上所占的相对大小（基于物体包围盒的屏幕空间高度）而非绝对距离。

原理伪代码
```cs
void Update()
    {
        // 计算当前屏幕相对高度
        screenRelativeHeight = CalculateScreenRelativeHeight();
        
        // 确定当前LOD级别
        currentLODLevel = lodGroup.GetCurrentLOD();
    }
    
    float CalculateScreenRelativeHeight()
    {
        if (targetCamera == null || lodGroup == null)
            return 0;
            
        // 获取LOD组的边界框
        Bounds bounds = lodGroup.GetWorldSpaceBounds();
        
        // 计算边界框在屏幕空间中的大小
        Vector3 center = bounds.center;
        Vector3 top = center + Vector3.up * bounds.extents.y;
        
        Vector3 screenCenter = targetCamera.WorldToViewportPoint(center);
        Vector3 screenTop = targetCamera.WorldToViewportPoint(top);
        
        // 计算屏幕相对高度
        return Mathf.Abs(screenTop.y - screenCenter.y) * 2;
    }
```

## LOD Group存放内容
LOD Group 切换的不是 SubMesh，而是整个 Renderer 组件（如 MeshRenderer 或 SkinnedMeshRenderer）。

在项目中，有一个逻辑外壳，该外壳用于存放各个Mono脚本。然后下层是一个统一管理整个渲染模型的父类，父类包括Lod的go和用于存放挂点的内容，每个Lod一个渲染模型(Mesh Render)。

+ 逻辑外壳
    + 渲染模型父类（存放lod Group）
        + lod1 （存放 meshRender）
        + lod2 （存放 meshRender）
        + lod3 （存放 meshRender）
        + 挂点A 
        + 挂点xxxxx

## LOD实现切换过渡动画

### 切换材质透明度

在CS代码中，为材质设置透明度, 实现在切换LOD时用协程淡入和淡出实现平滑过渡。

协程执行的时候，获得根据已经执行过的时间，每帧这是不同的透明度，实现淡入淡出

初始状态要设置一个默认的LOD强制开启显示。

```cs
void Update()
{
    int newLODLevel = lodGroup.GetCurrentLOD();
    
    if (newLODLevel != currentLODLevel && !isTransitioning)
    {
        targetLODLevel = newLODLevel;
        StartCoroutine(TransitionLODs(currentLODLevel, targetLODLevel));
    }
}

IEnumerator TransitionLODs(int fromLOD, int toLOD)
{
    isTransitioning = true;
    float elapsedTime = 0f;
    
    // 启用目标LOD（初始透明度为0）
    EnableLOD(toLOD, 0f);
    
    while (elapsedTime < transitionTime)
    {
        elapsedTime += Time.deltaTime;
        float t = elapsedTime / transitionTime;
        
        // 淡出旧LOD
        if (fromLOD >= 0 && fromLOD < lods.Length)
        {
            SetLODAlpha(fromLOD, 1f - t);
        }
        
        // 淡入新LOD
        if (toLOD >= 0 && toLOD < lods.Length)
        {
            SetLODAlpha(toLOD, t);
        }
        
        yield return null;
    }
    
    // 完成过渡后禁用旧LOD
    if (fromLOD >= 0 && fromLOD < lods.Length)
    {
        DisableLOD(fromLOD);
    }
    
    // 确保新LOD完全不透明
    SetLODAlpha(toLOD, 1f);
    
    currentLODLevel = toLOD;
    isTransitioning = false;
}

void SetLODAlpha(int lodLevel, float alpha)
{
    if (lodLevel < 0 || lodLevel >= lods.Length) return;
    
    foreach (Renderer renderer in lods[lodLevel].renderers)
    {
        if (renderer != null && renderer.enabled)
        {
            SetRendererAlpha(renderer, alpha);
        }
    }
}

void SetRendererAlpha(Renderer renderer, float alpha)
{
    Material[] mats = renderer.materials;
    for (int i = 0; i < mats.Length; i++)
    {
        Color color = mats[i].color;
        color.a = alpha;
        mats[i].color = color;
    }
}





```


### 用Shader做溶解效果

在原本淡入淡出的基础上，增加溶解Shader, 然后在`SetRendererAlpha`函数中，调用设置alpha的时候，设置溶解alpha的值

```cs
// 修改SetRendererAlpha方法以支持溶解效果
void SetRendererAlpha(Renderer renderer, float alpha)
{
    Material[] mats = renderer.materials;
    for (int i = 0; i < mats.Length; i++)
    {
        if (useDissolveEffect)
        {
            // 使用溶解效果
            mats[i].SetFloat("_DissolveAmount", alpha);
            mats[i].SetTexture("_DissolveTex", dissolveTexture);
            mats[i].SetColor("_DissolveColor", dissolveColor);
            mats[i].SetFloat("_EdgeWidth", dissolveEdgeWidth);
        }
        else
        {
            // 使用透明度效果
            Color color = mats[i].color;
            color.a = alpha;
            mats[i].color = color;
        }
    }
}
```

### srp处理方案

在SRP项目中，处理LOD淡入淡出是通过开启Fade Mode的*Cross Fade*方式结合自定义Shader实现的。

开启该模式以后，可以定义一个`LOD_FADE_CROSSFADE`变体，在片元着色器中，如果开启了该变体，就执行自定义的Clip方法。从而裁剪原来的模型。


```glsl
void ClipLOD (float2 positionCS, float fade) {
	#if defined(LOD_FADE_CROSSFADE)
		float dither = (positionCS.y % 32) / 32;;
		clip(fade - dither);
	#endif
}

void ShadowCasterPassFragment (Varyings input) {
	UNITY_SETUP_INSTANCE_ID(input);
	ClipLOD(input.positionCS.xy, unity_LODFade.x);

	…
}

float4 LitPassFragment (Varyings input) : SV_TARGET {
	UNITY_SETUP_INSTANCE_ID(input);
	ClipLOD(input.positionCS.xy, unity_LODFade.x);
	…
}

```


