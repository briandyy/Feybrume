local Error = require(if script then script.Parent.Error else "./Error")
local Result = require(if script then script.Parent.Result else "./Result")
local Schema = require(if script then script.Parent.Schema else "./Schema")

local Serializer = {}
Serializer.__index = Serializer
local ESCAPES = { ['"'] = '\\"', ['\\'] = '\\\\', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' }

local function quote(value, limit)
    if #value > limit or not utf8.len(value) then error("Invalid JSON text") end
    return '"' .. string.gsub(value, '[%z\1-\31\\"]', function(char)
        return ESCAPES[char] or string.format("\\u%04x", string.byte(char))
    end) .. '"'
end

local function sensitive(key)
    local name = string.lower(key):gsub("[^a-z]", "")
    for _, part in ipairs({ "password", "secret", "token", "cookie", "credential", "apikey", "privatekey", "authorization" }) do
        if string.find(name, part, 1, true) then return true end
    end
    return false
end

local function filter(value)
    if type(value) ~= "table" then return value end
    local data = {}
    for key, child in pairs(value) do
        if type(key) ~= "string" or not sensitive(key) then data[key] = filter(child) end
    end
    return table.freeze(data)
end

local function encode(value, write, limit)
    local kind = type(value)
    if kind == "string" then write(quote(value, limit))
    elseif kind == "boolean" then write(tostring(value))
    elseif kind == "number" then write(if value == 0 then "0" else string.format("%.17g", value))
    elseif kind == "nil" then write("null")
    elseif #value > 0 then
        write("[")
        for index, child in ipairs(value) do
            if index > 1 then write(",") end
            encode(child, write, limit)
        end
        write("]")
    else
        local keys = {}
        for key in pairs(value) do table.insert(keys, key) end
        table.sort(keys)
        write("{")
        for index, key in ipairs(keys) do
            if index > 1 then write(",") end
            write(quote(key, limit))
            write(":")
            encode(value[key], write, limit)
        end
        write("}")
    end
end

function Serializer.new(options)
    options = options or {}
    local version, limit = options.version or 1, options.maxBytes or 262144
    assert(type(version) == "number" and version > 0 and version % 1 == 0, "Invalid data version")
    assert(type(limit) == "number" and limit > 0 and limit % 1 == 0, "Invalid byte limit")
    return setmetatable({
        _version = version, _limit = limit, _decode = options.decodeJSON,
        _migrations = table.clone(options.migrations or {}), _schema = options.schema,
    }, Serializer)
end

local function serializationFailed()
    return Result.Err(Error.Create("SERIALIZATION_FAILED"))
end

function Serializer:_normalize(data)
    local checked = if self._schema then self._schema:Normalize(data) else Schema.Copy(data)
    if not checked.ok or checked.value == nil then return serializationFailed() end
    return Result.Ok(filter(checked.value))
end

function Serializer:Encode(data)
    local result = self:_normalize(data)
    if not result.ok then return result end
    local encoded = Result.CallSync(function()
        local chunks, bytes = {}, 0
        encode({ version = self._version, data = result.value }, function(chunk)
            bytes += #chunk
            if bytes > self._limit then error("Exceeded JSON size limit") end
            table.insert(chunks, chunk)
        end, self._limit)
        return table.concat(chunks)
    end)
    if not encoded.ok then return serializationFailed() end
    return encoded
end

function Serializer:Migrate(envelope)
    local checked = Schema.Copy(envelope)
    if not checked.ok or type(checked.value) ~= "table" or checked.value.data == nil then
        return serializationFailed()
    end
    local version, data = checked.value.version, filter(checked.value.data)
    if type(version) ~= "number" or version % 1 ~= 0 or version < 1 or version > self._version then
        return Result.Err(Error.Create("UNSUPPORTED_VERSION"))
    end
    for current = version, self._version - 1 do
        local migration = self._migrations[current]
        if type(migration) ~= "function" then
            return Result.Err(Error.Create("UNSUPPORTED_VERSION"))
        end
        local migrated = Result.CallSync(migration, data)
        if not migrated.ok then return serializationFailed() end
        checked = Schema.Copy(migrated.value)
        if not checked.ok or checked.value == nil then return serializationFailed() end
        data = filter(checked.value)
    end
    return self:_normalize(data)
end

function Serializer:Decode(json)
    if type(json) ~= "string" or #json > self._limit or type(self._decode) ~= "function" then
        return serializationFailed()
    end
    local decoded = Result.CallSync(self._decode, json)
    if not decoded.ok then return serializationFailed() end
    return self:Migrate(decoded.value)
end

return table.freeze(Serializer)
