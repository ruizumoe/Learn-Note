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

# 半透明渲染

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



