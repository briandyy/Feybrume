local ReopenStyle = {}
local defaults = table.freeze({
    size = 52, shape = "circle", radius = 12, label = "Open",
    image = false, imageScale = 0.62, allowTopbar = false,
})
local shapes = { square = true, rounded = true, circle = true }

local function imageUri(value: any)
    if value == false then return false end
    if type(value) == "number" and value > 0 and value <= 9007199254740991 and value % 1 == 0 then
        return string.format("rbxassetid://%.0f", value :: number)
    end
    if type(value) == "string" then
        local id = value:match("^rbxassetid://([1-9]%d*)$") or value:match("^([1-9]%d*)$")
        if id then return "rbxassetid://" .. id end
    end
    error("Expected a Roblox image asset ID or false", 3)
end

function ReopenStyle.Merge(base, patch)
    local result = table.clone(base or defaults)
    assert(type(patch) == "table", "Expected reopenBubble options")
    for key, value in pairs(patch) do
        assert(defaults[key] ~= nil, "Unknown reopenBubble option " .. tostring(key))
        result[key] = if key == "image" then imageUri(value) else value
    end
    assert(type(result.shape) == "string" and shapes[result.shape], "Expected square, rounded or circle")
    assert(type(result.size) == "number" and result.size >= 36 and result.size <= 160, "Bubble size must be 36 to 160")
    assert(type(result.radius) == "number" and result.radius >= 0 and result.radius <= 80, "Bubble radius must be 0 to 80")
    assert(type(result.label) == "string" and #result.label > 0 and #result.label <= 80, "Expected a bubble label")
    assert(type(result.imageScale) == "number" and result.imageScale >= 0.15 and result.imageScale <= 1,
        "Image scale must be 0.15 to 1")
    assert(type(result.allowTopbar) == "boolean", "Expected a boolean allowTopbar")
    return table.freeze(result)
end

function ReopenStyle.Corner(style, size, inset)
    if style.shape == "circle" then return 0.5, 0 end
    if style.shape == "square" then return 0, 0 end
    return 0, math.max(0, math.min(style.radius, size / 2) - inset)
end

return table.freeze(ReopenStyle)
