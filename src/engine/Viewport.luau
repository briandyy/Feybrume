local Layout = require(if script then script.Parent.Layout else "./Layout")
local Viewport = {}

function Viewport.Read(root, input, breakpoints)
    local size, origin = root.AbsoluteSize, root.AbsolutePosition
    local preferred = input.PreferredInput
    local kind = if preferred == Enum.PreferredInput.Touch then "touch"
        elseif preferred == Enum.PreferredInput.Gamepad then "gamepad" else "pointer"
    local area = Layout.Rect(0, 0, size.X, size.Y)
    if input.OnScreenKeyboardVisible then
        local keyboard = input.OnScreenKeyboardPosition
        local keyboardSize = input.OnScreenKeyboardSize
        if keyboardSize.X > 0 and keyboardSize.Y > 0 then
            area = Layout.KeyboardArea(area,
                Layout.Rect(keyboard.X - origin.X, keyboard.Y - origin.Y, keyboardSize.X, keyboardSize.Y))
        end
    end
    return Layout.Inset(area, 8), Layout.Profile(size.X, size.Y, kind, breakpoints), origin
end

function Viewport.RevealFocused(root, service)
    local editor = service:GetFocusedTextBox()
    if not editor or not editor:IsDescendantOf(root) then return end
    local scroll = editor:FindFirstAncestorWhichIsA("ScrollingFrame")
    if not scroll then return end
    local padding = 6
    local y = editor.AbsolutePosition.Y - scroll.AbsolutePosition.Y
    local viewHeight = scroll.AbsoluteWindowSize.Y
    local bottom = y + editor.AbsoluteSize.Y
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
