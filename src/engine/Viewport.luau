local Layout = require(if script then script.Parent.Layout else "./Layout")
local Viewport = {}

local function available(root, input)
    local size, origin = root.AbsoluteSize, root.AbsolutePosition
    local area = Layout.Rect(0, 0, size.X, size.Y)
    if input.OnScreenKeyboardVisible then
        local keyboard = input.OnScreenKeyboardPosition
        local keyboardSize = input.OnScreenKeyboardSize
        if keyboardSize.X > 0 and keyboardSize.Y > 0 then
            area = Layout.KeyboardArea(area,
                Layout.Rect(keyboard.X - origin.X, keyboard.Y - origin.Y, keyboardSize.X, keyboardSize.Y))
        end
    end
    return area
end

function Viewport.Read(root, input, breakpoints)
    local size = root.AbsoluteSize
    local preferred = input.PreferredInput
    local kind = if preferred == Enum.PreferredInput.Touch then "touch"
        elseif preferred == Enum.PreferredInput.Gamepad then "gamepad" else "pointer"
    return Layout.Inset(available(root, input), 8),
        Layout.Profile(size.X, size.Y, kind, breakpoints, input.TouchEnabled), root.AbsolutePosition
end

function Viewport.ReadLauncher(root, input, gui)
    local device = gui:GetInsetArea(Enum.ScreenInsets.DeviceSafeInsets)
    local topbar = gui:GetInsetArea(Enum.ScreenInsets.TopbarSafeInsets)
    local core = gui:GetInsetArea(Enum.ScreenInsets.CoreUISafeInsets)
    local area = available(root, input)
    local x, y = core.Min.X - device.Min.X, core.Min.Y - device.Min.Y
    local free = Layout.Rect(topbar.Min.X - device.Min.X, topbar.Min.Y - device.Min.Y, topbar.Width, topbar.Height)
    return area, x, y, Layout.TopbarObstacles(area, y, free)
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
