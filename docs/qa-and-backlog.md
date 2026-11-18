# QA and roadmap

Start with the [window demo](window.md) to reproduce a device issue. Include the preview version, device, input method, and the steps that trigger it. [Core tests](../evidence/phase1-checks.json) · [Theme tests](../evidence/phase2-checks.json) · [Traceability](../design/traceability.json)

## Window preview checks

The published v0.3.5 preview passed the Android checks that prompted the launcher patch. The repo's build record covers v0.3.4. [Detailed test record](../evidence/phase3-checks.json)

| Check | What was observed | Follow-up |
|---|---|---|
| Tabs and outlines | The owner reported no layout glitches in v0.3.4 on Android. | Include portrait and landscape in future layout checks. |
| Gamepad | The owner reported that controller navigation worked in the v0.3.4 Studio Controller Emulator. | Verify physical controller behavior separately. |
| Bubble placement | On v0.3.5 Android, the bubble reached both edges and moved clear of Jump when dropped over it. | Check on phones with other screen cutouts and touch layouts. |
| CDN logo | The sample PNG rendered inside the v0.3.5 bubble on Android. The preview refused an unregistered URL. | Cover other approved sources and failed downloads in the media phase. |
| Window appearance | CLI tests passed for property updates, restored bounds, and header layout on the v0.3.4 source. | Exercise the live appearance controls in Studio. |
| Keyboard and overlays | CLI fixtures cover focus and layout. | Check that rotation and the Android keyboard leave the focused field and dismissal controls reachable. |
| Studio warning | The Resize and Restore labels rendered in full in v0.3.1. A RoundedCorner8 warning disappeared with plugins disabled. | Check larger text settings. The specific plugin was not identified. |

## Release acceptance

| Area | Release weight | Acceptance evidence |
|---|---:|---|
| Correctness | 20 | API fixtures/common handles, zero-config keyless, schema validations, duplicate/shared flags, cancel/destroy, version contract and single bundle parity. |
| Mobile UX | 15 | All MOB-01–28, 159 component scenarios, touch/desktop/gamepad accessibility and real device evidence. |
| Customization | 15 | 40 themes smoke + per-state visual/contrast + localization, per-level override, motion policy, custom font/media/slot and theme/editor round-trip. |
| Component breadth | 10 | 159 registry entries, contract, schema, behavior, executable example, explicit unsupported methods. |
| Media/audio | 10 | MED-01–10, asset grant/timeout/permission playback tests, source verdict, safe fallback and scene/SFX limits. |
| Typography | 10 | FONT-01 license/dedup, FONT-02 native render, 03 atlas coverage/proof, 04 denied fallback test, 05 active cache/memory and browser stress, 06 1,000 family receipts. |
| Auth security | 10 | AUTH-01–15, entitlement server trust, provider/gateway live sandboxes, replay/failover/expiry/SSRF guards, policy compliance. |
| Docs/testing | 10 | 31 pages, ≥25 runnable examples, pinned release checksums, tested upgrades, migration and novice runbook. |

Release scores require evidence for every category. The library research links individual fixture IDs to their source. File bug reports with device, host version, reproduction, expected and actual behavior, earliest known affected version, and evidence. Omit secrets and personal information. [Research matrix](research.md)

## Test methods

1. **Design and CLI.** Run the manifest verifier, Luau analyzer, deterministic scheduler fixtures and schema checks. Cover cancellation, malformed inputs, cleanup and edge cases.
2. **Desktop Studio.** Run the applicable quickstart and test keyboard, pointer, controller, navigation, modal focus restoration, resizing, asset permissions and config restoration. Theme switches and reflow preserve IDs and values. After Destroy, owned connections, tasks, instances, tweens and audio return to baseline.
3. **Physical devices.** Run MOB-01–28 and all component fixtures. Capture cold start, first draw, median and p95 drag latency, a switch across 300 controls, a 1,000-row virtual list, visible fonts, media costs, five windows, 50 notices and 1,000 create/destroy cycles. Use at least three warm and cold runs per device profile. The design targets 60 FPS on midrange devices and a 30 FPS fallback. Record actual device, OS, client version, network, permission and resource evidence. [Mobile acceptance](mobile.md)
4. **Backend.** Use authorized sandboxes and synthetic credentials. Verify signatures, expiry, current authority, retry and redaction. Configure production writes only with the operator.
5. **Release.** Check source and bundle parity, byte-for-byte reproducibility, license evidence, pinned assets, links, compatibility, published checksums and example compilation.

## Risk register

| ID | Risk | Evidence or mitigation |
|---|---|---|
| R-01 | Roblox runtime evidence | CLI uses an injected host. Run Studio and physical desktop/mobile checks. |
| R-02 | Font permissions and 1,000 atlas families | Pilot ten families, audit notices and permission, and measure memory before scaling. |
| R-03 | Asset moderation, grants and quotas | Record permission per asset and test both grant and denied fallback. |
| R-04 | External media and handoffs | Use a permitted importer or verified host capability. Provide a poster or text fallback. |
| R-05 | Provider API changes and availability | Require documented authority and sandbox evidence. Keep keyless available. |
| R-06 | Client tampering, replay and plugin permissions | Verify on the server, minimize session data and keep credentials out of logs. Trust only approved plugins. |
| R-07 | Touch conflicts, keyboard insets and haptics | Use safe regions and scoped capture. Validate fallbacks on device. |
| R-08 | Icon provenance and license | Verify each approved glyph and its license. |
| R-09 | Focus loss, leaks and reentrancy | Use scope ownership, generation checks and atomic state. Test rotation and overlays. |
| R-10 | Bundle parity and host compatibility | Keep Studio Modules as a primary entry and test optional transpilation and the bundle. |
| R-11 | Config migration and remote content | Validate versioned immutable JSON. Bound size and host, and keep backups. |
| R-12 | Component API compatibility | Reserve stable IDs, track variants and maintain regression snapshots. |
| R-13 | Repository creation, resolved | The project owner created the public GitHub repository. |
| R-14 | Project license pending | Record an owner-approved license before redistributing code or bundled assets. |

The runtime baseline uses a native ModuleScript, canonical schema names, a 48-unit preset touch target and separate IDs for theme geometry. Pelinda is planned as a Panda compatibility layer. Device bugs require real-device reproduction.

## Roadmap

| Phase | Implementation | Acceptance |
|---:|---|---|
| 0 | Research, architecture, registry and QA baseline | Catalog, contrast checks and source evidence. |
| 1 | Runtime core, cancellation, state and diagnostics | CLI tests for ownership and state pass. Studio integration remains pending. |
| 2 | Tokens, style resolver, 40 presets, native fonts and motion | CLI checks 3,200 style combinations. The desktop preview retest passed. Device coverage is pending. |
| 3 | Windows, layout, input, navigation and focus | CLI geometry, gesture and focus fixtures pass. Studio interaction and device checks use the [window walkthrough](window.md). |
| 4 | Foundation controls and state bindings | Handles, callbacks, disposal and config restoration. |
| 5 | Forms and advanced controls | Touch input, validation and field focus. |
| 6 | Data views, notifications, search and command palette | Virtual rows, stable keys and bounded history. |
| 7 | Media and audio | Permission and playback fixtures with safe fallbacks. |
| 8 | Fonts and icons | Verify actual family and glyph counts, performance and licenses. |
| 9 | ThemeStudio, profiles, config and extensions | Undo/redo, schema migration and scoped plugin disposal. |
| 10 | Auth modes, gateway adapters and optional backend | Server authorization and verified integrations. |
| 11 | Hub routing, locale, onboarding and diagnostics | Locale edge cases, scoped commands and diagnostic redaction. |
| 12 | Catalog completion | Each of the 159 component types has a callable API, test and example. |
| 13 | Studio, devices and security regression | Record measurements by device and capability. |
| 14 | Bundle, licenses, docs and release | Verify hashes, parity, compatibility and the quickstart. |

The original specification maps to architecture and module contracts (§§00–04), public API and mobile (§§05–07), design system (§§08–09), typography (§§10–11), media and components (§§12–13), state and workspace (§§14–15), auth and persistence (§§16–17), extensions and content (§§18–20), locale and diagnostics (§§21–22), QA (§§23–24), and release documentation and phase gates (§§25–31). Record changes to a stable contract in the changelog and manifest.
