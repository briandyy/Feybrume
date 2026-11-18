local FakeHost = {}

function FakeHost.new()
    local now, serial = 0, 0
    local pending, lookups = {}, {}
    local registered = {
        RunService = {
            IsStudio = function() return true end,
            IsClient = function() return true end,
            IsServer = function() return false end,
        },
    }
    return {
        getService = function(name)
            lookups[name] = (lookups[name] or 0) + 1
            return registered[name]
        end,
        scheduler = {
            schedule = function(delay, callback)
                serial += 1
                local id = serial
                pending[id] = { when = now + delay, callback = callback }
                return function() pending[id] = nil end
            end,
            monotonic = function() return now end,
            wallUTC = function() return 1000 + now end,
        },
        advance = function(delay)
            local target = now + delay
            local steps = 0
            while true do
                local first, earliest
                for id, item in pairs(pending) do
                    if item.when <= target and (not earliest or item.when < earliest.when
                        or (item.when == earliest.when and id < first)) then
                        first, earliest = id, item
                    end
                end
                if not first then break end
                steps += 1
                assert(steps < 10000, "Scheduler failed to quiesce")
                pending[first] = nil
                now = earliest.when
                local ok, err = coroutine.resume(coroutine.create(earliest.callback))
                assert(ok, tostring(err))
            end
            now = target
        end,
        pending = function()
            local count = 0
            for _ in pairs(pending) do count += 1 end
            return count
        end,
        lookups = lookups,
        registered = registered,
    }
end

return FakeHost
