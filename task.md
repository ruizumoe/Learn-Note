## 客户端发展路线图

### 发展途径

- 代码熟练编写，能够阅读并分析问题，能够深入理解源码，能够profiler性能
- UI模块的需求开发，UI动效渲染的问题解决，UI逻辑框架的编写
- UI渲染框架

- gameplay 3c, camera, character, controller
- cinemachine 学习和拓展 cinemachine
- FBX模型设置，动画导入，skinmesh 的原理
- 动画状态机，GPUSkinmesh
- 技能/buff 这一套机制
- 开发工具，nodegraph, 数据序列化(odin)
- controller inputsystem, easytouch
- AI 寻路 navmesh, subgoal, astar, jps.
- AI 行为 behaviortree, Goal Oriented Action Planning。

- 物理引擎
- 场景管理
- 渲染管线

### Month1

#### 熟练使用lua, csharp 代码进行业务开发

- lua/c# 语法学习，Best Practice（最佳实践）
- lua/c# 数据结构学习。
- foundation 网络同步
- 能够使用 profiler, luaprofiler 进行性能查看和调优
- git / svn 的使用

- 业务开发。

#### w1 目标

1. lua 5.1.5 table 源码和库的学习。 

- lua代码中，table的使用， metatable 的使用. const 的实现，class 的实现。
- lua c ltable.c, ltablib.c 源码学习。 * 不做必选项

2. csharp 数据结构学习

- array，List, LinkList, Dictionary, Stack, Queue, HashSet 源码学习。
- 归类阐述, 理解底层存储机制。
- 分析性能问题。

3. svn, git 的使用， xlua 编译环境。


#### w3 目标
1. 研究一下 foundation slg 目前的网络同步相关知识点。创建单位的网络同步，系统里面的网络通信流程，自己试着写测试代码调通
2. xlua 和 unity 的研究。 xlua 的使用，如果导出c#代码到lua调用，以及如何在 c# 代码调用lua。 看一下框架原理的代码


#### w4 目标

1. 继续阅读xlua与CS相互调用的框架原理的代码
2. 熟悉AvatarSystem使用的网络同步方法
    1. 对RPC进行封装的原因，优势
    2. 编写测试用例，跑通world和avatar进程。
3. 熟悉unity性能分析方法与工具
    1. 分析工具每个模块的功能
    2. 分析性能的角度


#### w5 目标
1. 学习UI相关内容
  1. 熟悉UI Panel，Lua代码导出，服务端代码调用相关内容
  2. 编写代码测试跑通
2. 了解UGUI，同时和项目使用的FPUI进行对比
3. 了解FP动画相关内容

### Final

- 全面的客户端工程师
