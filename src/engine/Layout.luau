local Layout = { TabPadding = 5 }
type Rectangle = { x: number, y: number, width: number, height: number }
type Anchor = { x: number, y: number }
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

function Layout.Profile(width, height, input, breakpoints, touchDevice)
    local limits = breakpoints or defaults
    local name
    if width < limits.micro then name = "micro"
    elseif width <= limits.compact then name = "compact"
    elseif width <= limits.phone then name = "phoneLarge"
    elseif width <= limits.tablet then name = "tablet"
    else name = "desktop" end
    local narrow = width <= limits.phone
    local short = height <= limits.short
    local landscape = width > height
    local touchLayout = input == "touch" or (touchDevice == true and (narrow or short))
    return {
        name = name, narrow = narrow, short = short, landscape = landscape, touch = input == "touch",
        touchLayout = touchLayout, compactChrome = touchLayout and short and landscape,
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

function Layout.HeaderAdornmentWidths(width, requestedLeading, requestedTrailing)
    local available = math.max(0, width - 64)
    local leading = math.min(requestedLeading, math.max(0, available - 8))
    if leading > 0 then available -= leading + 8 end
    local trailing = math.min(requestedTrailing, math.max(0, available - 8))
    return leading, trailing
end

function Layout.TopbarObstacles(area: Rectangle, top: number, free: Rectangle)
    local height = math.clamp(top - area.y, 0, area.height)
    if height == 0 then return {} end
    local right, bottom = area.x + area.width, area.y + height
    local x1 = math.max(area.x, free.x)
    local x2 = math.min(right, free.x + free.width)
    local y1 = math.max(area.y, free.y)
    local y2 = math.min(bottom, free.y + free.height)
    if x2 <= x1 or y2 <= y1 then return { Layout.Rect(area.x, area.y, area.width, height) } end
    local blocked = {}
    if y1 > area.y then table.insert(blocked, Layout.Rect(area.x, area.y, area.width, y1 - area.y)) end
    if y2 < bottom then table.insert(blocked, Layout.Rect(area.x, y2, area.width, bottom - y2)) end
    if x1 > area.x then table.insert(blocked, Layout.Rect(area.x, y1, x1 - area.x, y2 - y1)) end
    if x2 < right then table.insert(blocked, Layout.Rect(x2, y1, right - x2, y2 - y1)) end
    return blocked
end

function Layout.TabBounds(width, step, index, slots, rail)
    local padding, gap = Layout.TabPadding, 8
    local usable = math.max(0, width - 2 * padding - (if rail then 4 else 0))
    local buttonW = if rail then usable else math.floor((usable - gap * (slots - 1)) / math.max(slots, 1))
    local x = padding + (if rail then 0 else index * (buttonW + gap))
    local y = padding + (if rail then index * (step + gap) else 0)
    return Layout.Rect(x, y, buttonW, step)
end

function Layout.BubbleAnchor(rect, area)
    local travelX, travelY = area.width - rect.width, area.height - rect.height
    return {
        x = if travelX > 0 then math.clamp((rect.x - area.x) / travelX, 0, 1) else 0.5,
        y = if travelY > 0 then math.clamp((rect.y - area.y) / travelY, 0, 1) else 0.5,
    }
end

function Layout.FreeBubble(area: Rectangle, reserved: { Rectangle }, anchor: Anchor, requestedSize: number)
    local size = math.min(requestedSize, area.width, area.height)
    local maxX, maxY = area.x + area.width - size, area.y + area.height - size
    local x = area.x + (maxX - area.x) * anchor.x
    local y = area.y + (maxY - area.y) * anchor.y
    local function available(rect)
        for _, region in ipairs(reserved) do
            if Layout.Intersects(rect, region) then return false end
        end
        return true
    end
    local requested = Layout.Rect(x, y, size, size)
    if available(requested) then return requested end

    local xs, ys = { x, area.x, maxX }, { y, area.y, maxY }
    for _, region in ipairs(reserved) do
        table.insert(xs, math.clamp(region.x - size, area.x, maxX))
        table.insert(xs, math.clamp(region.x + region.width, area.x, maxX))
        table.insert(ys, math.clamp(region.y - size, area.y, maxY))
        table.insert(ys, math.clamp(region.y + region.height, area.y, maxY))
    end
    local best, distance
    for _, nextX in ipairs(xs) do
        for _, nextY in ipairs(ys) do
            local cost = (nextX - x)^2 + (nextY - y)^2
            if not distance or cost < distance then
                local candidate = Layout.Rect(nextX, nextY, size, size)
                if available(candidate) then best, distance = candidate, cost end
            end
        end
    end
    return best
end

function Layout.WindowBody(width, height, top, padding, resize, compact, target)
    local footer = if resize and not compact then target + padding else 0
    return Layout.Rect(padding, top, math.max(0, width - 2 * padding), math.max(0, height - top - padding - footer))
end

function Layout.Navigation(profile, requested, width, height, target, count)
    if requested ~= "auto" then return requested end
    if count <= 1 then return "hidden" end
    if profile.compactChrome then
        if width >= 400 and height >= target * 2 + 24 then return "left" end
        return "bottom"
    end
    return profile.navigation
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
