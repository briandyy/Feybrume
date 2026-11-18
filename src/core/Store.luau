local Error = require(if script then script.Parent.Error else "./Error")
local Result = require(if script then script.Parent.Result else "./Result")
local Schema = require(if script then script.Parent.Schema else "./Schema")
local Signal = require(if script then script.Parent.Signal else "./Signal")

local Store = {}
Store.__index = Store

local SOURCES = table.freeze({ user = true, programmatic = true, restore = true, remote = true })
local MAX_QUEUE = 128

function Store.new(initial, options)
    options = options or {}
    local result = Schema.Copy(initial or {})
    assert(result.ok and type(result.value) == "table", "Store requires plain initial state")
    for key in pairs(result.value) do
        assert(type(key) == "string", "Store keys must be strings")
    end
    return setmetatable({
        _snapshot = result.value, _revision = 0, _onError = options.onError, _queue = {},
        _signal = Signal.new(options.clock, options.onError), _onDestroy = options.onDestroy,
    }, Store)
end

function Store:Get(key)
    return self:Snapshot()[key]
end

function Store:Snapshot()
    return self._snapshot, self._revision
end

function Store:Observe(keys, callback)
    if keys == nil then return self._signal:Connect(callback) end
    local selected = table.clone(keys)
    return self._signal:Connect(function(snapshot, event)
        for _, key in ipairs(selected) do
            if event.changed[key] then
                callback(snapshot, event)
                return
            end
        end
    end)
end

local function runBatch(self, callback, source, silent)
    local previous = self._snapshot
    local draft, invalid = table.clone(previous), nil
    local active = true
    local transaction = table.freeze({
        Get = function(_, key)
            assert(active, "Transaction has closed")
            return draft[key]
        end,
        Set = function(_, key, value)
            assert(active, "Transaction has closed")
            local result
            if type(key) ~= "string" or #key == 0 or (self._computed and self._computed:_has(key)) then
                result = Result.Err(Error.Create("INVALID_ARGUMENT"))
            else
                result = Schema.Copy(value)
            end
            if result.ok then draft[key] = result.value else invalid = invalid or result end
            return result
        end,
    })

    self._inTransaction = true
    local result = Result.CallSync(callback, transaction)
    active = false
    if result.ok and not invalid and self._computed and not self._destroyed then
        result = self._computed:_evaluate(draft, previous)
    end
    self._inTransaction = false
    if self._destroyed then return Result.Err(Error.Create("DISPOSED")) end
    if invalid then return invalid end
    if not result.ok then return result end

    local changed = {}
    for key, value in pairs(draft) do
        if not Schema.Equal(value, previous[key]) then changed[key] = true end
    end
    for key in pairs(previous) do
        if draft[key] == nil then changed[key] = true end
    end
    if next(changed) == nil then return Result.Ok(self._revision) end

    self._revision += 1
    self._snapshot = table.freeze(draft)
    self._publishing = true
    self._signal:Fire(self._snapshot, table.freeze({
        previous = previous, source = source, revision = self._revision, changed = table.freeze(changed),
        silent = silent == true,
    }))
    self._publishing = false
    return Result.Ok(self._revision)
end

function Store:Batch(callback, source, silent)
    source = source or "programmatic"
    if self._destroyed then return Result.Err(Error.Create("DISPOSED")) end
    if self._inTransaction or type(callback) ~= "function" or not SOURCES[source] then
        return Result.Err(Error.Create("INVALID_ARGUMENT"))
    end
    if self._publishing then
        if #self._queue >= MAX_QUEUE then return Result.Err(Error.Create("INVALID_ARGUMENT")) end
        table.insert(self._queue, { callback = callback, source = source, silent = silent })
        return Result.Ok(table.freeze({ queued = true }))
    end

    local result = runBatch(self, callback, source, silent)
    local remaining = MAX_QUEUE
    while #self._queue > 0 and remaining > 0 and not self._destroyed do
        remaining -= 1
        local item = table.remove(self._queue, 1)
        local queued = runBatch(self, item.callback, item.source, item.silent)
        if not queued.ok and self._onError then Result.CallSync(self._onError, queued.error) end
    end
    if #self._queue > 0 then
        table.clear(self._queue)
        if not self._destroyed and self._onError then
            Result.CallSync(self._onError, Error.Create("CALLBACK_FAILED"))
        end
    end
    return result
end

function Store:Set(key, value, source)
    local result = Schema.Copy(value)
    if not result.ok then return result end
    return self:Batch(function(transaction)
        transaction:Set(key, result.value)
    end, source)
end

function Store:Destroy()
    if self._destroyed then return end
    self._destroyed = true
    table.clear(self._queue)
    if self._computed then self._computed:Dispose() end
    self._signal:Destroy()
    local onDestroy = self._onDestroy
    self._onDestroy = nil
    if onDestroy then Result.CallSync(onDestroy, self) end
end

return table.freeze(Store)
