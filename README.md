# Feybrume

[Bahasa Indonesia](README.id.md) · [简体中文](README.zh-CN.md)

Feybrume adds draggable windows to Roblox experiences. A window can dock to an edge, hold tabs, and reopen from a floating button. Tabs accept Roblox GUI instances directly.

## Run the demo

With [Rojo](https://rojo.space/) installed, build the window demo from the repository root.

```sh
rojo build foundation-preview.project.json -o Feybrume.rbxlx
```

Open `Feybrume.rbxlx` in Roblox Studio and press **F5**. Record a lap, load the hard preset, and check that the tips toggle follows across tabs.

## Add a window to your game

Sync the project with Rojo to install `Feybrume` in `ReplicatedStorage`. Put this in a `LocalScript` under `StarterPlayerScripts`. [Studio setup](docs/core.md)

```luau
local Fey = require(game:GetService("ReplicatedStorage"):WaitForChild("Feybrume"))

local window = Fey:Window({ id = "tools", title = "Game tools", theme = "cosmic" })
local home = window:Tab({ id = "home", title = "Home" })

local label = Instance.new("TextLabel")
label.Size = UDim2.new(1, 0, 0, 40)
label.Text = "Ready to play"
home:Add(label)
```

[Foundation controls](docs/components.md) · [Window API and examples](docs/window.md) · [Themes](docs/design-system.md) · [Documentation](docs/index.md)

## Preview status

**v0.4.0** adds 18 foundation controls and flag bindings. The window engine builds on the v0.3.5 preview tested on Android. [Component test record](evidence/phase4-checks.json) · [Android window tests](docs/qa-and-backlog.md#window-preview-checks)

## Develop locally

Run the checks with the [Luau CLI](https://github.com/luau-lang/luau/releases).

```sh
luau tests/core.luau
luau tests/theme.luau
luau tests/window.luau
luau tests/components.luau
luau-analyze src tests examples/foundation-preview.client.luau examples/window-preview.client.luau examples/reopen-logo.server.luau examples/theme-preview.client.luau
```

[Changelog](CHANGELOG.md) · [Phase 4 build record](phase4-manifest.json)
