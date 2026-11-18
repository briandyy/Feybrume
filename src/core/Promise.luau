local Error = require(if script then script.Parent.Error else "./Error")
local Result = require(if script then script.Parent.Result else "./Result")
local Signal = require(if script then script.Parent.Signal else "./Signal")
local Promise = {}
Promise.__index = Promise

local function settle(self, result)
    if self._result then return false end
    self._result = result
    if self._start then
        self._start.Cancel()
        self._start = nil
    end
    if self._parentConnection then
        self._parentConnection:Disconnect()
        self._parentConnection = nil
    end
    if Error.Is(result.error, "CANCELLED") then
        self._cancelled:Fire(result.error)
    end
    self._cancelled:Destroy()
    self._settled:Fire(result)
    self._settled:Destroy()
    return true
end

function Promise.Spawn(clock, work, parentToken, onError)
    assert(type(work) == "function", "Expected a task function")
    local self = setmetatable({
        _settled = Signal.new(clock, onError),
        _cancelled = Signal.new(clock, onError),
    }, Promise)
    local token = table.freeze({
        IsCancelled = function() return self._result ~= nil and Error.Is(self._result.error, "CANCELLED") end,
        OnCancelled = function(_, callback)
            if self._result and Error.Is(self._result.error, "CANCELLED") then
                local replay = Signal.new(clock, onError)
                local connection = replay:Once(callback)
                replay:Fire(self._result.error)
                replay:Destroy()
                return connection
            end
            return self._cancelled:Connect(callback)
        end,
    })
    if parentToken then
        if parentToken:IsCancelled() then
            self:Cancel()
        else
            local connection = parentToken:OnCancelled(function() self:Cancel() end)
            if self._result then connection:Disconnect() else self._parentConnection = connection end
        end
    end
    if not self._result then
        self._start = clock:After(0, function()
            self._start = nil
            if self._result then return end
            local ok, value = pcall(work, token)
            if ok then
                settle(self, Result.Ok(value))
            else
                settle(self, Result.Err(value))
            end
        end)
    end
    return self
end

function Promise:Cancel(_reason)
    return settle(self, Result.Err(Error.Create("CANCELLED")))
end

function Promise:Await(timeoutSeconds)
    if self._result then return self._result end
    local outcome = self._settled:Wait(timeoutSeconds)
    if not outcome.ok then return outcome end
    return outcome.value[1]
end

function Promise:OnSettled(callback)
    if self._result then
        local connection = self._settled:Once(callback)
        local outcome = Result.CallSync(callback, self._result)
        if not outcome.ok and self._settled._onError then
            Result.CallSync(self._settled._onError, outcome.error)
        end
        return connection
    end
    return self._settled:Once(callback)
end

return table.freeze(Promise)
