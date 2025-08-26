# AO

为了实现遮挡效果，可以使用遮挡贴图，可以理解为该贴图是材质内定的固定阴影贴图。

从该贴图中采样的是光的衰弱系数，因此采样的结果要乘以实际的光照。但是由于阴影是间接光照随着遮挡而减弱，而直接光照应该不受影响。因此该遮挡系数需要不应该出现在直接光照中（除非美术强烈要求）。

> 非环境光ao采样
```hlsl
float occlusion = GetOcclusion(i);
indirectLight.diffuse *= occlusion;
indirectLight.specular *= occlusion;
```

> 屏幕空间环境遮蔽（SSAO）是一种后处理技术，其是利用深度缓冲区实时为整个帧生成遮挡图。因此是在已经完成渲染图以后再生成遮挡。这种阴影会同时作用于间接光和直接光。


# 遮罩细节

为了让物体增加细节，可以使用细节反照率贴图（Detail Albedo）和对应的法线贴图，为了让细节更丰富，可以用Tilling实现复杂平铺。比如 x:3 y:3，就可以让细节贴图在X轴上重复3次，Y轴同理。


但是这样会让贴图所有地方都显得充满细节。因此可以通过细节遮罩来剔除部分细节反照率贴图的内容。其数值 0 表示无细节，数值 1 表示完整细节。

因此采样后，可以作为lerp的参数，让贴图在普通反照率贴图和细节贴图的结合上做处理

```hlsl
float3 GetAlbedo (Interpolators i) {
	float3 albedo = tex2D(_MainTex, i.uv.xy).rgb * _Tint.rgb;
	float3 details = tex2D(_DetailTex, i.uv.zw) * unity_ColorSpaceDouble;
	albedo = lerp(albedo, albedo * details, GetDetailMask(i));
	return albedo;
}
```
同理法线也可以这么处理

# 更多关键字

当有多种不同贴图采样的时候，应该需要为不同的贴图采样开启不同的变体，增设更多关键字。

> 在SRP中，不是直接判断是否要根据关键字的启用进行采样，而且通过关键字定义一个输入变量，然后基于这个变量来确定是否要采样。


# 同时编辑多个材质

同时选中多个材质的时候，可以对使用同一个shader的材质进行编辑，但是如果要为其设置关键字，需要在对应的编辑器代码中设置遍历
```cs
void SetKeyword (string keyword, bool state) {
    if (state) {
        foreach (Material m in editor.targets) {
            m.EnableKeyword(keyword);
        }
    }
    else {
        foreach (Material m in editor.targets) {
            m.DisableKeyword(keyword);
        }
    }
}
```

但是如果两个材质有不同的纹理属性（比如某一个没有发现贴图）则需要在设置时还原到原本的内容

```cs
void DoNormals () {
    MaterialProperty map = FindProperty("_NormalMap");

    // 获得原本是否有贴图数据
    Texture tex = map.textureValue;
    EditorGUI.BeginChangeCheck();
    editor.TexturePropertySingleLine(
        MakeLabel(map), map,
        tex ? FindProperty("_BumpScale") : null
    );

    // 如果原本没有贴图，则设置对应的关键字
    if (EditorGUI.EndChangeCheck() && tex != map.textureValue) {
        SetKeyword("_NORMAL_MAP", map.textureValue);
    }
}
```




