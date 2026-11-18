local Layout = require(if script then script.Parent.Parent.engine.Layout else "../engine/Layout")
local Color = require(if script then script.Parent.Parent.engine.Color else "../engine/Color")
local ControlSpec = require(if script then script.Parent.ControlSpec else "./ControlSpec")
local WindowProps = {}
local defaults = table.freeze({
    title = "Feybrume", subtitle = "", titleSize = 18, titleFont = false,
    titleAlign = "auto", titleLogo = false, titleLogoSize = 26, titleLogoPosition = "before",
    chromeButtons = table.freeze({}),
    backgroundOpacity = 1, cornerRadius = false, padding = false,
    topbarHeight = 0, sidebarWidth = 0, snapDistance = 22,
    topbarLeadingWidth = 0, topbarTrailingWidth = 0, statusBarHeight = 0,
})

local function range(low, high, optional)
    return function(value)
        return (optional == true and value == false) or (type(value) == "number" and value >= low and value <= high)
    end
end

local function asset(value)
    return value == false or ControlSpec.IconUri(value) ~= nil
end

local function optionalColor(value)
    return value == false or Color.IsHex(value)
end

local chromeValidators = {
    text = function(value) return value == false or (type(value) == "string" and #value <= 80) end,
    icon = asset, iconSize = range(8, 40), background = optionalColor, iconColor = optionalColor,
}
local chromeNames = { max = true, restore = true, hide = true }

local function mergeChrome(base, patch)
    assert(type(patch) == "table", "Expected chromeButtons options")
    local result = table.clone(base)
    for name, options in pairs(patch) do
        assert(chromeNames[name] and (options == false or type(options) == "table"), "Invalid window chrome button")
        if options == false then
            result[name] = nil
        else
            local button = table.clone(result[name] or {})
            for key, value in pairs(options) do
                local check = chromeValidators[key]
                assert(check and check(value), "Invalid window chrome option: " .. tostring(key))
                button[key] = if key == "icon" and value ~= false then ControlSpec.IconUri(value) else value
            end
            result[name] = table.freeze(button)
        end
    end
    return table.freeze(result)
end

local validators = {
    title = function(value) return type(value) == "string" end,
    subtitle = function(value) return type(value) == "string" end,
    titleSize = range(10, 40),
    titleFont = function(value)
        local kind = typeof(value)
        return value == false or kind == "Font"
    end,
    titleAlign = function(value) return value == "auto" or value == "left" or value == "center" or value == "right" end,
    titleLogo = asset,
    titleLogoSize = range(10, 80),
    titleLogoPosition = function(value) return value == "before" or value == "after" end,
    chromeButtons = function(value) return type(value) == "table" end,
    backgroundOpacity = range(0, 1),
    cornerRadius = range(0, 100, true),
    padding = range(0, 32, true),
    topbarHeight = range(0, 140),
    sidebarWidth = range(0, 320),
    snapDistance = range(0, 120),
    topbarLeadingWidth = range(0, 320),
    topbarTrailingWidth = range(0, 320),
    statusBarHeight = range(0, 128),
}

function WindowProps.Merge(base, patch)
    assert(type(patch) == "table", "Expected window props")
    local result = table.clone(base or defaults)
    for key, value in pairs(patch) do
        local check = validators[key]
        assert(check and check(value), "Invalid window prop: " .. tostring(key))
        if key == "chromeButtons" then result[key] = mergeChrome(result[key], value)
        elseif key == "titleLogo" and value ~= false then result[key] = ControlSpec.IconUri(value)
        else result[key] = value end
    end
    return table.freeze(result)
end

function WindowProps.FromOptions(options)
    local patch = {}
    for key in pairs(validators) do patch[key] = options[key] end
    return WindowProps.Merge(nil, patch)
end

function WindowProps.Position(value)
    if value == nil then return "center" end
    if Layout.IsPanelAnchor(value) then return value end
    assert(type(value) == "table" and type(value.x) == "number" and type(value.y) == "number",
        "Expected a window anchor or position with x and y")
    for key in pairs(value) do assert(key == "x" or key == "y", "Unknown window position field") end
    return table.freeze(WindowProps.Bounds({}, value))
end

function WindowProps.Bounds(current, patch)
    assert(type(patch) == "table", "Expected window bounds")
    local result = table.clone(current)
    for key, value in pairs(patch) do
        assert(key == "x" or key == "y" or key == "width" or key == "height", "Unknown bounds field")
        assert(type(value) == "number" and math.abs(value) < math.huge, "Expected a finite window bound")
        assert(key == "x" or key == "y" or value > 0, "Expected a positive dimension")
        result[key] = value
    end
    return result
end

return table.freeze(WindowProps)
