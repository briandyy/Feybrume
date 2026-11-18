local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Fey = require(ReplicatedStorage:WaitForChild("Feybrume"))
local runtime = Fey.Runtime.Create()
local registry = Fey.Theme.new({ initial = "cultivation", clock = runtime.Clock })
local typesetter = Fey.Typography.new()
local transitions = Fey.Transition.new(Fey.Animation.RobloxAdapter(runtime.Services), runtime.Scope)
runtime.Scope:Give(registry)

local gui = Instance.new("ScreenGui")
gui.Name = "FeybrumeThemePreview"
gui.ResetOnSpawn = false
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
runtime.Scope:Give(gui)

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.new(0.9, 0, 0, 238)
panel.Parent = gui

local limit = Instance.new("UISizeConstraint")
limit.MaxSize = Vector2.new(480, 238)
limit.Parent = panel

local panelShape = Instance.new("UICorner")
panelShape.Parent = panel
local panelStroke = Instance.new("UIStroke")
panelStroke.Parent = panel

local swatch = Instance.new("Frame")
swatch.Position = UDim2.fromOffset(16, 16)
swatch.Size = UDim2.new(1, -32, 0, 30)
swatch.BackgroundColor3 = Color3.new(1, 1, 1)
swatch.BorderSizePixel = 0
swatch.Parent = panel
local swatchCorner = Instance.new("UICorner")
swatchCorner.Parent = swatch
local gradient = Instance.new("UIGradient")
gradient.Parent = swatch

local title = Instance.new("TextLabel")
title.Position = UDim2.fromOffset(16, 52)
title.Size = UDim2.new(1, -32, 0, 42)
title.BackgroundTransparency = 1
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

local sample = Instance.new("TextLabel")
sample.Position = UDim2.fromOffset(16, 99)
sample.Size = UDim2.new(1, -32, 0, 56)
sample.TextWrapped = true
sample.TextXAlignment = Enum.TextXAlignment.Left
sample.Text = "The quick brown fox · Selamat datang · 中文排版"
sample.BackgroundTransparency = 1
sample.Parent = panel

local button = Instance.new("TextButton")
button.Position = UDim2.fromOffset(16, 170)
button.AutoButtonColor = false
button.Selectable = true
button.Text = "Next theme"
button.Parent = panel
local buttonShape = Instance.new("UICorner")
buttonShape.Parent = button
local buttonStroke = Instance.new("UIStroke")
buttonStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
buttonStroke.Parent = button

local state = { hovered = false, focused = false, pressed = false }
local index = 1
local presets = registry:List()

local function hex(value)
    return Color3.fromHex(value:sub(2))
end

local function setTypography(target, theme, role, size)
    local resolved = typesetter:Resolve(theme, role)
    if resolved.ok then Fey.Typography.Apply(target, resolved.value, size) end
end

local function render(theme)
    local input = if UserInputService.PreferredInput == Enum.PreferredInput.Touch then "touch" else "pointer"
    local resolved = Fey.StyleResolver.Resolve(theme, {
        input = input,
        states = state,
        overrides = { component = { variant = "solid", size = "L" } },
        accessibility = {
            systemReducedMotion = Fey.Motion.ReadRobloxPreference(runtime.Services),
        },
    })
    assert(resolved.ok)
    local style = resolved.value
    panel.BackgroundColor3 = hex(theme.palette.surface)
    panelShape.CornerRadius = UDim.new(0, theme.radius)
    panelStroke.Color = hex(theme.decorationColor or theme.tokens.essentialStroke)
    panelStroke.Thickness = 1
    swatchCorner.CornerRadius = UDim.new(0, math.min(12, theme.radius))
    local stops = {}
    for _, stop in ipairs(theme.gradient) do
        table.insert(stops, ColorSequenceKeypoint.new(stop.at, hex(stop.color)))
    end
    gradient.Color = ColorSequence.new(stops)

    title.Text = string.format("%02d · %s", index, theme.name)
    title.TextColor3 = hex(theme.tokens.onSurface)
    sample.TextColor3 = title.TextColor3
    setTypography(title, theme, "title", 20)
    setTypography(sample, theme, "body", 15)
    local buttonFont = typesetter:ResolvePlan(style.typography)
    if buttonFont.ok then Fey.Typography.Apply(button, buttonFont.value, style.textSize) end

    button.Size = UDim2.new(1, -32, 0, style.minHeight)
    buttonShape.CornerRadius = UDim.new(0, style.radius)
    buttonStroke.Thickness = if style.focus then style.focus.width else style.borderWidth
    buttonStroke.Enabled = buttonStroke.Thickness > 0
    buttonStroke.Color = hex(if style.focus then style.focus.outer else style.stroke)

    -- Set the foreground immediately and tween unrelated decorative chrome only.
    button.BackgroundColor3 = hex(style.background)
    button.BackgroundTransparency = 1 - style.backgroundOpacity
    button.TextColor3 = hex(style.foreground)
    transitions:Apply(gradient, { Rotation = (index * 31) % 360 }, style.motion, { Rotation = true })
end

runtime.Scope:Give(registry:Subscribe(render))
runtime.Scope:Give(button.Activated:Connect(function()
    index = index % #presets + 1
    registry:Set(presets[index].id)
end))
runtime.Scope:Give(button.MouseEnter:Connect(function()
    state.hovered = true
    render(registry:Get())
end))
runtime.Scope:Give(button.MouseLeave:Connect(function()
    state.hovered = false
    state.pressed = false
    render(registry:Get())
end))
runtime.Scope:Give(button.MouseButton1Down:Connect(function()
    state.pressed = true
    render(registry:Get())
end))
runtime.Scope:Give(button.MouseButton1Up:Connect(function()
    state.pressed = false
    render(registry:Get())
end))
runtime.Scope:Give(button.SelectionGained:Connect(function()
    state.focused = true
    render(registry:Get())
end))
runtime.Scope:Give(button.SelectionLost:Connect(function()
    state.focused = false
    render(registry:Get())
end))
runtime.Scope:Give(UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(function()
    render(registry:Get())
end))
local guiService = runtime.Services:TryGet("GuiService")
if guiService.ok then
    runtime.Scope:Give(guiService.value:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(function()
        render(registry:Get())
    end))
end
runtime.Scope:Give(gui.Destroying:Connect(function()
    runtime:Dispose()
end))
render(registry:Get())
