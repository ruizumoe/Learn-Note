# 视差

由于透视的原因，当我们调整观察视角时，所看到的事物的相对位置会发生变化。这种视觉现象被称为视差。近处的事物显得很大且快速移动，而远处的背景则显得较小且移动较慢。

用法线贴图能让表面获得一个相对简单的凹凸效果，但是近距离查看，其本质上还是一个平坦表面的视差。而加强发现效果，反正会让光照显得不自然。

要获得真实的深度感，需要高度图。借助高度图，我们就能像伪造坡度那样伪造视差效果。高度图，采用灰度表示，黑色代表最低点，白色代表最高点。


## 定义着色器

在偏远着色器中，传入当前像素内容， 基于该像素的数据来采样高度图信息


### 沿视线方向偏移
视差是由透视投影引起的，这与观察者相对位置有关。因此我们必须基于这个原理来偏移纹理坐标。

要获得偏移，还需要知道切线空间中的视角方向，我们可以在顶点程序中创建一个从对象空间到切线空间的变换矩阵。

```glsl
InterpolatorsVertex MyVertexProgram (VertexData v) {
    #if defined (_PARALLAX_MAP)
        float3x3 objectToTangent = float3x3(
            v.tangent.xyz,
            cross(v.normal, v.tangent.xyz) * v.tangent.w,
            v.normal
        );
        i.tangentViewDir = mul(objectToTangent, ObjSpaceViewDir(v.vertex));
    #endif
}

void ApplyParallax (inout Interpolators i) {
	#if defined(_PARALLAX_MAP)
		i.tangentViewDir = normalize(i.tangentViewDir);
		i.uv.xy += i.tangentViewDir.xy * _ParallaxStrength;
	#endif
}

```

### 基于高度的滑动

此时需要采样高度图来作为表面UV的偏移数据量，且为了保证低洼地区和高地区的分离，需要手动增加一个阈值
```glsl

void ApplyParallax (inout Interpolators i) {

    // 1. 原始视角向量（在切线空间中）
    i.tangentViewDir = normalize(i.tangentViewDir);

    // 2. 从高度贴图获取高度并调整
    float height = tex2D(_ParallaxMap, i.uv.xy).g;

    height -= 0.5;  // 从[0,1]转到[-0.5,0.5]
    height *= _ParallaxStrength;   // 应用强度缩放


    i.uv.xy += i.tangentViewDir.xy * height;
}

```

## 正确的投影偏移量

上述使用的视差映射技术被称为带偏移限制的视差映射。我们仅使用观察方向的 XY 分量，其最大长度为 1，因此纹理偏移受到限制。这种方法能产生不错的效果，但并不能代表正确的透视投影。

高度偏移本质上是描述表面在切线空间的法线方向（Z轴）上的凹凸。但是纹理的偏移只能发生在表面平面内（XY轴 UV方向的偏移）。

因此需要使用视角向量的XY分量计算UV偏移。

// 视觉化解释：
// tangentViewDir.xy - 视角在表面平面内的分量
// tangentViewDir.z - 视角与表面法线的夹角程度

而用xy / z表示精细透视矫正，确保偏移量与视角和表面之间的角度成正确比例。

根据相似三角形原理

$$
 \frac{offset.x}  {viewDirTS.x} = \frac{height}  {viewDirTS.z}
$$

所以正确的偏移量应该是

$$
    offset.x = \frac{viewDirTS.x}  {viewDirTS.z} * height
$$

![Alt text](<chap20 Parallax/image.png>)

因此正确的视角方向应该除以z轴方向

```glsl
i.tangentViewDir = normalize(i.tangentViewDir);
i.tangentViewDir.xy /= (i.tangentViewDir.z + 0.42);     // 增加偏移值来缓解浅视角下的伪影
```


# 光线步进

问题： 
1. 之前的方法假设表面是完全平坦的，但实际上高度贴图描述的是复杂的三维表面。当表面有较大的高度变化时，这种线性近似就会失效。

2. 自遮挡：当视角比较倾斜时，较高的凸起可能会"遮挡"后面的区域，但直接偏移法无法正确处理这种遮挡关系

3. 边缘失真： 深度变化的边缘区域，直接偏移会导致纹理拉伸或压缩失真

4. 采样点不正确：直接偏移找到的点不一定是视线与表面的真正交点：


因此使用光线追踪（Raymarching）方法能够能够用更精确方法找到实际交点，来计算偏移。

光线步进需要沿着视线以小步长移动，每次采样高度场，直至触及表面。


光线步进中，都是从高度场为1的地方出发，向视线方向步进。每一步高度下降 1 / 步进次数，直到完成n次步进或当前步进位置高度小于当前位置采样高度场的高度。

但是随着步进次数增加，会消耗性能；步进次数减少可能穿过某一个高度。因此有一些可以提高质量的方法


## 层间插值

层间插值是在找到交点所在的大致区间后，在两个采样层之间进行数学插值，从而获得亚像素级的精确交点位置。

核心步骤

1. 粗略的步进查找，直到找到交点可能存在的区间

2. 在粗略找到的前后两个区间中寻找上一个点没有碰撞，下一个点碰撞的的情况

3. 用碰撞点P1和即将碰撞点P2连线，然后与P1的采样点P1'和P2的采样点P2'的连线相交，找出交点。以交点做目标点。（两直线相交方程求出对应的t）


## 层间搜索

层间搜索是一种优化策略，用于快速定位视线与高度场的交点所在的大致深度区间，避免对每个深度层都进行精细采样。

核心步骤

1. 粗略的通过线性查找找到有交点的一个区间
2. 使用二分查找从两端逐渐向交点逼近






