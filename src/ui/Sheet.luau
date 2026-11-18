local Container = require(if script then script.Parent.Container else "./Container")
local Factory = require(if script then script.Parent.Parent.engine.Factory else "../engine/Factory")
local Layout = require(if script then script.Parent.Parent.engine.Layout else "../engine/Layout")
local Focus = require(if script then script.Parent.Parent.engine.Focus else "../engine/Focus")
local Sheet = {}
Sheet.__index = Sheet

function Sheet.new(workspace, options, owner)
    assert(options.title == nil or type(options.title) == "string", "Expected a sheet title")
    assert(options.action == nil or type(options.action) == "function", "Expected an action callback")
    assert(options.actionLabel == nil or type(options.actionLabel) == "string", "Expected an action label")
    local scope = workspace._scope:Fork()
    local theme = if owner then owner:_theme() else workspace.Themes:Get()
    local overlay = scope:Give(Factory.Frame(workspace._overlaysLayer, "Modal", {
        Size = UDim2.fromScale(1, 1), Active = true, BackgroundTransparency = 0.52,
        BackgroundColor3 = Factory.Hex(theme.tokens.backdrop),
    }))
    local card = Factory.Frame(overlay, "Sheet", {
        BackgroundTransparency = 0, ClipsDescendants = true, Active = true,
        SelectionGroup = true, SelectionBehaviorUp = Enum.SelectionBehavior.Stop,
        SelectionBehaviorDown = Enum.SelectionBehavior.Stop, SelectionBehaviorLeft = Enum.SelectionBehavior.Stop,
        SelectionBehaviorRight = Enum.SelectionBehavior.Stop,
    })
    local shape = Factory.Create("UICorner", card)
    local heading = Factory.Label(card, options.title or "Options", 18)
    heading.Font = Enum.Font.SourceSansBold
    local close = Factory.Button(card, "Close")
    local body = Factory.Scroll(card, "Body")
    Factory.Padding(body, 4)
    Factory.List(body, 8)
    local self = setmetatable({
        _workspace = workspace, _scope = scope, _owner = owner, _options = options,
        _overlay = overlay, _card = card, _shape = shape, _heading = heading,
        _close = close, _body = body, _controls = { close },
        _container = Container.new(body, scope), _previous = workspace._guiService.SelectedObject,
    }, Sheet)
    scope:Give(close.Activated:Connect(function()
        if workspace:_top() == self then self:Close() end
    end))
    if options.action then
        local done = Factory.Button(card, options.actionLabel or "Done")
        self._done = done
        table.insert(self._controls, done)
        scope:Give(done.Activated:Connect(function()
            if workspace:_top() ~= self then return end
            self:Close()
            workspace:_invoke(options.action)
        end))
    end
    return self
end

function Sheet:GetContent()
    assert(not self._closed, "Sheet is closed")
    return self._container
end

function Sheet:AddAction(text, callback)
    assert(type(text) == "string" and type(callback) == "function", "Expected a label and callback")
    local button = Factory.Button(nil, text)
    self:GetContent():Add(button)
    table.insert(self._controls, button)
    self._scope:Give(button.Activated:Connect(function()
        if self._workspace:_top() ~= self then return end
        self:Close()
        self._workspace:_invoke(callback)
    end))
    self:_reflow()
    return button
end

function Sheet:_selectNext(direction)
    local gui, candidates = self._workspace._guiService, {}
    for _, object in ipairs(self._card:GetDescendants()) do
        if object:IsA("GuiObject") and Focus.Eligible(object, self._card) then table.insert(candidates, object) end
    end
    if #candidates == 0 then return end
    table.sort(candidates, function(a, b)
        if a.AbsolutePosition.Y == b.AbsolutePosition.Y then return a.AbsolutePosition.X < b.AbsolutePosition.X end
        return a.AbsolutePosition.Y < b.AbsolutePosition.Y
    end)
    local index = table.find(candidates, gui.SelectedObject)
    gui.SelectedObject = if index then candidates[(index - 1 + direction) % #candidates + 1] else candidates[1]
end

function Sheet:_reflow()
    if self._closed then return end
    local workspace, owner = self._workspace, self._owner
    local theme = if owner then owner:_theme() else workspace.Themes:Get()
    local profile, area = workspace._profile, workspace._area
    local rect = Layout.Sheet(area, profile, self._options.width or 460, self._options.height or 390)
    local step, pad = workspace:_target(theme), 12
    local header = step + pad * 2
    local footer = if self._done then step + pad * 2 else 0
    Factory.Rect(self._card, rect.x, rect.y, rect.width, rect.height)
    Factory.Rect(self._body, pad, header, rect.width - 2 * pad, rect.height - header - pad - footer)
    if self._done then Factory.Rect(self._done, pad, rect.height - step - pad, rect.width - 2 * pad, step) end
    self._card.BackgroundColor3 = Factory.Hex(theme.tokens.popup)
    self._shape.CornerRadius = UDim.new(0, theme.radius)
    self._heading.TextColor3 = Factory.Hex(theme.tokens.onSurface)
    self._heading.TextSize = math.round(18 * workspace._settings.fontScale)
    for _, button in ipairs(self._controls) do
        if button ~= self._close and button ~= self._done then button.Size = UDim2.new(1, -4, 0, step) end
        Factory.StyleButton(button, theme, profile, { focused = workspace._guiService.SelectedObject == button },
            if button == self._done then "solid" else "soft", workspace._settings.fontScale)
    end
    local closeWidth = math.min(rect.width, workspace:_buttonWidth(self._close, step + 18))
    Factory.Rect(self._heading, pad, pad, rect.width - 3 * pad - closeWidth, step)
    Factory.Rect(self._close, math.max(0, rect.width - pad - closeWidth), pad, closeWidth, step)
end

function Sheet:Close()
    if self._closed then return end
    self._closed = true
    self._workspace:_finishSheet(self)
end

return table.freeze(Sheet)
