# Feybrume

[English](README.md) · [Bahasa Indonesia](README.id.md)

Feybrume 为 Roblox 游戏提供可拖动的窗口。窗口可以停靠在屏幕边缘，包含多个标签页，隐藏后可通过浮动按钮重新打开。标签页可直接添加 Roblox GUI 对象。

## 运行示例

安装 [Rojo](https://rojo.space/)，然后在仓库根目录运行以下命令。

```sh
rojo build window-preview.project.json -o Feybrume.rbxlx
```

用 Roblox Studio 打开 `Feybrume.rbxlx`，按 **F5**。试试停靠窗口、打开弹出面板，或在 Device Emulator 中选择手机布局。

## 在自己的游戏中使用

通过 Rojo 将 `Feybrume` 模块同步到 `ReplicatedStorage`。把下面的示例放入 `StarterPlayerScripts` 下的 `LocalScript`。[安装指南](docs/zh-CN/core.md)

```luau
local Fey = require(game:GetService("ReplicatedStorage"):WaitForChild("Feybrume"))

local window = Fey:Window({ id = "tools", title = "Game tools", theme = "cosmic" })
local home = window:Tab({ id = "home", title = "Home" })

local label = Instance.new("TextLabel")
label.Size = UDim2.new(1, 0, 0, 40)
label.Text = "准备就绪"
home:Add(label)
```

[窗口指南](docs/zh-CN/window.md) · [主题](docs/zh-CN/design-system.md) · [文档](docs/zh-CN/index.md)

## 预览状态

`main` 分支的源码构建 **v0.3.4**。项目维护者在 Android 上单独测试了 Roblox 中的 **v0.3.5** 预览，确认浮动按钮可到达屏幕左右边缘、避开跳跃按钮，并显示 CDN 示例图片。下一阶段将添加基础控件及状态绑定。[设备测试记录](docs/qa-and-backlog.md#window-preview-checks)

## 本地检查

使用 [Luau CLI](https://github.com/luau-lang/luau/releases) 运行检查。

```sh
luau tests/core.luau
luau tests/theme.luau
luau tests/window.luau
luau-analyze src tests examples
```

[更新日志](CHANGELOG.md) · [第三阶段构建记录](phase3-manifest.json)
