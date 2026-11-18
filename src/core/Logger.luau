local Error = require(if script then script.Parent.Error else "./Error")
local Signal = require(if script then script.Parent.Signal else "./Signal")
local Logger = {}
Logger.__index = Logger

function Logger.new(capacity, clock, sink)
    capacity = capacity or 100
    assert(type(capacity) == "number" and capacity % 1 == 0
        and capacity >= 1 and capacity <= 10000, "Invalid diagnostic capacity")
    local self = setmetatable({
        _capacity = capacity, _items = {}, _head = 1, _size = 0,
        _signal = Signal.new(clock), _clock = clock,
    }, Logger)
    if sink then self:Subscribe(sink) end
    return self
end

function Logger:Push(value)
    if self._destroyed then return end
    local entry = table.freeze({
        error = Error.Redact(value),
        timestamp = self._clock and self._clock:WallUTC(),
    })
    local index = (self._head + self._size - 1) % self._capacity + 1
    self._items[index] = entry
    if self._size < self._capacity then
        self._size += 1
    else
        self._head = self._head % self._capacity + 1
    end
    if not self._publishing then
        self._publishing = true
        self._signal:Fire(entry)
        self._publishing = false
    end
end

function Logger:List()
    local list = {}
    for offset = 0, self._size - 1 do
        list[offset + 1] = self._items[(self._head + offset - 1) % self._capacity + 1]
    end
    return table.freeze(list)
end

Logger.Export = Logger.List

function Logger:Subscribe(callback)
    return self._signal:Connect(callback)
end

function Logger:Destroy()
    if self._destroyed then return end
    self._destroyed = true
    self._signal:Destroy()
    table.clear(self._items)
    self._size = 0
end

return table.freeze(Logger)
