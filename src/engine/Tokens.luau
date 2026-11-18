local freeze = table.freeze
local sizes = {
    XS = { height = 24, text = 12, padding = 6, icon = 12 },
    S = { height = 30, text = 13, padding = 8, icon = 14 },
    M = { height = 36, text = 14, padding = 12, icon = 16 },
    L = { height = 44, text = 16, padding = 16, icon = 20 },
    XL = { height = 52, text = 18, padding = 20, icon = 24 },
    ["2XL"] = { height = 60, text = 20, padding = 24, icon = 28 },
}
for _, size in pairs(sizes) do freeze(size) end

return freeze({
    Spacing = freeze({ 0, 2, 4, 6, 8, 12, 16, 20, 24, 28, 32, 40, 48, 56, 64 }),
    Radii = freeze({ 0, 2, 4, 6, 8, 12, 16, 20, 24, 999 }),
    Sizes = freeze(sizes),
    Variants = freeze({
        solid = true, soft = true, ghost = true, outline = true, glass = true,
        neomorphic = true, brutalist = true, minimal = true,
    }),
    MinimumTouch = 44,
    NormalTextContrast = 4.5,
    NonTextContrast = 3,
})
