local Error = require(if script then script.Parent.Error else "./Error")
local Result = require(if script then script.Parent.Result else "./Result")
local Services = {}
Services.__index = Services

function Services.new(host)
    return setmetatable({ _host = host, _cache = {} }, Services)
end

function Services:TryGet(name: any)
    if self._disposed then return Result.Err(Error.Create("DISPOSED")) end
    if type(name) ~= "string" or not string.match(name, "^[A-Za-z][A-Za-z0-9]*$") then
        return Result.Err(Error.Create("INVALID_ARGUMENT"))
    end
    if self._cache[name] then return self._cache[name] end
    local call = Result.CallSync(self._host.getService, name)
    local result = if call.ok and call.value ~= nil then call
        else Result.Err(Error.Create("SERVICE_UNAVAILABLE", { retryable = true }))
    self._cache[name] = result
    return result
end

function Services:Get(name)
    local result = self:TryGet(name)
    if not result.ok then error(result.error, 2) end
    return result.value
end

function Services:Invalidate(name)
    if name == nil then table.clear(self._cache) else self._cache[name] = nil end
end

function Services:Dispose()
    self._disposed = true
    table.clear(self._cache)
end

return table.freeze(Services)
