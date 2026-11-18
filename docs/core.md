# Runtime core

[English](core.md) · [Bahasa Indonesia](id/core.md) · [简体中文](zh-CN/core.md)

Feybrume runs with Roblox services or an injected host. The core owns resources, dispatches signals and tasks, and publishes validated state.

## Roblox Studio

Run `rojo serve` from the repository root and connect the Rojo Studio plugin. The project maps `src` to `ReplicatedStorage.Feybrume`. To install manually, create a ModuleScript named `Feybrume` from `src/init.luau`. Add folders named `core`, `engine` and `ui` under it, then put each module from the corresponding `src` folder into it as a ModuleScript with the filename as its name and no extension.

Add this LocalScript to StarterPlayerScripts and press Play.

```luau
local replicatedStorage = game:GetService("ReplicatedStorage")
local Fey = require(replicatedStorage:WaitForChild("Feybrume"))
local runtime = Fey.Runtime.Create()
local store = runtime:CreateStore({ opened = false })

runtime.Scope:Give(store:Observe({ "opened" }, function(state, change)
    print(state.opened, change.revision)
end))

assert(store:Set("opened", true, "user").ok)
assert(runtime:GetCapabilities()["host.client"].state == "available")

local job = runtime:Spawn(function()
    return "ready"
end)
local result = job:Await(5)
assert(result.ok and result.value == "ready")

runtime:Dispose()
assert(runtime.Scope:GetCounts().resources == 0)
```

The script should print `true 1`, complete the task and release the scope. Repeat in Studio's Device Emulator and on a phone using an authorized test place. The desktop and real-device Roblox checks are pending. The deterministic tests run in the Luau CLI with an injected host.

## API

| Module | Behavior |
|---|---|
| Runtime | `Runtime.Create(host?, options?)` creates a scope, clock, service cache and diagnostics. `CreateStore` and `Spawn` register resources. `Dispose` closes the scope. |
| Services | `TryGet(name)` returns a Result. `Get(name)` returns the service or raises a structured error. The cache includes misses. `Invalidate(name?)` clears stale entries. |
| Capabilities | `GetCapabilities()` returns a frozen map. `Refresh(id)` runs a probe. `CapabilityChanged` fires when a state or reason changes. A probe returns `true` for available, `false` for unavailable, or no answer for unknown. Failed probes are unknown. |
| Janitor | `Give(resource, cleanup?, key?)`, `Remove(key)`, `Fork()`, `GetCounts()`, `Destroy()`. Teardown works in reverse registration order and continues after cleanup failures. Remove a key before reusing it. |
| Signal | `Connect`, `Once`, `Fire`, `Wait(timeout?)`, `DisconnectAll`, `Destroy`. A successful wait returns packed arguments, including the argument count and nil positions. Disconnecting all listeners releases pending waits. |
| Promise | `Runtime:Spawn(work, parentToken?)` passes a cancellation token to work. `Await(timeout?)` returns a Result, `OnSettled` runs once or replays an existing result, and `Cancel` discards later results. |
| Clock and Throttle | `After(seconds, callback)` returns a cancel handle. `Throttle.Wrap(clock, callback, options)` returns a handle with `Call`, `Flush`, `Cancel` and `Destroy`. Options include interval, debounce or throttle, leading or trailing calls and an optional scope. |
| Result and Error | `Ok(value)` and `Err(error)` return frozen outcomes. The types `Result<T>` and `FeyError` are exported by the Result ModuleScript. Errors have fixed messages and allowlisted numeric or boolean context. |
| Logger | `Push`, `List`, `Subscribe` and `Export` use a bounded in-memory buffer. Redaction happens before notification. |
| Schema | `Schema.new(rule)` supports types, defaults, bounds, enums, arrays, nested fields, unknown-field policy and validators. `NormalizePatch(base, patch)` validates the combined object. |
| Store | `Set(key, value, source?)` and `Batch(function(tx) ... end, source?)` write state. `Snapshot` and `Observe(keys?, callback)` expose immutable state. Observer writes run after the current notification. |
| Computed | `Computed.new(store)`, `Define(key, dependencies, calculate)`, `Invalidate(key)` and `Dispose()`. A failed calculation aborts the transaction. |
| Flags | `Bind(namespace, name, options)` returns `Get`, `Set` and `Unbind`. Sharing requires the same schema object and matching options. `Export(namespace)` selects flags marked for persistence. |
| Serializer | `Serializer.new({ version, schema, maxBytes, decodeJSON, migrations })` then `Encode`, `Decode` or `Migrate`. Inject a decoder such as a wrapper around `HttpService:JSONDecode`. Each migration is indexed by its source version. |

A custom host supplies `getService(name)` and a scheduler with `monotonic()`, `wallUTC()` and `schedule(seconds, callback)`. A scheduler queues work for a later turn and returns a cancellation function. Runtime options support named capability probes, a diagnostic capacity and an optional diagnostic subscriber. [Example test host](../tests/FakeHost.luau)

## Limits

- Transactions, validators, signal listeners and cleanup callbacks are synchronous. Call `Await` or `Wait` from a yielding context. An await timeout affects its waiter. Call `Cancel` to stop accepting a task result.
- Work checks `token:IsCancelled()` and can attach cleanup with `token:OnCancelled(callback)`. Roblox operations that already yielded may still finish.
- State accepts finite, tree-shaped data. Use plain representations for Roblox objects in persisted values. Computed keys are read-only while registered. Observer queues have a fixed limit.
- Serialization strips known credential fields. Use an allowlisted schema and keep credentials out of the input. An empty Luau table becomes a JSON object. On decode, null uses the decoder's representation.
- The default probes cover Studio, client and server. Device and asset capabilities need separate probes.

[Core test results](../evidence/phase1-checks.json) · [Core manifest](../phase1-manifest.json)
