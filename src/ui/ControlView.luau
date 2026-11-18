local Error = require(if script then script.Parent.Parent.core.Error else "../core/Error")
local Result = require(if script then script.Parent.Parent.core.Result else "../core/Result")
local Color = require(if script then script.Parent.Parent.engine.Color else "../engine/Color")
local Factory = require(if script then script.Parent.Parent.engine.Factory else "../engine/Factory")
local Focus = require(if script then script.Parent.Parent.engine.Focus else "../engine/Focus")
local StyleResolver = require(if script then script.Parent.Parent.engine.StyleResolver else "../engine/StyleResolver")
local Viewport = require(if script then script.Parent.Parent.engine.Viewport else "../engine/Viewport")
local ControlSpec = require(if script then script.Parent.ControlSpec else "./ControlSpec")

local ControlView = {}
ControlView.__index = ControlView
local slotNames = { "Leading", "Main", "Trailing", "Footer" }

local function failed(code)
    return Result.Err(Error.Create(code))
end

local function styleFor(container, definition, props, states, display)
    local context = container._context
    local workspace = context.workspace
    local id = props.theme or container._themeOverride
    local theme = if id then workspace.Themes:Get(id) else context.theme()
    if not theme then return failed("THEME_NOT_FOUND") end
    local component = table.clone(props.style or {})
    if props.variant then component.variant = props.variant end
    if props.size then component.size = props.size end
    if props.font then component.font = props.font end
    local defaults = { variant = definition.style, textSize = definition.size }
    if not props.size and not component.size and not container._styleOverrides.size then
        defaults.padding = if definition.compact then 9 elseif definition.quote then 12 elseif display then 3 else 10
    end
    if props.size or component.size or container._styleOverrides.size then defaults.textSize = nil end
    return StyleResolver.Resolve(theme, {
        input = if workspace._profile.touchLayout then "touch" else "pointer",
        role = definition.role, states = states,
        overrides = { framework = defaults, container = container._styleOverrides, component = component },
        accessibility = { fontScale = workspace._settings.fontScale, essentialBoundary = false },
    }), theme
end

function ControlView.Validate(container, spec, props)
    local check = styleFor(container, spec.definition, props, {}, spec.definition.model == "display")
    return check.ok
end

local function text(parent, order)
    return Factory.Create("TextLabel", parent, {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = order,
        AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextTruncate = Enum.TextTruncate.None,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
        Text = "", TextSize = 16, ZIndex = 2,
    })
end

local function shape(parent, name, radius)
    local frame = Factory.Frame(parent, name, { BackgroundTransparency = 0, ZIndex = 3, Visible = false })
    local corner = Factory.Create("UICorner", frame, { CornerRadius = UDim.new(0, radius) })
    local stroke = Factory.Create("UIStroke", frame, { Enabled = false, Thickness = 1 })
    return frame, corner, stroke
end

local function indicator(parent, definition, interactive)
    if not interactive then return nil end
    local kind = definition.indicator or "action"
    local radius = if kind == "checkbox" then 4 else 20
    local body, _, edge = shape(parent, "Indicator", radius)
    local thumb = shape(body, "Mark", 20)
    local arm = if kind == "checkbox" or kind == "action" then shape(body, "TickEnd", 1) else nil
    return { body = body, edge = edge, thumb = thumb, arm = arm, kind = kind, width = 0, height = 0 }
end

local function paintIndicator(entry, design, theme, selected, active, show)
    local control = entry.indicator
    if not control then return end
    control.body.Visible = show
    if not show then return end

    local kind, edge, thumb = control.kind, control.edge, control.thumb
    local background = design.compositeBackground
    local accent = Color.EnsureContrast(theme.palette.accent, background, 3)
    local quiet = Color.EnsureContrast(theme.tokens.essentialStroke, background, 3)
    local tint = if active then accent else quiet
    local fill = if selected then tint else background
    local mark = Factory.Hex(Color.EnsureContrast(theme.tokens.accentOn, fill, 3))
    edge.Color = Factory.Hex(if selected then tint else quiet)
    edge.Enabled = not selected and kind ~= "action" or kind == "radio"
    control.body.BackgroundTransparency = if kind == "action" then 1 else 0
    control.body.BackgroundColor3 = Factory.Hex(if kind == "radio" then background else fill)
    thumb.Visible = selected or kind == "toggle" or kind == "action"
    thumb.BackgroundColor3 = if kind == "radio" then Factory.Hex(tint) elseif kind == "action" then Factory.Hex(design.foreground) else mark
    if kind == "toggle" then
        control.width, control.height = 34, 19
        Factory.Rect(thumb, if selected then 17 else 3, 3, 13, 13)
    elseif kind == "radio" then
        control.width, control.height = 18, 18
        Factory.Rect(thumb, 5, 5, 8, 8)
    elseif kind == "checkbox" then
        control.width, control.height = 18, 18
        Factory.Rect(thumb, 4, 9, 5, 2)
        thumb.Rotation = 45
        Factory.Rect(control.arm, 7, 8, 8, 2)
        control.arm.Rotation = -45
    else
        control.width, control.height = 15, 18
        Factory.Rect(thumb, 4, 6, 6, 2)
        thumb.Rotation = 45
        Factory.Rect(control.arm, 4, 10, 6, 2)
        control.arm.Rotation = -45
    end
    if control.arm then
        control.arm.BackgroundColor3 = thumb.BackgroundColor3
        control.arm.Visible = thumb.Visible
    end
end

local function row(scope, parent, order, interactive, choice, model)
    local definition = model._spec.definition
    local face
    if interactive then
        face = Factory.Button(parent, "")
    else
        face = Factory.Frame(parent, "Content")
        Factory.Create("UICorner", face, { Name = "Shape" })
        Factory.Create("UIStroke", face, { Name = "Edge", ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
    end
    face.LayoutOrder = order
    face.Size = UDim2.new(1, 0, 0, 0)
    local copy = Factory.Frame(face, "Text", { ZIndex = 2 })
    local list = Factory.List(copy, 2)
    local title, detail, hint = text(copy, 1), text(copy, 2), text(copy, 3)
    local icon = Factory.Create("ImageLabel", face, {
        Name = "Icon", BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, Visible = false, ZIndex = 2,
    })
    local marker = text(face, 1)
    marker.AutomaticSize = Enum.AutomaticSize.None
    marker.TextWrapped = false
    marker.TextXAlignment = Enum.TextXAlignment.Center
    local entry = {
        face = face, copy = copy, list = list, title = title, detail = detail, hint = hint,
        icon = icon, marker = marker, choice = choice, interactive = interactive,
        indicator = indicator(face, definition, interactive),
        height = 0, padded = 0, vertical = 0, iconWidth = 0, right = 0, markerWidth = 0,
    }
    if definition.compact then
        entry.chip, entry.chipCorner, entry.chipStroke = shape(face, "Chip", 12)
        entry.chip.ZIndex = 1
    elseif definition.quote then
        entry.rule = shape(face, "QuoteRule", 2)
        entry.rule.ZIndex = 1
    end
    local function arrange()
        local size = list.AbsoluteContentSize.Y
        local total = math.max(entry.height, size + entry.vertical * 2)
        copy.Position = UDim2.fromOffset(entry.padded + entry.iconWidth, math.floor((total - size) / 2))
        copy.Size = UDim2.new(1, -(entry.padded * 2 + entry.iconWidth + entry.right), 0, size)
        if entry.iconWidth > 0 then
            local iconSize = entry.iconWidth - 8
            icon.Position = UDim2.fromOffset(entry.padded, math.floor((total - iconSize) / 2))
            icon.Size = UDim2.fromOffset(iconSize, iconSize)
        end
        marker.Position = UDim2.new(1, -entry.padded - entry.markerWidth, 0, 0)
        marker.Size = UDim2.fromOffset(entry.markerWidth, total)
        local visual = entry.indicator
        if visual and visual.body.Visible then
            visual.body.Position = UDim2.new(1, -entry.padded - visual.width, 0, math.floor((total - visual.height) / 2))
            visual.body.Size = UDim2.fromOffset(visual.width, visual.height)
        end
        if entry.chip then
            local measured = math.max(title.TextBounds.X, detail.TextBounds.X, hint.TextBounds.X)
            local preferred = measured + entry.padded * 2 + entry.iconWidth
            Factory.Rect(entry.chip, 0, 0, math.min(face.AbsoluteSize.X, preferred), total)
        elseif entry.rule then
            Factory.Rect(entry.rule, 1, 3, 2, math.max(0, total - 6))
        end
        face.Size = UDim2.new(1, 0, 0, total)
    end
    entry.arrange = arrange
    scope:Give(list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(arrange))
    if entry.chip then
        scope:Give(face:GetPropertyChangedSignal("AbsoluteSize"):Connect(arrange))
        for _, label in ipairs({ title, detail, hint }) do
            scope:Give(label:GetPropertyChangedSignal("TextBounds"):Connect(arrange))
        end
    end
    scope:Give(icon:GetPropertyChangedSignal("IsLoaded"):Connect(function() model:_render() end))
    local function state(key, active)
        entry[key] = active
        model:_render()
    end
    if interactive then
        scope:Give(face.Activated:Connect(function(input)
            state("pressed", false)
            model:_activate(if choice then choice.id else nil, "user", input)
        end))
        scope:Give(face.MouseEnter:Connect(function() state("hovered", true) end))
        scope:Give(face.MouseLeave:Connect(function()
            entry.pressed = false
            state("hovered", false)
        end))
        scope:Give(face.MouseButton1Down:Connect(function() state("pressed", true) end))
        scope:Give(face.MouseButton1Up:Connect(function() state("pressed", false) end))
        scope:Give(face.SelectionGained:Connect(function()
            model:_render()
            model._focused:Fire(if choice then choice.id else nil, model)
        end))
        scope:Give(face.SelectionLost:Connect(function()
            entry.pressed = false
            model:_render()
            model._blurred:Fire(if choice then choice.id else nil, model)
        end))
    end
    return entry
end

local function slotsFor(scope, root)
    local layers = {
        Background = Factory.Frame(root, "Background", { Size = UDim2.fromScale(1, 1), ZIndex = 1 }),
        Overlay = Factory.Frame(root, "Overlay", { Size = UDim2.fromScale(1, 1), ZIndex = 5 }),
    }
    local stack = Factory.Frame(root, "Stack", {
        Size = UDim2.new(1, 0, 0, 0), ZIndex = 2, AutomaticSize = Enum.AutomaticSize.Y,
    })
    local order = Factory.List(stack, 5)
    for index, name in ipairs(slotNames) do
        local layer = Factory.Frame(stack, name, {
            Size = UDim2.new(1, 0, 0, 0), LayoutOrder = index, AutomaticSize = Enum.AutomaticSize.Y, Visible = false,
        })
        layers[name] = layer
        Factory.List(layer, 6)
        local function sync()
            layer.Visible = layer:FindFirstChildWhichIsA("GuiObject") ~= nil
        end
        scope:Give(layer.ChildAdded:Connect(sync))
        scope:Give(layer.ChildRemoved:Connect(sync))
    end
    scope:Give(order:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        root.Size = UDim2.new(1, 0, 0, order.AbsoluteContentSize.Y)
    end))
    return layers
end

function ControlView.new(container, model)
    local definition, scope = model._spec.definition, model._scope
    local root = scope:Give(Factory.Frame(nil, model.Kind, { Size = UDim2.new(1, 0, 0, 0) }))
    local slots = slotsFor(scope, root)
    local self = setmetatable({
        _root = root, _slots = slots, _container = container, _model = model, _rows = {},
    }, ControlView)
    self._main = row(scope, slots.Main, 1, definition.model ~= "display" and not definition.group, nil, model)
    if definition.group then
        for index, choice in ipairs(model._spec.choices) do
            self._rows[index] = row(scope, slots.Main, index + 1, true, choice, model)
        end
    end
    if definition.divider then
        self._divider = Factory.Frame(slots.Main, "Line", {
            LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 1), BackgroundTransparency = 0,
        })
    end
    container:Add(root, model._props.slot)
    container:_ownControl(self)
    scope:Give(function() self._container:_releaseControl(self) end)
    scope:Give(root.Destroying:Connect(function() model:Destroy() end))
    local changed = container._context.workspace._componentChanged
    scope:Give(changed:Connect(function(owner)
        if not owner or self._container._context.owner == owner then model:_render() end
    end))
    return self
end

local function paintRow(view, model, entry, label, description, selected, display)
    local definition, props = model._spec.definition, model._props
    local workspace = view._container._context.workspace
    local current = workspace._guiService.SelectedObject
    local optionDisabled = entry.choice and entry.choice.disabled
    local disabled = model._disabled or optionDisabled == true
    local active = not disabled and not model._locked and not props.loading and model._visible
    local face = entry.face
    local canSelect = entry.interactive and active
    if entry.interactive then
        face.Selectable, face.Interactable, face.Active = canSelect, canSelect, canSelect
    end
    local focused = current == face and canSelect
    if current == face and not canSelect then
        workspace._guiService.SelectedObject = nil
    end
    local style, theme = styleFor(view._container, definition, props, {
        disabled = disabled, locked = model._locked, loading = props.loading,
        selected = selected, focused = focused, hovered = active and entry.hovered == true,
        pressed = active and entry.pressed == true,
    }, display)
    if not style.ok then
        model:_report(style.error)
        return
    end
    local design = style.value
    face.BackgroundColor3 = Factory.Hex(design.background)
    face.BackgroundTransparency = if entry.chip then 1 else 1 - design.backgroundOpacity
    local radius = if props.style and props.style.radius ~= nil or view._container._styleOverrides.radius ~= nil
        then design.radius else math.min(design.radius, 9)
    local strokeColor = Factory.Hex(if design.focus then design.focus.outer else design.stroke)
    face.Shape.CornerRadius = UDim.new(0, radius)
    face.Edge.Enabled = not entry.chip and (design.focus ~= nil or design.borderWidth > 0)
    face.Edge.Thickness = if design.focus then design.focus.width else design.borderWidth
    face.Edge.Color = strokeColor
    if entry.chip then
        entry.chip.Visible = label ~= "" or (description ~= nil and description ~= "")
        entry.chip.BackgroundTransparency = 1 - design.backgroundOpacity
        entry.chip.BackgroundColor3 = face.BackgroundColor3
        entry.chipCorner.CornerRadius = UDim.new(0, if props.style and props.style.radius ~= nil then radius else 20)
        entry.chipStroke.Enabled = design.borderWidth > 0
        entry.chipStroke.Thickness, entry.chipStroke.Color = design.borderWidth, strokeColor
    elseif entry.rule then
        entry.rule.Visible = true
        entry.rule.BackgroundColor3 = Factory.Hex(theme.palette.accent)
    end
    local muted = Color.EnsureContrast(Color.Mix(design.foreground, design.compositeBackground, 0.23), design.compositeBackground, 4.5)
    local ink = Factory.Hex(if definition.muted then muted else design.foreground)
    local secondary = Factory.Hex(muted)
    local choice = entry.choice
    local showHint = not choice and props.tooltip and props.tooltip ~= ""
        and (entry.hovered or focused or workspace._profile.touchLayout)
    entry.title.Text, entry.title.RichText = label, definition.rich == true
    entry.detail.Text, entry.detail.Visible = description or "", description ~= nil and description ~= ""
    entry.hint.Text, entry.hint.Visible = props.tooltip or "", showHint == true
    entry.title.TextSize = design.textSize
    entry.detail.TextSize = math.max(12, math.floor(design.textSize * 0.82))
    entry.hint.TextSize = entry.detail.TextSize
    if entry.chip then
        entry.title.TextWrapped = false
        entry.title.TextTruncate = Enum.TextTruncate.AtEnd
        entry.title.AutomaticSize = Enum.AutomaticSize.None
        entry.title.Size = UDim2.new(1, 0, 0, design.textSize + 4)
    end
    local font = workspace._typography:ResolvePlan(design.typography)
    if font.ok then
        local fontFace = font.value.face
        local customFont = props.font or (props.style and props.style.font) or view._container._styleOverrides.font
        if not customFont and definition.quote then
            entry.title.FontFace = Font.new(fontFace.Family, fontFace.Weight, Enum.FontStyle.Italic)
        elseif not customFont and (definition.compact or definition.model == "action" or definition.group and not choice) then
            entry.title.FontFace = Font.new(fontFace.Family, Enum.FontWeight.SemiBold, fontFace.Style)
        else
            entry.title.FontFace = fontFace
        end
        entry.detail.FontFace = fontFace
        entry.hint.FontFace = fontFace
        entry.marker.FontFace = fontFace
    else
        model:_report(font.error)
    end
    entry.title.TextColor3, entry.marker.TextColor3 = ink, ink
    entry.detail.TextColor3, entry.hint.TextColor3 = secondary, secondary
    local uri = not choice and ControlSpec.IconUri(props.icon)
    if entry.icon.Image ~= (uri or "") then entry.icon.Image = uri or "" end
    entry.icon.Visible = uri ~= nil and uri ~= false and entry.icon.IsLoaded
    entry.iconWidth = if entry.icon.Visible then design.iconSize + (definition.iconEmphasis or 0) + 8 else 0
    local marker = if entry.interactive and props.loading then "…" elseif entry.interactive and model._locked then "Locked" else ""
    entry.marker.Text, entry.marker.Visible = marker, marker ~= ""
    entry.marker.TextSize = if marker == "Locked" then 12 else math.min(design.textSize, 20)
    entry.markerWidth = if marker == "Locked" then 45 elseif marker == "" then 0 else 23
    local showIndicator = entry.interactive and marker == "" and (definition.indicator ~= nil or not entry.icon.Visible)
    paintIndicator(entry, design, theme, selected, active, showIndicator)
    local markerWidth = if showIndicator then entry.indicator.width else entry.markerWidth
    entry.right = if markerWidth > 0 then markerWidth + 10 else 0
    entry.padded = math.max(0, math.round(design.padding))
    entry.vertical = if entry.chip then 4 elseif display then math.min(entry.padded, 6) else math.min(entry.padded, 8)
    entry.height = if display then 0 else design.minHeight
    entry.arrange()
end

function ControlView:Render(model)
    self._root.Visible = model._visible
    local definition, props, value = model._spec.definition, model._props, model._value
    local label, subtitle = props.name, props.description
    if definition.model == "display" then
        label = if definition.metric then tostring(value) .. (if props.unit and props.unit ~= "" then " " .. props.unit else "")
            elseif definition.rich then ControlSpec.SafeRichText(value)
            else value
        if definition.metric then subtitle = if props.name ~= "" then props.name else subtitle end
        if definition.quote and props.author and props.author ~= "" then subtitle = "— " .. props.author end
    end
    paintRow(self, model, self._main, label, subtitle, value == true, definition.model == "display" or definition.group == true)
    for _, entry in ipairs(self._rows) do
        paintRow(self, model, entry, entry.choice.name, nil, value == entry.choice.id, false)
    end
    if self._divider then self._divider.BackgroundColor3 = self._main.face.Edge.Color end
end

function ControlView:CanInteract(input)
    return self._container._context.canInteract(input)
end

function ControlView:GetSlot(name)
    return self._slots[name or "Main"]
end

function ControlView:SetOrder(value)
    self._root.LayoutOrder = value
    self._container._order = math.max(self._container._order, value)
    return Result.Ok(self._model)
end

function ControlView:MoveStep(direction)
    local root = self._root
    if not root.Parent then return failed("DISPOSED") end
    local nearest
    for _, sibling in ipairs(root.Parent:GetChildren()) do
        if sibling:IsA("GuiObject") then
            local distance = (sibling.LayoutOrder - root.LayoutOrder) * direction
            if distance > 0 and (not nearest or distance < (nearest.LayoutOrder - root.LayoutOrder) * direction) then
                nearest = sibling
            end
        end
    end
    if nearest then root.LayoutOrder, nearest.LayoutOrder = nearest.LayoutOrder, root.LayoutOrder end
    return Result.Ok(self._model)
end

function ControlView:MoveTo(container, slot)
    local previous = self._container
    if type(container) ~= "table" or not container._controls or not container._context
        or container._context.workspace ~= previous._context.workspace
        or type(container.GetSlot) ~= "function" then return failed("INVALID_ARGUMENT") end
    local target = container:GetSlot(slot)
    if not target or not target.Parent or target:IsDescendantOf(self._root) then return failed("INVALID_VALUE") end
    if not ControlView.Validate(container, self._model._spec, self._model._props) then return failed("INVALID_VALUE") end
    container:Add(self._root, slot)
    if previous ~= container then
        self._container = container
        self._model._context.container = container
        previous:_releaseControl(self)
        container:_ownControl(self)
    end
    self._model:_render()
    return Result.Ok(self._model)
end

function ControlView:Focus(model, selectTarget)
    local workspace = self._container._context.workspace
    local gui = workspace._guiService
    if not selectTarget then
        local previous = gui.SelectedObject
        if previous and previous:IsDescendantOf(self._root) then gui.SelectedObject = nil end
        return Result.Ok(model)
    end
    local face = self._main.face
    for _, entry in ipairs(self._rows) do
        if entry.choice.id == model._value then
            face = entry.face
            break
        end
    end
    if not self:CanInteract() or not Focus.Eligible(face, workspace._root) then
        return failed("CONTROL_INACTIVE")
    end
    gui.SelectedObject = face
    Viewport.Reveal(face)
    return Result.Ok(model)
end

return table.freeze(ControlView)
