# 窗口与工作区

[English](../window.md) · [Bahasa Indonesia](../id/window.md) · [简体中文](window.md)

一个工作区可以容纳多个 Roblox 窗口。每个窗口分别保留当前标签页、位置、大小与主题。标签页支持 Roblox 原生 GUI。分区包含六类插槽，网格按面板宽度调整列数。

## 在 Studio 中试用

1. 打开第三阶段的预览文件，然后按 **F5**。[安装指南](core.md) · [预览脚本](../../examples/window-preview.client.luau)
2. 拖动标题移动窗口，用右下角的 **Resize** 调整大小。在靠近屏幕左、右或上边缘时松开以停靠窗口。点击 **Floating layout** 恢复浮动布局。
3. 打开 **Preferences**，点击 **Hide**，再按 **UI** 浮动按钮。窗口应回到原标签页。按钮 **2** 用于打开第二个窗口。
4. 在 **Home** 点击 **Open sheet**，打开和关闭嵌套面板。滚动到输入框，检查软键盘出现后 **Done** 按钮是否仍可触达。
5. 在设备模拟器中测试竖屏与横屏。窄屏下标签移到底部，屏幕高度较小时可通过 **Tabs** 打开。

在 **Help** 标签页可右键点击或长按标题来打开菜单，也可以点击 **Open actions**。**Preferences** 中的 **Move reopen bubble** 可切换浮动按钮的位置。

Luau CLI 已测试布局计算、手势识别与焦点恢复规则。仍需在 Studio 和真机中验证实际交互。[完整 API（英文）](../window.md) · [测试记录](../../evidence/phase3-checks.json)
