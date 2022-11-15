# Denoise

## 完成的部分

- 全部基本内容
- 提高项：a-trous加速large filter

## 提高项涉及的代码部分

Denoiser::Filter函数内，根据变量m_useAtrous来判断是否启用atrous方法加速。

详细代码见if (m_useAtrous)代码块。

## 结果说明

全部结果视频均为开启了atrous方法加速后的结果。