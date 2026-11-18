# Runtime core

Feybrume's core can run with Roblox services or with an injected host. The core supplies the state and lifecycle utilities that the UI will use.

## Roblox Studio

Run `rojo serve` from the repository root and connect the Rojo Studio plugin. The project maps `src` to `ReplicatedStorage.Feybrume`. For a manual install, create a ModuleScript named `Feybrume` from `src/init.luau`. Add a Folder named `core` under it, then add each file in `src/core` as a ModuleScript with the same basename.

Run this client smoke check from a LocalScript under StarterPlayerScripts.

```luau
local replicatedStorage = game:GetService("ReplicatedStorage")
local Core = require(replicatedStorage:WaitForChild("Feybrume"))
local runtime = Core.Runtime.Create()
local store = runtime:CreateStore({ opened = false })

runtime.Scope:Give(store:Observe({ "opened" }, function(state, change)
    print(state.opened, change.revision)
end))

local changed = store:Set("opened", true, "user")
assert(changed.ok)
assert(runtime:GetCapabilities()["host.client"].state == "available")

local job = runtime:Spawn(function()
    return "ready"
end)
local result = job:Await(5)
assert(result.ok and result.value == "ready")

runtime:Dispose()
assert(runtime.Scope:GetCounts().resources == 0)
```

On a desktop Studio client, start Play and check that the event prints `true 1`, the task finishes, and the cleanup assertions pass. Repeat with Studio's device emulator and with a mobile Roblox client in an authorized test experience. The logged result and lifecycle assertions are the same for touch clients. Roblox-specific checks are pending. The automated suite has run in the Luau CLI using an injected host.

## API

| Module | Entry points and behavior |
|---|---|
| Runtime | `Runtime.Create(host?, options?)` creates a scope, clock, services, and diagnostics. `CreateStore` and `Spawn` register resources with that scope. `Dispose` closes it. |
| Services | `TryGet(name)` returns a Result. `Get(name)` returns a service or raises a structured error. Cache entries include misses. Use `Invalidate(name?)` before retrying a changed host. |
| Capabilities | `GetCapabilities()` returns a frozen map. `Refresh(id)` runs the probe. `CapabilityChanged` fires when its state or reason changes. Probe result `true` means available, `false` means unavailable, and a missing answer or failure means unknown. |
| Janitor | `Give(resource, cleanup?, key?)`, `Remove(key)`, `Fork()`, `GetCounts()`, `Destroy()`. Register a function, a supported resource, or a value with an explicit cleanup function. Teardown works in reverse registration order and continues after a cleanup error. Remove a key before reusing it. |
| Signal | `Connect`, `Once`, `Fire`, `Wait(timeout?)`, `DisconnectAll`, `Destroy`. A successful wait returns packed arguments, including a count and any nil positions. Disconnecting all listeners releases pending waits. |
| Promise | `Runtime:Spawn(work, parentToken?)` passes a cancellation token to work. `Await(timeout?)` returns a Result. `OnSettled` calls once and replays an existing result. `Cancel` settles pending work and discards any later result. |
| Clock and Throttle | `After(seconds, callback)` returns a cancel handle. `Throttle.Wrap(clock, callback, options)` returns a handle with `Call`, `Flush`, `Cancel`, and `Destroy`. Configure interval, debounce or throttle, leading or trailing calls, and an optional scope. |
| Result and Error | `Ok(value)` and `Err(error)` return frozen outcomes. `Result<T>` and `FeyError` are exported from `src/core/Result.luau`. Error codes use fixed public messages and allowlisted numeric or boolean context. |
| Logger | `Push`, `List`, `Subscribe`, and `Export` use a bounded in-memory buffer. Payloads are redacted before reaching subscribers. |
| Schema | `Schema.new(rule)` supports types, defaults, bounds, enums, arrays, nested fields, unknown-field policy and validators. `NormalizePatch(base, patch)` validates a complete combined object with top-level overrides. |
| Store | `Set(key, value, source?)` or `Batch(function(tx) ... end, source?)` writes state. `Snapshot` and `Observe(keys?, callback)` expose immutable state. Changes triggered by an observer run after the current notification. |
| Computed | `Computed.new(store)`, `Define(key, dependencies, calculate)`, `Invalidate(key)`, `Dispose()`. Explicit dependency keys determine which calculations rerun. A failed calculation aborts the transaction. |
| Flags | `Bind(namespace, name, options)` returns a handle with `Get`, `Set`, and `Unbind`. Sharing requires the same schema object and matching options. `Export(namespace)` selects entries marked for persistence. |
| Serializer | `Serializer.new({ version, schema, maxBytes, decodeJSON, migrations })` then `Encode`, `Decode`, or `Migrate`. Inject a decoder such as a wrapper around `HttpService:JSONDecode` in Roblox. Migration functions are indexed by the source version. |

A custom host supplies `getService(name)` and `scheduler` with `monotonic()`, `wallUTC()`, and `schedule(seconds, callback)`. Schedule queues work for a later turn and returns a cancellation function. An example host lives in [tests/FakeHost.luau](../tests/FakeHost.luau). Runtime options allow named capability probes, diagnostic capacity, and an optional diagnostic subscriber.

## Limits and error cases

- Transactions, validators, signal listeners, and cleanup callbacks must complete synchronously. Call `Await` or `Wait` from a yielding context. An await timeout affects that waiter. Use `Cancel` to stop accepting a task result.
- Running work must cooperate with cancellation through `token:IsCancelled()` and `token:OnCancelled(callback)`. Roblox engine operations that already yielded may still finish. If work starts an external wait, use its cancellation hook to release it.
- Core state stores finite, tree-shaped data. Represent Roblox objects like Color3 as plain data when persisting state. Computed keys are read-only while their registry owns them. The observer queue is bounded.
- Serializer strips known credential fields. Persist only an allowlisted schema and keep secrets out of the state supplied to it. An empty Luau table serializes as a JSON object, and JSON decoding uses the host's representation of null.
- Capability probes cover Studio, client and server plus checks supplied by the host. Device and asset access need their own probes. No desktop or mobile Roblox runtime result is recorded yet.

Run `luau tests/core.luau` for the deterministic test suite. See [test evidence](../evidence/phase1-checks.json) and the [manifest](../phase1-manifest.json) for the tested scope.
