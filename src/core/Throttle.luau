local Error = require(if script then script.Parent.Error else "./Error")
local Result = require(if script then script.Parent.Result else "./Result")
local Throttle = {}
Throttle.__index = Throttle

function Throttle.Wrap(clock, callback, options)
    assert(type(callback) == "function", "Expected a callback")
    options = options or {}
    local mode, seconds = options.mode or "throttle", options.seconds
    assert(mode == "throttle" or mode == "debounce", "Unknown scheduling mode")
    assert(type(seconds) == "number" and seconds > 0 and seconds < math.huge, "Expected a positive interval")
    local self = setmetatable({
        _clock = clock, _callback = callback, _seconds = seconds, _mode = mode,
        _leading = if options.leading == nil then mode == "throttle" else options.leading == true,
        _trailing = options.trailing ~= false, _onError = options.onError,
    }, Throttle)
    if options.scope then
        self._scope = options.scope
        options.scope:Give(self, function(throttle) throttle:Destroy() end, self)
    end
    return self
end

local function invoke(self, args)
    local result = Result.CallSync(self._callback, table.unpack(args, 1, args.n))
    if not result.ok and self._onError then Result.CallSync(self._onError, result.error) end
    return result
end

local function start(self)
    self._timer = self._clock:After(self._seconds, function()
        self._timer = nil
        local args = self._pending
        self._pending = nil
        if not args then return end
        if self._mode == "throttle" then start(self) end
        invoke(self, args)
    end)
end

function Throttle:Call(...)
    if self._destroyed then return Result.Err(Error.Create("DISPOSED")) end
    local args = table.pack(...)
    if not self._timer then
        start(self)
        if self._leading then return invoke(self, args) end
    elseif self._mode == "debounce" then
        self._timer.Cancel()
        start(self)
    end
    if self._trailing then self._pending = args end
    return Result.Ok(nil)
end

function Throttle:Flush()
    if self._destroyed then return Result.Err(Error.Create("DISPOSED")) end
    local args = self._pending
    self:Cancel()
    if args then return invoke(self, args) end
    return Result.Ok(nil)
end

function Throttle:Cancel()
    if self._timer then self._timer.Cancel() end
    self._timer, self._pending = nil, nil
end

function Throttle:Destroy()
    if self._destroyed then return end
    self._destroyed = true
    self:Cancel()
    self._callback = nil
    if self._scope then
        self._scope:Remove(self)
        self._scope = nil
    end
end

return table.freeze(Throttle)
