# 混合光照

## 烘焙间接光

只烘焙间接光一个最大的优势在于能够让光源职责分离，比如在实现昼夜交替时，如果烘焙了中午的直接光，那么到晚上也会被采样到中午的直接光。但是如果只采样间接光，就可以实现以该间接光做基地，来动态调整不同时间天空盒对环境光的影响。

比如要实现昼夜循环，就可以通过
+ 创造一个中性、灰白色的基底天空盒 （只负责提供均匀的环境光亮度和光线反弹的基本能力）
+ 烘焙不带方向性的、间接光、使用中性天空盒的光照贴图和光照探针

通过以上步骤获得一个纯净的间接光能量分布图

+ 根据游戏时间更新天空盒信息，控制环境光照

天空盒可以通过4-6个关键天气天空盒，然后跟随游戏时间实时对天空盒进行插值。在C#中进行插值，或者在设置着色器的blend参数均可。


## 阴影遮罩

阴影遮罩用于将间接光照和混合光源的阴影衰减信息均存储在光照贴图中，便于获得静态阴影。

### 增加延迟光照模式支持

在前向光照中直接，Shader采样光照贴图的中的阴影衰减即可得到对应的间接阴影。但是对于延迟光照，需要增加一个G-buffer来获取对应的纹理

```glsl
FragmentOutput output;
#if defined(DEFERRED_PASS)
    ...
    output.gBuffer3 = color;

    #if defined(SHADOWS_SHADOWMASK) && (UNITY_ALLOWED_MRT_COUNT > 4)
        float2 shadowUV = 0;
			#if defined(LIGHTMAP_ON)
				shadowUV = i.lightmapUV;
			#endif
			output.gBuffer4 =
				UnityGetRawBakedOcclusions(shadowUV, i.worldPos.xyz);
    #endif
#else
    output.color = ApplyFog(color, i);
#endif
```
