local Error = require(if script then script.Parent.Error else "./Error")
local Result = require(if script then script.Parent.Result else "./Result")
local Clock = {}
Clock.__index = Clock

function Clock.new(scheduler, onError)
    return setmetatable({ _scheduler = scheduler, _onError = onError }, Clock)
end

function Clock:Monotonic()
    return self._scheduler.monotonic()
end

function Clock:WallUTC()
    return self._scheduler.wallUTC()
end

function Clock:After(delaySeconds, callback)
    assert(type(delaySeconds) == "number" and delaySeconds >= 0
        and delaySeconds < math.huge, "Expected a finite nonnegative delay")
    local active = true
    local cancel = self._scheduler.schedule(delaySeconds, function()
        if active then
            active = false
            local ok, err = pcall(callback)
            if not ok and self._onError then
                Result.CallSync(self._onError, Error.Redact(err))
            end
        end
    end)
    return table.freeze({
        Cancel = function()
            if active then
                active = false
                cancel()
            end
        end,
    })
end

return table.freeze(Clock)
