local Gesture = {}
Gesture.__index = Gesture

function Gesture.new(slop)
    return setmetatable({ _slop = slop or 6 }, Gesture)
end

function Gesture:IsActive()
    return self._active ~= nil
end

function Gesture:Begin(pointer, x, y, subject)
    if self._active or pointer == nil then return false end
    self._active = { pointer = pointer, x = x, y = y, subject = subject, dragged = false }
    return true
end

function Gesture:Move(pointer, x, y)
    local active = self._active
    if not active or pointer ~= active.pointer then return nil end
    local dx, dy = x - active.x, y - active.y
    active.dragged = active.dragged or dx * dx + dy * dy >= self._slop * self._slop
    if active.dragged then return active.subject, dx, dy end
    return nil
end

function Gesture:Finish(pointer, x, y)
    local active = self._active
    if not active or pointer ~= active.pointer then return nil end
    self:Move(pointer, x, y)
    self._active = nil
    return active.subject, active.dragged, x - active.x, y - active.y
end

function Gesture:Cancel(owner)
    local active = self._active
    if active and (owner == nil or active.subject.owner == owner) then
        self._active = nil
        return active.subject
    end
    return nil
end

return table.freeze(Gesture)
