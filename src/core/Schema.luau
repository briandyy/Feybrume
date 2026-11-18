local Error = require(if script then script.Parent.Error else "./Error")
local Result = require(if script then script.Parent.Result else "./Result")
local Schema = {}
Schema.__index = Schema

local function finite(value)
    return type(value) == "number" and math.abs(value) < math.huge
end

local function reject()
    error(Error.Create("INVALID_VALUE"), 0)
end

local function copy(value, visited, depth, budget)
    budget.remaining -= 1
    if budget.remaining < 0 or depth > 32 then reject() end
    local kind = type(value)
    if kind == "nil" or kind == "string" or kind == "boolean" or finite(value) then return value end
    if kind ~= "table" or getmetatable(value) ~= nil or visited[value] then reject() end

    visited[value] = true
    local result, keyKind, count, highest = {}, nil, 0, 0
    for key, child in pairs(value) do
        local currentKind = type(key)
        if keyKind ~= nil and keyKind ~= currentKind then reject() end
        keyKind = currentKind
        if currentKind == "number" then
            if not finite(key) or key < 1 or key % 1 ~= 0 then reject() end
            highest = math.max(highest, key)
        elseif currentKind ~= "string" then
            reject()
        end
        count += 1
        result[key] = copy(child, visited, depth + 1, budget)
    end
    if keyKind == "number" and highest ~= count then reject() end
    visited[value] = nil
    return table.freeze(result)
end

function Schema.Copy(value)
    return Result.CallSync(copy, value, {}, 0, { remaining = 20000 })
end

function Schema.Equal(left, right)
    if left == right then return true end
    if type(left) ~= "table" or type(right) ~= "table" then return false end
    for key, value in pairs(left) do
        if not Schema.Equal(value, right[key]) then return false end
    end
    for key in pairs(right) do
        if left[key] == nil then return false end
    end
    return true
end

local function normalize(rule, value)
    if value == nil then
        value = rule.default
        if value == nil then
            if rule.required then reject() end
            return nil
        end
        local result = Schema.Copy(value)
        if not result.ok then reject() end
        value = result.value
    end

    local kind = rule.type
    if kind == "integer" then
        if not finite(value) or value % 1 ~= 0 then reject() end
    elseif kind == "array" or kind == "object" then
        if type(value) ~= "table" then reject() end
    elseif kind ~= nil and type(value) ~= kind then
        reject()
    end

    if rule.enum and not table.find(rule.enum, value) then reject() end

    if type(value) == "number" then
        if not finite(value) or (rule.min and value < rule.min) or (rule.max and value > rule.max) then reject() end
    elseif type(value) == "string" then
        if (rule.minLength and #value < rule.minLength)
            or (rule.maxLength and #value > rule.maxLength) then reject() end
    end

    if kind == "array" then
        for key in pairs(value) do
            if type(key) ~= "number" then reject() end
        end
        if (rule.minLength and #value < rule.minLength)
            or (rule.maxLength and #value > rule.maxLength) then reject() end
        if rule.items then
            local items = {}
            for index, item in ipairs(value) do items[index] = normalize(rule.items, item) end
            value = table.freeze(items)
        end
    elseif kind == "object" then
        for key in pairs(value) do
            if type(key) ~= "string" then reject() end
        end
        if rule.fields then
            local object = {}
            for key, childRule in pairs(rule.fields) do
                object[key] = normalize(childRule, value[key])
            end
            for key, child in pairs(value) do
                if rule.fields[key] == nil then
                    if rule.unknown == "preserve" then object[key] = child
                    elseif rule.unknown ~= "strip" then reject() end
                end
            end
            value = table.freeze(object)
        end
    end

    if rule.validate then
        local check = Result.CallSync(rule.validate, value)
        if not check.ok then error(check.error, 0) end
        if check.value ~= true then reject() end
    end
    return value
end

function Schema.new(rule)
    assert(type(rule) == "table", "Expected a schema rule")
    return setmetatable({ _rule = rule }, Schema)
end

function Schema:Normalize(value)
    local result = Schema.Copy(value)
    if not result.ok then return result end
    return Result.CallSync(normalize, self._rule, result.value)
end

function Schema:NormalizePatch(base, patch)
    local result = Schema.Copy(patch)
    if not result.ok then return result end
    if self._rule.type ~= "object" or type(result.value) ~= "table" or type(base) ~= "table" then
        return Result.Err(Error.Create("INVALID_ARGUMENT"))
    end
    local combined = table.clone(base)
    for key, value in pairs(result.value) do combined[key] = value end
    return self:Normalize(combined)
end

return table.freeze(Schema)
