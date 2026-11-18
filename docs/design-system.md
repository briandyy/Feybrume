# Themes and style resolution

[English](design-system.md) · [Bahasa Indonesia](id/design-system.md) · [简体中文](zh-CN/design-system.md)

The [theme registry](../design/themes.json) defines 40 presets with their original palettes. Each preset provides semantic colors, radius, desktop and touch spacing, typography roles, a decorative gradient, and a motion profile. The four signature presets are Cultivation, Memoir, Noir, and Cosmic.

| Signature | Implemented styling |
|---|---|
| Cultivation 仙 | Jade surfaces, antique gold trim and a restrained gradient |
| Memoir 忆 | Parchment gradient, warm accent and a literary heading font intent |
| Noir | Charcoal surfaces, crimson accent and a condensed heading font intent |
| Cosmic ✦ | Violet-to-teal gradient and wide heading font intent |

The registry also carries material, ornament, geometry, and fallback IDs for future renderers. Star fields, textures, animated typewriter text, and ThemeStudio are planned. The preview applies the current color, shape, gradient, native typography, and motion values to Roblox controls.

## Preview in Studio

Set up the ModuleScript using the [core guide](core.md). Create a LocalScript in StarterPlayerScripts with [theme-preview.client.luau](../examples/theme-preview.client.luau). In Play mode, press **Next theme** to cycle through all 40 presets. Check that the swatch, button, typography, and corner shape update. In the Device Emulator, try a 320×568 display and rotate to landscape. Switch between pointer and touch input and verify the next button remains reachable. Enable reduced motion and confirm the gradient rotation snaps to the new angle. Check the Latin, Indonesian, and Chinese sample in the preview, and remove the ScreenGui to exercise cleanup.

The Studio preview has been compiled by Luau CLI. Visual rendering, font access, text selection behavior, and real touch input still need testing in Roblox.

## Define and apply a theme

```luau
local Fey = require(game:GetService("ReplicatedStorage"):WaitForChild("Feybrume"))
local themes = Fey.Theme.new({ initial = "noir" })

local registered = themes:Register({
    id = "plum",
    name = "Plum",
    inherits = "noir",
    palette = { accent = "#B274D8" },
    radius = 10,
})
assert(registered.ok)
assert(themes:Set("plum").ok)

local outcome = Fey.StyleResolver.Resolve(themes:Get(), {
    input = "touch",
    states = { selected = true, focused = true },
    overrides = {
        window = { variant = "outline" },
        component = { size = "S", padding = 12 },
    },
    accessibility = { fontScale = 1.2, reducedMotion = "system" },
})
assert(outcome.ok)
print(outcome.value.foreground, outcome.value.minHeight)
themes:Destroy()
```

`Theme:Derive(baseId, overrides)` returns an immutable theme without adding it to the registry. `Register` creates a new ID and optionally inherits an existing theme. Built-in IDs cannot be replaced. A palette change regenerates its dependent colors and gradient. Explicit `tokens` or `gradient` fields take precedence. Gradients need two to twelve strictly ordered stops at offsets from 0 through 1, including both endpoints. `Subscribe(callback)` receives the new theme, changed field and token keys, and previous theme. Reentrant `Set` returns an error, so subscribers see a consistent sequence. Use `Destroy` to release listeners.

## Resolver rules

- Overrides apply from framework to window, container, component, then state. Theme values and variant defaults fill missing settings. Supported variants are solid, soft, ghost, outline, glass, neomorphic, brutalist, and minimal. Sizes run from XS through 2XL.
- Primary state order is disabled, locked, loading, pressed, invalid, success, selected, then hovered. Focus is independent. Touch input ignores hover, and a status indicator can accompany color. Touch targets default to at least 48×48 for built-in presets, with a hard floor of 44.
- `accessibility.fontScale` accepts 0.8–2. Solid and translucent fills use the specified solid backdrop to calculate contrast. Normal text targets 4.5:1. At a resolved size of at least 24, `largeText = true` enables the 3:1 target. The two focus ring colors meet 3:1 against the fill and surrounding area respectively. Turning off automatic contrast preserves requested text and stroke colors and reports warnings. Apply decorative gradients on a separate layer or give text a solid surface where contrast can be computed. [Contrast reference](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html)
- `Typography:Resolve(theme, role, descriptor?)` tries the preferred native family or asset ID, the role family, and the fallback. Descriptors accept `family` or `assetId` and optional `weight` and `style`. `ResolvePlan(style.typography)` consumes the font plan from a resolved style. `Typography.Apply` writes `FontFace` and `TextSize`. A constructed Font value does not prove asset access or glyph coverage. [Roblox Font API](https://create.roblox.com/docs/reference/engine/datatypes/Font)
- Motion policies are `system`, `always` (reduce motion), and `never`. A zero duration applies immediately. `Transition:Apply` animates only the properties marked for tweening. Rapid changes cancel the previous tween, and repeated goals do not restart it. Register the transition controller with the owning scope and tween decorative properties unless intermediate text contrast has also been checked.

Edit the registry in `design/themes.json` and run `python3 tooling/generate_themes.py` to regenerate the Luau presets. `python3 tooling/generate_themes.py --check` checks that they match. [Test evidence](../evidence/phase2-checks.json)
