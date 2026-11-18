local Container = require(if script then script.Parent.Container else "./Container")
local Factory = require(if script then script.Parent.Parent.engine.Factory else "../engine/Factory")
local Layout = require(if script then script.Parent.Parent.engine.Layout else "../engine/Layout")
local Input = require(if script then script.Parent.Parent.engine.Input else "../engine/Input")
local Window = {}
Window.__index = Window
local Tab = {}
Tab.__index = Tab

local placements = { floating = true, fullscreen = true, left = true, right = true }
local navigation = { auto = true, left = true, right = true, top = true, bottom = true, drawer = true, hidden = true }

local function positive(value, default)
    if value == nil then return default end
    assert(type(value) == "number" and value > 0 and value < math.huge, "Expected a positive dimension")
    return value
end

function Window.new(workspace, options)
    assert(options.id == nil or (type(options.id) == "string" and #options.id > 0), "Expected a window ID")
    assert(navigation[options.navigation or "auto"], "Unknown navigation placement")
    assert(placements[options.placement or "floating"], "Unknown window placement")
    assert(options.theme == nil or workspace.Themes:Get(options.theme), "Unknown window theme")
    assert(options.title == nil or type(options.title) == "string", "Expected a title")
    local width, height = positive(options.width, 590), positive(options.height, 420)
    local limits = {
        minWidth = positive(options.minWidth, 280), minHeight = positive(options.minHeight, 220),
        maxWidth = positive(options.maxWidth, 1200), maxHeight = positive(options.maxHeight, 900),
    }
    assert(limits.minWidth <= limits.maxWidth and limits.minHeight <= limits.maxHeight, "Invalid size limits")

    local scope = workspace._scope:Fork()
    local self = setmetatable({
        _workspace = workspace, _scope = scope, _options = table.clone(options), _limits = limits,
        _width = width, _height = height, _placement = options.placement or "floating",
        _navigation = options.navigation or "auto", _themeId = options.theme,
        _tabs = {}, _open = true, _canDrag = options.movable ~= false, _canResize = options.resizable ~= false,
        _side = workspace._settings.side,
    }, Window)
    local newFrame, newButton = Factory.Frame, Factory.Button
    local shell = scope:Give(newFrame(workspace._windowsLayer, options.id or "Window", {
        Active = true, BackgroundTransparency = 0, ClipsDescendants = true,
    }))
    self._shell = shell
    self._shape = Factory.Create("UICorner", shell)
    self._edge = Factory.Create("UIStroke", shell)
    self._background = newFrame(shell, "Background", { Size = UDim2.fromScale(1, 1), ZIndex = 1 })
    local body = newFrame(shell, "Chrome", { Size = UDim2.fromScale(1, 1), ZIndex = 2 })
    self._overlay = newFrame(shell, "Overlay", { Size = UDim2.fromScale(1, 1), ZIndex = 3 })
    self._heading = Factory.Label(body, options.title or "Feybrume", 18)
    self._heading.Font = Enum.Font.SourceSansBold
    self._grip = newFrame(body, "DragHandle")
    self._hide = newButton(body, "Hide")
    self._max = newButton(body, "Max")
    self._nav = Factory.Scroll(body, "Navigation")
    self._more = newButton(self._nav, "More")
    self._pages = newFrame(body, "Pages", { ClipsDescendants = true })
    self._resize = newButton(body, "Resize")
    self._resize.Name = "Resize"
    self._resizeMark = newFrame(self._resize, "ResizeMark", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(18, 18), Visible = false,
    })
    self._resizeLines = {
        newFrame(self._resizeMark, "Horizontal", {
            Position = UDim2.fromOffset(3, 14), Size = UDim2.fromOffset(13, 2), BackgroundTransparency = 0,
        }),
        newFrame(self._resizeMark, "Vertical", {
            Position = UDim2.fromOffset(14, 3), Size = UDim2.fromOffset(2, 13), BackgroundTransparency = 0,
        }),
    }
    self._bubble = scope:Give(newButton(workspace._bubblesLayer, options.reopenLabel or "Open"))
    self._bubble.Name = "Reopen" .. shell.Name
    self._bubble.Visible = false
    self._chrome = { self._hide, self._max, self._more, self._resize, self._bubble }
    scope:Give(self._hide.Activated:Connect(function() if self:_canInteract() then self:Hide() end end))
    scope:Give(self._max.Activated:Connect(function()
        if self:_canInteract() then
            self:Dock(if self._placement == "floating" then "fullscreen" else "floating")
        end
    end))
    scope:Give(self._more.Activated:Connect(function()
        if self:_canInteract() then self:_showTabs() end
    end))
    scope:Give(self._resize.Activated:Connect(function(input)
        if self:_canInteract() and not Input.IsPointerActivation(input) then
            self:Dock(if self._placement == "floating" then "fullscreen" else "floating")
        end
    end))
    scope:Give(shell.InputBegan:Connect(function(input)
        if self:_canInteract() and Input.IsPointerActivation(input) then workspace:_raise(self) end
    end))
    scope:Give(self._bubble.Activated:Connect(function(input)
        if not Input.IsPointerActivation(input) and not workspace:_hasModal() then self:Show() end
    end))
    for _, button in ipairs(self._chrome) do
        scope:Give(button.SelectionGained:Connect(function() self:_styleChrome() end))
        scope:Give(button.SelectionLost:Connect(function() self:_styleChrome() end))
    end
    scope:Give(self._bubble.SelectionGained:Connect(function() workspace:_placeBubbles() end))
    scope:Give(self._bubble.SelectionLost:Connect(function() workspace:_placeBubbles() end))
    self:_bindGestures()
    return self
end

function Window:_canInteract()
    return not self._destroyed and self._open and not self._workspace:_hasModal()
end

function Window:_theme()
    return self._workspace.Themes:Get(self._themeId)
end

function Window:_styleChrome()
    local workspace = self._workspace
    local theme, profile, selected = self:_theme(), workspace._profile, workspace._guiService.SelectedObject
    for _, button in ipairs(self._chrome) do
        Factory.StyleButton(button, theme, profile, { focused = selected == button },
            if button == self._bubble then "solid" elseif button == self._resize then "outline" else "soft",
            workspace._settings.fontScale)
    end
    for _, tab in ipairs(self._tabs) do
        Factory.StyleButton(tab._button, theme, profile, {
            selected = tab == self._activeTab, disabled = tab._disabled, focused = selected == tab._button,
        }, "soft", workspace._settings.fontScale)
    end
end

function Window:_reflow()
    if self._destroyed then return end
    local workspace = self._workspace
    local area, profile = workspace._area, workspace._profile
    if area.width <= 0 or area.height <= 0 then
        self._shell.Visible = false
        return
    end
    if not self._requested then self._requested = Layout.Center(area, self._width, self._height) end
    local rect = Layout.Window(self._requested, area, profile, self._placement, self._limits,
        self._options.fillCompact ~= false)
    self._rect = rect
    self._shell.Visible = self._open
    if not self._open then return end

    local theme, scale = self:_theme(), workspace._settings.fontScale
    Factory.Rect(self._shell, rect.x, rect.y, rect.width, rect.height)
    self._shell.BackgroundColor3 = Factory.Hex(theme.palette.surface)
    self._edge.Color = Factory.Hex(theme.tokens.essentialStroke)
    self._shape.CornerRadius = UDim.new(0, theme.radius)
    self._heading.TextColor3 = Factory.Hex(theme.tokens.onSurface)
    self._heading.TextSize = math.round(18 * scale)

    local w, h = rect.width, rect.height
    local target = workspace:_target(theme)
    local gap, pad = 8, if profile.compactChrome then 6 else 12
    local bar = math.min(h, target + 2 * pad)
    self._max.Text = if self._placement == "floating" then "Max" else "Restore"
    self._resize.Text = if profile.compactChrome then "" else "Resize"
    self._resizeMark.Visible = profile.compactChrome
    for _, line in ipairs(self._resizeLines) do line.BackgroundColor3 = self._heading.TextColor3 end
    self:_styleChrome()
    local minimumWidth = target + (if profile.compactChrome then 2 else 14)
    local hideW = math.min(w, workspace:_buttonWidth(self._hide, minimumWidth))
    local maxW = workspace:_buttonWidth(self._max, minimumWidth)
    local maxVisible = not profile.narrow and w >= math.max(280, hideW + maxW + gap + 4 * pad)
    Factory.Rect(self._hide, math.max(0, w - pad - hideW), pad, hideW, target)
    Factory.Rect(self._max, w - pad - hideW - maxW - gap, pad, maxW, target)
    self._max.Visible = maxVisible
    local headingWidth = w - 3 * pad - hideW - (if maxVisible then maxW + gap else 0)
    Factory.Rect(self._heading, pad, pad, headingWidth, target)
    Factory.Rect(self._grip, 0, 0, headingWidth + pad, bar)
    self._grip.Visible = self._canDrag and not (profile.narrow and self._options.fillCompact ~= false)

    local resizable = self._canResize and self._placement == "floating" and not (profile.narrow and self._options.fillCompact ~= false)
    local useGutter = resizable and profile.compactChrome
    local footerH = if resizable and not useGutter then target + pad else 0
    self._resize.Visible = resizable
    if resizable then
        local resizeW = math.min(w, if useGutter then target else workspace:_buttonWidth(self._resize, target + 16))
        Factory.Rect(self._resize, math.max(0, w - pad - resizeW), h - target - 4, resizeW, target)
    end
    local y = bar
    local gutter = if useGutter then target + gap else 0
    local bodyW, bodyH = math.max(0, w - 2 * pad - gutter), math.max(0, h - bar - pad - footerH)
    local mode = Layout.Navigation(profile, self._navigation, bodyW, bodyH, target, #self._tabs)
    self._bubbleExclusions = { Layout.Rect(rect.x, rect.y, w, bar) }
    if mode == "hidden" or #self._tabs == 0 then
        self._nav.Visible = false
        Factory.Rect(self._pages, pad, y, bodyW, bodyH)
    else
        self._nav.Visible = true
        if mode == "left" or mode == "right" then
            local rail = math.min(136, math.max(target, math.floor(bodyW * 0.29)))
            table.insert(self._bubbleExclusions,
                Layout.Rect(rect.x + (if mode == "left" then pad else pad + bodyW - rail), rect.y + y, rail, bodyH))
            self:_layoutTabs(mode, rail, target)
            Factory.Rect(self._nav, if mode == "left" then pad else pad + bodyW - rail, y, rail, bodyH)
            Factory.Rect(self._pages, if mode == "left" then pad + rail + gap else pad, y, bodyW - rail - gap, bodyH)
        else
            local navH = target + 2
            local navY = if mode == "bottom" then y + math.max(0, bodyH - navH) else y
            table.insert(self._bubbleExclusions, Layout.Rect(rect.x + pad, rect.y + navY, bodyW, navH))
            self:_layoutTabs(mode, bodyW, target)
            Factory.Rect(self._nav, pad, navY, bodyW, navH)
            Factory.Rect(self._pages, pad, if mode == "bottom" then y else y + navH + gap, bodyW, bodyH - navH - gap)
        end
    end
end

function Window:_layoutTabs(mode, width, step)
    local rail = mode == "left" or mode == "right"
    local count = #self._tabs
    local capacity = if rail then count elseif mode == "drawer" then 0 else Layout.TabCapacity(width, math.max(step, 62), 8)
    local overflow = capacity < count
    local visible = if overflow then math.max(0, capacity - 1) else count
    local shown = {}
    for _, tab in ipairs(self._tabs) do
        if #shown >= visible then break end
        table.insert(shown, tab)
    end
    if visible > 0 and self._activeTab and not table.find(shown, self._activeTab) then shown[visible] = self._activeTab end
    local slots = visible + (if overflow then 1 else 0)
    local cell = if rail then width - 5 else math.floor((width - 8 * (slots - 1)) / math.max(slots, 1))
    for _, tab in ipairs(self._tabs) do
        local index = table.find(shown, tab)
        tab._button.Visible = index ~= nil
        if index then
            local i = index - 1
            Factory.Rect(tab._button, if rail then 0 else i * (cell + 8), if rail then i * (step + 8) else 0, cell, step)
        end
    end
    self._more.Visible = overflow
    self._more.Text = if visible == 0 then "Tabs" else "More"
    if overflow then Factory.Rect(self._more, visible * (cell + 8), 0, cell, step) end
    self._nav.ScrollingEnabled = rail
    self._nav.AutomaticCanvasSize = Enum.AutomaticSize.None
    self._nav.CanvasSize = UDim2.fromOffset(0, if rail then count * (step + 8) else 0)
    if not rail then self._nav.CanvasPosition = Vector2.zero end
end

function Window:_bindGestures()
    local workspace, input = self._workspace, self._workspace._input
    input:Bind(self._scope, self._grip, self, function(position, native)
        if not self:_canInteract() or not self._canDrag or not self._rect then return nil end
        workspace:_raise(self)
        local before = self._rect
        local restorePlacement = self._placement
        local wasDocked = restorePlacement ~= "floating"
        local snap = self._options.dockable ~= false
            and (native.UserInputType ~= Enum.UserInputType.Touch or self._options.touchDock == true)
        local changed = false
        return {
            drag = function(dx, dy)
                local origin, area = workspace._origin, workspace._area
                if wasDocked and not changed then
                    local requested = Layout.Clamp(self._requested, area)
                    local fraction = math.clamp(((position.X - origin.X) - before.x) / math.max(1, before.width), 0, 1)
                    before = Layout.Rect(position.X - origin.X - requested.width * fraction,
                        position.Y - origin.Y - workspace:_target(self:_theme()) / 2, requested.width, requested.height)
                    self._placement = "floating"
                end
                changed = true
                self._requested = Layout.Clamp(Layout.Rect(before.x + dx, before.y + dy, before.width, before.height), area)
                self:_reflow()
            end,
            finish = function(pointer)
                if snap then
                    self:Dock(Layout.DockAt(pointer.X - workspace._origin.X, pointer.Y - workspace._origin.Y, workspace._area, 22))
                else
                    workspace:_placeBubbles()
                end
            end,
        }
    end)
    input:Bind(self._scope, self._resize, self, function()
        if not self:_canInteract() or not self._resize.Visible then return nil end
        workspace:_raise(self)
        local rect = self._rect
        return { drag = function(dx, dy)
            self._requested = Layout.Resize(rect, workspace._area, dx, dy, self._limits)
            self:_reflow()
        end, finish = function() workspace:_placeBubbles() end }
    end)
    input:Bind(self._scope, self._bubble, self, function()
        if self._open or workspace:_hasModal() or not self._bubbleRect then return nil end
        local rect = self._bubbleRect
        local function finish()
            if self._bubbleDragging then
                self._bubbleAnchor = Layout.BubbleAnchor(self._bubbleDragging, workspace._bubbleArea)
                self._side = if self._bubbleAnchor.x < 0.5 then "left" else "right"
            end
            self._bubbleDragging = nil
            workspace:_placeBubbles()
        end
        return {
            drag = function(dx, dy)
                local nextRect = Layout.Clamp(Layout.Rect(rect.x + dx, rect.y + dy, rect.width, rect.height), workspace._bubbleArea)
                self._bubbleDragging = nextRect
                Factory.Rect(self._bubble, nextRect.x, nextRect.y, nextRect.width, nextRect.height)
            end,
            tap = function() self:Show() end,
            finish = finish,
            cancel = function()
                self._bubbleDragging = nil
                workspace:_placeBubbles()
            end,
        }
    end)
end

function Window:Tab(options)
    self:_assertLive()
    assert(type(options) == "table" and type(options.id) == "string" and #options.id > 0, "Expected a tab ID")
    assert(options.title == nil or type(options.title) == "string", "Expected a tab title")
    for _, tab in ipairs(self._tabs) do assert(tab.Id ~= options.id, "Duplicate tab ID") end
    local scope = self._scope:Fork()
    local page = scope:Give(Factory.Scroll(self._pages, options.id))
    page.Size = UDim2.fromScale(1, 1)
    page.Visible = false
    Factory.Padding(page, 6)
    Factory.List(page, 8)
    local button = scope:Give(Factory.Button(self._nav, options.title or options.id))
    local tab = setmetatable({
        Id = options.id, _window = self, _page = page, _button = button, _scope = scope,
        _disabled = options.disabled == true, _container = Container.new(page, scope):Section({ name = "Content" }),
    }, Tab)
    table.insert(self._tabs, tab)
    scope:Give(button.Activated:Connect(function()
        if self:_canInteract() then self:SelectTab(tab.Id) end
    end))
    scope:Give(button.SelectionGained:Connect(function() self:_styleChrome() end))
    scope:Give(button.SelectionLost:Connect(function() self:_styleChrome() end))
    self:_selectAvailable()
    self:_reflow()
    return tab
end

function Window:_selectAvailable()
    if not self._activeTab then
        for _, tab in ipairs(self._tabs) do
            if not tab._disabled then
                self._activeTab = tab
                break
            end
        end
    end
    for _, tab in ipairs(self._tabs) do
        tab._page.Visible = tab == self._activeTab
        tab._button.Selectable = not tab._disabled
        tab._button.Active = not tab._disabled
    end
end

function Window:SelectTab(id)
    self:_assertLive()
    for _, tab in ipairs(self._tabs) do
        if tab.Id == id and not tab._disabled then
            local selected = self._workspace._guiService.SelectedObject
            local transfer = selected and self._activeTab and self._activeTab ~= tab
                and selected:IsDescendantOf(self._activeTab._page)
            if self._activeTab ~= tab then self._workspace._input:Cancel(self) end
            self._activeTab = tab
            self:_selectAvailable()
            self:_reflow()
            if transfer then
                local target = if tab._button.Visible then tab._button elseif self._more.Visible then self._more else self._hide
                self._workspace._guiService.SelectedObject = target
            end
            return true
        end
    end
    return false
end

function Window:GetActiveTab()
    return if self._activeTab then self._activeTab.Id else nil
end

function Window:GetBounds()
    return if self._rect then table.freeze(table.clone(self._rect)) else nil
end

function Window:_showTabs()
    local items = {}
    for _, tab in ipairs(self._tabs) do
        if not tab._disabled then
            table.insert(items, { label = tab._button.Text, callback = function() self:SelectTab(tab.Id) end })
        end
    end
    if #items > 0 then self:OpenContextMenu(items, { title = "Tabs" }) end
end

function Window:OpenContextMenu(items, options)
    self:_assertLive()
    options = options or {}
    return self._workspace:_openMenu(self, items, options)
end

function Window:BindContextMenu(target, items, options)
    self:_assertLive()
    assert(target:IsA("GuiObject") and target:IsDescendantOf(self._shell), "Expected a target inside this window")
    options = options or {}
    local scope, workspace = self._scope:Fork(), self._workspace
    local function open()
        if self:_canInteract() and target.Visible and target:IsDescendantOf(self._shell) then
            self:OpenContextMenu(items, options)
        end
    end
    scope:Give(target.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then open() end
    end))
    workspace._input:Bind(scope, target, self, function(_, input)
        if input.UserInputType ~= Enum.UserInputType.Touch or not self:_canInteract() then return nil end
        local timer
        local function cancel()
            if timer then
                timer.Cancel()
                scope:Remove(timer)
                timer = nil
            end
        end
        return {
            began = function()
                timer = workspace.Runtime.Clock:After(0.5, function()
                    cancel()
                    open()
                end)
                scope:Give(timer, nil, timer)
            end,
            cancel = cancel, drag = cancel, finish = cancel, tap = cancel,
        }
    end)
    scope:Give(target.Destroying:Connect(function() scope:Destroy() end))
    return function() scope:Destroy() end
end

function Window:_assertLive()
    assert(not self._destroyed, "Window is destroyed")
end

function Window:SetTheme(id)
    self:_assertLive()
    if id ~= nil and not self._workspace.Themes:Get(id) then return false end
    self._themeId = id
    self:_reflow()
    self._workspace:_placeBubbles()
    return true
end

function Window:SetNavigation(mode)
    self:_assertLive()
    if not navigation[mode] then return false end
    self._navigation = mode
    self:_reflow()
    self._workspace:_placeBubbles()
    return true
end

function Window:Dock(mode)
    self:_assertLive()
    if not placements[mode] then return false end
    self._placement = mode
    self._workspace:_raise(self)
    self:_reflow()
    self._workspace:_placeBubbles()
    return true
end

function Window:Show()
    self:_assertLive()
    local selected = self._workspace._guiService.SelectedObject == self._bubble
    self._open = true
    self._workspace:_raise(self)
    self:_reflow()
    self._workspace:_placeBubbles()
    if selected and self._shell.Visible then self._workspace._guiService.SelectedObject = self._hide end
end

function Window:Hide()
    self:_assertLive()
    local workspace = self._workspace
    local selected = workspace._guiService.SelectedObject
    local transfer = selected and selected:IsDescendantOf(self._shell)
    self._open = false
    workspace._input:Cancel(self)
    workspace:_closeOwned(self)
    self:_reflow()
    workspace:_placeBubbles()
    if transfer then workspace._guiService.SelectedObject = if self._bubble.Visible then self._bubble else nil end
end

function Window:IsVisible()
    return self._open and not self._destroyed
end

function Window:GetSlot(name)
    self:_assertLive()
    if name == "Background" then return self._background end
    if name == "Overlay" then return self._overlay end
    return if self._activeTab then self._activeTab:GetSlot(name) else nil
end

function Window:Destroy()
    if self._destroyed then return end
    self._destroyed, self._open = true, false
    local workspace = self._workspace
    workspace._input:Cancel(self)
    workspace:_closeOwned(self)
    local selected = workspace._guiService.SelectedObject
    if selected and (selected == self._bubble or selected:IsDescendantOf(self._shell)) then
        workspace._guiService.SelectedObject = nil
    end
    self._scope:Destroy()
    workspace:_forget(self)
end

function Tab:GetSlot(name)
    return self._container:GetSlot(name)
end

function Tab:Section(options)
    return self._container:Section(options)
end

function Tab:MoveTo(index)
    local window = self._window
    window:_assertLive()
    assert(type(index) == "number" and index % 1 == 0 and index >= 1 and index <= #window._tabs, "Invalid tab index")
    local current = table.find(window._tabs, self)
    if not current then return false end
    table.remove(window._tabs, current)
    table.insert(window._tabs, index, self)
    window:_reflow()
    return true
end

function Tab:Add(gui, slot)
    return self._container:Add(gui, slot)
end

function Tab:SetDisabled(value)
    local window = self._window
    window:_assertLive()
    if self._destroyed then return false end
    self._disabled = value == true
    if self._disabled and window._activeTab == self then
        local gui = window._workspace._guiService
        if gui.SelectedObject and gui.SelectedObject:IsDescendantOf(self._page) then gui.SelectedObject = nil end
        window._activeTab = nil
    end
    window:_selectAvailable()
    window:_reflow()
    return true
end

function Tab:Destroy()
    local window = self._window
    if self._destroyed or window._destroyed then return end
    self._destroyed = true
    if window._activeTab == self then window._activeTab = nil end
    table.remove(window._tabs, assert(table.find(window._tabs, self)))
    self._scope:Destroy()
    window:_selectAvailable()
    window:_reflow()
end

return table.freeze(Window)
