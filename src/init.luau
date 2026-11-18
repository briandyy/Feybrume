local function core(name)
    if script then
        return require(script.core[name])
    end
    -- The CLI resolves paths in a directory module from its parent.
    return require("./src/core/" .. name)
end

local function engine(name)
    if script then
        return require(script.engine[name])
    end
    return require("./src/engine/" .. name)
end

local Workspace = require(if script then script.ui.Workspace else "./src/ui/Workspace")
local defaultWorkspace
local function getWorkspace()
    if not defaultWorkspace or defaultWorkspace._destroyed then defaultWorkspace = Workspace.new() end
    return defaultWorkspace
end

return table.freeze({
    Runtime = core("Runtime"),
    Clock = core("Clock"),
    Error = core("Error"),
    Result = core("Result"),
    Signal = core("Signal"),
    Janitor = core("Janitor"),
    Logger = core("Logger"),
    Services = core("Services"),
    Promise = core("Promise"),
    Schema = core("Schema"),
    Store = core("Store"),
    Computed = core("Computed"),
    Flags = core("Flags"),
    Serializer = core("Serializer"),
    Throttle = core("Throttle"),
    Theme = engine("Theme"),
    StyleResolver = engine("StyleResolver"),
    Tokens = engine("Tokens"),
    Typography = engine("Typography"),
    Motion = engine("Motion"),
    Animation = engine("Animation"),
    Transition = engine("Transition"),
    Workspace = Workspace,
    CreateWorkspace = function(_, options) return Workspace.new(options) end,
    Window = function(_, options) return getWorkspace():Window(options) end,
    SetTheme = function(_, id) return getWorkspace():SetTheme(id) end,
    RegisterTheme = function(_, spec) return getWorkspace():RegisterTheme(spec) end,
    Destroy = function()
        if not defaultWorkspace then return end
        defaultWorkspace:Destroy()
        defaultWorkspace = nil
    end,
})
