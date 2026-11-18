# 窗口与工作区

[English](../window.md) · [Bahasa Indonesia](../id/window.md) · [简体中文](window.md)

一个工作区可以容纳多个 Roblox 窗口。每个窗口分别保留当前标签页、位置、大小与主题。标签页支持 Roblox 原生 GUI。分区包含六类插槽，网格按面板宽度调整列数。

## 在 Studio 中试用

1. 打开第三阶段的预览文件，然后按 **F5**。[安装指南](core.md) · [预览脚本](../../examples/window-preview.client.luau)
2. 拖动标题移动窗口，用右下角的 **Resize** 调整大小。使用鼠标时，靠近左、右或上边缘后松开可停靠窗口。触屏可使用 **Dock left** 和 **Dock right**。较矮的横屏布局使用角形调整手柄。点击 **Floating layout** 恢复浮动布局。
3. 打开 **Preferences**，点击 **Hide**，再按 **UI** 浮动按钮。窗口应回到原标签页。将浮动按钮拖到屏幕中间再松手。它应留在安全区内的放置位置。在 **Preferences** 选择 **Open second window**，隐藏第二个窗口后会显示 **2** 按钮。
4. 在 **Home** 点击 **Open sheet**，打开和关闭嵌套面板。滚动到输入框，检查软键盘出现后 **Done** 按钮是否仍可触达。
5. 在设备模拟器中测试竖屏与横屏。窄屏下标签移到底部。空间充足的横屏布局使用侧栏。

在 **Help** 标签页可右键点击或长按标题来打开菜单，也可以点击 **Open actions**。**Preferences** 中的 **Move bubble to side** 可切换浮动按钮的侧边。要恢复吸附边缘的方式，可使用 `reopenMode = "edge"`。

在手柄模拟器中，在 **Preferences** 中选择 **Navigation: drawer**，按方向键移到 **Tabs**，按 **A** 打开列表并选择标签页。打开嵌套面板后按一次 **B** 应返回上一层。

## 自定义窗口

在 **Preferences** 中点击 **Window appearance**，即可在运行时切换窗口外观。脚本可用 `window:SetProps(...)` 修改标题、副标题、圆角、内边距、顶栏高度和侧栏宽度，并用 `window:SetBounds(...)` 修改浮动窗口的位置和大小。用 `window:GetSlot(name)` 获取顶栏、状态栏、背景和叠加层的原生 GUI 容器。[完整选项](../window.md)

## 自定义浮动按钮

在 **Preferences** 中调整按钮尺寸、形状和图片缩放。输入 Roblox 图片 ID 或已在预览服务器上登记的 HTTPS PNG 链接。点击 **Try CDN logo** 试用 CDN 图片，再点击 **Hide** 查看效果。脚本可用 `Window:SetReopenBubble(options)` 即时修改。预览使用 `reopenEdge = "screen"`，按钮可到达物理屏幕的左右边缘，默认仍位于顶栏下方。库的默认设置 `"device"` 会保留设备安全区。[启用 CDN 图片](../window.md#customize-the-reopen-button)

在桌面确认 **Resize** 和 **Restore** 两个按钮都显示完整文字。Luau CLI 已测试布局计算、手势识别与焦点恢复规则。仍需在 Studio 和真机中验证实际交互。[完整 API（英文）](../window.md) · [测试记录](../../evidence/phase3-checks.json)
