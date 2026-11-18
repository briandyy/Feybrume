local Error = require(if script then script.Parent.Parent.core.Error else "../core/Error")
local Result = require(if script then script.Parent.Parent.core.Result else "../core/Result")
local ControlSpec = require(if script then script.Parent.ControlSpec else "./ControlSpec")
local ControlBase = require(if script then script.Parent.ControlBase else "./ControlBase")
local ControlView = require(if script then script.Parent.ControlView else "./ControlView")
local Components = { Definitions = ControlSpec.Definitions }

function Components.Create(container, kind, options)
    local context = container._context
    local workspace = context and context.workspace
    local function fail(errorValue)
        if workspace then workspace.Runtime.Diagnostics:Push(errorValue) end
        return nil, errorValue
    end
    if not workspace then return fail(Error.Create("UNSUPPORTED_OPERATION")) end
    local spec = ControlSpec.Mount(kind, options)
    if not spec.ok then return fail(spec.error) end
    local target = container:GetSlot(spec.value.props.slot)
    if not target or not target.Parent then return fail(Error.Create("DISPOSED")) end
    local modelContext = {
        flags = workspace._flags, namespace = workspace._flagNamespace, clock = workspace.Runtime.Clock,
        report = function(errorValue) workspace.Runtime.Diagnostics:Push(errorValue) end,
        container = container,
    }
    modelContext.validate = function(definition, props)
        return ControlView.Validate(modelContext.container, definition, props)
    end
    local model = ControlBase.new(modelContext, spec.value)
    if not model.ok then return fail(model.error) end
    local handle = model.value
    local view = Result.CallSync(ControlView.new, container, handle)
    if not view.ok then
        handle:Destroy()
        return fail(view.error)
    end
    handle:_mount(view.value)
    return handle
end

return table.freeze(Components)
