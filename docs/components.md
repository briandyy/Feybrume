# Foundation controls

[Bahasa Indonesia](id/components.md)

Feybrume has 18 foundation controls. Create them on a tab, section, grid, or sheet content container. Install the ModuleScript with the [Studio setup guide](core.md).

```luau
local storage = game:GetService("ReplicatedStorage")
local Fey = require(storage:WaitForChild("Feybrume"))
local workspace = Fey:CreateWorkspace({ theme = "cosmic", flagNamespace = "practice" })
local window = workspace:Window({ title = "Practice tools" })
local home = window:Tab({ id = "home", title = "Home" })
local section = home:Section()
local tips = section:Toggle({ name = "Show tips", flag = "tips", default = true, persist = true })
section:Paragraph({
    text = "Choose a difficulty before starting.",
    visibleIf = function(flags) return flags.tips == true end,
})
section:Button({
    name = "Reset tips",
    onClick = function() tips:Reset() end,
})
```

Factories return a handle. An invalid factory call returns `nil, error` and logs the error code. Handle operations that validate or return a value return a `Result`. Check `result.ok` before reading `result.value` or `result.error`.

## Factories

Pass the options below to a tab or container. Optional presentation props are shared with other controls. See the [live preview source](../examples/foundation-preview.client.luau) for every factory in one place.

| Factory | Example call | Value |
|---|---|---|
| Label | `section:Label({ text = "Ready" })` | String |
| Heading | `section:Heading({ text = "Practice" })` | String, large |
| Subheading | `section:Subheading({ text = "Round two" })` | String, medium |
| Paragraph | `section:Paragraph({ text = "Wraps across lines." })` | String |
| RichText | `section:RichText({ text = "<b>Ready</b>" })` | String rendered with safe spans |
| Caption | `section:Caption({ text = "Last run" })` | String, small |
| TextDivider | `section:TextDivider({ text = "Options" })` | String with a divider line |
| IconText | `section:IconText({ text = "Help" })` | String with a leading icon when available |
| Statistic | `section:Statistic({ name = "Practice", default = 3, unit = "laps" })` | Finite number |
| Quote | `section:Quote({ text = "Try again.", author = "Coach" })` | String with an optional author |
| Button | `section:Button({ name = "Start", onClick = begin })` | Action |
| IconButton | `section:IconButton({ name = "Help", onClick = showHelp })` | Outlined action with a larger optional icon |
| Toggle | `section:Toggle({ name = "Tips", default = true })` | Boolean |
| Checkbox | `section:Checkbox({ name = "Pin guide" })` | Boolean |
| Radio | `section:Radio({ name = "Mark as read" })` | Boolean, selecting sets true |
| RadioGroup | `section:RadioGroup({ name = "Difficulty", options = choices })` | One enabled choice ID |
| Tag | `section:Tag({ text = "Practice" })` | String, compact outline |
| Badge | `section:Badge({ text = "New" })` | String, compact filled surface |

In the table, `begin` and `showHelp` are callbacks supplied by your game. For a radio group, pass options such as `{{ id = "easy", name = "Easy" }, { id = "hard", name = "Hard", disabled = true }}`. IDs are unique. At least one choice must be enabled. The group defaults to its first enabled option.

## Options and handles

| Options | Used for |
|---|---|
| `name`, `text`, `description`, `tooltip` | Titles and supporting copy. Use `text` or `default` to seed display text. Use `Set` to update it. Tooltips show as inline help on touch. |
| `default`, `options` | Initial value and stable radio choices. These are creation options. |
| `size`, `variant`, `style`, `theme`, `font`, `icon` | Sizes XS–2XL, [style variants](design-system.md), a registered theme ID, native font descriptor, and a permissioned Roblox image ID. The label stays visible if an icon is absent or fails to load. |
| `visible`, `disabled`, `locked`, `loading` | Visibility and input state. User activation respects all four. Programmatic value changes can still restore a hidden or disabled control. |
| `visibleIf`, `enabledIf`, `lockedIf` | Synchronous predicates receiving the workspace flag namespace. Re-evaluate on flag events. |
| `flag`, `flagNamespace`, `persist`, `shared` | Stable values. Boolean controls can opt in to sharing the same flag. Radio groups accept a stable flag, with a dedicated schema for their choices. |
| `onClick`, `onChanged`, `callbackTiming` | Synchronous callbacks. Optional timing supports debounce or throttle with `seconds`, `leading`, and `trailing`. |
| `slot` | Initial container slot. Use a named slot that takes layout children. |

Use `Get`, `Set`, `Reset`, and `Serialize` for values. `Set(value, { source = "programmatic", silent = true })` updates the view without change callbacks, including other controls bound to the same flag. It leaves the validation result available through `OnValidate`. Actions use `Activate` and report `UNSUPPORTED_OPERATION` for value methods. RichText supports `b`, `i`, `u`, `s`, line breaks, and hex color spans such as `<font color="#BBA8FF">Tip</font>`. Other markup renders as text.

Use `SetProps` for atomic appearance updates, with helpers `SetStyle`, `SetThemeOverride`, `SetFont`, `SetIcon`, `SetDescription`, and `SetTooltip`. Use `Show`/`Hide`, `Enable`/`Disable`, or `Lock`/`Unlock` to change access. `SetOrder`, `MoveUp`, `MoveDown`, and `MoveTo(container, slot)` reorder controls within a workspace. `Focus` and `Blur` work on interactive rows. `GetInstance` exposes the native root, and `GetSlot` gives access to Leading, Main, Trailing, Footer, Background, and Overlay. `Destroy` unbinds the flag and closes owned subscriptions, timers, and GUI.

`OnChanged` receives next value, previous value, and the source tag. `OnInteract` receives the source. `OnFocus` and `OnBlur` give the choice ID on radio groups. `OnValidate` observes explicit value checks, and `OnError` receives protected callback and rendering errors. Subscribe with a callback and disconnect the returned connection when needed. `OnMounted` runs immediately on a live handle. `OnDestroyed` runs once.

## Export and restore

```luau
local snapshot = workspace:ExportFlags()
tips:Set(false)
local restored = workspace:RestoreFlags(snapshot)
assert(restored.ok, restored.error and restored.error.publicMessage)
```

Only currently bound flags with `persist = true` enter the snapshot. Bind controls before restoring. Restore validates known persisted fields together and skips keys outside that set. The source tag is `restore`. The snapshot is a plain table suitable for a future storage adapter. The preview keeps it in session memory.

## Try the preview

Run this from the repository root and open the generated place in Studio.

```sh
rojo build foundation-preview.project.json -o Feybrume-Foundation.rbxlx
```

- In Studio, press **F5**, record a lap, and load the hard preset. **Difficulty**, **Show training tips**, and **Hard mode reminder** should update together.
- In the Controller Emulator, use D-pad to reach a row and **A** to activate it. Verify a disabled row is skipped.
- On a phone in a published test place, try the full row tap target in portrait and landscape. Turn tips off on Setup and check that Guide shows the same state. Drag the resize icon in the lower-right corner in landscape. Check that the scrolling page reaches the right padding and that the selection survives rotation.
- Version 0.4.3 was compiled and checked with Luau CLI and Rojo. Native Studio and phone interaction still require the checks above. [Test record](../evidence/phase4-checks.json)
