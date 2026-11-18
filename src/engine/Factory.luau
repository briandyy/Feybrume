local StyleResolver = require(if script then script.Parent.StyleResolver else "./StyleResolver")
local Factory = {}
local buttonMeasurements = setmetatable({}, { __mode = "k" })

function Factory.Create(className, parent, properties)
    local node = Instance.new(className)
    for key, value in pairs(properties or {}) do node[key] = value end
    node.Parent = parent
    return node
end

function Factory.Hex(value)
    return Color3.fromHex(value:sub(2))
end

function Factory.Rect(node, x, y, w, h)
    node.Position = UDim2.fromOffset(x, y)
    node.Size = UDim2.fromOffset(math.max(0, w), math.max(0, h))
end

function Factory.Frame(parent, name, properties)
    local props = table.clone(properties or {})
    props.Name, props.BorderSizePixel = name, 0
    if props.BackgroundTransparency == nil then props.BackgroundTransparency = 1 end
    return Factory.Create("Frame", parent, props)
end

function Factory.List(parent, gap)
    return Factory.Create("UIListLayout", parent, {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, gap or 8),
    })
end

function Factory.Padding(parent, amount)
    local inset = UDim.new(0, amount)
    return Factory.Create("UIPadding", parent, {
        PaddingLeft = inset, PaddingRight = inset, PaddingTop = inset, PaddingBottom = inset,
    })
end

function Factory.Scroll(parent, name)
    return Factory.Create("ScrollingFrame", parent, {
        Name = name, BackgroundTransparency = 1, BorderSizePixel = 0,
        CanvasSize = UDim2.fromOffset(0, 0), Active = true,
        AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
        ScrollBarThickness = 4,
    })
end

function Factory.Label(parent, text, size)
    return Factory.Create("TextLabel", parent, {
        Text = text, TextSize = size or 14, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
    })
end

function Factory.Button(parent, text)
    local node = Factory.Create("TextButton", parent, {
        Text = text, AutoButtonColor = false, Active = true, Selectable = true,
        TextTruncate = Enum.TextTruncate.AtEnd, BorderSizePixel = 0,
    })
    Factory.Create("UICorner", node, { Name = "Shape" })
    Factory.Create("UIStroke", node, { Name = "Edge", ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
    return node
end

function Factory.StyleButton(node, theme, profile, states, variant, fontScale)
    local design = StyleResolver.Resolve(theme, {
        input = if profile.touchLayout then "touch" else "pointer",
        states = states,
        overrides = { component = { variant = variant or "soft", size = "M" } },
        accessibility = { fontScale = fontScale },
    })
    if not design.ok then return end
    local style = design.value
    node.BackgroundColor3 = Factory.Hex(style.background)
    node.BackgroundTransparency = 1 - style.backgroundOpacity
    node.TextColor3 = Factory.Hex(style.foreground)
    node.TextSize = style.textSize
    node.Shape.CornerRadius = UDim.new(0, style.radius)
    node.Edge.Enabled = style.focus ~= nil or style.borderWidth > 0
    node.Edge.Thickness = if style.focus then style.focus.width else style.borderWidth
    node.Edge.Color = Factory.Hex(if style.focus then style.focus.outer else style.stroke)
end

function Factory.ButtonWidth(button, measure, preferredSize, minimum)
    local text, size, font = button.Text, button.TextSize, button.Font
    local measured = buttonMeasurements[button]
    if not measured or measured.text ~= text or measured.size ~= size or measured.font ~= font
        or measured.preferredSize ~= preferredSize then
        local width = measure(text, size, font)
        measured = { text = text, size = size, font = font, preferredSize = preferredSize, width = width }
        buttonMeasurements[button] = measured
    end
    return math.max(minimum, math.ceil(measured.width) + 16)
end

return table.freeze(Factory)
