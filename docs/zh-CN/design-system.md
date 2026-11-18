# 主题与样式解析

[English](../design-system.md) · [Bahasa Indonesia](../id/design-system.md) · [简体中文](design-system.md)

[主题目录](../../design/themes.json) 包含 40 套预设，每套提供调色板、控件状态颜色、圆角、桌面与触屏间距、字体角色、装饰渐变及动效配置。四套代表主题分别是带古金色边线的 Cultivation 仙、纸张风格的 Memoir 忆、以深红色为强调色的 Noir，以及从紫色过渡至青绿色的 Cosmic ✦。纹理与星空等装饰仍在规划中。

## 在 Studio 试用

按[安装指南](core.md)配置模块。将[主题预览示例](../../examples/theme-preview.client.luau)放入 StarterPlayerScripts 下的 LocalScript，进入 Play 模式。点击 **Next theme** 循环切换 40 套预设，检查颜色、圆角、字体和渐变。用设备模拟器测试 320×568 的屏幕与横屏，确认按钮始终可触达。开启减少动态效果后，渐变角度应直接切换。0.2.0 版的 Studio 照片显示 40 套主题均可切换。0.2.1 版单独绘制 Cosmic 图标，将标题和正文顶部对齐，并将 Garamond 换为 Bodoni。修复版的视觉效果和真机输入仍待验证。

## 创建派生主题

```luau
local Fey = require(game:GetService("ReplicatedStorage"):WaitForChild("Feybrume"))
local themes = Fey.Theme.new({ initial = "noir" })
assert(themes:Register({
    id = "plum",
    name = "Plum",
    inherits = "noir",
    palette = { accent = "#B274D8" },
}).ok)
assert(themes:Set("plum").ok)

local style = Fey.StyleResolver.Resolve(themes:Get(), {
    input = "touch",
    states = { selected = true, focused = true },
    overrides = { component = { variant = "outline", size = "S" } },
    accessibility = { fontScale = 1.2, reducedMotion = "system" },
})
assert(style.ok)
print(style.value.foreground, style.value.minHeight)
themes:Destroy()
```

`Derive` 返回可直接使用的派生主题。用 `Register` 注册新 ID。主题切换时，`Subscribe` 会收到变更的字段和颜色标记。可通过 `tokens` 覆盖自动计算的颜色。

覆盖顺序依次为框架、窗口、容器、控件和状态。焦点独立于主状态。触屏下忽略悬停，内置预设的触控目标至少为 48×48。普通文本按给定的纯色底层计算 4.5:1 的对比度。关闭 `autoContrast` 后，系统保留指定颜色并报告警告。图片或渐变上的文字需要另外验证。

`Typography:Resolve` 按用户指定字体、主题字体和 Roblox 回退字体的顺序尝试。预览会尝试测量短文本，失败时回退到下一个字体。测量成功仍需验证完整的字形覆盖。通过 `reducedMotion = "always"` 始终减少动效，或用 `"system"` 跟随系统设置。

[完整参数参考（英文）](../design-system.md) · [测试记录](../../evidence/phase2-checks.json)
