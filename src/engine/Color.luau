local Color = {}

function Color.IsHex(value)
    return type(value) == "string" and #value == 7 and value:match("^#%x%x%x%x%x%x$") ~= nil
end

function Color.Channels(hex)
    return tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16)
end

function Color.Mix(from, to, fraction)
    local r1, g1, b1 = Color.Channels(from)
    local r2, g2, b2 = Color.Channels(to)
    return string.format("#%02X%02X%02X",
        math.round(r1 + (r2 - r1) * fraction),
        math.round(g1 + (g2 - g1) * fraction),
        math.round(b1 + (b2 - b1) * fraction))
end

local function linear(channel)
    local value = channel / 255
    return if value <= 0.04045 then value / 12.92 else ((value + 0.055) / 1.055) ^ 2.4
end

local function luminance(hex)
    local r, g, b = Color.Channels(hex)
    return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
end

function Color.Contrast(foreground, background)
    local first, second = luminance(foreground), luminance(background)
    return (math.max(first, second) + 0.05) / (math.min(first, second) + 0.05)
end

function Color.Readable(background)
    return if Color.Contrast("#FFFFFF", background) > Color.Contrast("#000000", background)
        then "#FFFFFF" else "#000000"
end

function Color.EnsureContrast(foreground, background, minimum)
    if Color.Contrast(foreground, background) >= minimum then return foreground end
    local candidate = Color.Readable(background)
    local low, high = 0, 1
    for _ = 1, 10 do
        local middle = (low + high) / 2
        local mixed = Color.Mix(foreground, candidate, middle)
        if Color.Contrast(mixed, background) >= minimum then high = middle else low = middle end
    end
    return Color.Mix(foreground, candidate, high)
end

return table.freeze(Color)
