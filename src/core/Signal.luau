local Error = require(if script then script.Parent.Error else "./Error")
local Result = require(if script then script.Parent.Result else "./Result")

local Signal = {}
Signal.__index = Signal

function Signal.new(clock, onError)
    return setmetatable({ _clock = clock, _onError = onError, _listeners = {}, _waiters = {} }, Signal)
end

local function connect(self, callback, once)
    assert(type(callback) == "function", "Expected a signal callback")
    local record = { callback = callback, once = once, connected = not self._destroyed }
    if record.connected then
        table.insert(self._listeners, record)
    end
    local function disconnect()
        if not record.connected then
            return
        end
        record.connected = false
        record.callback = nil
        local index = table.find(self._listeners, record)
        if index then
            table.remove(self._listeners, index)
        end
    end
    record.disconnect = disconnect
    return table.freeze(setmetatable({}, table.freeze({
        __index = function(_, key)
            if key == "Connected" then return record.connected end
            if key == "Disconnect" then return disconnect end
            return nil
        end,
    })))
end

function Signal:Connect(callback)
    return connect(self, callback, false)
end

function Signal:Once(callback)
    return connect(self, callback, true)
end

function Signal:Fire(...)
    for _, record in ipairs(table.clone(self._listeners)) do
        if record.connected then
            local callback = record.callback
            if record.once then
                record.disconnect()
            end
            local result = Result.CallSync(callback, ...)
            if not result.ok and self._onError then
                Result.CallSync(self._onError, result.error)
            end
        end
    end
end

function Signal:Wait(timeoutSeconds)
    if self._destroyed then return Result.Err(Error.Create("DISPOSED")) end
    if not Result.CanYield() or (timeoutSeconds ~= nil
        and (not self._clock or type(timeoutSeconds) ~= "number"
            or not (timeoutSeconds >= 0 and timeoutSeconds < math.huge))) then
        return Result.Err(Error.Create("INVALID_ARGUMENT"))
    end

    local thread = coroutine.running()
    local timer, connection
    local function finish(result)
        if not self._waiters[thread] then return end
        self._waiters[thread] = nil
        connection:Disconnect()
        if timer then timer.Cancel() end
        if coroutine.status(thread) == "suspended" then
            local ok, err = coroutine.resume(thread, result)
            if not ok and self._onError then Result.CallSync(self._onError, Error.Redact(err)) end
        end
    end
    self._waiters[thread] = finish
    connection = self:Once(function(...)
        finish(Result.Ok(table.freeze(table.pack(...))))
    end)
    if timeoutSeconds ~= nil then
        timer = self._clock:After(timeoutSeconds, function()
            finish(Result.Err(Error.Create("TIMEOUT")))
        end)
    end
    return coroutine.yield()
end

function Signal:DisconnectAll()
    for _, record in ipairs(table.clone(self._listeners)) do
        record.disconnect()
    end
    for _, finish in pairs(table.clone(self._waiters)) do
        finish(Result.Err(Error.Create("CANCELLED")))
    end
end

function Signal:Destroy()
    if self._destroyed then return end
    self._destroyed = true
    self:DisconnectAll()
end

return table.freeze(Signal)
