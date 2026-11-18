# Windows and workspaces

[English](window.md) · [Bahasa Indonesia](id/window.md) · [简体中文](zh-CN/window.md)

A workspace owns a ScreenGui under PlayerGui. Windows within the workspace keep their own tabs, theme overrides and floating bounds. Create one from a LocalScript after [installing the runtime](core.md).

```luau
local Fey = require(game:GetService("ReplicatedStorage"):WaitForChild("Feybrume"))

local workspace = Fey:CreateWorkspace({ theme = "cosmic", reopenSide = "right" })
local window = workspace:Window({ id = "tools", title = "Tools", width = 600, height = 410 })
local overview = window:Tab({ id = "overview", title = "Overview" })
local section = overview:Section({ name = "Details" })

local message = Instance.new("TextLabel")
message.Size = UDim2.new(1, 0, 0, 48)
message.Text = "Your native GUI goes here"
section:Add(message)
```

`Fey:Window(options)` opens a window in a lazily created default workspace. `Fey:Destroy()` closes that default workspace. Call `workspace:Destroy()` to dispose an explicitly created workspace and its windows, modals and input bindings.

## Window and tab controls

| API | Behavior |
|---|---|
| `workspace:Window(options)` | Create a window with an optional ID, title, theme, width, height, minimum and maximum dimensions, navigation placement, and initial dock. All dimensions use GUI units. |
| `window:Dock(mode)` | Use `floating`, `left`, `right` or `fullscreen`. Windowed bounds are saved when docked. Narrow windows fill the available rectangle by default and restore their prior floating bounds when it grows. |
| `window:Hide()` and `window:Show()` | Keep page state and preserve the current size and dock. A draggable button reopens the hidden window. Drag it to either edge. Set `workspace:SetReopenSide("left")` for left-hand use. |
| `window:SetNavigation(mode)` | Use `auto`, `left`, `right`, `top`, `bottom`, `drawer` or `hidden`. Auto uses a bottom bar on narrow portrait, a Tabs drawer on short screens and a side rail on wider layouts. |
| `window:Tab({ id, title, disabled? })` | Create a tab with a stable ID. Use `SelectTab(id)`, `GetActiveTab()`, `tab:SetDisabled(value)`, `tab:MoveTo(index)`, and `tab:Destroy()`. |
| `tab:Section(options)` | Create a section. Use `section:Add(guiObject, slot?)`, `GetSlot(name)`, `Grid({ columns, minWidth, rowHeight, gap })`, and `HStack(options)`. A grid reduces its column count as the viewport narrows. |
| `window:OpenContextMenu(items, options)` | Open a scoped menu. Items provide `label` and a callback. `BindContextMenu(target, items, options)` connects right-click and touch hold to the same menu and returns an unbind function. Provide a separate clickable action for keyboard access. |

Window options use `movable`, `resizable`, and `dockable` to enable default gestures, and `fillCompact = false` to request a floating layout at narrow widths. The header is the drag target. The resize grip is separate from page scrolling. Dropping a floating window near the top, left or right edge docks it. Use Max/Restore or `Dock("floating")` to restore the floating request.

Tabs and sections expose Leading, Main, Trailing, Footer, Background and Overlay slots. A window provides window-sized Background and Overlay slots plus the active page's other slots. Use native GuiObjects for content. Passing ownership to a section lets its scope remove that content on teardown. `section:Destroy()` releases the section and any nested grids or child sections.

## Bottom sheets and focus

`workspace:OpenSheet({ title, width, height, actionLabel, action })` returns a sheet with `GetContent()`, `AddAction(label, callback)` and `Close()`. A compact portrait screen uses a bottom sheet. Wider or landscape screens use a centered dialog. The body scrolls independently of the header and action footer. Another nested sheet hides the previous layer. Close, Escape or gamepad Back dismiss the top layer and restore an eligible selection. Tab and Shift+Tab cycle focus while the sheet owns keyboard input. An active TextBox keeps native editing shortcuts.

The ScreenGui opts into Roblox core and device safe insets. If the host reports an on-screen keyboard rectangle, Feybrume shrinks the available area and tries to reveal the focused editor within its scroll container. Use `reserved = { { x, y, width, height } }` on the workspace to reserve host-specific areas for the reopen bubble. Touch mode also reserves estimated thumbstick and jump areas. On extremely restricted viewports, reopening takes priority if the requested reservations leave no room. Studio and device tests should confirm these positions with the experience's actual controls. [Roblox screen insets](https://create.roblox.com/docs/reference/engine/enums/ScreenInsets) · [UserInputService](https://create.roblox.com/docs/reference/engine/classes/UserInputService)

## Build the Studio preview

With [Rojo](https://rojo.space/) installed, run this from the repository root. The resulting place opens directly in Studio without the Rojo plugin.

```sh
rojo build window-preview.project.json -o Feybrume_Phase_3_Window_Preview.rbxlx
```

## Test the Studio preview

1. Install [window-preview.client.luau](../examples/window-preview.client.luau) as a LocalScript under StarterPlayerScripts in a place containing the Feybrume modules, or open the packaged Phase 3 place. Press **F5**.
2. Drag the title and the lower-right **Resize** grip. Drop near a screen edge, or use **Dock left** and **Dock right**. Confirm the window stays reachable. Use **Floating layout** to restore it.
3. Open **Preferences**, hide the window, then tap the **UI** bubble. The tab should still be active. The **2** bubble opens an independent second window.
4. Open **Open sheet**, then the nested sheet. Close the top sheet and confirm the first one returns. Scroll to the text field and check that the action stays reachable when the keyboard appears.
5. In Device Emulator try narrow portrait and short landscape, then repeat on a phone. Verify the tabs move from a bottom bar to the Tabs drawer when space is short and switching layout preserves the active page.

Luau CLI exercises the layout, pointer capture and focus rules. Studio callbacks, real keyboard geometry, gamepad and device safe areas require the walkthrough. Standard widgets and universal component methods are planned in later phases. [Phase 3 test evidence](../evidence/phase3-checks.json)

The preview covers floating, compact, docked, fullscreen and multi-window arrangements. Left and right docking can be combined to make a split view. Advanced navigation such as pinned and nested tabs, branded window variants, configurable chrome and mini-mode remain tracked in the [roadmap](qa-and-backlog.md). These depend on later component, media and customization work. Haptics, tab swipes and two-finger hide have no public bindings in this release.
