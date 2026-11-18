local messages = {
    INVALID_ARGUMENT = "Invalid argument",
    INVALID_VALUE = "Value failed validation",
    CALLBACK_FAILED = "Callback failed",
    CALLBACK_YIELDED = "Synchronous callback yielded",
    CANCELLED = "Operation cancelled",
    TIMEOUT = "Operation timed out",
    DISPOSED = "Resource was disposed",
    CLEANUP_FAILED = "Resource cleanup failed",
    SERVICE_UNAVAILABLE = "Service unavailable",
    CAPABILITY_PROBE_FAILED = "Capability probe failed",
    DUPLICATE_FLAG = "Flag is already bound",
    COMPUTED_CYCLE = "Computed dependency cycle",
    SERIALIZATION_FAILED = "Could not serialize value",
    THEME_NOT_FOUND = "Theme not found",
    DUPLICATE_THEME = "Theme ID already registered",
    FONT_UNAVAILABLE = "No compatible native font could be resolved",
    UNSUPPORTED_VERSION = "Unsupported data version",
    UNSUPPORTED_OPERATION = "This control does not support that operation",
    CONTROL_INACTIVE = "Control is hidden, disabled, locked, or loading",
}

local Error = {}

local safeContextFields = {
    count = true, index = true, revision = true, version = true, resourceCount = true,
}

function Error.Is(value, code)
    if type(value) ~= "table" then return false end
    local actual = rawget(value, "code")
    return type(actual) == "string" and messages[actual] ~= nil and (code == nil or actual == code)
end

function Error.Create(code, metadata)
    metadata = if type(metadata) == "table" then metadata else {}
    if messages[code] == nil then
        code = "INVALID_ARGUMENT"
    end
    local context = {}
    local input = rawget(metadata, "context")
    if type(input) == "table" then
        for key, value in pairs(input) do
            if safeContextFields[key] and (type(value) == "boolean"
                or (type(value) == "number" and math.abs(value) < math.huge)) then
                context[key] = value
            end
        end
    end
    return table.freeze({
        code = code,
        publicMessage = messages[code],
        context = table.freeze(context),
        recoverable = rawget(metadata, "recoverable") ~= false,
        retryable = rawget(metadata, "retryable") == true,
    })
end

function Error.Redact(value)
    if Error.Is(value) then
        return Error.Create(value.code, value)
    end
    return Error.Create("CALLBACK_FAILED")
end

return table.freeze(Error)
