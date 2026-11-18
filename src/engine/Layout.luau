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

function Layout.FloatingLimits(area, limits)
    -- Leave travel available even if the requested floating size exceeds the viewport.
    local spareWidth = math.min(48, math.floor(area.width * 0.1))
    local spareHeight = math.min(56, math.floor(area.height * 0.16))
    return {
        minWidth = limits.minWidth, minHeight = limits.minHeight,
        maxWidth = math.min(limits.maxWidth, area.width - spareWidth),
        maxHeight = math.min(limits.maxHeight, area.height - spareHeight),
    }
end

local panelAnchors = table.freeze({
    ["top-left"] = { 0, 0 }, top = { 0.5, 0 }, ["top-right"] = { 1, 0 },
    left = { 0, 0.5 }, center = { 0.5, 0.5 }, right = { 1, 0.5 },
    ["bottom-left"] = { 0, 1 }, bottom = { 0.5, 1 }, ["bottom-right"] = { 1, 1 },
})

function Layout.IsPanelAnchor(value)
    return type(value) == "string" and panelAnchors[value] ~= nil
end

function Layout.PanelPosition(area, width, height, position)
    if type(position) == "table" then return position.x, position.y end
    local anchor = panelAnchors[position or "center"]
    return area.x + (area.width - width) * anchor[1], area.y + (area.height - height) * anchor[2]
end

function Layout.OpenFloating(bounds, area, limits, position)
    local fitted = Layout.FloatingLimits(area, limits)
    local size = Layout.Clamp(Layout.Rect(area.x, area.y, bounds.width, bounds.height), area,
        fitted.minWidth, fitted.minHeight, fitted.maxWidth, fitted.maxHeight)
    local x, y = Layout.PanelPosition(area, size.width, size.height, position)
    return Layout.Rect(bounds.x or x, bounds.y or y, bounds.width, bounds.height)
end

function Layout.Window(rect, area, profile, placement, limits, fillCompact, travel)
    if placement == "fullscreen" or (profile.narrow and fillCompact) then return table.clone(area) end
    if placement == "left" or placement == "right" then
        if area.width < limits.minWidth * 2 + 8 then return table.clone(area) end
        local half = math.floor((area.width - 8) / 2)
        local x = if placement == "left" then area.x else area.x + area.width - half
        return Layout.Rect(x, area.y, half, area.height)
    end
    local fitted = Layout.FloatingLimits(area, limits)
    return Layout.Clamp(rect, travel or area, fitted.minWidth, fitted.minHeight, fitted.maxWidth, fitted.maxHeight)
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

function Layout.WindowPointerAllowed(x, y, top, lane)
    return y >= top or (lane ~= nil and x >= lane.x and x < lane.x + lane.width
        and y >= lane.y and y < lane.y + lane.height)
end

function Layout.WindowNeedsDragHandle(grip, top, lane)
    local right, bottom = grip.x + grip.width, grip.y + grip.height
    if bottom - math.max(grip.y, top) >= math.min(16, grip.height) then return false end
    if not lane then return true end
    local freeWidth = math.min(right, lane.x + lane.width) - math.max(grip.x, lane.x)
    local freeHeight = math.min(bottom, lane.y + lane.height) - math.max(grip.y, lane.y)
    return freeWidth < math.min(24, grip.width) or freeHeight < math.min(16, grip.height)
end

function Layout.WindowActionRail(maximum, hide, compact)
    local y = hide.y + hide.height / 2
    local right = hide.x + hide.width / 2
    local left = if maximum then maximum.x + maximum.width / 2 else right
    local pull = if maximum then math.min(8, (right - left) / 6) else 0
    local radius = if compact then 14 else 13
    return Layout.Rect(left + pull - radius, y - radius, right - left - 2 * pull + 2 * radius, 2 * radius), pull
end

function Layout.HeaderTitle(startX, endX, midpoint, alignment, wanted)
    local width = math.max(0, endX - startX)
    if alignment == "center" then
        local centered = math.min(midpoint - startX, endX - midpoint)
        if centered >= math.min(28, width / 2) then
            width = math.min(wanted, centered * 2)
            return midpoint - width / 2, width
        end
        return startX + math.max(0, (width - wanted) / 2), math.min(width, wanted)
    end
    local fitted = math.min(width, wanted)
    return if alignment == "right" then endX - fitted else startX, fitted
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

function Layout.ResizeGrip(profile)
    if not profile.touchLayout then return 24 end
    return if profile.narrow or profile.compactChrome then 30 else 40
end

function Layout.WindowBody(width, height, top, padding, footer)
    return Layout.Rect(padding, top, math.max(0, width - 2 * padding), math.max(0, height - top - padding - footer))
end

function Layout.TabLauncherLabel(visible, activeTitle)
    return if visible > 0 then "More" else (activeTitle or "Tabs")
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
