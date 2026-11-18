local Layout = require(if script then script.Parent.Parent.engine.Layout else "../engine/Layout")
local Input = require(if script then script.Parent.Parent.engine.Input else "../engine/Input")
local Viewport = require(if script then script.Parent.Parent.engine.Viewport else "../engine/Viewport")
local Factory = require(if script then script.Parent.Parent.engine.Factory else "../engine/Factory")
local Focus = require(if script then script.Parent.Parent.engine.Focus else "../engine/Focus")
local Theme = require(if script then script.Parent.Parent.engine.Theme else "../engine/Theme")
local Runtime = require(if script then script.Parent.Parent.core.Runtime else "../core/Runtime")
local Result = require(if script then script.Parent.Parent.core.Result else "../core/Result")
local Window = require(if script then script.Parent.Window else "./Window")
local Sheet = require(if script then script.Parent.Sheet else "./Sheet")
local Workspace = {}
Workspace.__index = Workspace

local workspaceCount = 0
local modalOwner

local function finite(value)
    return type(value) == "number" and math.abs(value) < math.huge
end

local function settings(options)
    local side = options.reopenSide or "right"
    assert(side == "left" or side == "right", "Expected left or right reopen side")
    local scale = options.fontScale or 1
    assert(finite(scale) and scale >= 0.8 and scale <= 2, "Font scale must be 0.8 to 2")
    local count, reserved = 0, {}
    for _, rect in ipairs(options.reserved or {}) do
        count += 1
        assert(count <= 24 and type(rect) == "table" and finite(rect.x) and finite(rect.y)
            and finite(rect.width) and finite(rect.height) and rect.width >= 0 and rect.height >= 0,
            "Expected up to 24 reserved rectangles")
        table.insert(reserved, Layout.Rect(rect.x, rect.y, rect.width, rect.height))
    end
    return {
        side = side, fontScale = scale, reserved = reserved,
        avoidMovement = options.avoidMovementControls ~= false,
        breakpoints = Layout.ValidateBreakpoints(options.breakpoints or {}),
    }
end

local function hostParent(runtime, requested)
    if requested then return requested end
    local player = runtime.Services:Get("Players").LocalPlayer
    assert(player, "Create a workspace from a client LocalScript")
    return player:WaitForChild("PlayerGui")
end

function Workspace.new(options)
    options = options or {}
    assert(type(options) == "table", "Expected workspace options")
    local config = settings(options)
    local ownsRuntime = options.runtime == nil
    local runtime = options.runtime or Runtime.Create()
    local input = runtime.Services:Get("UserInputService")
    local parent = hostParent(runtime, options.parent)
    assert(parent:IsA("PlayerGui"), "The workspace parent must be a PlayerGui")
    local guiService, actions = runtime.Services:Get("GuiService"), runtime.Services:Get("ContextActionService")
    local textService = runtime.Services:Get("TextService")
    local unconstrainedText = Vector2.new(math.huge, math.huge)
    local scope = runtime.Scope:Fork()
    local themes = scope:Give(Theme.new({ clock = runtime.Clock, initial = options.theme }))
    workspaceCount += 1
    local self = setmetatable({
        Runtime = runtime, Themes = themes, _scope = scope, _ownsRuntime = ownsRuntime, _settings = config,
        _guiService = guiService, _actions = actions, _userInput = input, _windows = {}, _modal = {},
        _measureText = function(text, size, font)
            return textService:GetTextSize(text, size, font, unconstrainedText).X
        end,
        _area = Layout.Rect(0, 0, 0, 0), _profile = Layout.Profile(0, 0, "pointer", config.breakpoints),
        _actionName = "FeybrumeSheet" .. tostring(workspaceCount),
    }, Workspace)
    local screen = scope:Give(Factory.Create("ScreenGui", parent, {
        Name = options.name or "FeybrumeWorkspace", ResetOnSpawn = false,
        ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets, ClipToDeviceSafeArea = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = options.displayOrder or 10,
    }))
    self._screen = screen
    self._root = Factory.Frame(screen, "SafeArea", { Size = UDim2.fromScale(1, 1) })
    self._windowsLayer = Factory.Frame(self._root, "Windows", { Size = UDim2.fromScale(1, 1), ZIndex = 1 })
    self._bubblesLayer = Factory.Frame(self._root, "Reopen", { Size = UDim2.fromScale(1, 1), ZIndex = 2 })
    self._overlaysLayer = Factory.Frame(self._root, "Overlays", { Size = UDim2.fromScale(1, 1), ZIndex = 3 })
    self._input = Input.new(input, scope)
    runtime.Scope:Give(self, nil, self)
    scope:Give(screen.Destroying:Connect(function() self:Destroy() end))
    scope:Give(themes:Subscribe(function() self:_refresh() end))
    Viewport.Observe(scope, self._root, input, function()
        self._input:Cancel()
        self:_refresh()
    end)
    scope:Give(input.TextBoxFocused:Connect(function() Viewport.RevealFocused(self._root, input) end))
    scope:Give(guiService:GetPropertyChangedSignal("PreferredTextSize"):Connect(function() self:_refresh() end))
    scope:Give(guiService:GetPropertyChangedSignal("SelectedObject"):Connect(function()
        local top = self:_top()
        if top then
            local selected = guiService.SelectedObject
            if selected and not selected:IsDescendantOf(top._card) then Focus.Restore(guiService, top._card, nil, top._close) end
            top:_reflow()
        elseif guiService.SelectedObject then
            local selected = guiService.SelectedObject
            for _, window in ipairs(self._windows) do
                if selected:IsDescendantOf(window._shell) then
                    self:_raise(window)
                    break
                end
            end
        end
    end))
    self:_refresh()
    return self
end

function Workspace:_target(theme)
    return if self._profile.touch or self._profile.narrow then
        math.max(44, theme.touch.minimumHitTarget, math.ceil(16 * self._settings.fontScale) + 12)
        else math.max(36, math.ceil(16 * self._settings.fontScale) + 12)
end

function Workspace:_buttonWidth(button, minimum)
    return Factory.ButtonWidth(button, self._measureText, self._guiService.PreferredTextSize, minimum)
end

function Workspace:_assertLive()
    assert(not self._destroyed, "Workspace is destroyed")
end

function Workspace:_invoke(callback)
    local result = Result.CallSync(callback)
    if not result.ok and not self._destroyed then self.Runtime.Diagnostics:Push(result.error) end
end

function Workspace:_refresh()
    if self._destroyed then return end
    self._area, self._profile, self._origin = Viewport.Read(self._root, self._userInput, self._settings.breakpoints)
    for _, window in ipairs(self._windows) do window:_reflow() end
    for _, sheet in ipairs(self._modal) do sheet:_reflow() end
    self:_placeBubbles()
    Viewport.RevealFocused(self._root, self._userInput)
end

function Workspace:_placeBubbles()
    if self._destroyed then return end
    local area = self._area
    local reserved = table.clone(self._settings.reserved)
    if self._profile.touch and self._settings.avoidMovement and not self._userInput.OnScreenKeyboardVisible then
        local w, h = math.min(138, area.width / 2), math.min(142, area.height / 2)
        table.insert(reserved, Layout.Rect(area.x, area.y + area.height - h, w, h))
        table.insert(reserved, Layout.Rect(area.x + area.width - w, area.y + area.height - h, w, h))
    end
    for _, window in ipairs(self._windows) do
        local button = window._bubble
        if window._open or self:_hasModal() or math.min(area.width, area.height) < 44 then
            button.Visible, window._bubbleRect = false, nil
        else
            local theme = window:_theme()
            local size = math.max(52, self:_target(theme))
            local y = window._bubbleY or (area.y + area.height * 0.55)
            local rect = window._bubbleDragging or Layout.Bubble(area, reserved, window._side, y, size)
            if not rect then rect = Layout.Bubble(area, {}, window._side, area.y, size) end
            window._bubbleRect = rect
            button.Visible = rect ~= nil
            if rect then
                Factory.Rect(button, rect.x, rect.y, rect.width, rect.height)
                Factory.StyleButton(button, theme, self._profile, { focused = self._guiService.SelectedObject == button },
                    "solid", self._settings.fontScale)
                button.Shape.CornerRadius = UDim.new(0.5, 0)
                table.insert(reserved, rect)
            end
        end
    end
end

function Workspace:_raise(window)
    local index = table.find(self._windows, window)
    if not index then return end
    table.remove(self._windows, index)
    table.insert(self._windows, window)
    for order, candidate in ipairs(self._windows) do candidate._shell.ZIndex = order end
end

function Workspace:_forget(window)
    local index = table.find(self._windows, window)
    if index then table.remove(self._windows, index) end
    self:_placeBubbles()
end

function Workspace:Window(options)
    self:_assertLive()
    options = options or {}
    assert(type(options) == "table", "Expected window options")
    if options.id then
        for _, existing in ipairs(self._windows) do assert(existing._options.id ~= options.id, "Duplicate window ID") end
    end
    local window = Window.new(self, options)
    table.insert(self._windows, window)
    self:_raise(window)
    window:_reflow()
    return window
end

function Workspace:SetTheme(id)
    self:_assertLive()
    return self.Themes:Set(id)
end

function Workspace:RegisterTheme(specification)
    self:_assertLive()
    return self.Themes:Register(specification)
end

function Workspace:SetReopenSide(side)
    self:_assertLive()
    assert(side == "left" or side == "right", "Expected left or right")
    self._settings.side = side
    for _, window in ipairs(self._windows) do window._side = side end
    self:_placeBubbles()
end

function Workspace:GetViewport()
    return table.freeze(table.clone(self._area)), table.freeze(table.clone(self._profile))
end

function Workspace:_top()
    return self._modal[#self._modal]
end

function Workspace:_hasModal()
    return self:_top() ~= nil
end

function Workspace:_setShortcuts(active)
    if self._shortcuts == active then return end
    self._shortcuts = active
    if not active then
        self._actions:UnbindAction(self._actionName)
        return
    end
    self._actions:BindActionAtPriority(self._actionName, function(_, state, object)
        local sheet = self:_top()
        if modalOwner ~= self or not sheet or self._userInput:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
        if state == Enum.UserInputState.Begin then
            if object.KeyCode == Enum.KeyCode.Tab then
                local backwards = self._userInput:IsKeyDown(Enum.KeyCode.LeftShift)
                    or self._userInput:IsKeyDown(Enum.KeyCode.RightShift)
                sheet:_selectNext(if backwards then -1 else 1)
            else
                sheet:Close()
            end
        end
        return Enum.ContextActionResult.Sink
    end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Escape, Enum.KeyCode.ButtonB, Enum.KeyCode.Tab)
end

function Workspace:_openSheet(options, owner)
    self:_assertLive()
    assert(type(options) == "table", "Expected sheet options")
    local previous = self:_top()
    for _, prop in ipairs({ "width", "height" }) do
        assert(options[prop] == nil or (finite(options[prop]) and options[prop] > 0), "Invalid sheet dimension")
    end
    local sheet = Sheet.new(self, table.clone(options), owner)
    if modalOwner and modalOwner ~= self then
        local other = modalOwner
        while other:_top() do other:_top():Close() end
    end
    modalOwner = self
    table.insert(self._modal, sheet)
    if previous then previous._overlay.Visible = false end
    sheet._overlay.ZIndex = #self._modal + 1
    self._input:Suspend(true)
    self:_placeBubbles()
    self:_setShortcuts(true)
    local editor = self._userInput:GetFocusedTextBox()
    if editor and editor:IsDescendantOf(self._root) then editor:ReleaseFocus() end
    sheet:_reflow()
    if sheet._previous or self._userInput.PreferredInput == Enum.PreferredInput.Gamepad then
        Focus.Restore(self._guiService, sheet._card, nil, sheet._close)
    end
    return sheet
end

function Workspace:OpenSheet(options)
    return self:_openSheet(options or {}, nil)
end

function Workspace:_openMenu(owner, items, options)
    assert(type(items) == "table" and #items > 0, "Expected menu items")
    for _, item in ipairs(items) do
        assert(type(item) == "table" and type(item.label) == "string" and type(item.callback) == "function",
            "Expected a menu label and callback")
    end
    local sheet = self:_openSheet({ title = options.title or "Actions", width = 350, height = math.min(420, 98 + #items * 56) }, owner)
    for _, item in ipairs(items) do sheet:AddAction(item.label, item.callback) end
    return sheet
end

function Workspace:_finishSheet(sheet)
    local index = table.find(self._modal, sheet)
    if not index then return end
    local wasTop = index == #self._modal
    local prior = self._modal[index + 1]
    if prior and prior._previous and prior._previous:IsDescendantOf(sheet._card) then prior._previous = sheet._previous end
    table.remove(self._modal, index)
    sheet._scope:Destroy()
    if not wasTop or self._destroyed then return end

    local top = self:_top()
    if not top and modalOwner == self then modalOwner = nil end
    self._input:Suspend(top ~= nil)
    self:_setShortcuts(top ~= nil)
    self:_placeBubbles()
    if top then
        top._overlay.Visible = true
        top:_reflow()
        if sheet._previous or self._userInput.PreferredInput == Enum.PreferredInput.Gamepad then
            Focus.Restore(self._guiService, top._card, sheet._previous, top._close)
        end
    else
        local selected = self._guiService.SelectedObject
        if sheet._previous or (selected and selected:IsDescendantOf(self._root)) then
            Focus.Restore(self._guiService, self._root, sheet._previous, nil)
        end
    end
end

function Workspace:_closeOwned(window)
    for index = #self._modal, 1, -1 do
        if self._modal[index]._owner == window then self._modal[index]:Close() end
    end
end

function Workspace:Destroy()
    if self._destroyed then return end
    self._destroyed = true
    if modalOwner == self then modalOwner = nil end
    self:_setShortcuts(false)
    local selected = self._guiService.SelectedObject
    if selected and selected:IsDescendantOf(self._root) then self._guiService.SelectedObject = nil end
    while self:_top() do self:_top():Close() end
    while #self._windows > 0 do self._windows[#self._windows]:Destroy() end
    self._scope:Destroy()
    self.Runtime.Scope:Remove(self)
    if self._ownsRuntime then self.Runtime:Dispose() end
end

return table.freeze(Workspace)
