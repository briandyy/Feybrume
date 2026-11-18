# Kontrak modul dan dependensi

Setiap modul di bawah adalah desain yang direncanakan. Import path sesuai `src/<group>/<module>.luau`. Core dilarang mengimpor engine, UI atau vendor. Engine dan backend berkomunikasi melalui registri/facade yang diinjeksi pada composition root; contoh `engine/Media` dan `media/SourceResolver` dipisah antara lifecycle UI dan klasifikasi sumber. Desain API publik ada di [Architecture](architecture.md). Signature di sini mendeskripsikan bentuk kontrak, untuk diterjemahkan ke `--!strict` sebelum implementasi.

## core (fase 1)

| Modul | Kontrak | Dependensi / invariant |
|---|---|---|
| Runtime | `Create(host, options)`, `GetCapabilities()`, `Refresh(id)`, `Dispose()` | Services, Clock, Signal, Logger; injected host; capability berubah event. `auto` pilih Studio/native saat tepat, host tambahan hanya explicit contract. |
| Services | `Get(name)`, `TryGet(name)` | Host; cache sukses/failure transient dengan invalidasi. Players, TweenService, UserInputService, GuiService, RunService, HttpService, TextService, ContentProvider, SoundService, ContextActionService, HapticService jika ada. |
| Signal | `Connect`, `Once`, `Wait(timeout?)`, `DisconnectAll`, internal emit | Clock, scoped connection; disconnect saat emit deterministik dan once de-register sebelum callback. |
| Janitor | `Give(resource, cleanup?)`, `Remove(key)`, `Fork`, `Destroy`, `GetCounts` | Resource scope; cleanup terbalik, laporkan kegagalan per-resource, tutup resource yang masuk setelah destroy. |
| Promise | `Spawn(work,token)`, `Cancel`, `Await`, `OnSettled` | Clock, Signal, Result, Janitor; sekali terminal, generation guards. |
| Result | `Ok(value)`, `Err(error)`, `Map` | Error type; no implicit success on nil. |
| Error | `Create(code,metadata)`, `Redact`, `Is` | Registry error codes, localizable public message. |
| Logger | `Push`, `List`, `Subscribe`, `Export` | Error, Signal; bounded ring, opt-in sink, redacted before publish. |
| Clock | `Monotonic()`, `WallUTC()`, `After(delay, cb)` | Host scheduler; injectable fake clock, cancelable job. |
| Throttle | `Wrap`, `Flush`, `Cancel` | Clock, Scope. Separate debounce/throttle leading/trailing, callback boundary. |
| Store | `Get`, `Set`, `Batch`, `Observe(keys)`, `Snapshot` | Signal, Schema; batch atomic, immutable snapshot/version, observer reentrancy queued. |
| Computed | `Define`, `Invalidate`, `Dispose` | Store; dependency graph and cycle rejection. |
| Flags | `Bind`, `Unbind`, `Find`, `Export` | Store, Schema; scope + key unique unless shared opt-in and schema matches. |
| Schema | `Normalize(input)`, `NormalizePatch(base,patch)` | Result, Error; type/range/default/finite, copies and explicit unknown handling. |
| Serializer | `Encode`, `Decode`, `Migrate` | Schema, Result; canonical, bounded, excludes secret and cyclic refs. |

## engine (fase 2–3, integrasi 7–8)

| Modul | Kontrak dan ownership |
|---|---|
| Factory | Instance create/update, mounts by scope, applies validated props and rejects unauthorized parent/class. |
| StyleResolver | Resolve/Invalidate token into node variant/state selectors, accessibility, per-token diff. Theme/Viewport input snapshots. |
| Layout | Measure/Arrange/Invalidate by revision, structural slots, caching and breakpoints, preserve scroll anchor. |
| Viewport | SafeRect/GetProfile and coalesced Observe, mode changes from Services and configured avoid regions. |
| Input | Register targets, select mode, route activated/input events, exclusive capture per pointer, dispose once per root. |
| Gesture | Classify pointer intent using configurable slop/timer, tell Input to grant/cancel; restore scroll lease. |
| Focus | Register/Focus/Blur/PushScope/PopScope, stable ID selection, restore previous valid target. |
| ZIndex | Allocate/Activate/Release by layer/window, stable bottom-to-top order, rebase when range bounded. |
| Overlay | Open/Close/CloseTop, use Focus/Layout/ZIndex; bounded placement, focus trap and cancel. |
| Window | Geometry controller (move, resize, snap, dock/undock), Input/Layout/ZIndex; never direct public state update before validation. |
| Animation | Tween/Cancel group and bounded optional scheduled updates, reduced-motion instant behavior. |
| Transition | Swap interpolated style/layout states with generation; no restart or state loss on no-op. |
| Theme | Register/Get/Derive/List/Subscribe; immutable semantic tokens and validation/diff. |
| Typography | Resolve roles and dynamic scale, adapter via Fonts, native editable text fallback and focus preservation. |
| Icons | Pack registries and safe resolver, allocator/asset cache, fallback labels. |
| Media | Mount and own Media Handle and slot, pass to media backend, generation cancellation. |
| Audio | Mount buses/SFX controller interface, scope ducking, route events, disposal. |

## ui (fase 3–12)

| Modul | Kontrak dan ownership |
|---|---|
| Root | Compose core/engine/backends for host parent, root scopes and idempotency registry. |
| Window | Public Window handle, options and navigation state; engine controller owns geometry. |
| Topbar | Title/subtitle/avatar/logo/header action slots, accessible drag and window controls. |
| Sidebar | Nav rail/drawer/sidebar composition; listens active tab and breakpoint without overwriting selection. |
| Tab | Tree and nested tab state/lazy mount, selection/ordering/pin with stable ID. |
| Section | Columns/groupboxes/collapse, scoped child links. |
| Container | HStack, VStack, Grid/Add/TryAdd, own children and stable slot IDs. |
| ControlBase | Universal handles/edit transactions, event routing, derived visibility/lock/enabled, cleanup. |
| Components | Per-family factory dispatch and schema in design registry, declared variant remains independently testable. |
| Overlays | Modal/sheet/tooltip/toast UI output using engine Overlay contract. |
| AuthScreens | AuthController public snapshot only, slot/UI locale/media, keyboard mode, zero-dependency keyless. |

## systems (fase 6, 9, 11)

| Modul | Kontrak | Dependensi utama |
|---|---|---|
| Search | Upsert/Remove/Query nodes by IDs, permissions and fuzzy index. | Store/Clock, cancellable revision |
| CommandPalette | Register/Remove/Invoke with scope and entitlement guard, mobile open. | Search, Focus, Auth snapshots |
| Notifications | Push/Dismiss/List with queue ≤5 displayed, TTL/pin/dedup/history. | Clock/Overlay/Store |
| Favorites | Pin/Unpin/List and MRU by stable ID. | Flags/Profiles |
| Workspace | Spawn/Layout/Activate/Close workspace windows, serialize layout. | Window/ZIndex/Config |
| Profiles | List/Save/Load/Delete/Rename per namespace, active revision. | SaveManager |
| SaveManager | Save/Load/Autoload/Reset/Export/Import/RestoreBackup using storage adapter. | Serializer/Runtime, atomic file only when supported |
| ThemeManager | Save/archive/import/export theme data with migration, ownership separate from public registry. | Theme/Profiles |
| ThemeStudio | Preview/edit/commit/Undo/Redo/Rollback/Duplicate palettes. | StyleResolver/ThemeManager/Focus |
| Onboarding | Start/Next/Skip/Resume per profile, target stable nodes. | Overlay/Profiles/Localization |
| Changelog | Get current and optional cached versioned remote release/announcements. | Schema/Clock/HTTP adapter |
| Inspector | Snapshot node/flag/style/scopes/media/diag and sanitized stream. | Store/Logger/Runtime |
| Localization | T(key, params), register locale, set and subscribe. | Schema/Signal, EN/ID and fallback |

## fonts + media (fase 7–8)

| Modul | Kontrak dan dependensi |
|---|---|
| fonts/Catalog | Register/List/Get/Compare immutable manifests and status, Catalog alias normalization, Validation. |
| fonts/NativeResolver | Resolve/probe NativeFontFace on allowed target, Services + Capability. |
| fonts/AtlasResolver | Validate reference and page assets, load/pin by scoped ref-count and cache, GlyphLayout. |
| fonts/GlyphLayout | Shape from supported precomputed metrics/kerning, grapheme-safe wrap, bounds and overflow; disclose unsupported script clusters. |
| fonts/FontPicker | Preview virtual tiered cells and selected family states; Catalog, Resolvers, Theme. |
| fonts/Validation | Validate manifest checksum/provenance/license/coverage and fresh render evidence. |
| media/SourceResolver | Validate and resolve SourceSpec without fetching, adapter registry and policy. |
| media/Image | Load/swap/fit/crop and report actual ready state, source + cache + scope. |
| media/SpriteAnimation | Variable durations, loop/reverse/seek/step/poster, Clock + bounded Image rect updates. |
| media/Video | Media adapter for permissioned VideoFrame, loaded/error/progress/pause/dispose, own connections. |
| media/Audio | Sound/AudioPlayer renderer and output graph/scope, permission and playback readiness. |
| media/Player | Resolve/load/play/pause/seek and a public synchronized snapshot state. |
| media/Playlist | Queue/next/shuffle/loop/move, one active track and at most one crossfade partner per scene. |
| media/Background | Resolve fallback and pause policy while preserving layer ordering and gameplay input. |
| media/Cache | Acquire/Pin/Release/Evict + retry/negative TTL; ref-count and measured byte limits. |

## auth (fase 10)

| Modul | Kontrak |
|---|---|
| AuthController | Select route, begin validation/checkpoints, cancel, logout, publish redacted snapshot. |
| Session | Revise/CheckExpiry/Revoke, no client renewal/grant, TTL and stale invalidation. |
| ProviderRegistry | Register/Resolve/List supported methods and upstream versions; active authority immutable within transaction. |
| GatewayRegistry | Register/Resolve/Intersect capability sets and host policy; upstream choice only if authorizes this project and step. |
| CheckpointManager | Begin/Refresh/Cancel for providerManaged, backendManaged, externalLinkOnly. Completion source trusted. |
| Entitlements | Normalize grants, Check evaluation against scope/expiry/subject, reject mismatched authorities. Server holds final policy. |
| Errors | Normalize vendor error/unknown/auth denied without sensitive values. |
| Cache | Write and clear scoped public metadata/expiry, no secret tokens by default. |
| providers/`Luarmor,Panda,Vampauth,KeyVortex,KeyAuth,AuthGG,OpenAuth,Pelinda,SVAL,LuaProtect,Custom` | Each uses the shared Provider interface in [Auth](auth.md); ID remains reserved/blocked until official endpoint and fixture gates, no empty runtime stub. |
| gateways/`WorkInk,LootLabs,Platoboost,Linkvertise,AdMaven,Boostelar,Rekonise,MBoost,Custom` | Named adapter contracts as in [Auth](auth.md), equivalent registry extension IDs for Fly Inc/Rinku, Lockr, Short-Jambo, Cuty, ShrinkEarn, ShrtFly, Paster, BoostInk. No claim of vendor compatibility by name. |

## extensions (fase 9–11)

| Modul | Kontrak |
|---|---|
| Nexus | Use/Remove/List/Get/HasCapability/RequestPermission. Always scope requests and approved dependencies. |
| PluginHost | Init/Mount/Suspend/Resume/Dispose, own subscriptions/lifetime, publish sanitized errors. |
| HubManager | RegisterExperience/Select/Activate by PlaceId/UniverseId/entitlement, no remote code auto-execution. |
| ComponentRegistry | Register(name,factory,schema), Add/Resolve/List, namespace IDs and owning plugin. Affects type/docs generation. |
| ThemePacks | Load pinned JSON pack, validate version/path/cap/size/hash/licenses, register/unregister and fallback. |

## Data contracts and I/O

Adapters have `Probe(context)`, declared capability IDs, `Init(config,scope)`, one or more operation methods and `Destroy()`. `Probe` distinguishes unknown, unavailable and available. Network adapter accepts allowlisted endpoint IDs or host-owned URLs, bounded request payload/time and cancellation token. Storage adapter `Get/Put/Remove/List` advertises `atomicReplace` and durability. Media adapter `CanResolve/Resolve/Load` returns owned handle and provenance. ProviderResult and AuthResult schemas stay server-versioned with minimal public snapshots. Capability changes invalidate pending operations via generation; capability state alone never grants entitlement. Docs examples must compile and use the same registry in CI.

## English handoff

Module responsibilities define import direction, lifecycle and ownership. The core is reusable and host-independent through injection. Engine services handle GUI behavior. Specialized backends expose typed capabilities to registries. Higher-level UI and extensions use these interfaces and own disposable scopes.
