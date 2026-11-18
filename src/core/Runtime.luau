local function robloxHost()
    assert(game ~= nil and task ~= nil, "Inject a host when running outside Roblox")
    return {
        getService = function(name) return game:GetService(name) end,
        scheduler = {
            schedule = function(delaySeconds, callback)
                local thread = task.delay(delaySeconds, callback)
                return function() task.cancel(thread) end
            end,
            monotonic = os.clock,
            wallUTC = os.time,
        },
    }
end

local Clock = require(if script then script.Parent.Clock else "./Clock")
local Error = require(if script then script.Parent.Error else "./Error")
local Janitor = require(if script then script.Parent.Janitor else "./Janitor")
local Logger = require(if script then script.Parent.Logger else "./Logger")
local Promise = require(if script then script.Parent.Promise else "./Promise")
local Result = require(if script then script.Parent.Result else "./Result")
local Services = require(if script then script.Parent.Services else "./Services")
local Signal = require(if script then script.Parent.Signal else "./Signal")
local Store = require(if script then script.Parent.Store else "./Store")

local Runtime = {}
Runtime.__index = Runtime

local nativeProbes = {
    ["host.studio"] = function(services) return services:Get("RunService"):IsStudio() end,
    ["host.client"] = function(services) return services:Get("RunService"):IsClient() end,
    ["host.server"] = function(services) return services:Get("RunService"):IsServer() end,
}

function Runtime.Create(host, options)
    host = host or robloxHost()
    options = options or {}
    assert(type(host.getService) == "function", "Host requires getService")
    local probes = table.clone(nativeProbes)
    for id, probe in pairs(options.probes or {}) do
        assert(type(id) == "string" and probes[id] == nil and type(probe) == "function",
            "Expected a new capability ID and probe function")
        probes[id] = probe
    end

    local logger
    local function report(value)
        if logger then logger:Push(value) end
    end
    local clock = Clock.new(host.scheduler, report)
    logger = Logger.new(options.diagnosticCapacity, clock, options.diagnosticSink)
    local scope = Janitor.new(report)
    local services = Services.new(host)
    local changed = Signal.new(clock, report)
    scope:Give(logger)
    scope:Give(services)
    scope:Give(changed)
    local self = setmetatable({
        Clock = clock, Diagnostics = logger, Scope = scope, Services = services,
        CapabilityChanged = changed, _probes = probes, _capabilities = {}, _report = report,
    }, Runtime)
    local ids = {}
    for id in pairs(probes) do table.insert(ids, id) end
    table.sort(ids)
    for _, id in ipairs(ids) do self:Refresh(id) end
    return self
end

function Runtime:GetCapabilities()
    return table.freeze(table.clone(self._capabilities))
end

function Runtime:Refresh(id)
    if self._disposed then return Result.Err(Error.Create("DISPOSED")) end
    if type(id) ~= "string" or not self._probes[id] or self._probing then
        return Result.Err(Error.Create("INVALID_ARGUMENT"))
    end
    self._probing = true
    local probe = Result.CallSync(self._probes[id], self.Services)
    self._probing = false
    if self._disposed then return Result.Err(Error.Create("DISPOSED")) end
    local state, reason
    if not probe.ok then
        state, reason = "unknown", "CAPABILITY_PROBE_FAILED"
        self._report(Error.Create(reason))
    elseif type(probe.value) == "boolean" then
        state = if probe.value then "available" else "unavailable"
    else
        state, reason = "unknown", "NOT_VERIFIED"
    end
    if self._disposed then return Result.Err(Error.Create("DISPOSED")) end
    local previous = self._capabilities[id]
    local record = table.freeze({ id = id, state = state, reason = reason, checkedAt = self.Clock:WallUTC() })
    self._capabilities[id] = record
    if not previous or previous.state ~= state or previous.reason ~= reason then
        self.CapabilityChanged:Fire(record, previous)
    end
    return Result.Ok(record)
end

function Runtime:CreateStore(initial)
    assert(not self._disposed, "Runtime has been disposed")
    local scope = self.Scope
    local store = Store.new(initial, {
        clock = self.Clock,
        onError = self._report,
        onDestroy = function(closed) scope:Remove(closed) end,
    })
    scope:Give(store, nil, store)
    return store
end

function Runtime:Spawn(work, parentToken)
    assert(not self._disposed, "Runtime has been disposed")
    local job = Promise.Spawn(self.Clock, work, parentToken, self._report)
    local scope = self.Scope
    scope:Give(job, nil, job)
    job:OnSettled(function() scope:Remove(job) end)
    return job
end

function Runtime:Dispose()
    if self._disposed then return end
    self._disposed = true
    self.Scope:Destroy()
end

return table.freeze(Runtime)
