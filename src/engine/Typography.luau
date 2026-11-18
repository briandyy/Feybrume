local Error = require(if script then script.Parent.Parent.core.Error else "../core/Error")
local Result = require(if script then script.Parent.Parent.core.Result else "../core/Result")

local Typography = {}
Typography.__index = Typography
local roleFields = {
    heading = "headingRole", title = "headingRole", body = "bodyRole",
    button = "bodyRole", input = "bodyRole", caption = "bodyRole", code = "codeRole",
}
local families = {
    serif = "Bodoni", literary = "Merriweather", condensed = "Oswald", wide = "Montserrat",
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

local enumFonts

local function buildNative(descriptor)
    local weight = Enum.FontWeight[descriptor.weight]
    local style = Enum.FontStyle[descriptor.style]
    if descriptor.assetId then return Font.fromId(descriptor.assetId, weight, style) end
    if not enumFonts then
        enumFonts = {}
        for _, item in ipairs(Enum.Font:GetEnumItems()) do enumFonts[item.Name] = item end
    end
    local known = enumFonts[descriptor.family]
    if known then
        local face = Font.fromEnum(known)
        return Font.new(face.Family, weight, style)
    end
    return Font.fromName(descriptor.family, weight, style)
end

function Typography.RobloxBoundsProbe(services)
    return function(face)
        local textService = services:Get("TextService")
        local params = Instance.new("GetTextBoundsParams")
        local ok, bounds = pcall(function()
            params.Text = "Feybrume"
            params.Font = face
            params.Size = 16
            params.Width = 1024
            return textService:GetTextBoundsAsync(params)
        end)
        params:Destroy()
        return ok and bounds.X > 0 and bounds.Y > 0
    end
end

-- A supplied probe may yield. Configure it where resolution runs in an async task.
function Typography.new(createFont, checkFont)
    return setmetatable({ _create = createFont or buildNative, _check = checkFont, _cache = {}, _size = 0 }, Typography)
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
    for index, input in ipairs(plan.candidates) do
        if not Typography.IsDescriptor(input) then return Result.Err(Error.Create("INVALID_VALUE")) end
        local candidate = table.freeze({
            family = input.family, assetId = input.assetId,
            weight = input.weight or "Regular", style = input.style or "Normal",
        })
        local source = candidate.family or ("#" .. tostring(candidate.assetId))
        local key = source .. "/" .. candidate.weight .. "/" .. candidate.style
        local face = self._cache[key]
        if face == nil then
            local created = Result.CallSync(self._create, candidate)
            face = if created.ok then created.value or false else false
            if face and self._check then
                local ok, accepted = pcall(self._check, face, candidate)
                if not ok or accepted ~= true then face = false end
            end
            local cached = self._cache[key]
            if cached then
                face = cached
            else
                if self._size == 64 then
                    table.clear(self._cache)
                    self._size = 0
                end
                if self._cache[key] == nil then self._size += 1 end
                self._cache[key] = face
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
