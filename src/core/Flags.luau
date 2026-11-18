local Error = require(if script then script.Parent.Error else "./Error")
local Result = require(if script then script.Parent.Result else "./Result")
local Flags = {}
Flags.__index = Flags

function Flags.new(store)
    return setmetatable({ _store = store, _bindings = {} }, Flags)
end

local function keyFor(namespace, name)
    if type(namespace) ~= "string" or namespace == "" or type(name) ~= "string" or name == "" then
        return nil
    end
    return tostring(#namespace) .. ":" .. namespace .. name
end

function Flags:Bind(namespace, name, options)
    options = options or {}
    local key = keyFor(namespace, name)
    local schema = options.schema
    if self._store._destroyed then return Result.Err(Error.Create("DISPOSED")) end
    if self._store._publishing or self._store._inTransaction or not key or type(schema) ~= "table" or type(schema.Normalize) ~= "function"
        or (options.merge ~= nil and options.merge ~= "replace") then
        return Result.Err(Error.Create("INVALID_ARGUMENT"))
    end
    local existing = self._bindings[key]
    if existing and (not existing.shared or options.shared ~= true or existing.schema ~= schema
        or existing.persist ~= (options.persist == true) or existing.merge ~= (options.merge or "replace")) then
        return Result.Err(Error.Create("DUPLICATE_FLAG"))
    end
    local slot = existing or {
        schema = schema, shared = options.shared == true, persist = options.persist == true,
        merge = options.merge or "replace", count = 0, namespace = namespace, name = name,
    }
    self._bindings[key] = slot
    slot.count += 1

    local alive = true
    local registry = self
    local handle = table.freeze({
        Set = function(_, value, source)
            if not alive then return Result.Err(Error.Create("DISPOSED")) end
            local normalized = schema:Normalize(value)
            if not normalized.ok then return normalized end
            if not alive then return Result.Err(Error.Create("DISPOSED")) end
            return registry._store:Batch(function(transaction)
                if not alive then error(Error.Create("DISPOSED"), 0) end
                transaction:Set(key, normalized.value)
            end, source)
        end,
        Get = function()
            if not alive or registry._store._destroyed then return Result.Err(Error.Create("DISPOSED")) end
            return Result.Ok(registry._store:Get(key))
        end,
        Unbind = function()
            if not alive then return end
            alive = false
            slot.count -= 1
            if slot.count == 0 then registry._bindings[key] = nil end
        end,
    })
    if not existing then
        local previous = self._store:Get(key)
        if previous == nil then previous = options.default end
        local seeded = handle:Set(previous)
        if not seeded.ok then
            handle:Unbind()
            return seeded
        end
    end
    return Result.Ok(handle)
end

function Flags:Unbind(handle)
    handle:Unbind()
end

function Flags:Find(namespace, name)
    local key = keyFor(namespace, name)
    local slot = key and self._bindings[key]
    if slot then
        return table.freeze({ key = key, count = slot.count, shared = slot.shared, persist = slot.persist })
    end
    return nil
end

function Flags:Export(namespace)
    local values = {}
    for key, slot in pairs(self._bindings) do
        if slot.namespace == namespace and slot.persist then
            values[slot.name] = self._store:Get(key)
        end
    end
    return table.freeze(values)
end

return table.freeze(Flags)
