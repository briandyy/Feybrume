# Feybrume

[English](README.md) · [Bahasa Indonesia](README.id.md) · [简体中文](README.zh-CN.md)

面向 Roblox 体验的 Luau 界面框架，支持自定义样式，优先考虑触屏操作。

当前源码包含运行时核心和主题引擎，提供 40 套预设、分层样式覆盖、对比度控制、Roblox 原生字体回退和减少动态效果设置。Studio 示例可在一个控件上预览主题。窗口与布局引擎将在后续阶段实现。

## 试用

- [在 Roblox Studio 中安装运行时核心](docs/zh-CN/core.md)
- [运行主题预览或创建主题](docs/zh-CN/design-system.md)
- [查看文档目录](docs/zh-CN/index.md)

安装 [Luau CLI](https://github.com/luau-lang/luau/releases)，然后在仓库根目录运行以下命令。

```sh
luau tests/core.luau
luau tests/theme.luau
luau-analyze src tests examples
```

[更新日志](CHANGELOG.md) · [测试记录](evidence/phase2-checks.json)
