# 镂空渲染

要让物体透明通常采用采样贴图的Alpha通道来处理。但是部分贴图不一定有alpha通道，因此需要通过关键字来处理分支情况。

而为了有一个默认条件，一般将alpha直接采样_Tint.a的内容，然后在需要的时候，乘以albebo的a通道。

## 剔除

对于渲染透明物体，可以使用clip函数，当函数参数为负数时，这个片元就不会被渲染。此时 GPU 不会混合其颜色，也不会写入深度缓冲区。

```hlsl
float alpha = GetAlpha(i);
clip(alpha - 0.5);
```

为了增加控制效果，可以增加一个特定的剔除阈值，alpha值低于这个阈值就需要被剔除

> 移动端GPU非常排斥clip函数，因此需要区分透明物体和不透明物体，不透明物体应该使用关键字屏蔽剔除函数的。

可以通过为自定义ShaderInspector增加物体类型枚举，来实现关键词添加


## 渲染队列

由于裁剪操作耗费资源，因此渲染镂空物体的渲染队列通常更大，不透明物体队列一般为2000，镂空队列一遍2450.

通过区分渲染队列，能保证在不透明物体后的镂空物体一定不会被渲染。

> 在TinyRender中，如果一个片元的深度比当前深度缓冲的数值更大，则根本不会让这个片元进入片元着色器。但是镂空剔除，是当前片元已经进入了片元着色器，所以也更耗

可以在着色器中，自己手动设置Pass的队列`"Queue" = "number"`或者`"Queue" = "Geometry+1"`

也可以直接在材质中修改渲染队列，Unity的`RenderingMode`中提供了渲染队列枚举，可以通过自定义材质编辑器，直接修改材质的renderQueue属性。

## 渲染类型标签 RenderType 

RenderType本身没有任何功能。它是一个提示，用于告知 Unity 该着色器的类型。替换着色器会利用这个标签来判断是否应该渲染物体。

替换着色器可以覆盖用于渲染对象的着色器。随后，你可以手动使用这些着色器来渲染场景。

# 半透明渲染 Fade

镂空是基于片段的，因此边缘会出现锯齿，且透明和不透明之间没有平滑过渡。因此需要新增新的类型来显示半透明。名称为Fade，Fade 模式自带渲染队列和渲染类型。队列编号为 3000，这是透明对象的默认设置。渲染类型为 Transparent 。

因此新增新的渲染类型，并增加新的关键字

> 半透明物体的渲染一般是通过Render.TransparentGeometry的方法执行，而透明和镂空物体是Render.OpaqueGeometry
> 
> 当场景同时存在两种物体是，优先使用OpaqueGeometry，在使用TransparentGeometry。保证半透明物体一定在不透明物体之后渲染。

## 混合片段

为了实现不透明效果，需要让片元最后的颜色的alpha通道使用采样后的alpha值。而实际的混合效果取决于alpha值。

> 当 alpha 值为 1 时，表示渲染的是完全不透明物体。这种情况下，基础通道应使用 Blend One Zero ，加法通道应使用 Blend One One ，这与常规操作一致。但当 alpha 值为 0 时，渲染的是完全透明物体，此时不应进行任何修改。这种情况下两个通道都应采用 Blend Zero One 混合模式。若 alpha 值为¼，则需要类似 Blend 0.25 0.75 和 Blend 0.25 One 的混合方式。

为了实现以上效果，需要结果的alpha 叠加上 OneMinusSrcAlpha 

因此基础通道的shader需要使用`Blend [_SrcBlend] [_DstBlend]`

此时可以在Material编辑器中去配置srcBlend 和dstBlend ，然后为material配置对应的字段
```cs
m.SetInt("_SrcBlend", (int)settings.srcBlend);
m.SetInt("_DstBlend", (int)settings.dstBlend);
```

## 深度控制

Unity渲染不透明物体，一般是从前往后，这样能减少渲染内容。但是渲染透明物体，需要从后往前。这样才能保证颜色正确混合。

Untiy会自动帮我们判断物体的先后顺序，但是这个先后顺序判断是基于物体的中心点，但这种判断是不可靠的

+ 当两个物体的中心点很近，在每一帧刷新的过程中，当视角发生变化时，绘制顺序可能会突然翻转
+ 一个物体更大，但是中心点远，一个物体小，但是中心点近，但是恰好大物体的外边缘覆盖了小物体，逻辑上应该先渲染小物体，在混合大物体。但是Unity让大物体的的颜色去混合小物体。因此出现错误
+ 渲染透明物体的通道错误使用了深度写入

![第1种错误和第3种错误的结合](<chap11 Transparency/image.png>)

出现上述问题的原因是，因为两个物体的中心接近，因此出现了绘制顺序的错误：
1. 由于排序错误，Unity认为右侧的图形中心较远，因此先进行了绘制，此时写入了图形的深度
2. 绘制左侧的图形时，该图片部分元素的深度可能远于右侧图片，因此不会被渲染。

为了解决以上问题，

+ 在渲染不透明物体是，一般需要人手动传入排序好的物体
+ 把渲染不透明物体的通道使用参数化的形式进行定义

```shader
// pass代码
ZWrite [_ZWrite]
```

```cs
// 自定义着色器代码
m.SetInt("_ZWrite", settings.zWrite ? 1 : 0);
```

# 淡出与透明度  

Fade模式会会让几何体的颜色都随着alpha值逐渐淡化（漫反射和镜面反射），但是比如玻璃等物体，虽然内容透明，但是有明显高光和反射，其使用的的是Transparent模式

该模式的混合模式为
srcBlend = BlendMode.One,  原颜色 * 1
dstBlend = BlendMode.OneMinusSrcAlpha,  （目标颜色 * （1-源alpha)

要使透明度生效，就需要对漫反射使用 albedo *= alpha , 该方法也被称为预乘alpha混合，因此在混合前就乘以了alpha值、

对于玻璃来说，其本身能够看到后方内容，就说明光线透过物体，但是其又有反射效果。但是为了能量守恒，就需要将两种光线进行混合。 无论物体本身透明度如何，其反射性越强，能穿透的光线就越少。

对于物体来说，如果表面无反射，则alpha保持不变；如果完全反射，则alpha应该为1。因此公式应该为 $1 - (1-a)(1-r)$ 其中原始 alpha 值为 a 反射率为 r。 

由于（1-r）可以用oneMinusReflectivity 替代，化解可得$1 - R + aR$

```hlsl
#if defined(_RENDERING_TRANSPARENT)
    albedo *= alpha;
    alpha = 1 - oneMinusReflectivity + alpha * oneMinusReflectivity;
#endif
```

