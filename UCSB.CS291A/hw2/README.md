# GAMES202 homework0

## 作业完成内容

+ [ √ ]基础内容：Light、Transport预计算；预计算数据使用
+ [ √ ]Bonus1：Diffuse inter-reflection
+ [ √ ]Bonus2：SH旋转

## Bonus1 - Diffuse inter-reflection实现

在prt.cpp中的preprocess函数的`if (m_Type == Type::Interreflection)`分支中实现了inter-reflection的transport预计算，具体实现方法请参照源码及注释

## Bonus2 - SH旋转实现

实现了作业框架tool.js里的getRotationPrecomputeL、computeSquareMatrix_3by3、computeSquareMatrix_5by5函数，具体实现方法请参照源码和注释。

## 结果说明

截取images文件夹下的展示图的时候，运行条件和作业文档中展示图的条件不完全相同，此处特别说明：

+ 在预计算Transport Vector时考虑了BRDF项(否则能量不守恒，inter-reflection结果会出错)；albedo为1.0，即足够多次bounce后结果和unshadowed很接近
+ prt预计算的nori程序有小bug，详见[此处](http://games-cn.org/forums/topic/zuoye2guanyuprt-cppyuanchengxutupianzairuduiyingguanxi/)；所有Light Vector的预计算都是在修正bug后进行的。
+ 渲染时进行了gamma校正(2.2)
