local Error = require(if script then script.Parent.Parent.core.Error else "../core/Error")
local Result = require(if script then script.Parent.Parent.core.Result else "../core/Result")
local Janitor = require(if script then script.Parent.Parent.core.Janitor else "../core/Janitor")
local Signal = require(if script then script.Parent.Parent.core.Signal else "../core/Signal")
local Store = require(if script then script.Parent.Parent.core.Store else "../core/Store")
local Schema = require(if script then script.Parent.Parent.core.Schema else "../core/Schema")
local Throttle = require(if script then script.Parent.Parent.core.Throttle else "../core/Throttle")
local ControlSpec = require(if script then script.Parent.ControlSpec else "./ControlSpec")

local ControlBase = {}
ControlBase.__index = ControlBase
local sources = { user = true, programmatic = true, restore = true, remote = true }
local function failure(code)
    return Result.Err(Error.Create(code))
end

local function settings(options)
    if options == nil then return { source = "programmatic", silent = false } end
    if type(options) ~= "table" or getmetatable(options) ~= nil then return nil end
    for key in pairs(options) do
        if key ~= "source" and key ~= "silent" then return nil end
    end
    local source = options.source
    if source ~= nil and (type(source) ~= "string" or not sources[source]) then return nil end
    if options.silent ~= nil and type(options.silent) ~= "boolean" then return nil end
    return { source = source or "programmatic", silent = options.silent == true }
end

function ControlBase.new(context, spec)
    local props = spec.props
    if context.validate and not context.validate(spec, props) then return failure("INVALID_VALUE") end
    local scope = Janitor.new(context.report)
    local self = setmetatable({
        Kind = spec.definition.kind, _spec = spec, _context = context, _scope = scope,
        _props = props, _namespace = props.flagNamespace or context.namespace,
        _value = spec.default,
        _changed = scope:Give(Signal.new(context.clock, context.report)),
        _interacted = scope:Give(Signal.new(context.clock, context.report)),
        _destroying = scope:Give(Signal.new(context.clock, context.report)),
        _focused = scope:Give(Signal.new(context.clock, context.report)),
        _blurred = scope:Give(Signal.new(context.clock, context.report)),
        _errors = scope:Give(Signal.new(context.clock, context.report)),
        _validated = scope:Give(Signal.new(context.clock, context.report)),
    }, ControlBase)

    if spec.definition.model ~= "action" then
        if props.flag then
            if not context.flags then
                scope:Destroy()
                return failure("INVALID_ARGUMENT")
            end
            local bind = context.flags:Bind(self._namespace, props.flag, {
                schema = spec.schema, default = spec.default, shared = props.shared, persist = props.persist,
            })
            if not bind.ok then
                scope:Destroy()
                return bind
            end
            self._binding = bind.value
            self._value = self._binding:Get().value
            scope:Give(function() self._binding:Unbind() end)
            scope:Give(self._binding:Observe(function(value, previous, event)
                self:_changedValue(value, previous, event)
            end))
        else
            self._store = scope:Give(Store.new({ value = spec.default }, {
                clock = context.clock, onError = context.report,
            }))
            scope:Give(self._store:Observe({ "value" }, function(snapshot, event)
                self:_changedValue(snapshot.value, event.previous.value, event)
            end))
        end
    end

    self:_updateTiming()
    self:_watchConditions()
    return Result.Ok(self)
end

function ControlBase:_report(errorValue)
    if self._context.report then self._context.report(errorValue) end
    if not self._destroyed then self._errors:Fire(errorValue, self) end
end

function ControlBase:_callback(kind, ...)
    local callback = self._props[kind]
    if not callback then return end
    if self._timing then
        self._timing:Call(callback, ...)
    else
        local result = Result.CallSync(callback, ...)
        if not result.ok then self:_report(result.error) end
    end
end

function ControlBase:_updateTiming()
    self._scope:Remove("callbackTiming")
    local timing = self._props.callbackTiming
    self._timing = nil
    if not timing then return end
    local options = table.clone(timing)
    options.onError = function(errorValue) self:_report(errorValue) end
    self._timing = self._scope:Give(Throttle.Wrap(self._context.clock, function(callback, ...)
        callback(...)
    end, options), nil, "callbackTiming")
end

function ControlBase:_render()
    if self._view and not self._destroyed then self._view:Render(self) end
end

function ControlBase:_watchConditions()
    self._scope:Remove("conditions")
    local flags = self._context.flags
    local props = self._props
    local function passes(predicate, values, fallback, onFailure)
        if not predicate then return fallback end
        local result = Result.CallSync(predicate, values)
        if result.ok and type(result.value) == "boolean" then return result.value end
        self:_report(if result.ok then Error.Create("INVALID_VALUE") else result.error)
        return onFailure == true
    end
    local function update(values)
        if self._destroyed then return end
        self._visible = props.visible and passes(props.visibleIf, values, true)
        self._disabled = props.disabled or not passes(props.enabledIf, values, true)
        self._locked = props.locked or passes(props.lockedIf, values, false, true)
        self:_render()
    end
    if flags and (props.visibleIf or props.enabledIf or props.lockedIf) then
        self._scope:Give(flags:ObserveNamespace(self._namespace, update), nil, "conditions")
    end
    update(if flags then flags:Snapshot(self._namespace) else table.freeze({}))
end

function ControlBase:_changedValue(value, previous, event)
    if self._destroyed then return end
    self._value = value
    self:_render()
    if event.silent then return end
    self._changed:Fire(value, previous, event.source, self)
    if not self._destroyed then self:_callback("onChanged", value, previous, event.source, self) end
end

function ControlBase:_mount(view)
    self._view = view
    self:_render()
end

function ControlBase:Get()
    if self._destroyed then return failure("DISPOSED") end
    if self._spec.definition.model == "action" then return failure("UNSUPPORTED_OPERATION") end
    return Result.Ok(self._value)
end

function ControlBase:Set(value, options)
    if self._destroyed then return failure("DISPOSED") end
    local behavior = settings(options)
    if not behavior then return failure("INVALID_ARGUMENT") end
    local normalized = ControlSpec.Value(self._spec, value)
    if self._spec.definition.model ~= "action" then
        self._validated:Fire(normalized, behavior.source, self)
    end
    if not normalized.ok then return normalized end
    if self._destroyed then return failure("DISPOSED") end
    if self._binding then return self._binding:Set(normalized.value, behavior.source, behavior.silent) end
    return self._store:Batch(function(transaction)
        transaction:Set("value", normalized.value)
    end, behavior.source, behavior.silent)
end

function ControlBase:Reset(options)
    return self:Set(self._spec.default, options)
end

function ControlBase:_activate(choice, source, input)
    if self._destroyed then return failure("DISPOSED") end
    local definition = self._spec.definition
    if definition.model == "display" then return failure("UNSUPPORTED_OPERATION") end
    if not self._visible or self._disabled or self._locked or self._props.loading
        or (self._view and not self._view:CanInteract(input)) then return failure("CONTROL_INACTIVE") end
    if definition.model == "value" then
        local value
        if definition.group then
            value = choice
        else
            value = definition.selectOnly or not self._value
        end
        local changed = self:Set(value, { source = source })
        if not changed.ok then return changed end
    end
    if self._destroyed then return Result.Ok(nil) end
    self._interacted:Fire(source, self)
    if not self._destroyed then self:_callback("onClick", source, self) end
    return Result.Ok(nil)
end

function ControlBase:Activate()
    if self._spec.definition.model ~= "action" then return failure("UNSUPPORTED_OPERATION") end
    return self:_activate(nil, "programmatic")
end

function ControlBase:SetProps(patch)
    if self._destroyed then return failure("DISPOSED") end
    local edited = ControlSpec.Patch(self._props, patch)
    if not edited.ok then return edited end
    local nextProps = edited.value
    if (nextProps.onClick and self._spec.definition.model ~= "action")
        or (nextProps.onChanged and self._spec.definition.model == "action")
        or (self._context.validate and not self._context.validate(self._spec, nextProps)) then
        return failure("INVALID_VALUE")
    end
    local timingChanged = not Schema.Equal(self._props.callbackTiming, nextProps.callbackTiming)
        or self._props.onClick ~= nextProps.onClick or self._props.onChanged ~= nextProps.onChanged
    self._props = nextProps
    if timingChanged then self:_updateTiming() end
    self:_watchConditions()
    return Result.Ok(self)
end

function ControlBase:SetStyle(style) return self:SetProps({ style = if style == nil then false else style }) end
function ControlBase:SetThemeOverride(theme) return self:SetProps({ theme = if theme == nil then false else theme }) end
function ControlBase:SetFont(font) return self:SetProps({ font = if font == nil then false else font }) end
function ControlBase:SetIcon(icon) return self:SetProps({ icon = if icon == nil then false else icon }) end
function ControlBase:SetTooltip(text) return self:SetProps({ tooltip = if text == nil then "" else text }) end
function ControlBase:SetDescription(text) return self:SetProps({ description = if text == nil then "" else text }) end
function ControlBase:SetVisible(value)
    if type(value) ~= "boolean" then return failure("INVALID_VALUE") end
    return self:SetProps({ visible = value })
end
function ControlBase:SetDisabled(value)
    if type(value) ~= "boolean" then return failure("INVALID_VALUE") end
    return self:SetProps({ disabled = value })
end
function ControlBase:Show() return self:SetVisible(true) end
function ControlBase:Hide() return self:SetVisible(false) end
function ControlBase:Enable() return self:SetDisabled(false) end
function ControlBase:Disable() return self:SetDisabled(true) end
function ControlBase:Lock() return self:SetProps({ locked = true }) end
function ControlBase:Unlock() return self:SetProps({ locked = false }) end

function ControlBase:Refresh()
    if self._destroyed then return failure("DISPOSED") end
    self:_watchConditions()
    return Result.Ok(self)
end

function ControlBase:SetOrder(order)
    if self._destroyed then return failure("DISPOSED") end
    if type(order) ~= "number" or order % 1 ~= 0 or order < 1 or order > 1000000000 then
        return failure("INVALID_VALUE")
    end
    return if self._view then self._view:SetOrder(order) else failure("UNSUPPORTED_OPERATION")
end

function ControlBase:MoveTo(container, slot)
    if self._destroyed then return failure("DISPOSED") end
    return if self._view then self._view:MoveTo(container, slot) else failure("UNSUPPORTED_OPERATION")
end

local function step(self, direction)
    if self._destroyed then return failure("DISPOSED") end
    return if self._view then self._view:MoveStep(direction) else failure("UNSUPPORTED_OPERATION")
end

function ControlBase:MoveUp() return step(self, -1) end
function ControlBase:MoveDown() return step(self, 1) end

local function focus(self, selected)
    if self._destroyed then return failure("DISPOSED") end
    if self._spec.definition.model == "display" or not self._view then return failure("UNSUPPORTED_OPERATION") end
    return self._view:Focus(self, selected)
end

function ControlBase:Focus() return focus(self, true) end
function ControlBase:Blur() return focus(self, false) end

function ControlBase:GetSlot(name)
    if self._destroyed then return nil end
    return if self._view then self._view:GetSlot(name) else nil
end

function ControlBase:GetInstance()
    return if self._view then self._view._root else nil
end

function ControlBase:Serialize()
    local result = self:Get()
    if not result.ok then return result end
    return Result.Ok(table.freeze({ kind = self.Kind, flag = self._props.flag, value = result.value }))
end

function ControlBase:OnChanged(callback)
    if self._destroyed then return failure("DISPOSED") end
    if self._spec.definition.model == "action" then return failure("UNSUPPORTED_OPERATION") end
    if type(callback) ~= "function" then return failure("INVALID_ARGUMENT") end
    return Result.Ok(self._changed:Connect(callback))
end

function ControlBase:OnInteract(callback)
    if self._destroyed then return failure("DISPOSED") end
    if self._spec.definition.model == "display" then return failure("UNSUPPORTED_OPERATION") end
    if type(callback) ~= "function" then return failure("INVALID_ARGUMENT") end
    return Result.Ok(self._interacted:Connect(callback))
end

function ControlBase:OnMounted(callback)
    if self._destroyed then return failure("DISPOSED") end
    if type(callback) ~= "function" then return failure("INVALID_ARGUMENT") end
    local result = Result.CallSync(callback, self)
    if not result.ok then self:_report(result.error) end
    return result
end

function ControlBase:OnDestroyed(callback)
    if self._destroyed then return failure("DISPOSED") end
    if type(callback) ~= "function" then return failure("INVALID_ARGUMENT") end
    return Result.Ok(self._destroying:Once(callback))
end

local function onFocus(self, callback, signal)
    if self._destroyed then return failure("DISPOSED") end
    if self._spec.definition.model == "display" then return failure("UNSUPPORTED_OPERATION") end
    if type(callback) ~= "function" then return failure("INVALID_ARGUMENT") end
    return Result.Ok(signal:Connect(callback))
end

function ControlBase:OnFocus(callback) return onFocus(self, callback, self._focused) end
function ControlBase:OnBlur(callback) return onFocus(self, callback, self._blurred) end

function ControlBase:OnError(callback)
    if self._destroyed then return failure("DISPOSED") end
    if type(callback) ~= "function" then return failure("INVALID_ARGUMENT") end
    return Result.Ok(self._errors:Connect(callback))
end

function ControlBase:OnValidate(callback)
    if self._destroyed then return failure("DISPOSED") end
    if self._spec.definition.model == "action" then return failure("UNSUPPORTED_OPERATION") end
    if type(callback) ~= "function" then return failure("INVALID_ARGUMENT") end
    return Result.Ok(self._validated:Connect(callback))
end

function ControlBase:Destroy()
    if self._destroyed then return end
    self._destroyed = true
    self._destroying:Fire(self)
    self._scope:Destroy()
    self._view = nil
end

return table.freeze(ControlBase)
