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
| `window:Hide()` and `window:Show()` | Keep page state and preserve the current size and dock. A draggable button reopens the hidden window. Drop it anywhere inside the safe area. Set `workspace:SetReopenSide("left")` to move it toward the left. Pass `reopenMode = "edge"` to `CreateWorkspace` for edge snapping. |
| `window:SetNavigation(mode)` | Use `auto`, `left`, `right`, `top`, `bottom`, `drawer` or `hidden`. Auto hides navigation for a single tab and uses a side rail on short touch screens that have enough room, or a bottom bar on narrower windows. Other small layouts can use a Tabs drawer. |
| `window:Tab({ id, title, disabled? })` | Create a tab with a stable ID. Use `SelectTab(id)`, `GetActiveTab()`, `tab:SetDisabled(value)`, `tab:MoveTo(index)`, and `tab:Destroy()`. |
| `tab:Section(options)` | Create a section. Use `section:Add(guiObject, slot?)`, `GetSlot(name)`, `Grid({ columns, minWidth, rowHeight, gap })`, and `HStack(options)`. A grid reduces its column count as the viewport narrows. |
| `window:OpenContextMenu(items, options)` | Open a scoped menu. Items provide `label` and a callback. `BindContextMenu(target, items, options)` connects right-click and touch hold to the same menu and returns an unbind function. Provide a separate clickable action for keyboard access. |

Drag the title bar to move a floating window to any edge of the usable viewport. A floating panel can reach the physical edges. Where it overlaps the Roblox top bar, only the free segment of its top is painted. The title and controls remain reachable. An oversized floating window opens centered with room to drag. Drag the bottom-right corner icon to resize. Set `movable = false` or `resizable = false` to disable the gestures. Use `fillCompact = true` for a full-window layout at narrow widths. Set `dockable = true` for mouse drag-to-dock or `touchDock = true` for touch. Use Max/Restore or `Dock("floating")` to restore the floating request.

Set `initialPosition` when creating a window. Choose `top-left`, `top`, `top-right`, `left`, `center`, `right`, `bottom-left`, `bottom`, or `bottom-right`. The default is `center`. For a custom origin, use `initialPosition = { x = 64, y = 48 }` in viewport pixels. Existing `x` and `y` take precedence on their respective axes. Dragging or resizing takes over from the initial placement.

```luau
local window = workspace:Window({
    title = "My tools",
    initialPosition = "top-right",
    titleLogo = 123456789,
    titleLogoPosition = "before",
    titleAlign = "center",
    chromeButtons = {
        max = { icon = 987654321, iconSize = 18, background = "#232641" },
        restore = { text = "Restore" },
        hide = { text = "Minimize" },
    },
})
```

Use your own Roblox image asset IDs. Set `title = ""` for a logo-only header. Use `titleLogoPosition = "after"` for text followed by a logo. `titleLogoSize` sets the logo size. The default `titleAlign = "auto"` centers the header text on short touch layouts and aligns it left elsewhere. Existing top-bar slots can host arbitrary Roblox GUI objects.

`chromeButtons` supports `max`, `restore`, and `hide` overrides with `text`, `icon`, `iconSize`, `background`, and `iconColor`. When an image loads, it takes precedence over the text. The text or built-in glyph remains available while the image loads. Update these properties with `window:SetProps()`. Set a control override to `false` to reset it to the theme defaults.


Tabs and sections expose Leading, Main, Trailing, Footer, Background and Overlay slots. A window provides window-sized Background and Overlay slots plus the active page's other slots. Use native GuiObjects for content. Passing ownership to a section lets its scope remove that content on teardown. `section:Destroy()` releases the section and any nested grids or child sections.

## Customize a window

Set these options when creating a window or update them in place with `window:SetProps(patch)`. Use the same APIs for floating and docked windows.

| Property | Behavior |
|---|---|
| `title`, `subtitle`, `titleSize`, `titleFont` | Set the heading and an optional subtitle. Supply a Roblox `Font` value or `false` to restore the default heading font. |
| `backgroundOpacity`, `cornerRadius`, `padding` | Customize the window surface and spacing. Set `cornerRadius = false` or `padding = false` to restore the inherited setting. |
| `topbarHeight`, `sidebarWidth`, `snapDistance` | Set the requested header height, navigation rail width and pointer docking threshold. A value of 0 uses the automatic header or rail size. |
| `topbarLeadingWidth`, `topbarTrailingWidth`, `statusBarHeight` | Give space to persistent `TopbarLeading`, `TopbarTrailing`, and `StatusBar` slots. A value of 0 collapses that slot. Narrow windows shrink adornments to leave room for the title. |

Call `window:SetBounds({ x = 24, y = 30, width = 520, height = 360 })` to edit the floating bounds. Coordinates use the workspace's GUI units. When docked, the request is applied when the window returns to floating. Safe areas and the configured size limits still apply. The same four bounds are accepted at creation, and unspecified coordinates are centered. Invalid patches leave the previous values in effect.

Use `window:GetSlot("TopbarLeading")` for a logo or avatar, `TopbarTrailing` for custom header actions, or `StatusBar` for footer content. These slots accept native GuiObjects and are owned by the window. `Background` and `Overlay` span the window. Source resolution and media playback are tracked separately in the [media plan](media.md).

## Customize the reopen button

Set `reopenBubble` on a workspace for defaults or on a window to override them. Use `Window:SetReopenBubble(options)` to update the current window in place.

```luau
window:SetReopenBubble({
    size = 68,
    shape = "rounded",
    radius = 14,
    image = 14304828123,
    imageScale = 0.72,
    label = "UI",
})
```

Use `square`, `rounded`, or `circle` for the shape. The requested size is 36–160 GUI units and is increased to the minimum hit target when appropriate. A viewport that is too small caps the displayed size. For rounded corners, set `radius` in GUI units. The image fits inside the fraction given by `imageScale` (0.15–1). The label displays while the image is unavailable, and `image = false` removes it. Changes apply to the current session.

The device safe area determines the default left and right limits. Pass `reopenEdge = "screen"` to `CreateWorkspace` to use the physical sides, as the preview does. On a phone with a side cutout, drag the button away from that cutout or use the default `"device"`. The button stays below the Roblox top bar by default. `allowTopbar = true` permits free space beside Core UI if the button fits. [Roblox screen insets](https://create.roblox.com/docs/reference/engine/enums/ScreenInsets)

Pass either a Roblox image ID or an HTTPS URL as `image`. For URLs, supply `resolveReopenImage(url)` in `CreateWorkspace`. It can yield and returns `{ width, height, pixels }` with a packed RGBA buffer and dimensions of 1–128 pixels, or `nil` to use the text label. The loader creates an EditableImage on the client. Updating a source discards any outstanding result for the old source.

The [preview server](../examples/reopen-logo.server.luau) fetches a PNG up to 64 KiB from an exact allowlist. Add your own public CDN or R2 PNG to `approvedUrls`, paste its URL in **Preferences**, then hide the window. The default sample is available under **Try CDN logo**. Enable **Allow HTTP Requests** and **Allow Mesh / Image APIs** under the published test experience's security settings, then restart the test session. The decoder is sircfenner/png-luau v0.2.1 (MIT). The sample rocket is from Twemoji (CC BY 4.0). [HTTP requests](https://create.roblox.com/docs/cloud-services/http-service) · [EditableImage](https://create.roblox.com/docs/reference/engine/classes/EditableImage) · [Twemoji](https://github.com/twitter/twemoji/tree/v14.0.2)

## Bottom sheets and focus

`workspace:OpenSheet({ title, width, height, actionLabel, action })` returns a sheet with `GetContent()`, `AddAction(label, callback)` and `Close()`. A compact portrait screen uses a bottom sheet. Wider or landscape screens use a centered dialog. The body scrolls independently of the header and action footer. Another nested sheet hides the previous layer. Close, Escape or gamepad Back dismiss the top layer and restore an eligible selection. Tab and Shift+Tab cycle focus while the sheet owns keyboard input. An active TextBox keeps native editing shortcuts.

D-pad selects an entry control when an open window has no focus and then navigates within that window or the top sheet. Use Select/View to enter or leave window navigation, or to select a reopen bubble when all windows are hidden. A activates the selected button. Set `gamepadNavigation = false` on the workspace to let an experience manage D-pad and Select itself.

The window ScreenGui uses Roblox core and device safe insets. If the host reports an on-screen keyboard rectangle, Feybrume shrinks the available area and tries to reveal the focused editor within its scroll container. Use `reserved = { { x, y, width, height } }` on the workspace to reserve host-specific areas for the reopen bubble. The launcher keeps its preferred relative position across rotation and checks estimated thumbstick and jump areas while Roblox touch controls are enabled. It tries to stay away from open windows and their navigation controls. On extremely restricted viewports, reopening takes priority if the requested reservations leave no room. Studio and device tests should confirm these positions with the experience's actual controls. [Roblox screen insets](https://create.roblox.com/docs/reference/engine/enums/ScreenInsets) · [UserInputService](https://create.roblox.com/docs/reference/engine/classes/UserInputService)

## Build the Studio preview

With [Rojo](https://rojo.space/) installed, run this from the repository root. The resulting place opens directly in Studio without the Rojo plugin.

```sh
rojo build window-preview.project.json -o Feybrume_Phase_3_Window_Preview.rbxlx
```

## Test the Studio preview

1. Install [window-preview.client.luau](../examples/window-preview.client.luau) as a LocalScript under StarterPlayerScripts in a place containing the Feybrume modules, or open the packaged Phase 3 place. Press **F5**.
2. Drag the title to each playable edge and pull it back. Resize from the icon in the bottom-right corner. Use **Dock left**, **Dock right**, or **Max** to dock. Use **Floating layout** or **Restore** to return to a floating window.
3. Open **Preferences**, hide the window, then tap the **UI** bubble. The tab should still be active. Drag **UI** to the middle and confirm it stays there, then tap it. Choose **Open second window** on Preferences. Hiding that window exposes its **2** bubble.
4. Open **Open sheet**, then the nested sheet. Close the top sheet and confirm the first one returns. Scroll to the text field and check that the action stays reachable when the keyboard appears.
5. In Device Emulator try narrow portrait and short landscape, then repeat on a phone. Verify the tabs remain reachable from the side or bottom and rotation preserves the active page. Check that the lower-right resize grip fits the device. With a condensed tab picker, verify the launcher shows the selected tab title.

6. In Controller Emulator, select **Navigation: drawer** under Preferences. Focus **Tabs** with D-pad, then press A to open the list. Select a tab with A. Open a nested sheet and press B once to check focus restoration.
7. In **Preferences**, change the launcher size, shape, and image scale. Toggle the sample image or enter a Roblox image ID. Hide the window to check the updated launcher and drag it toward the right safe edge.

Luau CLI exercises the layout, pointer capture and focus rules. Studio callbacks, real keyboard geometry, gamepad and device safe areas require the walkthrough. Standard widgets and universal component methods are planned in later phases. [Phase 3 test evidence](../evidence/phase3-checks.json)

The preview covers floating, compact, docked, fullscreen and multi-window arrangements. Left and right docking can be combined to make a split view. Advanced navigation such as pinned and nested tabs, branded window variants, configurable chrome and mini-mode remain tracked in the [roadmap](qa-and-backlog.md). These depend on later component, media and customization work. Haptics, tab swipes and two-finger hide have no public bindings in this release.
