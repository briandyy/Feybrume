local Error = require(if script then script.Parent.Error else "./Error")
export type FeyError = {
    code: string, publicMessage: string, context: { [string]: number | boolean },
    recoverable: boolean, retryable: boolean,
}

export type Outcome<T> = { ok: true, value: T } | { ok: false, error: FeyError }

export type Result<T> = Outcome<T>

local Result = {}
local synchronous = setmetatable({}, { __mode = "k" })

function Result.Ok<T>(value: T): Outcome<T>
    return table.freeze({ ok = true, value = value })
end

function Result.Err(value: any): Outcome<never>
    return table.freeze({ ok = false, error = Error.Redact(value) })
end

function Result.Map(result, transform)
    if not result.ok then
        return result
    end
    local ok, value = pcall(transform, result.value)
    if ok then
        return Result.Ok(value)
    end
    return Result.Err(value)
end

-- Used by transactions, listeners, and cleanup that must finish on this stack.
function Result.CanYield()
    return coroutine.isyieldable() and not synchronous[coroutine.running()]
end

function Result.CallSync(callback, ...)
    local thread = coroutine.create(callback)
    synchronous[thread] = true
    local ok, value = coroutine.resume(thread, ...)
    synchronous[thread] = nil
    if not ok then
        return Result.Err(value)
    end
    if coroutine.status(thread) ~= "dead" then
        coroutine.close(thread)
        return Result.Err(Error.Create("CALLBACK_YIELDED"))
    end
    return Result.Ok(value)
end

return table.freeze(Result)
