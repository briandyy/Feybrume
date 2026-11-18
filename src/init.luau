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
})
