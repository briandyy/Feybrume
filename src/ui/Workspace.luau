local Layout = require(if script then script.Parent.Parent.engine.Layout else "../engine/Layout")
local Input = require(if script then script.Parent.Parent.engine.Input else "../engine/Input")
local Viewport = require(if script then script.Parent.Parent.engine.Viewport else "../engine/Viewport")
local Factory = require(if script then script.Parent.Parent.engine.Factory else "../engine/Factory")
local Focus = require(if script then script.Parent.Parent.engine.Focus else "../engine/Focus")
local Theme = require(if script then script.Parent.Parent.engine.Theme else "../engine/Theme")
local Runtime = require(if script then script.Parent.Parent.core.Runtime else "../core/Runtime")
local Result = require(if script then script.Parent.Parent.core.Result else "../core/Result")
local Error = require(if script then script.Parent.Parent.core.Error else "../core/Error")
local Flags = require(if script then script.Parent.Parent.core.Flags else "../core/Flags")
local Signal = require(if script then script.Parent.Parent.core.Signal else "../core/Signal")
local Typography = require(if script then script.Parent.Parent.engine.Typography else "../engine/Typography")
local Window = require(if script then script.Parent.Window else "./Window")
local Sheet = require(if script then script.Parent.Sheet else "./Sheet")
local ReopenStyle = require(if script then script.Parent.ReopenStyle else "./ReopenStyle")
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
    local reopenMode = options.reopenMode or "free"
    assert(reopenMode == "free" or reopenMode == "edge", "Expected free or edge reopen mode")
    local reopenEdge = options.reopenEdge or "device"
    assert(reopenEdge == "device" or reopenEdge == "screen", "Expected device or screen reopen edge")
    assert(options.resolveReopenImage == nil or type(options.resolveReopenImage) == "function",
        "Expected a reopen image resolver function")
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
        side = side, reopenMode = reopenMode, reopenEdge = reopenEdge, fontScale = scale, reserved = reserved,
        resolveReopenImage = options.resolveReopenImage,
        reopenBubble = ReopenStyle.Merge(nil, if options.reopenBubble == nil then {} else options.reopenBubble),
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
    local namespace = options.flagNamespace or "Feybrume"
    assert(type(namespace) == "string" and #namespace <= 96 and namespace:match("^[%w_.-]+$"),
        "Invalid flag namespace")
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
    local state = scope:Give(runtime:CreateStore({}))
    local function report(errorValue) runtime.Diagnostics:Push(errorValue) end
    workspaceCount += 1
    local self = setmetatable({
        Runtime = runtime, Themes = themes, _scope = scope, _ownsRuntime = ownsRuntime, _settings = config,
        _guiService = guiService, _actions = actions, _userInput = input, _windows = {}, _modal = {},
        _measureText = function(text, size, font)
            return textService:GetTextSize(text, size, font, unconstrainedText).X
        end,
        _area = Layout.Rect(0, 0, 0, 0), _profile = Layout.Profile(0, 0, "pointer", config.breakpoints),
        _actionName = "FeybrumeSheet" .. tostring(workspaceCount),
        _gamepadAction = "FeybrumeGamepad" .. tostring(workspaceCount),
        _topbarObstacles = {}, _launcherOffsetX = 0, _launcherOffsetY = 0,
        _flags = Flags.new(state), _flagNamespace = namespace,
        _componentChanged = scope:Give(Signal.new(runtime.Clock, report)),
        _typography = Typography.new(),
    }, Workspace)
    local screen = scope:Give(Factory.Create("ScreenGui", parent, {
        Name = options.name or "FeybrumeWorkspace", ResetOnSpawn = false,
        ScreenInsets = Enum.ScreenInsets.None, ClipToDeviceSafeArea = false,
        SafeAreaCompatibility = Enum.SafeAreaCompatibility.None,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = options.displayOrder or 10,
    }))
    self._screen = screen
    self._bubbleArea = self._area
    local surface = Factory.Frame(screen, "ScreenBounds", { Size = UDim2.fromScale(1, 1) })
    self._root = Factory.Frame(surface, "SafeArea")
    self._windowsLayer = Factory.Frame(self._root, "Windows", { Size = UDim2.fromScale(1, 1), ZIndex = 1 })
    local fullWidth = config.reopenEdge == "screen"
    local launcher = scope:Give(Factory.Create("ScreenGui", parent, {
        Name = screen.Name .. "Reopen", ResetOnSpawn = false,
        ScreenInsets = if fullWidth then Enum.ScreenInsets.None else Enum.ScreenInsets.DeviceSafeInsets,
        ClipToDeviceSafeArea = not fullWidth,
        SafeAreaCompatibility = Enum.SafeAreaCompatibility.None,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = screen.DisplayOrder + 1,
    }))
    self._bubblesLayer = Factory.Frame(launcher, "Reopen", { Size = UDim2.fromScale(1, 1) })
    self._overlaysLayer = Factory.Frame(self._root, "Overlays", { Size = UDim2.fromScale(1, 1), ZIndex = 3 })
    self._input = Input.new(input, scope)
    runtime.Scope:Give(self, nil, self)
    scope:Give(screen.Destroying:Connect(function() self:Destroy() end))
    scope:Give(launcher.Destroying:Connect(function() self:Destroy() end))
    scope:Give(screen:GetPropertyChangedSignal("Enabled"):Connect(function() launcher.Enabled = screen.Enabled end))
    scope:Give(screen:GetPropertyChangedSignal("DisplayOrder"):Connect(function() launcher.DisplayOrder = screen.DisplayOrder + 1 end))
    scope:Give(themes:Subscribe(function() self:_refresh() end))
    local function refreshBounds()
        self._input:Cancel()
        self:_refresh()
    end
    Viewport.Observe(scope, surface, input, refreshBounds)
    scope:Give(self._bubblesLayer:GetPropertyChangedSignal("AbsoluteSize"):Connect(refreshBounds))
    scope:Give(self._bubblesLayer:GetPropertyChangedSignal("AbsolutePosition"):Connect(refreshBounds))
    scope:Give(guiService:GetPropertyChangedSignal("TopbarInset"):Connect(refreshBounds))
    scope:Give(input.TextBoxFocused:Connect(function() Viewport.RevealFocused(self._root, input) end))
    scope:Give(guiService:GetPropertyChangedSignal("TouchControlsEnabled"):Connect(function() self:_placeBubbles() end))
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
    if options.gamepadNavigation ~= false then self:_bindGamepad() end
    self:_refresh()
    return self
end

function Workspace:_target(theme)
    return if self._profile.touchLayout or self._profile.narrow then
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
    local safeFrame
    self._area, self._profile, self._origin, self._screenArea, self._chromeArea, safeFrame =
        Viewport.Read(self._userInput, self._guiService, self._settings.breakpoints)
    Factory.Rect(self._root, safeFrame.x, safeFrame.y, safeFrame.width, safeFrame.height)
    self._bubbleArea, self._launcherOffsetX, self._launcherOffsetY, self._topbarObstacles, self._touchArea =
        Viewport.ReadLauncher(self._bubblesLayer, self._userInput, self._guiService, self._settings.reopenEdge == "screen")
    for _, window in ipairs(self._windows) do window:_reflow() end
    for _, sheet in ipairs(self._modal) do sheet:_reflow() end
    self:_placeBubbles()
    self._componentChanged:Fire()
    Viewport.RevealFocused(self._root, self._userInput)
end

function Workspace:ExportFlags(namespace)
    self:_assertLive()
    return self._flags:Export(namespace or self._flagNamespace)
end

function Workspace:RestoreFlags(values, options)
    self:_assertLive()
    if options ~= nil and type(options) ~= "table" then
        return Result.Err(Error.Create("INVALID_ARGUMENT"))
    end
    options = options or {}
    for key in pairs(options) do
        if key ~= "namespace" and key ~= "silent" then return Result.Err(Error.Create("INVALID_ARGUMENT")) end
    end
    if (options.namespace ~= nil and type(options.namespace) ~= "string")
        or (options.silent ~= nil and type(options.silent) ~= "boolean") then
        return Result.Err(Error.Create("INVALID_ARGUMENT"))
    end
    return self._flags:Restore(options.namespace or self._flagNamespace, values, options.silent)
end

function Workspace:_bubbleBounds(window)
    local area = self._bubbleArea
    if window._bubbleStyle.allowTopbar then return area, self._topbarObstacles end
    local top = math.clamp(self._launcherOffsetY, area.y, area.y + area.height)
    return Layout.Rect(area.x, top, area.width, area.y + area.height - top), {}
end

function Workspace:_placeBubbles()
    if self._destroyed then return end
    local reserved = {}
    local function launcherRect(rect)
        return Layout.Rect(rect.x + self._launcherOffsetX, rect.y + self._launcherOffsetY, rect.width, rect.height)
    end
    for _, region in ipairs(self._settings.reserved) do table.insert(reserved, launcherRect(region)) end
    if self._userInput.TouchEnabled and self._guiService.TouchControlsEnabled
        and self._settings.avoidMovement and not self._userInput.OnScreenKeyboardVisible then
        local touch = self._touchArea
        local w, h = math.min(138, touch.width / 2), math.min(142, touch.height / 2)
        table.insert(reserved, Layout.Rect(touch.x, touch.y + touch.height - h, w, h))
        table.insert(reserved, Layout.Rect(touch.x + touch.width - w, touch.y + touch.height - h, w, h))
    end
    local visible, chrome = {}, {}
    for _, window in ipairs(self._windows) do
        if window._shell.Visible and window._rect then
            table.insert(visible, launcherRect(window._rect))
            for _, region in ipairs(window._bubbleExclusions or {}) do table.insert(chrome, launcherRect(region)) end
        end
    end
    for _, window in ipairs(self._windows) do
        local button = window._bubble
        local bounds, protected = self:_bubbleBounds(window)
        if window._open or self:_hasModal() or math.min(bounds.width, bounds.height) < 36 then
            button.Visible, window._bubbleRect = false, nil
        else
            local theme = window:_theme()
            local size = math.max(window._bubbleStyle.size, self:_target(theme))
            local anchor = window._bubbleAnchor or { x = if window._side == "left" then 0 else 1, y = 0.58 }
            local avoid = table.clone(reserved)
            for _, region in ipairs(protected) do table.insert(avoid, region) end
            local rect = window._bubbleDragging
            if not rect and self._settings.reopenMode == "edge" then
                local y = bounds.y + math.max(0, bounds.height - size) * anchor.y
                rect = Layout.Bubble(bounds, avoid, window._side, y, size)
            end
            if not rect then
                if not window._bubbleAnchor then
                    local clear = table.clone(avoid)
                    for _, region in ipairs(visible) do table.insert(clear, region) end
                    rect = Layout.FreeBubble(bounds, clear, anchor, size)
                end
                if not rect then
                    local controls = table.clone(avoid)
                    for _, region in ipairs(chrome) do table.insert(controls, region) end
                    rect = Layout.FreeBubble(bounds, controls, anchor, size)
                        or Layout.FreeBubble(bounds, avoid, anchor, size)
                        or Layout.FreeBubble(bounds, protected, anchor, size)
                end
            end
            window._bubbleRect = rect
            button.Visible = rect ~= nil
            if rect then
                Factory.Rect(button, rect.x, rect.y, rect.width, rect.height)
                Factory.StyleButton(button, theme, self._profile, { focused = self._guiService.SelectedObject == button },
                    "solid", self._settings.fontScale)
                window:_styleBubble(rect.width)
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
    if self._tabsPress and self._tabsPress.window == window then self._tabsPress = nil end
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
    self:_placeBubbles()
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
    for _, window in ipairs(self._windows) do
        window._side = side
        if window._bubbleAnchor then window._bubbleAnchor.x = if side == "left" then 0 else 1 end
    end
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

function Workspace:_ownsSelection(object)
    return object and (object:IsDescendantOf(self._root) or object:IsDescendantOf(self._bubblesLayer))
end

function Workspace:_gamepadEntry(allowHidden)
    local sheet = self:_top()
    if sheet then return sheet._card, sheet._close end
    for index = #self._windows, 1, -1 do
        local window = self._windows[index]
        if window._shell.Visible then
            local root, tab = window._shell, window._activeTab
            if tab and Focus.Eligible(tab._button, root) then return root, tab._button end
            if Focus.Eligible(window._more, root) then return root, window._more end
            if tab then
                local first = Focus.First(tab._page)
                if first then return root, first end
            end
            return root, window._hide
        end
    end
    if allowHidden then return self._bubblesLayer, Focus.First(self._bubblesLayer) end
    return nil, nil
end

function Workspace:_handleTabLauncher(state, device, selected, active)
    local press = self._tabsPress
    if press and press.device == device then
        if state == "End" or state == "Cancel" then self._tabsPress = nil end
        if state == "End" and active and selected == press.window._more then
            press.window:_showTabs()
        end
        return true
    end
    if not press and state == "Begin" and active and selected and not self:_hasModal() then
        for _, window in ipairs(self._windows) do
            if selected == window._more and Focus.Eligible(selected, window._shell) then
                self._tabsPress = { window = window, device = device }
                return true
            end
        end
    end
    return false
end

function Workspace:_bindGamepad()
    local key, actions = Enum.KeyCode, self._actions
    local directions = {
        [key.DPadUp] = { 0, -1 }, [key.DPadDown] = { 0, 1 },
        [key.DPadLeft] = { -1, 0 }, [key.DPadRight] = { 1, 0 },
    }
    actions:BindActionAtPriority(self._gamepadAction, function(_, state, input)
        local gui = self._guiService
        local pass, sink = Enum.ContextActionResult.Pass, Enum.ContextActionResult.Sink
        local code, selected = input.KeyCode, gui.SelectedObject
        local active = not self._destroyed and self._screen.Enabled and not gui.MenuIsOpen
            and (not modalOwner or modalOwner == self) and not self._userInput:GetFocusedTextBox()
        if code == key.ButtonA then
            return if self:_handleTabLauncher(state.Name, input.UserInputType, selected, active) then sink else pass
        end
        if not active or (selected and not self:_ownsSelection(selected)) then return pass end
        local root, first = self:_gamepadEntry(code == key.ButtonSelect or selected ~= nil)
        if selected and not self:_hasModal() then
            if selected:IsDescendantOf(self._bubblesLayer) then
                root = self._bubblesLayer
            else
                for _, window in ipairs(self._windows) do
                    if selected:IsDescendantOf(window._shell) then
                        root = window._shell
                        break
                    end
                end
            end
        end
        if not root then return pass end
        if code == key.ButtonSelect then
            if state == Enum.UserInputState.Begin then
                gui.SelectedObject = if selected and not self:_hasModal() then nil else first
            end
            return if selected or first then sink else pass
        end
        if not Focus.Eligible(selected, root) then
            if state == Enum.UserInputState.Begin and Focus.Eligible(first, root) then
                gui.SelectedObject = first
                Viewport.Reveal(first, Layout.TabPadding)
                return sink
            end
            return pass
        end
        local direction = directions[code]
        if not direction then return pass end
        if state == Enum.UserInputState.Begin then
            local target = Focus.InDirection(root, selected, direction[1], direction[2])
            if target then
                gui.SelectedObject = target
                Viewport.Reveal(target, Layout.TabPadding)
            end
        end
        return sink
    end, false, Enum.ContextActionPriority.High.Value, key.DPadUp, key.DPadDown,
        key.DPadLeft, key.DPadRight, key.ButtonSelect, key.ButtonA)
    self._scope:Give(self._userInput.GamepadDisconnected:Connect(function(device)
        if self._tabsPress and device == self._tabsPress.device then self._tabsPress = nil end
    end))
    self._scope:Give(function() actions:UnbindAction(self._gamepadAction) end)
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
        if modalOwner ~= self or not sheet or self._guiService.MenuIsOpen
            or self._userInput:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
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
        if sheet._previous or self._userInput.PreferredInput == Enum.PreferredInput.Gamepad
            or self:_ownsSelection(selected) then
            local _, fallback = self:_gamepadEntry(true)
            local previous = sheet._previous
            if Focus.Eligible(previous, self._root) or Focus.Eligible(previous, self._bubblesLayer) then
                self._guiService.SelectedObject = previous
            else
                self._guiService.SelectedObject = fallback
            end
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
    if self:_ownsSelection(selected) then self._guiService.SelectedObject = nil end
    while self:_top() do self:_top():Close() end
    while #self._windows > 0 do self._windows[#self._windows]:Destroy() end
    self._scope:Destroy()
    self.Runtime.Scope:Remove(self)
    if self._ownsRuntime then self.Runtime:Dispose() end
end

return table.freeze(Workspace)
