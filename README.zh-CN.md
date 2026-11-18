# Feybrume

[English](README.md) · [Bahasa Indonesia](README.id.md)

Feybrume 为 Roblox 游戏提供可拖动的窗口。窗口可以停靠在屏幕边缘，包含多个标签页，隐藏后可通过浮动按钮重新打开。标签页可直接添加 Roblox GUI 对象。

## 运行示例

安装 [Rojo](https://rojo.space/)，然后在仓库根目录运行以下命令。

```sh
rojo build foundation-preview.project.json -o Feybrume.rbxlx
```

用 Roblox Studio 打开 `Feybrume.rbxlx`，按 **F5**。点击 **Record lap** 和 **Load hard preset**，再到 Guide 标签页检查开关是否同步。

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

[基础控件（英文）](docs/components.md) · [窗口指南](docs/zh-CN/window.md) · [主题](docs/zh-CN/design-system.md) · [文档](docs/zh-CN/index.md)

## 预览状态

**v0.4.0** 新增 18 种基础控件和标记绑定。窗口机制沿用已在 Android 上测试过的 v0.3.5。[控件测试记录](evidence/phase4-checks.json) · [Android 窗口测试](docs/qa-and-backlog.md#window-preview-checks)

## 本地检查

使用 [Luau CLI](https://github.com/luau-lang/luau/releases) 运行检查。

```sh
luau tests/core.luau
luau tests/theme.luau
luau tests/window.luau
luau tests/components.luau
luau-analyze src tests examples/foundation-preview.client.luau examples/window-preview.client.luau examples/reopen-logo.server.luau examples/theme-preview.client.luau
```

[更新日志](CHANGELOG.md) · [第四阶段构建记录](phase4-manifest.json)
