local Error = require(if script then script.Parent.Parent.core.Error else "../core/Error")
local Result = require(if script then script.Parent.Parent.core.Result else "../core/Result")

local Typography = {}
Typography.__index = Typography
local roleFields = {
    heading = "headingRole", title = "headingRole", body = "bodyRole",
    button = "bodyRole", input = "bodyRole", caption = "bodyRole", code = "codeRole",
}
local families = {
    serif = "Garamond", literary = "Merriweather", condensed = "Oswald", wide = "Montserrat",
    sans = "BuilderSans", geometric = "Montserrat", rounded = "FredokaOne", mono = "RobotoMono",
}
local weights = {
    Thin = true, ExtraLight = true, Light = true, Regular = true, Medium = true,
    SemiBold = true, Bold = true, ExtraBold = true, Heavy = true,
}

local function validName(name)
    return type(name) == "string" and #name <= 64 and name:match("^[A-Za-z][A-Za-z0-9]*$") ~= nil
end

function Typography.IsDescriptor(value)
    if type(value) ~= "table" or getmetatable(value) ~= nil then return false end
    for key in pairs(value) do
        if key ~= "family" and key ~= "assetId" and key ~= "weight" and key ~= "style" then return false end
    end
    local family, id = value.family, value.assetId
    if (family == nil) == (id == nil) then return false end
    if family ~= nil and not validName(family) then return false end
    if id ~= nil and (type(id) ~= "number" or id < 1 or id > 9007199254740991 or id % 1 ~= 0) then
        return false
    end
    return (value.weight == nil or weights[value.weight] == true)
        and (value.style == nil or value.style == "Normal" or value.style == "Italic")
end

function Typography.Describe(theme, role, preferred)
    local field = roleFields[role]
    if not field or (preferred ~= nil and not Typography.IsDescriptor(preferred)) then
        return Result.Err(Error.Create("INVALID_VALUE"))
    end
    local weight = if role == "title" or role == "heading" then "Bold" else "Regular"
    local candidates = {}
    local function add(descriptor)
        local normalized = table.freeze({
            family = descriptor.family, assetId = descriptor.assetId,
            weight = descriptor.weight or weight, style = descriptor.style or "Normal",
        })
        for _, candidate in ipairs(candidates) do
            if normalized.family == candidate.family and normalized.assetId == candidate.assetId
                and normalized.weight == candidate.weight and normalized.style == candidate.style then
                return
            end
        end
        table.insert(candidates, normalized)
    end
    if preferred then add(preferred) end
    local design = theme.typography
    local fallback = if validName(design.nativeFallback) then design.nativeFallback else "BuilderSans"
    local family = families[design[field]] or fallback
    add({ family = family })
    add({ family = fallback })
    add({ family = "SourceSans" })
    return Result.Ok(table.freeze({ role = role, candidates = table.freeze(candidates) }))
end

local function buildNative(descriptor)
    local weight = Enum.FontWeight[descriptor.weight]
    local style = Enum.FontStyle[descriptor.style]
    if descriptor.family then return Font.fromName(descriptor.family, weight, style) end
    return Font.fromId(descriptor.assetId, weight, style)
end

function Typography.new(createFont)
    return setmetatable({ _create = createFont or buildNative, _cache = {}, _size = 0 }, Typography)
end

function Typography:Resolve(theme, role, preferred)
    local plan = Typography.Describe(theme, role, preferred)
    if not plan.ok then return plan end
    return self:ResolvePlan(plan.value)
end

function Typography:ResolvePlan(plan)
    if type(plan) ~= "table" or type(plan.candidates) ~= "table" or #plan.candidates == 0 then
        return Result.Err(Error.Create("INVALID_VALUE"))
    end
    for index, candidate in ipairs(plan.candidates) do
        if not Typography.IsDescriptor(candidate) then return Result.Err(Error.Create("INVALID_VALUE")) end
        local source = candidate.family or ("#" .. tostring(candidate.assetId))
        local key = source .. "/" .. candidate.weight .. "/" .. candidate.style
        local face = self._cache[key]
        if not face then
            local created = Result.CallSync(self._create, candidate)
            if created.ok then face = created.value end
            if face then
                if self._size == 64 then
                    table.clear(self._cache)
                    self._size = 0
                end
                self._cache[key] = face
                self._size += 1
            end
        end
        if face then
            return Result.Ok(table.freeze({ face = face, selected = candidate, fallback = index > 1 }))
        end
    end
    return Result.Err(Error.Create("FONT_UNAVAILABLE"))
end

function Typography.Apply(target, resolved, size)
    if type(size) ~= "number" or not (size >= 1 and size <= 100) then
        return Result.Err(Error.Create("INVALID_VALUE"))
    end
    return Result.CallSync(function()
        target.FontFace = resolved.face
        target.TextSize = size
    end)
end

return table.freeze(Typography)
