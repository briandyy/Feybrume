local Container = require(if script then script.Parent.Container else "./Container")
local Components = require(if script then script.Parent.Components else "./Components")
local Factory = require(if script then script.Parent.Parent.engine.Factory else "../engine/Factory")
local Layout = require(if script then script.Parent.Parent.engine.Layout else "../engine/Layout")
local Input = require(if script then script.Parent.Parent.engine.Input else "../engine/Input")
local ReopenStyle = require(if script then script.Parent.ReopenStyle else "./ReopenStyle")
local WindowProps = require(if script then script.Parent.WindowProps else "./WindowProps")
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
    local props = WindowProps.FromOptions(options)
    local initialBounds = WindowProps.Bounds({ width = 590, height = 420 },
        { x = options.x, y = options.y, width = options.width, height = options.height })
    local limits = {
        minWidth = positive(options.minWidth, 280), minHeight = positive(options.minHeight, 220),
        maxWidth = positive(options.maxWidth, 1200), maxHeight = positive(options.maxHeight, 900),
    }
    assert(limits.minWidth <= limits.maxWidth and limits.minHeight <= limits.maxHeight, "Invalid size limits")

    local bubble = workspace._settings.reopenBubble
    if options.reopenLabel ~= nil then bubble = ReopenStyle.Merge(bubble, { label = options.reopenLabel }) end
    if options.reopenBubble ~= nil then bubble = ReopenStyle.Merge(bubble, options.reopenBubble) end
    local scope = workspace._scope:Fork()
    local self = setmetatable({
        _workspace = workspace, _scope = scope, _options = table.clone(options), _limits = limits,
        _initialBounds = initialBounds, _props = props, _placement = options.placement or "floating",
        _navigation = options.navigation or "auto", _themeId = options.theme,
        _tabs = {}, _open = true, _canDrag = options.movable ~= false, _canResize = options.resizable ~= false,
        _side = workspace._settings.side, _bubbleStyle = bubble,
    }, Window)
    local newFrame, newButton = Factory.Frame, Factory.Button
    local shell = scope:Give(newFrame(workspace._windowsLayer, options.id or "Window", {
        Active = true, BackgroundTransparency = 0, ClipsDescendants = true,
    }))
    self._shell = shell
    self._shape = Factory.Create("UICorner", shell)
    self._edge = Factory.Create("UIStroke", shell)
    self._background = newFrame(shell, "Background", { Size = UDim2.fromScale(1, 1), ZIndex = 1 })
    local body = newFrame(shell, "Chrome", { ZIndex = 2 })
    self._body = body
    self._overlay = newFrame(shell, "Overlay", { Size = UDim2.fromScale(1, 1), ZIndex = 3 })
    self._heading = Factory.Label(body, props.title, props.titleSize)
    self._heading.Font = Enum.Font.SourceSansBold
    self._subtitle = Factory.Label(body, props.subtitle, 13)
    self._layoutSlots = {
        TopbarLeading = newFrame(body, "TopbarLeading", { ClipsDescendants = true }),
        TopbarTrailing = newFrame(body, "TopbarTrailing", { ClipsDescendants = true }),
        StatusBar = newFrame(body, "StatusBar", { ClipsDescendants = true }),
    }
    self._grip = newFrame(body, "DragHandle")
    self._hide = newButton(body, "Hide")
    self._max = newButton(body, "Max")
    self._nav = newFrame(body, "Navigation")
    self._tabScroll = Factory.Scroll(self._nav, "TabList")
    self._tabScroll.Size = UDim2.fromScale(1, 1)
    self._more = newButton(self._nav, "More")
    self._more.Name = "TabLauncher"
    self._more.ZIndex = 2
    self._pages = newFrame(body, "Pages", { ClipsDescendants = true })
    self._resize = newButton(body, "")
    self._resize.Name = "Resize"
    local resizeMark = newFrame(self._resize, "ResizeMark", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(18, 18),
    })
    self._resizeLines = {
        newFrame(resizeMark, "Horizontal", {
            Position = UDim2.fromOffset(3, 14), Size = UDim2.fromOffset(13, 2), BackgroundTransparency = 0,
        }),
        newFrame(resizeMark, "Vertical", {
            Position = UDim2.fromOffset(14, 3), Size = UDim2.fromOffset(2, 13), BackgroundTransparency = 0,
        }),
    }
    self._bubble = scope:Give(newButton(workspace._bubblesLayer, bubble.label))
    self._bubble.Name = "Reopen" .. shell.Name
    self._bubble.Visible = false
    self._bubbleIcon = Factory.Create("ImageLabel", self._bubble, {
        Name = "Icon", BackgroundTransparency = 1, Active = false, Selectable = false,
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        ScaleType = Enum.ScaleType.Fit,
    })
    self._bubbleIconCorner = Factory.Create("UICorner", self._bubbleIcon)
    scope:Give(self._bubbleIcon:GetPropertyChangedSignal("IsLoaded"):Connect(function() self:_refreshBubbleImage() end))
    self:_applyBubbleImage(bubble.image)
    self._chrome = { self._hide, self._max, self._more, self._resize }
    scope:Give(self._hide.Activated:Connect(function() if self:_canInteract() then self:Hide() end end))
    scope:Give(self._max.Activated:Connect(function()
        if self:_canInteract() then
            self:Dock(if self._placement == "floating" then "fullscreen" else "floating")
        end
    end))
    scope:Give(self._more.Activated:Connect(function()
        self:_showTabs()
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
            if profile.compactChrome or button == self._resize then "ghost" else "soft",
            workspace._settings.fontScale)
    end
    for _, tab in ipairs(self._tabs) do
        local button = tab._button
        local focused = selected == button
        Factory.StyleButton(button, theme, profile, {
            selected = tab == self._activeTab, disabled = tab._disabled, focused = focused,
        }, if profile.compactChrome then "ghost" else "soft", workspace._settings.fontScale)
        if profile.compactChrome then
            button.Edge.Enabled = focused
            button.Shape.CornerRadius = UDim.new(0, math.min(theme.radius, 8))
            button.TextSize = math.round(14 * workspace._settings.fontScale)
        end
    end
    if profile.compactChrome then
        for _, button in ipairs(self._chrome) do
            button.Edge.Enabled = selected == button
            button.TextSize = math.round(14 * workspace._settings.fontScale)
        end
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
    if not self._requested then
        local initial = self._initialBounds
        local centered = Layout.Center(area, initial.width, initial.height)
        self._requested = Layout.Rect(initial.x or centered.x, initial.y or centered.y, centered.width, centered.height)
    end
    local fillCompact = profile.narrow and self._options.fillCompact == true
    local floating = self._placement == "floating" and not fillCompact
    local rect = Layout.Window(self._requested, if floating then workspace._screenArea else area, profile,
        self._placement, self._limits, fillCompact)
    self._rect = rect
    self._shell.Visible = self._open
    if not self._open then return end

    local theme, scale = self:_theme(), workspace._settings.fontScale
    Factory.Rect(self._shell, rect.x, rect.y, rect.width, rect.height)
    local props = self._props
    self._shell.BackgroundColor3 = Factory.Hex(theme.palette.surface)
    self._shell.BackgroundTransparency = 1 - props.backgroundOpacity
    self._edge.Color = Factory.Hex(theme.tokens.essentialStroke)
    self._shape.CornerRadius = UDim.new(0, props.cornerRadius or theme.radius)
    self._heading.Text = props.title
    self._heading.TextColor3 = Factory.Hex(theme.tokens.onSurface)
    self._heading.TextSize = math.round(props.titleSize * scale)
    if props.titleFont then self._heading.FontFace = props.titleFont else self._heading.Font = Enum.Font.SourceSansBold end
    self._subtitle.Text = props.subtitle
    self._subtitle.TextColor3 = Factory.Hex(theme.tokens.textMuted or theme.tokens.onSurface)
    self._subtitle.TextSize = math.round(13 * scale)

    local content = Layout.WindowContent(rect, workspace._chromeArea)
    Factory.Rect(self._body, content.x, content.y, content.width, content.height)
    local w, h = content.width, content.height
    local target = workspace:_target(theme)
    local gap = if profile.compactChrome then 6 else 8
    local pad = math.min(props.padding or (if profile.compactChrome then 6 else 12), w / 2)
    local subtitleH = if props.subtitle == "" then 0 else self._subtitle.TextSize + 3
    local titleH = self._heading.TextSize + 4
    local bar = math.min(h, math.max(target, titleH + subtitleH, props.topbarHeight - 2 * pad) + 2 * pad)
    self._max.Text = if self._placement == "floating" then "Max" else "Restore"
    for _, line in ipairs(self._resizeLines) do line.BackgroundColor3 = self._heading.TextColor3 end
    self:_styleChrome()
    local minimumWidth = target + (if profile.compactChrome then 2 else 14)
    local hideW = math.min(w, workspace:_buttonWidth(self._hide, minimumWidth))
    local maxW = workspace:_buttonWidth(self._max, minimumWidth)
    local maxVisible = not profile.narrow and w >= math.max(280, hideW + maxW + gap + 4 * pad)
    local buttonY = math.max(0, (bar - target) / 2)
    Factory.Rect(self._hide, math.max(0, w - pad - hideW), buttonY, hideW, target)
    Factory.Rect(self._max, w - pad - hideW - maxW - gap, buttonY, maxW, target)
    self._max.Visible = maxVisible

    local standardButtons = hideW + (if maxVisible then maxW + gap else 0)
    local gripSize = if self._canResize and floating then math.min(Layout.ResizeGrip(profile), w, math.max(0, h - bar)) else 0
    self._resize.Visible = gripSize > 0
    if gripSize > 0 then
        local inset = 3
        Factory.Rect(self._resize, math.max(0, w - gripSize - inset), math.max(bar, h - gripSize - inset), gripSize, gripSize)
    end
    local headingWidth = math.max(0, w - 3 * pad - standardButtons)
    local leading, trailing = Layout.HeaderAdornmentWidths(headingWidth, props.topbarLeadingWidth, props.topbarTrailingWidth)
    local titleX = pad + (if leading > 0 then leading + gap else 0)
    local titleWidth = headingWidth - (titleX - pad) - (if trailing > 0 then trailing + gap else 0)
    local titleY = math.max(0, (bar - titleH - subtitleH) / 2)
    Factory.Rect(self._heading, titleX, titleY, titleWidth, titleH)
    Factory.Rect(self._subtitle, titleX, titleY + titleH, titleWidth, subtitleH)
    self._subtitle.Visible = subtitleH > 0
    local slotHeight = math.max(0, bar - 2 * pad)
    local leftSlot, rightSlot = self._layoutSlots.TopbarLeading, self._layoutSlots.TopbarTrailing
    Factory.Rect(leftSlot, pad, pad, leading, slotHeight)
    Factory.Rect(rightSlot, pad + headingWidth - trailing, pad, trailing, slotHeight)
    leftSlot.Visible, rightSlot.Visible = leading > 0, trailing > 0
    local gripX = if leading > 0 then titleX else 0
    Factory.Rect(self._grip, gripX, 0, titleX + titleWidth - gripX, bar)
    self._grip.Visible = self._canDrag and not fillCompact

    local y = math.min(h, bar + (if profile.compactChrome then 3 else 0))
    local body = Layout.WindowBody(w, h, y, pad, gripSize)
    local bodyW, remaining = body.width, body.height
    local statusH = math.min(props.statusBarHeight, math.max(0, remaining - target - gap))
    local bodyH = remaining - statusH - (if statusH > 0 then gap else 0)
    local status = self._layoutSlots.StatusBar
    Factory.Rect(status, pad, y + remaining - statusH, bodyW, statusH)
    status.Visible = statusH > 0
    local mode = Layout.Navigation(profile, self._navigation, bodyW, bodyH, target, #self._tabs)
    local contentX, contentY = rect.x + content.x, rect.y + content.y
    self._bubbleExclusions = { Layout.Rect(contentX, contentY, w, bar) }
    if mode == "hidden" or #self._tabs == 0 then
        self._nav.Visible = false
        Factory.Rect(self._pages, pad, y, bodyW, bodyH)
    else
        self._nav.Visible = true
        if mode == "left" or mode == "right" then
            local railLimit = if profile.compactChrome then 106 else 136
            local preferredRail = if props.sidebarWidth > 0 then props.sidebarWidth else math.min(railLimit, math.floor(bodyW * 0.29))
            local rail = math.min(math.max(0, bodyW - gap), math.max(target, preferredRail))
            table.insert(self._bubbleExclusions,
                Layout.Rect(contentX + (if mode == "left" then pad else pad + bodyW - rail), contentY + y, rail, bodyH))
            self:_layoutTabs(mode, rail, target)
            Factory.Rect(self._nav, if mode == "left" then pad else pad + bodyW - rail, y, rail, bodyH)
            Factory.Rect(self._pages, if mode == "left" then pad + rail + gap else pad, y, bodyW - rail - gap, bodyH)
        else
            local navH = target + 2 * Layout.TabPadding
            local navY = if mode == "bottom" then y + math.max(0, bodyH - navH) else y
            table.insert(self._bubbleExclusions, Layout.Rect(contentX + pad, contentY + navY, bodyW, navH))
            self:_layoutTabs(mode, bodyW, target)
            Factory.Rect(self._nav, pad, navY, bodyW, navH)
            Factory.Rect(self._pages, pad, if mode == "bottom" then y else y + navH + gap, bodyW, bodyH - navH - gap)
        end
    end
end

function Window:_layoutTabs(mode, width, step)
    local rail = mode == "left" or mode == "right"
    local count = #self._tabs
    local capacity = if rail then count elseif mode == "drawer" then 0 else Layout.TabCapacity(width - 2 * Layout.TabPadding, math.max(step, 62), 8)
    local overflow = capacity < count
    local visible = if overflow then math.max(0, capacity - 1) else count
    local shown = {}
    for _, tab in ipairs(self._tabs) do
        if #shown >= visible then break end
        table.insert(shown, tab)
    end
    if visible > 0 and self._activeTab and not table.find(shown, self._activeTab) then shown[visible] = self._activeTab end
    local slots = visible + (if overflow then 1 else 0)
    for _, tab in ipairs(self._tabs) do
        local index = table.find(shown, tab)
        tab._button.Visible = index ~= nil
        if index then
            local rect = Layout.TabBounds(width, step, index - 1, slots, rail)
            Factory.Rect(tab._button, rect.x, rect.y, rect.width, rect.height)
        end
    end
    self._more.Visible = overflow
    self._more.Text = Layout.TabLauncherLabel(visible, if self._activeTab then self._activeTab._button.Text else nil)
    if overflow then
        local rect = Layout.TabBounds(width, step, visible, slots, false)
        Factory.Rect(self._more, rect.x, rect.y, rect.width, rect.height)
    end
    local scroll = self._tabScroll
    scroll.Visible = visible > 0
    scroll.ScrollingEnabled = rail
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.None
    local canvas = if rail then count * step + math.max(0, count - 1) * 8 + 2 * Layout.TabPadding else 0
    scroll.CanvasSize = UDim2.fromOffset(0, canvas)
    if not rail then scroll.CanvasPosition = Vector2.zero end
end

function Window:_bindGestures()
    local workspace, input = self._workspace, self._workspace._input
    input:Bind(self._scope, self._grip, self, function(position, native)
        if not self:_canInteract() or not self._canDrag or not self._rect then return nil end
        workspace:_raise(self)
        local before = self._rect
        local restorePlacement = self._placement
        local wasDocked = restorePlacement ~= "floating"
        local snap = if native.UserInputType == Enum.UserInputType.Touch
            then self._options.dockable ~= false and self._options.touchDock == true
            else self._options.dockable == true
        local changed = false
        return {
            drag = function(dx, dy)
                local origin, area = workspace._origin, workspace._screenArea
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
                    self:Dock(Layout.DockAt(pointer.X - workspace._origin.X, pointer.Y - workspace._origin.Y, workspace._screenArea, self._props.snapDistance))
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
            self._requested = Layout.Resize(rect, workspace._screenArea, dx, dy, self._limits)
            self:_reflow()
        end, finish = function() workspace:_placeBubbles() end }
    end)
    input:Bind(self._scope, self._bubble, self, function()
        if self._open or workspace:_hasModal() or not self._bubbleRect then return nil end
        local rect = self._bubbleRect
        local area, protected = workspace:_bubbleBounds(self)
        local function finish()
            if self._bubbleDragging then
                self._bubbleAnchor = Layout.BubbleAnchor(self._bubbleDragging, area)
                self._side = if self._bubbleAnchor.x < 0.5 then "left" else "right"
            end
            self._bubbleDragging = nil
            workspace:_placeBubbles()
        end
        return {
            drag = function(dx, dy)
                local nextRect = Layout.Clamp(Layout.Rect(rect.x + dx, rect.y + dy, rect.width, rect.height), area)
                local anchor = Layout.BubbleAnchor(nextRect, area)
                local safe = Layout.FreeBubble(area, protected, anchor, nextRect.width)
                if safe then
                    self._bubbleDragging = safe
                    Factory.Rect(self._bubble, safe.x, safe.y, safe.width, safe.height)
                end
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
    local inset = Factory.Padding(page, 6)
    inset.PaddingRight = UDim.new(0, 8)
    Factory.List(page, 8)
    local button = scope:Give(Factory.Button(self._tabScroll, options.title or options.id))
    local tab
    local context = {
        workspace = self._workspace, owner = self,
        theme = function() return self:_theme() end,
        canInteract = function() return self:_canInteract() and self._activeTab == tab and page.Visible end,
    }
    tab = setmetatable({
        Id = options.id, _window = self, _page = page, _button = button, _scope = scope,
        _disabled = options.disabled == true,
        _container = Container.new(page, scope, { context = context }):Section({ name = "Content" }),
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
    if not self:_canInteract() or not self._nav.Visible or not self._more.Visible then return end
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

function Window:_refreshBubbleImage()
    if self._destroyed then return end
    local appearance, icon = self._bubbleStyle, self._bubbleIcon
    local hasImage = self._bubbleEditable ~= nil
        or (appearance.image and not ReopenStyle.IsImageUrl(appearance.image) and icon.IsLoaded)
    icon.Visible = hasImage == true
    self._bubble.Text = if hasImage then "" else appearance.label
end

function Window:_applyBubbleImage(source)
    local icon = self._bubbleIcon
    if self._bubbleEditable then
        icon.ImageContent = Content.none
        self._bubbleEditable:Destroy()
        self._bubbleEditable = nil
    end
    local request = {}
    self._bubbleImageRequest = request
    local remote = ReopenStyle.IsImageUrl(source)
    icon.Image = if source and not remote then source else ""
    self:_refreshBubbleImage()
    local workspace = self._workspace
    local resolve = remote and workspace._settings.resolveReopenImage
    if not resolve then return end

    task.defer(function()
        if self._destroyed or self._bubbleImageRequest ~= request then return end
        local ok, image = pcall(resolve, source)
        if self._destroyed or self._bubbleImageRequest ~= request or not ok
            or not ReopenStyle.IsPixelImage(image) then return end
        local editable
        local rendered = pcall(function()
            local size = Vector2.new(image.width, image.height)
            editable = workspace.Runtime.Services:Get("AssetService"):CreateEditableImage({ Size = size })
            if editable then
                editable:WritePixelsBuffer(Vector2.zero, size, image.pixels)
                icon.ImageContent = Content.fromObject(editable)
            end
        end)
        if not rendered then
            if editable then editable:Destroy() end
            return
        end
        self._bubbleEditable = editable
        self:_refreshBubbleImage()
    end)
end

function Window:_styleBubble(size)
    local appearance = self._bubbleStyle
    local scale, radius = ReopenStyle.Corner(appearance, size, 0)
    self._bubble.Shape.CornerRadius = UDim.new(scale, radius)
    local imageScale = appearance.imageScale
    self._bubbleIcon.Size = UDim2.fromScale(imageScale, imageScale)
    local iconScale, iconRadius = ReopenStyle.Corner(appearance, size, size * (1 - imageScale) / 2)
    self._bubbleIconCorner.CornerRadius = UDim.new(iconScale, iconRadius)
end

function Window:SetReopenBubble(options)
    self:_assertLive()
    local appearance = ReopenStyle.Merge(self._bubbleStyle, options)
    self._workspace._input:Cancel(self)
    local changed = self._bubbleStyle.image ~= appearance.image
    self._bubbleStyle = appearance
    if changed then self:_applyBubbleImage(appearance.image) else self:_refreshBubbleImage() end
    self._workspace:_placeBubbles()
end

function Window:SetProps(patch)
    self:_assertLive()
    local props = WindowProps.Merge(self._props, patch)
    self._workspace._input:Cancel(self)
    self._props = props
    self:_reflow()
    self._workspace:_placeBubbles()
end

function Window:SetBounds(patch)
    self:_assertLive()
    local current = self._requested or self._initialBounds
    local bounds = WindowProps.Bounds(current, patch)
    self._workspace._input:Cancel(self)
    if self._requested then
        self._requested = bounds
    else
        self._initialBounds = bounds
    end
    self:_reflow()
    self._workspace:_placeBubbles()
end

function Window:SetTheme(id)
    self:_assertLive()
    if id ~= nil and not self._workspace.Themes:Get(id) then return false end
    self._themeId = id
    self:_reflow()
    self._workspace:_placeBubbles()
    self._workspace._componentChanged:Fire(self)
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
    local slot = self._layoutSlots[name]
    if slot then return slot end
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
    if self._bubbleEditable then
        self._bubbleEditable:Destroy()
        self._bubbleEditable = nil
    end
    workspace:_forget(self)
end

function Tab:GetSlot(name)
    return self._container:GetSlot(name)
end

function Tab:Section(options)
    return self._container:Section(options)
end

for kind in pairs(Components.Definitions) do
    Tab[kind] = function(self, props) return Components.Create(self._container, kind, props) end
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
