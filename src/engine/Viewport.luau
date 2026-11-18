local Layout = require(if script then script.Parent.Layout else "./Layout")
local Viewport = {}

local function keyboardBounds(input, origin)
    if not input.OnScreenKeyboardVisible then return nil end
    local keyboard, size = input.OnScreenKeyboardPosition, input.OnScreenKeyboardSize
    if size.X <= 0 or size.Y <= 0 then return nil end
    return Layout.Rect(keyboard.X - origin.X, keyboard.Y - origin.Y, size.X, size.Y)
end

local function available(root, input)
    local size = root.AbsoluteSize
    return Layout.KeyboardArea(Layout.Rect(0, 0, size.X, size.Y), keyboardBounds(input, root.AbsolutePosition))
end

function Viewport.Read(input, gui, breakpoints)
    local screen = gui:GetInsetArea(Enum.ScreenInsets.None)
    local core = gui:GetInsetArea(Enum.ScreenInsets.CoreUISafeInsets)
    local device = gui:GetInsetArea(Enum.ScreenInsets.DeviceSafeInsets)
    local free = gui:GetInsetArea(Enum.ScreenInsets.TopbarSafeInsets)
    local origin = core.Min
    local keyboard = keyboardBounds(input, origin)
    local safe = Layout.Rect(0, 0, core.Width, core.Height)
    local area = Layout.KeyboardArea(safe, keyboard)
    local lane
    if free.Width > 0 and free.Height > 0 and free.Min.Y <= device.Min.Y and free.Max.Y >= origin.Y then
        lane = Layout.Rect(free.Min.X - origin.X, device.Min.Y - origin.Y, free.Width, origin.Y - device.Min.Y)
    end
    local root = Layout.Rect(origin.X - screen.Min.X, origin.Y - screen.Min.Y, core.Width, core.Height)
    local travel = Layout.KeyboardArea(
        Layout.Rect(screen.Min.X - origin.X, screen.Min.Y - origin.Y, screen.Width, screen.Height), keyboard)
    local preferred = input.PreferredInput
    local kind = if preferred == Enum.PreferredInput.Touch then "touch"
        elseif preferred == Enum.PreferredInput.Gamepad then "gamepad" else "pointer"
    return Layout.Inset(area, 8), Layout.Profile(core.Width, core.Height, kind, breakpoints, input.TouchEnabled),
        origin, area, root, lane, travel
end

function Viewport.LauncherAreas(visible, device, originX, originY)
    local top = math.clamp(device.y - originY, visible.y, visible.y + visible.height)
    local bottom = math.clamp(device.y + device.height - originY, top, visible.y + visible.height)
    local left = math.clamp(device.x - originX, visible.x, visible.x + visible.width)
    local right = math.clamp(device.x + device.width - originX, left, visible.x + visible.width)
    return Layout.Rect(visible.x, top, visible.width, bottom - top),
        Layout.Rect(left, top, right - left, bottom - top)
end

function Viewport.ReadLauncher(root, input, gui, fullWidth)
    local device = gui:GetInsetArea(Enum.ScreenInsets.DeviceSafeInsets)
    local topbar = gui:GetInsetArea(Enum.ScreenInsets.TopbarSafeInsets)
    local core = gui:GetInsetArea(Enum.ScreenInsets.CoreUISafeInsets)
    local origin = if fullWidth then gui:GetInsetArea(Enum.ScreenInsets.None).Min else device.Min
    local deviceRect = Layout.Rect(device.Min.X, device.Min.Y, device.Width, device.Height)
    local area, touchArea = Viewport.LauncherAreas(available(root, input), deviceRect, origin.X, origin.Y)
    local x, y = core.Min.X - origin.X, core.Min.Y - origin.Y
    local free = Layout.Rect(topbar.Min.X - origin.X, topbar.Min.Y - origin.Y, topbar.Width, topbar.Height)
    return area, x, y, Layout.TopbarObstacles(area, y, free), touchArea
end

function Viewport.RevealFocused(root, service)
    local editor = service:GetFocusedTextBox()
    if not editor or not editor:IsDescendantOf(root) then return end
    Viewport.Reveal(editor)
end

function Viewport.Reveal(object, padding)
    padding = padding or 6
    local scroll = object:FindFirstAncestorWhichIsA("ScrollingFrame")
    if not scroll then return end
    local y = object.AbsolutePosition.Y - scroll.AbsolutePosition.Y
    local viewHeight = scroll.AbsoluteWindowSize.Y
    local bottom = y + object.AbsoluteSize.Y
    local offset = 0
    if bottom > viewHeight - padding then offset = bottom - viewHeight + padding end
    if y < padding then offset = y - padding end
    if offset ~= 0 then
        local current = scroll.CanvasPosition
        scroll.CanvasPosition = Vector2.new(current.X,
            math.clamp(current.Y + offset, 0, math.max(0, scroll.AbsoluteCanvasSize.Y - viewHeight)))
    end
end

function Viewport.Observe(scope, root, service, callback)
    scope:Give(root:GetPropertyChangedSignal("AbsoluteSize"):Connect(callback))
    scope:Give(root:GetPropertyChangedSignal("AbsolutePosition"):Connect(callback))
    for _, property in ipairs({ "PreferredInput", "OnScreenKeyboardVisible", "OnScreenKeyboardPosition", "OnScreenKeyboardSize" }) do
        scope:Give(service:GetPropertyChangedSignal(property):Connect(callback))
    end
end

return table.freeze(Viewport)
