local Error = require(if script then script.Parent.Parent.core.Error else "../core/Error")
local Result = require(if script then script.Parent.Parent.core.Result else "../core/Result")
local Schema = require(if script then script.Parent.Parent.core.Schema else "../core/Schema")
local Signal = require(if script then script.Parent.Parent.core.Signal else "../core/Signal")
local Color = require(if script then script.Parent.Color else "./Color")
local Motion = require(if script then script.Parent.Motion else "./Motion")
local Presets = require(if script then script.Parent.Presets else "./Presets")

local Theme = {}
Theme.__index = Theme
local DEFAULT_ID = "feybrume-default"

local function text(value)
    return type(value) == "string" and #value > 0 and #value <= 120 and utf8.len(value) ~= nil
end

local function inRange(minimum, maximum)
    return function(value)
        return type(value) == "number" and value >= minimum and value <= maximum
    end
end

local function boolean(value)
    return type(value) == "boolean"
end

local px = inRange(0, 999)
local alpha = inRange(0, 1)
local fields = {
    palette = {
        background = Color.IsHex, surface = Color.IsHex, accent = Color.IsHex,
        text = Color.IsHex, stroke = Color.IsHex,
    },
    tokens = {},
    touch = { navigation = text, minimumHitTarget = px, sectionGap = px, actionGap = px },
    desktop = { navigation = text, controlGap = px, sectionGap = px },
    typography = { headingRole = text, bodyRole = text, nativeFallback = text, codeRole = text, editable = function(value) return value == "native" end },
    elevation = { shadowAlpha = alpha, backdropAlpha = alpha },
    motion = {
        profile = Motion.HasProfile,
        reduced = function(value) return value == "instant" end,
        optionalDecorationsDefault = boolean,
    },
    fallback = { material = text, ornament = text, motion = Motion.HasProfile },
}
for key in pairs(Presets[1].tokens) do fields.tokens[key] = Color.IsHex end
local simple = { name = text, geometry = text, radius = px, material = text, ornament = text, iconTreatment = text }
local signatureGradients = {
    cultivation = { "#15221B", "#293D2F", "#786D49" },
    memoir = { "#F6F0E5", "#E9E1D0", "#CEBCAF" },
    noir = { "#09090C", "#1A171E", "#30202A" },
    cosmic = { "#131936", "#643AA2", "#187D83" },
}

local function makeGradient(palette, signature)
    local colors = signature or { palette.surface, Color.Mix(palette.surface, palette.accent, 0.22), palette.background }
    return { { at = 0, color = colors[1] }, { at = 0.55, color = colors[2] }, { at = 1, color = colors[3] } }
end

local function isGradient(value)
    if type(value) ~= "table" or #value < 2 or #value > 12 then return false end
    local last = -1
    for index, stop in ipairs(value) do
        if type(stop) ~= "table" or not alpha(stop.at) or stop.at <= last or not Color.IsHex(stop.color)
            or (index == 1 and stop.at ~= 0) or (index == #value and stop.at ~= 1) then
            return false
        end
        for key in pairs(stop) do if key ~= "at" and key ~= "color" then return false end end
        last = stop.at
    end
    return true
end

local function tint(surface, accent, weight)
    return Color.Mix(surface, accent, weight)
end

local function recalculate(base, palette, patch)
    local t = table.clone(base.tokens)
    local bg, accent = palette.surface, palette.accent
    if patch.surface or patch.accent then
        t.hover, t.pressed, t.selection = tint(bg, accent, 0.10), tint(bg, accent, 0.24), tint(bg, accent, 0.20)
        t.raised, t.overlay = tint(bg, accent, 0.07), tint(bg, accent, 0.10)
        t.input, t.disabled = tint(bg, accent, 0.04), tint(bg, accent, 0.03)
        t.header, t.sidebar, t.tooltip, t.popup = t.overlay, t.raised, t.raised, t.overlay
        t.focus = Color.EnsureContrast(accent, bg, 3)
        t.essentialStroke = Color.EnsureContrast(palette.stroke, bg, 3)
        t.accentOn = Color.Readable(accent)
        for _, status in ipairs({ "success", "warning", "danger", "info" }) do
            t[status] = Color.EnsureContrast(t[status], bg, 4.5)
        end
        t.infoOn = Color.Readable(t.info)
    elseif patch.stroke then
        t.essentialStroke = Color.EnsureContrast(palette.stroke, bg, 3)
    end
    if patch.surface or patch.accent or patch.text then
        t.onSurface = Color.EnsureContrast(palette.text, bg, 4.5)
        t.onHover = Color.EnsureContrast(palette.text, t.hover, 4.5)
        t.onPressed = Color.EnsureContrast(palette.text, t.pressed, 4.5)
        t.onSelection = Color.EnsureContrast(palette.text, t.selection, 4.5)
        t.onDisabled = Color.EnsureContrast(tint(t.disabled, palette.text, 0.63), t.disabled, 4.5)
        t.placeholder = Color.EnsureContrast(tint(t.input, palette.text, 0.68), t.input, 4.5)
    end
    return t
end

local function merge(base, validation, overrides)
    if type(overrides) ~= "table" then return nil end
    local data = table.clone(base)
    for key, value in pairs(overrides) do
        if not validation[key] or not validation[key](value) then return nil end
        data[key] = value
    end
    return data
end

local builtin, order = {}, {}
for _, raw in ipairs(Presets) do
    local record = table.clone(raw)
    record.gradient = makeGradient(record.palette, signatureGradients[record.id])
    if record.id == "cultivation" then record.decorationColor = "#B79A63" end
    builtin[record.id] = Schema.Copy(record).value
    table.insert(order, record.id)
end
table.freeze(builtin)

local function invalid()
    return Result.Err(Error.Create("INVALID_VALUE"))
end

function Theme.new(options)
    options = options or {}
    assert(builtin[options.initial or DEFAULT_ID], "Unknown initial theme")
    return setmetatable({
        _active = options.initial or DEFAULT_ID,
        _custom = {}, _customOrder = {},
        _changed = Signal.new(options.clock, options.onError),
    }, Theme)
end

function Theme:Get(id)
    if self._disposed then return nil end
    id = id or self._active
    return self._custom[id] or builtin[id]
end

function Theme:List()
    local result = {}
    if not self._disposed then
        for _, id in ipairs(order) do table.insert(result, builtin[id]) end
        for _, id in ipairs(self._customOrder) do table.insert(result, self._custom[id]) end
    end
    return table.freeze(result)
end

function Theme:Derive(baseId, overrides)
    if self._disposed then return Result.Err(Error.Create("DISPOSED")) end
    local base = self:Get(baseId)
    if not base then return Result.Err(Error.Create("THEME_NOT_FOUND")) end
    local checked = Schema.Copy(overrides)
    if not checked.ok then return checked end
    overrides = checked.value
    if type(overrides) ~= "table" then return invalid() end

    local record = table.clone(base)
    if overrides.palette ~= nil then
        record.palette = merge(base.palette, fields.palette, overrides.palette)
        if not record.palette then return invalid() end
        record.tokens = recalculate(base, record.palette, overrides.palette)
        record.gradient = makeGradient(record.palette)
    end

    for key, value in pairs(overrides) do
        if key == "palette" then continue end
        if key == "id" then
            if type(value) ~= "string" or #value > 60 or not value:match("^[a-z0-9][a-z0-9%-]*$") then
                return invalid()
            end
            record.id = value
            if value ~= base.id then
                record.signature, record.themeNumber = false, nil
            end
        elseif fields[key] then
            record[key] = merge(record[key], fields[key], value)
            if not record[key] then return invalid() end
        elseif simple[key] and simple[key](value) then
            record[key] = value
        elseif (key == "gradient" and isGradient(value)) or (key == "decorationColor" and Color.IsHex(value)) then
            record[key] = value
        else
            return invalid()
        end
    end
    return Schema.Copy(record)
end

function Theme:Register(spec)
    if self._disposed then return Result.Err(Error.Create("DISPOSED")) end
    local checked = Schema.Copy(spec)
    if not checked.ok then return checked end
    if type(checked.value) ~= "table" or type(checked.value.id) ~= "string" then return invalid() end
    if self:Get(checked.value.id) then return Result.Err(Error.Create("DUPLICATE_THEME")) end
    local overrides = table.clone(checked.value)
    local baseId = overrides.inherits or DEFAULT_ID
    overrides.inherits = nil
    if type(baseId) ~= "string" then return invalid() end
    local result = self:Derive(baseId, overrides)
    if not result.ok then return result end
    local id = result.value.id
    self._custom[id] = result.value
    table.insert(self._customOrder, id)
    return result
end

function Theme.Diff(before, after)
    local changed = {}
    local function compare(group, old, new)
        for key, value in pairs(old) do
            if not Schema.Equal(value, new[key]) then changed[group .. key] = true end
        end
        for key in pairs(new) do
            if old[key] == nil then changed[group .. key] = true end
        end
    end
    compare("", before, after)
    compare("palette.", before.palette, after.palette)
    compare("tokens.", before.tokens, after.tokens)
    return table.freeze(changed)
end

function Theme:Set(id)
    if self._disposed then return Result.Err(Error.Create("DISPOSED")) end
    if self._publishing then return Result.Err(Error.Create("INVALID_ARGUMENT")) end
    local previous = self:Get()
    if type(id) ~= "string" or not self:Get(id) then return Result.Err(Error.Create("THEME_NOT_FOUND")) end
    local nextTheme = self:Get(id)
    if previous ~= nextTheme then
        self._active = id
        self._publishing = true
        self._changed:Fire(nextTheme, Theme.Diff(previous, nextTheme), previous)
        self._publishing = false
    end
    return Result.Ok(nextTheme)
end

function Theme:Subscribe(onChange)
    return self._changed:Connect(onChange)
end

function Theme:Destroy()
    if self._disposed then return end
    self._disposed = true
    self._changed:Destroy()
    table.clear(self._custom)
    table.clear(self._customOrder)
end

return table.freeze(Theme)
