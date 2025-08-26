# 制作自定义材质检视窗口

## 定义监视窗口

通过继承ShaderGUI，就能定义一个专门用于特定shader材质的检视窗口，然后再Shader中使用CustomEditor来让Shader知道GUI的存在

```hlsl
// 定义Editor
public class MyLightingShaderGUI : ShaderGUI {
    public override void OnGUI (
		MaterialEditor editor, MaterialProperty[] properties
	) {
        ...
	}

}

// Shader代码
Shader "Custom/My First Lighting Shader" {
	…
	
    // 如果有命名空间，需要用方括号内的方法去包括命名空间
	CustomEditor "[MyNamespace.]MyLightingShaderGUI"
}

```

在OnGUI中，
+ MaterialEditor editor定义了一个引用，该引用指向了我们需要的检查窗口。
+ MaterialProperty[] properties 定义了包含该材质属性的窗口，其属性为 Shader 在 ​Properties Block​ 中定义的所有属性, properties = ​Shader 定义的属性结构​ + ​Material 存储的属性数值

> 编辑器使用的是Unity旧版的UI系统，即时模式 UI ，其基础是GUI类。必须要通过矩形来定位每个元素，GUILayout 类提供相同的功能，同时使用简单的布局系统自动定位控件。

> + onGui在编辑模式下是靠事件驱动来改变的，比如Repain事件，和用于与UI交互的行为。只有游戏模式下，才会每一帧都刷新。
> + MaterialEditor 一般来说不会随意变更，但是当你在Project窗口切换不同材质时，其会调用OnGUI方法，并从MaterialEditor的缓存池中拿一个新的实例来进行绘制。如果你只是改动检视窗口的内容，只会调用OnGui方法重绘，但是其参数MaterialEditor还是当前的实例。

> properties中顺序索引取决于着色器中属性的定义顺序，但是为了方便，一般通过`FindProperty("_MainTex", properties);`进行查找


# 金属和非金属外观混合

如果想实现金属和非金属外观分离，除了在配置主贴图的情况下，还需要配置额外的贴图，用于专门区分金属和非金属，如生成一张金属图贴图，其是一张灰度图，金属值较高，非金属为0。

使用金属贴图最好使用Shader变体`#pragma multi_compile`或`#pragma shader_feature`，这样能保证在没有金属贴图的时候，也能正确获得内容。然后在有金属度贴图的时候，启动对应关键字

```csharp
// target是对应material
void SetKeyword (string keyword, bool state) {
    if (state) {
        target.EnableKeyword(keyword);
    }
    else {
        target.DisableKeyword(keyword);
    }
}

void xxx(){
    ...
    SetKeyword("_METALLIC_MAP", map.textureValue);
}

```
+ `#pragma multi_compile`会在编译时就排列组合所有可能的变体情况。会在Build的时候就打入包体内部。因此会占用空间。

+ `#pragma shader_feature`只会在构建的时候检查该变体是否被构建的场景内的物体所持有，如果没有引用对应的变体，则构建时会把对应变体剔除。

> 每个变体本质上都是一份独立的、完整的着色器代码副本。Unity的构建剔除过程就是移除那些未被任何材质实际使用的、独立的副本。
> 很多游戏开始时的编译着色器，是因为其把构建出来的Shader数据变成了一个中间语言，让后让PC自己根据平台去编译成对应的机器码, 因为PC有足够的预算效率去实现JIT，其实现过程为
> + 收集所有被Build的场景中所需要的变体
> + 根据收集到变体，对这些源码或者中间代码进行编译
> + 将已编译的代码存放在系统对应的着色器缓存（Shader Cache）​​，以便后续添加

> 但是移动端不允许JIT，因此就必须使用其他方式编译，Unity提供的是ShaderVariantCollection，其相当于给Unity提供了一个变体剔除白名单。即使构建的场景中不存在该变体，也不要被剔除。需要用户手动去添加

> 也就是说主包会包括所有可能会被使用的变体，而使用这些变体的材质，可能在不同的AB包里。
> 目前项目的主流方法是，所有Shader变体代码，也打一个依赖包，然后每次如果有新增变体，就重新打包。然后热更新出去。[Unity中Shader是否可以热更新的测试](https://www.cnblogs.com/cpxnet/p/6439706.html)


每次保证不会每次OnGUI的是都都设置关键词，可以通过以下代码来减少变更
```cs
void DoMetallic () {
		MaterialProperty map = FindProperty("_MetallicMap");
		EditorGUI.BeginChangeCheck();
		if (EditorGUI.EndChangeCheck()) {
			SetKeyword("_METALLIC_MAP", map.textureValue);
		}
	}

```

# 各类贴图

## 反照率贴图（albedo）

这也是通常所说的主贴图（"_MainTex"）

## 法线贴图

用于记录法线信息的忒图

## 金属贴图

记录物体的金属度贴图，一般是一个灰度图片，一般使用了金属度贴图以后，就需要关闭金属度的滑块，因此需要关键词分类

```cs
void DoMetallic () {
    MaterialProperty map = FindProperty("_MetallicMap");
    EditorGUI.BeginChangeCheck();
    editor.TexturePropertySingleLine(
        MakeLabel(map, "Metallic (R)"), map,
        map.textureValue ? null : FindProperty("_Metallic")
    );
    if (EditorGUI.EndChangeCheck()) {
        SetKeyword("_METALLIC_MAP", map.textureValue);
    }
}

```


## 光滑度贴图

光滑度也可以通过贴图来定义

金属度和光滑度贴图通常被合并到同一张纹理中,着色器会一次性采样所有内容，虽然金属度仅需 R 通道，但我仍将 RGB 通道都填充了金属度数值，平滑度则使用了 Alpha 通道

> 采样实例
```hlsl
float GetSmoothness (Interpolators i) {
	#if defined(_METALLIC_MAP)
		return tex2D(_MetallicMap, i.uv.xy).a;
	#else
		return _Smoothness;
	#endif
}
```

## 自发光贴图

自发光贴图发射的光来自于本体，因此一般是获得漫反射颜色后，再叠加上自发光颜色。
