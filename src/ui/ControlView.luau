local Error = require(if script then script.Parent.Parent.core.Error else "../core/Error")
local Result = require(if script then script.Parent.Parent.core.Result else "../core/Result")
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
    if props.size or component.size or container._styleOverrides.size then defaults.textSize = nil end
    return StyleResolver.Resolve(theme, {
        input = if workspace._profile.touchLayout then "touch" else "pointer",
        role = definition.role, states = states,
        overrides = { framework = defaults, container = container._styleOverrides, component = component },
        accessibility = { fontScale = workspace._settings.fontScale, essentialBoundary = not display },
    })
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

local function row(scope, parent, order, interactive, choice, model)
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
        height = 0, padded = 0, iconWidth = 0, right = 0, markerWidth = 0,
    }
    local function arrange()
        local size = list.AbsoluteContentSize.Y
        local total = math.max(entry.height, size + entry.padded * 2)
        copy.Position = UDim2.fromOffset(entry.padded + entry.iconWidth, math.floor((total - size) / 2))
        copy.Size = UDim2.new(1, -(entry.padded * 2 + entry.iconWidth + entry.right), 0, size)
        if entry.iconWidth > 0 then
            local iconSize = entry.iconWidth - 8
            icon.Position = UDim2.fromOffset(entry.padded, math.floor((total - iconSize) / 2))
            icon.Size = UDim2.fromOffset(iconSize, iconSize)
        end
        marker.Position = UDim2.new(1, -entry.padded - entry.markerWidth, 0, 0)
        marker.Size = UDim2.fromOffset(entry.markerWidth, total)
        face.Size = UDim2.new(1, 0, 0, total)
    end
    entry.arrange = arrange
    scope:Give(list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(arrange))
    scope:Give(icon:GetPropertyChangedSignal("IsLoaded"):Connect(function() model:_render() end))
    local function state(key, active)
        entry[key] = active
        model:_render()
    end
    if interactive then
        scope:Give(face.Activated:Connect(function()
            state("pressed", false)
            model:_activate(if choice then choice.id else nil, "user")
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

local function stateMarker(definition, selected, props, inactive, choice)
    if definition.indicator == "toggle" then return if selected then "On" else "Off" end
    if definition.indicator == "checkbox" then return if selected then "✓" else "□" end
    if definition.indicator == "radio" then return if selected then "●" else "○" end
    if inactive and not choice then
        if props.loading then return "…" end
        if props.locked then return "🔒" end
    end
    return ""
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
    local style = styleFor(view._container, definition, props, {
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
    face.BackgroundTransparency = 1 - design.backgroundOpacity
    face.Shape.CornerRadius = UDim.new(0, design.radius)
    face.Edge.Enabled = design.focus ~= nil or design.borderWidth > 0
    face.Edge.Thickness = if design.focus then design.focus.width else design.borderWidth
    face.Edge.Color = Factory.Hex(if design.focus then design.focus.outer else design.stroke)
    local ink = Factory.Hex(design.foreground)
    local choice = entry.choice
    local showHint = not choice and props.tooltip and props.tooltip ~= ""
        and (entry.hovered or focused or workspace._profile.touchLayout)
    entry.title.Text, entry.title.RichText = label, definition.rich == true
    entry.detail.Text, entry.detail.Visible = description or "", description ~= nil and description ~= ""
    entry.hint.Text, entry.hint.Visible = props.tooltip or "", showHint == true
    entry.title.TextSize = design.textSize
    entry.detail.TextSize = math.max(12, math.floor(design.textSize * 0.82))
    entry.hint.TextSize = entry.detail.TextSize
    if definition.compact then
        entry.title.TextWrapped = false
        entry.title.TextTruncate = Enum.TextTruncate.AtEnd
        entry.title.AutomaticSize = Enum.AutomaticSize.None
        entry.title.Size = UDim2.new(1, 0, 0, design.textSize + 8)
    end
    local font = workspace._typography:ResolvePlan(design.typography)
    if font.ok then
        local fontFace = font.value.face
        local customFont = props.font or (props.style and props.style.font) or view._container._styleOverrides.font
        entry.title.FontFace = if definition.quote and not customFont
            then Font.new(fontFace.Family, fontFace.Weight, Enum.FontStyle.Italic) else fontFace
        entry.detail.FontFace = fontFace
        entry.hint.FontFace = fontFace
        entry.marker.FontFace = fontFace
    else
        model:_report(font.error)
    end
    for _, layer in ipairs({ entry.title, entry.detail, entry.hint, entry.marker }) do
        layer.TextColor3 = ink
    end
    local uri = not choice and ControlSpec.IconUri(props.icon)
    if entry.icon.Image ~= (uri or "") then entry.icon.Image = uri or "" end
    entry.icon.Visible = uri ~= nil and uri ~= false and entry.icon.IsLoaded
    entry.iconWidth = if entry.icon.Visible then design.iconSize + (definition.iconEmphasis or 0) + 8 else 0
    local marker = if display then "" else stateMarker(definition, selected, props, not active, choice)
    entry.marker.Text, entry.marker.Visible = marker, marker ~= ""
    entry.marker.TextSize = math.min(design.textSize, 20)
    entry.markerWidth = if marker == "" then 0 elseif definition.indicator == "toggle" then 38 else 27
    entry.right = if entry.markerWidth > 0 then entry.markerWidth + 6 else 0
    entry.padded = math.max(0, math.round(design.padding))
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
        if definition.quote and props.author and props.author ~= "" then subtitle = props.author end
    end
    paintRow(self, model, self._main, label, subtitle, value == true, definition.model == "display" or definition.group == true)
    for _, entry in ipairs(self._rows) do
        paintRow(self, model, entry, entry.choice.name, nil, value == entry.choice.id, false)
    end
    if self._divider then self._divider.BackgroundColor3 = self._main.face.Edge.Color end
end

function ControlView:CanInteract()
    return self._container._context.canInteract()
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
