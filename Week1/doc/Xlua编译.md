# Xlua编译

## 安装编译环境
安装Visual studio, 最主要的是选中“使用C++桌面开发”来安装所需环境
![Alt text](Xlua编译IMG\image.png)

## 安装Cmake
Cmake是一个跨平台编译工具，下载对应版本以后，进行安装
![Alt text](Xlua编译IMG\image-0.png)


注意需要将安装好后的内容加入环境变量
![Alt text](Xlua编译IMG\image-1.png)


检测CMake是否安装成功
![Alt text](Xlua编译IMG\image-2.png)

## Xlua编译

从Xlua的GitHub中下载Xlua项目，重点是编译其中的build文件夹

将项目源码Clone下来后，找到Build文件夹，修改批处理文件的内容
需要保证使用的Visual Studio的版本与当前版本一致

![Alt text](Xlua编译IMG\image-3.png)

## 编译
完成上述步骤后即可双击.bat文件开始编译。

得到以下文件则表示编译完成
![Alt text](Xlua编译IMG\image-4.png)

> 每次编译都需要将带有build前缀的文件夹删除
![Alt text](Xlua编译IMG\image-5.png)

> [xlua参考资料](http://ggblog.site/2021/09/07/cktgycevx001mtowbgv1tboie/#%E7%BC%96%E8%AF%91)