local Gesture = require(if script then script.Parent.Gesture else "./Gesture")
local Input = {}
Input.__index = Input

local function pointer(input)
    local kind = input.UserInputType
    if kind == Enum.UserInputType.Touch then return input end
    if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.MouseMovement then return "mouse" end
    return nil
end

local function contains(target, point)
    local pos, size = target.AbsolutePosition, target.AbsoluteSize
    return point.X >= pos.X and point.Y >= pos.Y and point.X < pos.X + size.X and point.Y < pos.Y + size.Y
end

function Input.new(service, scope)
    local self = setmetatable({ _capture = Gesture.new(), _suspended = false }, Input)
    scope:Give(service.InputChanged:Connect(function(obj)
        if obj.UserInputType ~= Enum.UserInputType.MouseButton1 then
            local p = obj.Position
            local gesture, dx, dy = self._capture:Move(pointer(obj), p.X, p.Y)
            if gesture and gesture.drag then gesture.drag(dx, dy, p) end
        end
    end))
    scope:Give(service.InputEnded:Connect(function(obj)
        if obj.UserInputType == Enum.UserInputType.MouseMovement then return end
        local p = obj.Position
        local gesture, dragged, dx, dy = self._capture:Finish(pointer(obj), p.X, p.Y)
        if not gesture then return end
        if obj.UserInputState == Enum.UserInputState.Cancel then
            if gesture.cancel then gesture.cancel() end
        elseif dragged then
            if gesture.drag then gesture.drag(dx, dy, p) end
            if gesture.finish then gesture.finish(p) end
        elseif gesture.tap and contains(gesture.target, p) then
            gesture.tap()
        elseif gesture.cancel then
            gesture.cancel()
        end
    end))
    scope:Give(service.WindowFocusReleased:Connect(function() self:Cancel() end))
    scope:Give(function() self:Cancel() end)
    return self
end

function Input:Bind(scope, target, owner, start)
    target.Active = true
    scope:Give(target.InputBegan:Connect(function(obj)
        local p = pointer(obj)
        if not p or obj.UserInputType == Enum.UserInputType.MouseMovement or self._suspended or self._capture:IsActive() then return end
        local position = obj.Position
        local gesture = start(position, obj)
        if gesture then
            gesture.owner, gesture.target = owner, target
            if self._capture:Begin(p, position.X, position.Y, gesture) and gesture.began then gesture.began() end
        end
    end))
end

function Input:Cancel(owner)
    local gesture = self._capture:Cancel(owner)
    if gesture and gesture.cancel then gesture.cancel() end
end

function Input:Suspend(value)
    self._suspended = value
    if value then self:Cancel() end
end

function Input.IsPointerActivation(input)
    return input and pointer(input) ~= nil
end

return table.freeze(Input)
