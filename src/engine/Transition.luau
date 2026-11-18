local Error = require(if script then script.Parent.Parent.core.Error else "../core/Error")
local Result = require(if script then script.Parent.Parent.core.Result else "../core/Result")

local Transition = {}
Transition.__index = Transition

function Transition.new(adapter, scope, onError)
    assert(type(adapter) == "table" and type(adapter.read) == "function"
        and type(adapter.write) == "function" and type(adapter.create) == "function",
        "A transition adapter must provide read, write, and create")

    local self = setmetatable({ _adapter = adapter, _active = {}, _scope = scope, _onError = onError }, Transition)
    if scope then scope:Give(self, function(owned) owned:Destroy() end, self) end
    return self
end

local function release(self, target, record, cancel)
    if self._active[target] ~= record then return false end
    self._active[target] = nil
    local handle = record.handle
    if handle then
        if cancel then
            local cancelled = Result.CallSync(handle.Cancel, handle)
            if not cancelled.ok and self._onError then Result.CallSync(self._onError, cancelled.error) end
        end
        local disposed = Result.CallSync(handle.Destroy, handle)
        if not disposed.ok and self._onError then Result.CallSync(self._onError, disposed.error) end
    end
    return true
end

function Transition:Cancel(target)
    local record = self._active[target]
    return if record then release(self, target, record, true) else false
end

local function equal(left, right)
    for key, value in pairs(left) do if right[key] ~= value then return false end end
    for key in pairs(right) do if left[key] == nil then return false end end
    return true
end

function Transition:Apply(target, goals, motion, animated)
    if self._disposed then return Result.Err(Error.Create("DISPOSED")) end
    if target == nil or type(goals) ~= "table" or type(motion) ~= "table"
        or type(motion.seconds) ~= "number" or not (motion.seconds >= 0 and motion.seconds < math.huge)
        or (animated ~= nil and type(animated) ~= "table") then
        return Result.Err(Error.Create("INVALID_ARGUMENT"))
    end
    for key in pairs(goals) do
        if type(key) ~= "string" then return Result.Err(Error.Create("INVALID_ARGUMENT")) end
    end

    local current = self._active[target]
    if current and equal(current.goals, goals) and equal(current.motion, motion)
        and equal(current.animated, animated or {}) then return Result.Ok(false) end
    local immediate, changing = {}, {}
    local adapter = self._adapter
    for key, goal in pairs(goals) do
        local value = Result.CallSync(adapter.read, target, key)
        if not value.ok then return value end
        if value.value ~= goal then
            if motion.seconds > 0 and animated and animated[key] then
                changing[key] = goal
            else
                immediate[key] = goal
            end
        end
    end

    local record
    if next(changing) then
        local active = { goals = table.clone(goals), motion = table.clone(motion), animated = table.clone(animated) }
        local built = Result.CallSync(adapter.create, target, changing, motion, function()
            release(self, target, active, false)
        end)
        if not built.ok then return built end
        local handle = built.value
        if type(handle) ~= "table" or type(handle.Play) ~= "function"
            or type(handle.Cancel) ~= "function" or type(handle.Destroy) ~= "function" then
            return Result.Err(Error.Create("INVALID_ARGUMENT"))
        end
        active.handle = handle
        record = active
    end
    self:Cancel(target)
    if record then self._active[target] = record end

    if next(immediate) then
        local written = Result.CallSync(adapter.write, target, immediate)
        if not written.ok then
            if record then release(self, target, record, true) end
            return written
        end
    end

    if record then
        local started = Result.CallSync(record.handle.Play, record.handle)
        if not started.ok then
            release(self, target, record, true)
            return started
        end
    end
    return Result.Ok(record ~= nil or next(immediate) ~= nil)
end

function Transition:Destroy()
    if self._disposed then return end
    self._disposed = true
    for target in pairs(table.clone(self._active)) do self:Cancel(target) end
    if self._scope then
        local scope = self._scope
        self._scope = nil
        scope:Remove(self)
    end
end

return table.freeze(Transition)
