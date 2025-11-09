# 高度层级
## 设置每个单元格海拔高度

为了让网格能够正确拿到单元格信息，因此所有单元格信息都是存放在`HexCell`类中的，此时要保存海报高度，那么该信息也存放在此处。而每个高度实际的大小，存放在一个静态常量HexMetrics中。

为了编辑方便，设置一个UI Slider，ui值改变每个cell的高度和颜色，每次改变的时候同时重新绘制网格，让高度作为网格参数传入即可。

```cs
// HexCell.cs
public int Elevation
{
    get => elevation;
    set
    {
        elevation = value;
        Vector3 position = transform.localPosition;
        position.y = value * HexMetrics.elevationStep;
        transform.localPosition = position;
        
        // 设置ui高度
        Vector3 uiPosition = uiRect.localPosition;
        uiPosition.z = value * -HexMetrics.elevationStep;
        uiRect.localPosition = uiPosition;
        
    }
}

public float RealElevation => Elevation * HexMetrics.elevationStep;
```

```cs
// HexMapEditor.cs
private void HandleInput()
{
    Ray inputRay = Camera.main.ScreenPointToRay(Input.mousePosition);
    RaycastHit hit;
    if (Physics.Raycast(inputRay, out hit))
    {
        EditCell(hexGrid.GetCell(hit.point));
    }
}

void EditCell(HexCell cell)
{
    cell.color = activeColor;
    cell.Elevation = activeElevation;
    hexGrid.Refresh();
}
```

## 制作最简单的海拔高度

在上一章节中，由于我们将网格的链接分为了三个模块——桥接矩形和两个大三角形，此时由于单元格的高度产生了变化，那么要让网格正常链接，就需要让这几个链接网格的y值与具体链接的网格一致。

### 桥接矩形修改

桥接矩形最简单，由于网格分为自己部分v1,v2以及链接部分 v3和v4。

那么实际就只需要让v1和v2的y值为当前cell高度。 v3和v4的高度为邻居网格的高度

```cs
v3.y = v4.y = neighbor.Elevation * HexMetrics.elevationStep;
```
### 链接三角形修改

在上一章节中，链接三角形实际上中需要处理当前cell ne和e方向右侧的三角形，而这些三角形有个特点就是三个点分别是来源于自己、邻居、顺时针的下一个邻居。因此直接获取对应的高度即可。

```cs
if (direction <= HexDirection.E && nextNeighbor != null) {
    Vector3 v5 = v2 + HexMetrics.GetBridge(direction.Next());
    v5.y = nextNeighbor.Elevation * HexMetrics.elevationStep;
    AddTriangle(v2, v4, v5);
    AddTriangleColor(cell.color, neighbor.color, nextNeighbor.color);
}
```
## 制作阶梯斜坡

### 阶梯面片高度和长度数值的Lerp

只制作普通斜坡在观感上不行，因此某些游戏的做法是做成阶梯式的。此时就需要通过配置设置这些阶梯式的斜坡相关信息，其包含：
1. 梯田（每一层水平面）的数量 n
2. 斜坡和平面构成水平步长 2n + 1

通过这两个基础信息就可以通过lerp来获得实际每个节点的距离。

```cs
// HexMetrics.cs

public const int terracesPerSlope = 2;      // 每个山坡梯田的数量
public const int terraceSteps = terracesPerSlope * 2 + 1;  // 一个在纵向上被分为多少个块，比如terracesPerSlope为2时，就是三个斜坡，两个平坡
public const float horizontalTerraceStepSize = 1f / terraceSteps;       // 每个平面阶梯的步长
public const float verticalTerraceStepSize = 1f / (terracesPerSlope + 1);

// 梯田每一阶梯的平面方向距离插值
public static Vector3 TerraceLerp(Vector3 a, Vector3 b, float step)
{
    // 当前阶梯 的平面距离的步长总合
    float h = step * horizontalTerraceStepSize;
    a.x += (b.x - a.x) * h;
    a.z += (b.z - a.z) * h;


    float v = (int)((step + 1) / 2) * HexMetrics.verticalTerraceStepSize;
    a.y += (b.y - a.y) * v;
    return a;
}

// 颜色进行插值
public static Color TerraceLerp (Color a, Color b, float step)
{
    float h = step * HexMetrics.horizontalTerraceStepSize;
    return Color.Lerp(a, b, h);
}
#endregion
```

### 阶梯片面绘制

绘制阶梯面片要分成三部（可以优化，但此处暂时根据教程流程来）
1. 绘制第一个台阶（定义出第一个台阶的V3和V4变量）
2. 循环绘制中间斜坡和最后一个平面的面片
3. 绘制最后一个平面面片到邻居的的斜面面片

```cs
// HexMesh.cs
// 对每一个梯田斜坡进行插值
void TriangulateEdgeTerraces(
    Vector3 beginLeft, Vector3 beginRight, HexCell beginCell,
    Vector3 endLeft, Vector3 endRight, HexCell endCell)
{
    Vector3 v3 = HexMetrics.TerraceLerp(beginLeft, endLeft, 1);
    Vector3 v4 = HexMetrics.TerraceLerp(beginRight, endRight, 1);
    Color c2 = HexMetrics.TerraceLerp(beginCell.color, endCell.color, 1);
    AddQuad(beginLeft, beginRight, v3, v4);
    AddQuadColor(beginCell.color, c2);

    for (int i = 2; i < HexMetrics.terraceSteps; i++)
    {
        Vector3 v1 = v3;
        Vector3 v2 = v4;
        Color c1 = c2;
        
        v3 = HexMetrics.TerraceLerp(beginLeft, endLeft, i);
        v4 = HexMetrics.TerraceLerp(beginRight, endRight, i);
        c2 = HexMetrics.TerraceLerp(beginCell.color, endCell.color, i);
        AddQuad(v1, v2, v3, v4);
        AddQuadColor(c1, c2);
    }
    
    AddQuad(v3, v4, endLeft, endRight);
    AddQuadColor(c2, endCell.color);
}
```

