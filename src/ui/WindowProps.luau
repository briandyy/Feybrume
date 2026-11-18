local WindowProps = {}
local defaults = table.freeze({
    title = "Feybrume", subtitle = "", titleSize = 18, titleFont = false,
    backgroundOpacity = 1, cornerRadius = false, padding = false,
    topbarHeight = 0, sidebarWidth = 0, snapDistance = 22,
    topbarLeadingWidth = 0, topbarTrailingWidth = 0, statusBarHeight = 0,
})

local function range(low, high, optional)
    return function(value)
        return (optional == true and value == false) or (type(value) == "number" and value >= low and value <= high)
    end
end

local validators = {
    title = function(value) return type(value) == "string" end,
    subtitle = function(value) return type(value) == "string" end,
    titleSize = range(10, 40),
    titleFont = function(value)
        local kind = typeof(value)
        return value == false or kind == "Font"
    end,
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
        result[key] = value
    end
    return table.freeze(result)
end

function WindowProps.FromOptions(options)
    local patch = {}
    for key in pairs(validators) do patch[key] = options[key] end
    return WindowProps.Merge(nil, patch)
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
