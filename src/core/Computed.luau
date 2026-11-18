local Error = require(if script then script.Parent.Error else "./Error")
local Result = require(if script then script.Parent.Result else "./Result")
local Schema = require(if script then script.Parent.Schema else "./Schema")
local Computed = {}
Computed.__index = Computed

function Computed.new(store)
    assert(not store._destroyed and not store._computed and not store._inTransaction, "Expected an idle store without a computed registry")
    local self = setmetatable({ _store = store, _nodes = {}, _order = {}, _dirty = {} }, Computed)
    store._computed = self
    return self
end

local function sort(nodes)
    local order, state, keys = {}, {}, {}
    local function visit(key)
        if state[key] == "visiting" then return false end
        if state[key] == "done" or not nodes[key] then return true end
        state[key] = "visiting"
        for _, dependency in ipairs(nodes[key].dependencies) do
            if not visit(dependency) then return false end
        end
        state[key] = "done"
        table.insert(order, key)
        return true
    end
    for key in pairs(nodes) do table.insert(keys, key) end
    table.sort(keys)
    for _, key in ipairs(keys) do if not visit(key) then return nil end end
    return order
end

function Computed:_has(key)
    return self._nodes[key] ~= nil
end

function Computed:Define(key, dependencies, calculate)
    if self._disposed then return Result.Err(Error.Create("DISPOSED")) end
    if self._store._inTransaction or self._store._publishing or type(key) ~= "string" or key == ""
        or self._nodes[key] or self._store:Get(key) ~= nil or type(dependencies) ~= "table"
        or type(calculate) ~= "function" then
        return Result.Err(Error.Create("INVALID_ARGUMENT"))
    end
    for index, dependency in pairs(dependencies) do
        if type(index) ~= "number" or index < 1 or index > #dependencies or index % 1 ~= 0
            or type(dependency) ~= "string" or dependency == "" then
            return Result.Err(Error.Create("INVALID_ARGUMENT"))
        end
    end
    for index = 1, #dependencies do
        if dependencies[index] == nil then return Result.Err(Error.Create("INVALID_ARGUMENT")) end
    end
    local nodes = table.clone(self._nodes)
    nodes[key] = { dependencies = table.freeze(table.clone(dependencies)), calculate = calculate }
    local order = sort(nodes)
    if not order then return Result.Err(Error.Create("COMPUTED_CYCLE")) end
    local oldNodes, oldOrder = self._nodes, self._order
    self._nodes, self._order, self._dirty[key] = nodes, order, true
    local result = self._store:Batch(function() end)
    if not result.ok and not self._disposed then
        self._nodes, self._order, self._dirty[key] = oldNodes, oldOrder, nil
    end
    return result
end

function Computed:_evaluate(draft, previous)
    for _, key in ipairs(self._order) do
        if self._disposed then return Result.Err(Error.Create("DISPOSED")) end
        local node = self._nodes[key]
        local dirty, input = self._dirty[key], {}
        for _, dependency in ipairs(node.dependencies) do
            input[dependency] = draft[dependency]
            dirty = dirty or not Schema.Equal(draft[dependency], previous[dependency])
        end
        if dirty then
            local result = Result.CallSync(node.calculate, table.freeze(input))
            if self._disposed then return Result.Err(Error.Create("DISPOSED")) end
            if not result.ok then return result end
            result = Schema.Copy(result.value)
            if not result.ok then return result end
            draft[key] = result.value
        end
    end
    table.clear(self._dirty)
    return Result.Ok(nil)
end

function Computed:Invalidate(key)
    if self._disposed then return Result.Err(Error.Create("DISPOSED")) end
    if self._store._inTransaction or self._store._publishing or not self._nodes[key] then
        return Result.Err(Error.Create("INVALID_ARGUMENT"))
    end
    self._dirty[key] = true
    local result = self._store:Batch(function() end)
    if not result.ok then self._dirty[key] = nil end
    return result
end

function Computed:Dispose()
    if self._disposed then return end
    self._disposed = true
    self._store._computed = nil
    table.clear(self._nodes)
    table.clear(self._dirty)
end

return table.freeze(Computed)
