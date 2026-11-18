local Error = require(if script then script.Parent.Parent.core.Error else "../core/Error")
local Result = require(if script then script.Parent.Parent.core.Result else "../core/Result")
local Schema = require(if script then script.Parent.Parent.core.Schema else "../core/Schema")
local Typography = require(if script then script.Parent.Parent.engine.Typography else "../engine/Typography")

local ControlSpec = {}
local textSchema = Schema.new({ type = "string", required = true, maxLength = 8192 })
local numberSchema = Schema.new({ type = "number", required = true })
local boolSchema = Schema.new({ type = "boolean", required = true })
local text = { model = "display", style = "ghost", role = "body", size = 16, schema = textSchema }
local action = { model = "action", style = "soft", role = "button", size = 16 }
local boolean = { model = "value", style = "soft", role = "body", size = 16, schema = boolSchema }
local definitions = {}

local function define(name, base, changes)
    local spec = table.clone(base)
    for key, value in pairs(changes or {}) do spec[key] = value end
    spec.kind = name
    definitions[name] = table.freeze(spec)
end

define("Label", text)
define("Heading", text, { role = "heading", size = 24 })
define("Subheading", text, { role = "heading", size = 19 })
define("Paragraph", text, { size = 15 })
define("RichText", text, { rich = true })
define("Caption", text, { role = "caption", size = 13 })
define("TextDivider", text, { role = "caption", size = 13, divider = true })
define("IconText", text, { iconEmphasis = 4 })
define("Statistic", text, { role = "heading", size = 25, schema = numberSchema, metric = true })
define("Quote", text, { quote = true })
define("Button", action)
define("IconButton", action, { style = "outline", iconEmphasis = 6 })
define("Toggle", boolean, { indicator = "toggle" })
define("Checkbox", boolean, { indicator = "checkbox" })
define("Radio", boolean, { indicator = "radio", selectOnly = true })
define("RadioGroup", boolean, { indicator = "radio", group = true })
define("Tag", text, { style = "outline", size = 13, compact = true })
define("Badge", text, { style = "solid", size = 13, compact = true })
ControlSpec.Definitions = table.freeze(definitions)

local variants = {
    solid = true, soft = true, ghost = true, outline = true, glass = true,
    neomorphic = true, brutalist = true, minimal = true,
}
local sizes = { XS = true, S = true, M = true, L = true, XL = true, ["2XL"] = true }
local function boundedText(value)
    return type(value) == "string" and #value <= 8192 and utf8.len(value) ~= nil
end

local function keyName(value)
    return type(value) == "string" and #value <= 96 and value:match("^[%w_.-]+$") ~= nil
end

local function optionalFunction(value)
    return type(value) == "function" or value == false
end

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function isBoolean(value)
    return type(value) == "boolean"
end

local function timing(value)
    if value == false then return true end
    if not plain(value) then return false end
    for key in pairs(value) do
        if key ~= "mode" and key ~= "seconds" and key ~= "leading" and key ~= "trailing" then return false end
    end
    return (value.mode == "throttle" or value.mode == "debounce")
        and type(value.seconds) == "number" and value.seconds > 0 and value.seconds <= 60
        and (value.leading == nil or isBoolean(value.leading))
        and (value.trailing == nil or isBoolean(value.trailing))
end

function ControlSpec.IconUri(value: any)
    if value == false then return nil end
    if type(value) == "number" and value >= 1 and value <= 9007199254740991 and value % 1 == 0 then
        return string.format("rbxassetid://%.0f", value :: number)
    end
    if type(value) ~= "string" or #value > 32 then return nil end
    local id = value:match("^rbxassetid://([1-9]%d*)$") or value:match("^([1-9]%d*)$")
    if id then return "rbxassetid://" .. id end
    return nil
end

local mutable = {
    name = boundedText, description = boundedText, tooltip = boundedText, author = boundedText, unit = boundedText,
    variant = function(value) return type(value) == "string" and variants[value] == true end,
    size = function(value) return type(value) == "string" and sizes[value] == true end,
    style = function(value) return value == false or plain(value) end,
    theme = function(value) return value == false or keyName(value) end,
    font = function(value) return value == false or Typography.IsDescriptor(value) end,
    icon = function(value) return value == false or ControlSpec.IconUri(value) ~= nil end,
    visible = isBoolean, disabled = isBoolean, locked = isBoolean, loading = isBoolean,
    visibleIf = optionalFunction, enabledIf = optionalFunction, lockedIf = optionalFunction,
    onClick = optionalFunction, onChanged = optionalFunction, callbackTiming = timing,
}
local initial = {
    text = boundedText, default = function() return true end,
    flag = keyName, flagNamespace = keyName, persist = isBoolean, shared = isBoolean,
    slot = keyName, options = plain,
}
local required = { visible = true, disabled = false, locked = false, loading = false }

local function bad(code)
    return Result.Err(Error.Create(code or "INVALID_VALUE"))
end

local function merge(base, patch, definitionsAtMount)
    if not plain(patch) then return bad("INVALID_ARGUMENT") end
    local props = table.clone(base)
    for key, value in pairs(patch) do
        local validator = mutable[key] or (definitionsAtMount and initial[key])
        if not validator or not validator(value) then return bad() end
        if key == "style" or key == "font" or key == "callbackTiming" then
            local copied = Schema.Copy(value)
            if not copied.ok then return copied end
            value = copied.value
        end
        props[key] = value
    end
    return Result.Ok(table.freeze(props))
end

function ControlSpec.Patch(props, patch)
    return merge(props, patch, false)
end

local function groupOptions(options)
    if not plain(options) or #options < 1 or #options > 32 then return bad() end
    local seen, enabled, ordered, count = {}, {}, {}, 0
    for index, entry in pairs(options) do
        if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > #options
            or not plain(entry) or not keyName(entry.id) or seen[entry.id]
            or not boundedText(entry.name) or (entry.disabled ~= nil and type(entry.disabled) ~= "boolean") then
            return bad()
        end
        for key in pairs(entry) do
            if key ~= "id" and key ~= "name" and key ~= "disabled" then return bad() end
        end
        seen[entry.id] = true
        count += 1
        ordered[index] = table.freeze({ id = entry.id, name = entry.name, disabled = entry.disabled == true })
    end
    if count ~= #options then return bad() end
    for _, entry in ipairs(ordered) do
        if not entry.disabled then table.insert(enabled, entry.id) end
    end
    if #enabled == 0 then return bad() end
    return Result.Ok({
        options = table.freeze(ordered), default = enabled[1],
        schema = Schema.new({ type = "string", required = true, enum = table.freeze(enabled) }),
    })
end

function ControlSpec.Mount(kind, options)
    local definition = definitions[kind]
    if not definition then return bad("INVALID_ARGUMENT") end
    local props = merge(required, if options == nil then {} else options, true)
    if not props.ok then return props end
    local values = table.clone(props.value)
    local default, schema, choices = values.default, definition.schema, nil
    if (values.flag and definition.model ~= "value")
        or ((values.persist or values.shared) and not values.flag)
        or (values.shared and definition.group)
        or (not definition.group and values.options ~= nil)
        or (values.onClick and definition.model ~= "action")
        or (values.onChanged and definition.model == "action") then
        return bad()
    end
    if definition.group then
        local group = groupOptions(values.options)
        if not group.ok then return group end
        choices, schema = group.value.options, group.value.schema
        if default == nil then default = group.value.default end
    elseif definition.model == "value" and default == nil then
        default = false
    elseif definition.model == "display" and default == nil then
        default = if definition.metric then 0 else values.text or values.name or ""
    end
    if definition.model ~= "action" then
        if definition.model == "display" and not definition.metric and not boundedText(default) then return bad() end
        local normalized = schema:Normalize(default)
        if not normalized.ok then return normalized end
        default = normalized.value
    elseif default ~= nil then
        return bad()
    end
    values.name = values.name or values.text or (if definition.model == "display" then "" else kind)
    values.options, values.default, values.text = nil, nil, nil
    return Result.Ok(table.freeze({
        definition = definition, props = table.freeze(values), default = default, schema = schema, choices = choices,
    }))
end

function ControlSpec.Value(spec, value)
    if spec.definition.model == "action" then return bad("UNSUPPORTED_OPERATION") end
    if spec.definition.model == "display" and not spec.definition.metric and not boundedText(value) then return bad() end
    return spec.schema:Normalize(value)
end

local safeTags = { b = true, i = true, u = true, s = true }
local function escape(value)
    return (value:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

function ControlSpec.SafeRichText(value)
    local output, stack, cursor = {}, {}, 1
    for first, token, last in value:gmatch("()(<[^<>]+>)()") do
        table.insert(output, escape(value:sub(cursor, first - 1)))
        local tag = token:match("^<([bius])>$")
        local close = token:match("^</([bius])>$")
        if tag and safeTags[tag] and #stack < 16 then
            table.insert(stack, tag)
            table.insert(output, token)
        elseif close and stack[#stack] == close then
            table.remove(stack)
            table.insert(output, token)
        elseif token == "<br/>" or token == "<br />" then
            table.insert(output, "<br/>")
        else
            table.insert(output, escape(token))
        end
        cursor = last
    end
    table.insert(output, escape(value:sub(cursor)))
    for index = #stack, 1, -1 do table.insert(output, "</" .. stack[index] .. ">") end
    return table.concat(output)
end

return table.freeze(ControlSpec)
