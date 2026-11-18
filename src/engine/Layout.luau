local Layout = {}
local defaults = table.freeze({ micro = 360, compact = 480, phone = 640, tablet = 1000, short = 400 })

function Layout.ValidateBreakpoints(value)
    for key, number in pairs(value) do
        assert(defaults[key] ~= nil and type(number) == "number" and number > 0 and number < math.huge,
            "Invalid responsive breakpoint")
    end
    local result = table.clone(defaults)
    for key, number in pairs(value) do result[key] = number end
    assert(result.micro < result.compact and result.compact < result.phone and result.phone < result.tablet,
        "Width breakpoints must increase")
    return table.freeze(result)
end

function Layout.Profile(width, height, input, breakpoints)
    local limits = breakpoints or defaults
    local name
    if width < limits.micro then name = "micro"
    elseif width <= limits.compact then name = "compact"
    elseif width <= limits.phone then name = "phoneLarge"
    elseif width <= limits.tablet then name = "tablet"
    else name = "desktop" end
    local narrow = width <= limits.phone
    local short = height <= limits.short
    return {
        name = name, narrow = narrow, short = short, landscape = width > height, touch = input == "touch",
        navigation = if narrow then (if short then "drawer" else "bottom") else (if short then "drawer" else "left"),
    }
end

function Layout.Rect(x, y, width, height)
    return { x = x, y = y, width = math.max(0, width), height = math.max(0, height) }
end

function Layout.Inset(rect, amount)
    local x = math.min(amount, rect.width / 2)
    local y = math.min(amount, rect.height / 2)
    return Layout.Rect(rect.x + x, rect.y + y, rect.width - 2 * x, rect.height - 2 * y)
end

function Layout.Clamp(rect, area, minWidth, minHeight, maxWidth, maxHeight)
    local highW = math.min(area.width, maxWidth or math.huge)
    local highH = math.min(area.height, maxHeight or math.huge)
    local w = math.clamp(rect.width, math.min(minWidth or 0, highW), highW)
    local h = math.clamp(rect.height, math.min(minHeight or 0, highH), highH)
    return Layout.Rect(
        math.clamp(rect.x, area.x, area.x + area.width - w),
        math.clamp(rect.y, area.y, area.y + area.height - h), w, h)
end

function Layout.Center(area, width, height)
    return Layout.Rect(area.x + (area.width - width) / 2, area.y + (area.height - height) / 2, width, height)
end

function Layout.Window(rect, area, profile, placement, limits, fillCompact)
    if placement == "fullscreen" or (profile.narrow and fillCompact) then return table.clone(area) end
    if placement == "left" or placement == "right" then
        if area.width < limits.minWidth * 2 + 8 then return table.clone(area) end
        local half = math.floor((area.width - 8) / 2)
        local x = if placement == "left" then area.x else area.x + area.width - half
        return Layout.Rect(x, area.y, half, area.height)
    end
    return Layout.Clamp(rect, area, limits.minWidth, limits.minHeight, limits.maxWidth, limits.maxHeight)
end

function Layout.Resize(rect, area, dx, dy, limits)
    local available = Layout.Rect(rect.x, rect.y, area.x + area.width - rect.x, area.y + area.height - rect.y)
    return Layout.Clamp(Layout.Rect(rect.x, rect.y, rect.width + dx, rect.height + dy), available,
        limits.minWidth, limits.minHeight, limits.maxWidth, limits.maxHeight)
end

function Layout.DockAt(x, y, area, distance)
    if y <= area.y + distance then return "fullscreen" end
    if x <= area.x + distance then return "left" end
    if x >= area.x + area.width - distance then return "right" end
    return "floating"
end

function Layout.Intersects(a, b)
    return a.x < b.x + b.width and b.x < a.x + a.width
        and a.y < b.y + b.height and b.y < a.y + a.height
end

function Layout.KeyboardArea(area, keyboard)
    if keyboard and Layout.Intersects(area, keyboard) then
        return Layout.Rect(area.x, area.y, area.width, math.max(0, keyboard.y - area.y))
    end
    return area
end

function Layout.Bubble(area, reserved, side, requestedY, requestedSize)
    local size = math.min(requestedSize, area.width, area.height)
    local leftX, rightX = area.x, area.x + area.width - size
    local best, bestCost
    for _, edge in ipairs({ side, if side == "left" then "right" else "left" }) do
        local x = if edge == "left" then leftX else rightX
        local positions = { requestedY, area.y, area.y + area.height - size }
        for _, region in ipairs(reserved) do
            table.insert(positions, region.y - size - 8)
            table.insert(positions, region.y + region.height + 8)
        end
        for _, targetY in ipairs(positions) do
            local y = math.clamp(targetY, area.y, area.y + area.height - size)
            local candidate = Layout.Rect(x, y, size, size)
            local blocked = false
            for _, region in ipairs(reserved) do
                if Layout.Intersects(candidate, region) then
                    blocked = true
                    break
                end
            end
            local cost = math.abs(y - requestedY) + (if edge == side then 0 else area.height + 1)
            if not blocked and (not bestCost or cost < bestCost) then
                best, bestCost = candidate, cost
            end
        end
    end
    return best
end

function Layout.Columns(width, requested, minimum, gap)
    local fit = math.floor((width + gap) / (minimum + gap))
    return math.clamp(fit, 1, math.clamp(requested, 1, 4))
end

function Layout.TabCapacity(width, minimum, gap)
    return math.max(1, math.floor((width + gap) / (minimum + gap)))
end

function Layout.Sheet(area, profile, requestedWidth, requestedHeight)
    local rect = Layout.Clamp(Layout.Center(area, requestedWidth, requestedHeight), area)
    if profile.narrow and not profile.landscape then
        return Layout.Rect(area.x, area.y + area.height - rect.height, area.width, rect.height)
    end
    return Layout.Center(area, rect.width, rect.height)
end

return table.freeze(Layout)
