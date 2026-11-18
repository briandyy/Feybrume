local Error = require(if script then script.Parent.Parent.core.Error else "../core/Error")
local Result = require(if script then script.Parent.Parent.core.Result else "../core/Result")
local Schema = require(if script then script.Parent.Parent.core.Schema else "../core/Schema")
local Color = require(if script then script.Parent.Color else "./Color")
local Motion = require(if script then script.Parent.Motion else "./Motion")
local Tokens = require(if script then script.Parent.Tokens else "./Tokens")
local Typography = require(if script then script.Parent.Typography else "./Typography")

local StyleResolver = {}
local states = { "disabled", "locked", "loading", "pressed", "invalid", "success", "selected", "hovered" }
local stateNames = { default = true, focused = true }
for _, state in ipairs(states) do stateNames[state] = true end
local layers = { "framework", "window", "container", "component", "state" }
local layerNames = {}
for _, name in ipairs(layers) do layerNames[name] = true end

local variants = {
    solid = { fill = "accent", ink = "accentOn", alpha = 1, borderWidth = 0 },
    soft = { fill = "raised", ink = "onSurface", alpha = 1, borderWidth = 0 },
    ghost = { fill = "surface", ink = "onSurface", alpha = 0, borderWidth = 0 },
    outline = { fill = "surface", ink = "onSurface", alpha = 0, borderWidth = 1 },
    glass = { fill = "raised", ink = "onSurface", alpha = 0.8, borderWidth = 1 },
    neomorphic = { fill = "raised", ink = "onSurface", alpha = 1, borderWidth = 1, shadowScale = 0.75 },
    brutalist = { fill = "accent", ink = "accentOn", alpha = 1, borderWidth = 2, radius = 0, shadowScale = 1 },
    minimal = { fill = "surface", ink = "onSurface", alpha = 0, borderWidth = 0 },
}
local stateFill = {
    disabled = { "disabled", "onDisabled" },
    locked = { "disabled", "onDisabled" },
    loading = { "raised", "onSurface" },
    pressed = { "pressed", "onPressed" },
    selected = { "selection", "onSelection" },
    hovered = { "hover", "onHover" },
}
local indicators = { disabled = "disabled", locked = "lock", loading = "progress", invalid = "warning", success = "check", selected = "check" }
local motionModes = { system = true, always = true, never = true }

local function inRange(minimum, maximum)
    return function(value)
        return type(value) == "number" and value >= minimum and value <= maximum
    end
end

local function boolean(value)
    return type(value) == "boolean"
end

local rules = {
    variant = function(value) return type(value) == "string" and variants[value] ~= nil end,
    size = function(value) return type(value) == "string" and Tokens.Sizes[value] ~= nil end,
    background = Color.IsHex, foreground = Color.IsHex, stroke = Color.IsHex, focusColor = Color.IsHex,
    backgroundOpacity = inRange(0, 1), shadowOpacity = inRange(0, 1),
    radius = inRange(0, 999), padding = inRange(0, 100), borderWidth = inRange(0, 12),
    minHitTarget = inRange(0, 200), textSize = inRange(1, 50),
    font = Typography.IsDescriptor, largeText = boolean,
}

local policies = {
    autoContrast = boolean, systemReducedMotion = boolean, essentialBoundary = boolean,
    reducedMotion = function(value) return type(value) == "string" and motionModes[value] ~= nil end,
    fontScale = inRange(0.8, 2),
}

local inputKeys = {
    overrides = true, states = true, accessibility = true, parentSurface = true,
    input = true, role = true,
}

local function copyFields(target, source, validation)
    if type(source) ~= "table" then return false end
    for key, value in pairs(source) do
        if not validation[key] or not validation[key](value) then return false end
        target[key] = value
    end
    return true
end

local function statesFor(value)
    if type(value) == "string" then
        if not stateNames[value] then return nil end
        return { [value] = true }
    end
    if type(value) ~= "table" then return nil end
    for state, active in pairs(value) do
        if not stateNames[state] or type(active) ~= "boolean" then return nil end
    end
    return value
end

local function dominant(active, touch)
    for _, state in ipairs(states) do
        if active[state] and (state ~= "hovered" or not touch) then return state end
    end
    return "default"
end

local function invalid()
    return Result.Err(Error.Create("INVALID_VALUE"))
end

function StyleResolver.Resolve(theme, options)
    if type(theme) ~= "table" or type(theme.palette) ~= "table" or type(theme.tokens) ~= "table" then return invalid() end
    local checked = Schema.Copy(if options == nil then {} else options)
    if not checked.ok then return checked end
    options = checked.value
    if type(options) ~= "table" then return invalid() end
    for key in pairs(options) do if not inputKeys[key] then return invalid() end end

    local input = options.input or "pointer"
    if input ~= "pointer" and input ~= "touch" and input ~= "gamepad" and input ~= "keyboard" then return invalid() end
    local isTouch = input == "touch"
    local policy = { fontScale = 1, autoContrast = true, essentialBoundary = true }
    if options.accessibility ~= nil and not copyFields(policy, options.accessibility, policies) then return invalid() end
    local active = statesFor(if options.states == nil then {} else options.states)
    if not active then return invalid() end
    local state = dominant(active, isTouch)
    local overrides = options.overrides or {}
    if type(overrides) ~= "table" then return invalid() end
    for key in pairs(overrides) do if not layerNames[key] then return invalid() end end

    local style = { variant = "solid", size = "M" }
    for _, layer in ipairs(layers) do
        if overrides[layer] ~= nil and not copyFields(style, overrides[layer], rules) then return invalid() end
    end
    local font = Typography.Describe(theme, options.role or "button", style.font)
    if not font.ok then return font end

    local variant = variants[style.variant]
    local size = Tokens.Sizes[style.size]
    local tokens = theme.tokens
    local fill = stateFill[state]
    local function color(name)
        return tokens[name] or theme.palette[name]
    end
    local parent = options.parentSurface or theme.palette.surface
    if not Color.IsHex(parent) then return invalid() end
    local background = style.background or color(if fill then fill[1] else variant.fill)
    local opacity = style.backgroundOpacity or (if fill then 1 else variant.alpha)
    local composite = Color.Mix(parent, background, opacity)
    local foreground = style.foreground or color(if fill then fill[2] else variant.ink)
    local warnings = {}
    local function ensure(value, behind, threshold, code)
        if Color.Contrast(value, behind) >= threshold then return value end
        if policy.autoContrast then return Color.EnsureContrast(value, behind, threshold) end
        table.insert(warnings, code)
        return value
    end

    -- A caller may opt into the large-text threshold only at a sufficiently large size.
    local fontSize = math.max(1, math.round((style.textSize or size.text) * policy.fontScale))
    local textThreshold = if style.largeText and fontSize >= 24 then 3 else Tokens.NormalTextContrast
    foreground = ensure(foreground, composite, textThreshold, "TEXT_CONTRAST")
    local borderWidth = style.borderWidth or variant.borderWidth
    local statusStroke = if active.invalid then tokens.danger elseif active.success then tokens.success else nil
    if statusStroke then borderWidth = math.max(1, borderWidth) end
    if policy.essentialBoundary and Color.Contrast(composite, parent) < Tokens.NonTextContrast then
        borderWidth = math.max(1, borderWidth)
    end
    local border = style.stroke or statusStroke or tokens.essentialStroke
    if borderWidth > 0 then border = ensure(border, parent, Tokens.NonTextContrast, "STROKE_CONTRAST") end

    local focus
    if active.focused then
        local hue = style.focusColor or tokens.focus
        focus = table.freeze({
            width = 2,
            inner = Color.EnsureContrast(hue, composite, Tokens.NonTextContrast),
            outer = Color.EnsureContrast(hue, parent, Tokens.NonTextContrast),
        })
    end
    local height = math.max(size.height, style.minHitTarget or 0, fontSize + 12)
    if isTouch then height = math.max(height, Tokens.MinimumTouch, theme.touch.minimumHitTarget) end
    return Result.Ok(table.freeze({
        themeId = theme.id, variant = style.variant, size = style.size, state = state,
        background = background, backgroundOpacity = opacity, compositeBackground = composite,
        foreground = foreground, stroke = border, borderWidth = borderWidth,
        radius = style.radius or variant.radius or theme.radius, padding = style.padding or size.padding,
        minWidth = if isTouch then math.max(Tokens.MinimumTouch, theme.touch.minimumHitTarget, style.minHitTarget or 0) else style.minHitTarget or 0,
        minHeight = height, textSize = fontSize, iconSize = size.icon, typography = font.value,
        focus = focus, indicator = if active.invalid then indicators.invalid elseif active.success then indicators.success else indicators[state],
        shadowOpacity = style.shadowOpacity or theme.elevation.shadowAlpha * (variant.shadowScale or 0),
        geometry = theme.geometry, material = theme.material, ornament = theme.ornament,
        motion = Motion.Resolve(theme.motion.profile, policy), warnings = table.freeze(warnings),
    }))
end

function StyleResolver.Diff(before, after)
    local changed = {}
    for key, value in pairs(after) do
        if not Schema.Equal(value, before[key]) then changed[key] = true end
    end
    for key in pairs(before) do
        if after[key] == nil then changed[key] = true end
    end
    return table.freeze(changed)
end

return table.freeze(StyleResolver)
