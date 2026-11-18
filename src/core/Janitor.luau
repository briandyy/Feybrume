local Error = require(if script then script.Parent.Error else "./Error")
local Result = require(if script then script.Parent.Result else "./Result")

local Janitor = {}
Janitor.__index = Janitor

function Janitor.new(onError)
    return setmetatable({ _resources = {}, _keys = {}, _state = "open", _onError = onError }, Janitor)
end

local function inferCleanup(resource)
    if type(resource) == "function" then return resource end
    local resourceType = typeof(resource)
    if resourceType == "Instance" then return function() resource:Destroy() end end
    if resourceType == "RBXScriptConnection" then return function() resource:Disconnect() end end
    if type(resource) == "table" then
        for _, method in ipairs({ "Disconnect", "Cancel", "Destroy", "Dispose" }) do
            if type(resource[method]) == "function" then
                return function() resource[method](resource) end
            end
        end
    end
    error("Resource requires an explicit cleanup function", 3)
end

local function runCleanup(self, callback)
    local result = Result.CallSync(callback)
    if not result.ok and self._onError then
        Result.CallSync(self._onError, Error.Create("CLEANUP_FAILED"))
    end
end

function Janitor:Give(resource, cleanup, key)
    local callback
    if cleanup then
        assert(type(cleanup) == "function", "Expected cleanup function")
        callback = function() cleanup(resource) end
    else
        callback = inferCleanup(resource)
    end

    if key ~= nil and self._keys[key] then
        error("Cleanup key is already registered. Remove it before replacing the resource.", 2)
    end
    if self._state ~= "open" then
        runCleanup(self, callback)
        return resource
    end
    local entry = { cleanup = callback, key = key }
    table.insert(self._resources, entry)
    if key ~= nil then self._keys[key] = entry end
    return resource
end

local function detach(self, entry)
    local index = table.find(self._resources, entry)
    if index then table.remove(self._resources, index) end
    if entry.key ~= nil then self._keys[entry.key] = nil end
end

function Janitor:Remove(key)
    local entry = self._keys[key]
    if not entry then return false end
    detach(self, entry)
    runCleanup(self, entry.cleanup)
    return true
end

function Janitor:Fork()
    local child = Janitor.new(self._onError)
    self:Give(child, function(scope) scope:Destroy() end, child)
    local entry = self._keys[child]
    if entry then
        entry.child = child
        child._parent = self
    end
    return child
end

function Janitor:GetCounts()
    local scopes, resources = 0, 0
    for _, entry in ipairs(self._resources) do
        if entry.child then
            local nested = entry.child:GetCounts()
            scopes += 1 + nested.scopes
            resources += nested.resources
        else
            resources += 1
        end
    end
    return table.freeze({ scopes = scopes, resources = resources })
end

local function markClosing(scope)
    if scope._state ~= "open" then return end
    scope._state = "closing"
    for _, entry in ipairs(scope._resources) do
        if entry.child then markClosing(entry.child) end
    end
end

function Janitor:Destroy()
    if self._state == "closed" then return end
    markClosing(self)
    self._state = "closed"
    local parent = self._parent
    self._parent = nil
    if parent and parent._keys[self] then detach(parent, parent._keys[self]) end
    while #self._resources > 0 do
        local entry = self._resources[#self._resources]
        detach(self, entry)
        runCleanup(self, entry.cleanup)
    end
end

return table.freeze(Janitor)
