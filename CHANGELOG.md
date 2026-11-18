# Changelog

## 0.4.1-foundation

- Move touch resize into the window header so pages use the full width. Use a narrower automatic sidebar on short touch screens.
- Give toggle, checkbox, and radio controls their own indicators. Fit tags and badges to their text and distinguish headings, descriptions, and actions.
- Support hex text color in RichText and refresh the foundation preview.

## 0.4.0-foundation

- Add 18 foundation controls to tabs and containers, including labels, actions, toggles, and radio groups.
- Bind controls to shared flags, restore snapshots in a single transaction, and update conditional visibility on flag changes.
- Add a Studio preview with synced toggles and a restore preset.

## 0.3.5-window

- Add an opt-in physical left and right edge for the reopen button. Keep the window and the default reopen position below the Roblox top bar.
- Accept HTTPS image sources for the reopen button through an experience-supplied pixel resolver. The preview fetches an approved CDN PNG server-side and draws it with EditableImage.
- Record v0.3.4 Android and Controller Emulator feedback.

## 0.3.4-window

- Update window titles, subtitles, typography, panel opacity, corner radius, padding, header height, sidebar width, and snap distance at runtime.
- Add runtime floating bounds and stable header and status slots for native UI content.
- Document window customization and the planned media source backends.

## 0.3.3-window

- Route Gamepad A on **Tabs** and **More** through the same tab picker as mouse and touch.
- Inset tab borders from the scrolling viewport and separate the first tab from the header.
- Move the reopen button into the device-safe viewport. Keep it below the top bar by default, with an option to use free space beside the Roblox controls.
- Add configurable launcher size, shape, radius, image, image scale, and a live preview in Preferences.

## 0.3.2-window

- Let reopen buttons keep a free position inside the safe area and restore it after rotation. Edge snapping is available as an option.
- Reduce window chrome on short touch layouts, place navigation alongside or below the content, and skip auto navigation for single-tab windows.
- Give D-pad and Select/View a focus entry point and directional navigation in windows and sheets.
- Allow rotation in the Studio preview and open the secondary window on demand.

## 0.3.1-window

- Fit the full Resize, Restore, Hide and Close labels to Roblox text measurements, including changes to the player's preferred text size.
- Record the v0.3.0 Studio smoke test and the editor warning investigation.

## 0.3.0-window

- Mount responsive Roblox windows with tabs, drag, resize, docking and reopen buttons.
- Add bottom sheets, context menus, focus restoration, and named slots with responsive grids.
- Add a Studio walkthrough and CLI fixtures for layout, pointer capture, and focus.

## 0.2.1-theme

- Switch the default serif role from Garamond to Bodoni.
- Add an optional text-bounds probe to native font resolution and use it in the Studio preview.
- Top-align preview headings and body text, and draw Cosmic's sparkle with UI frames.

## 0.2.0-theme

- Load all 40 built-in theme palettes and derive new themes at runtime.
- Resolve styles for eight variants and ten states, with touch sizing, focus rings and contrast checks.
- Resolve Roblox native fonts by role and support reduced motion in transitions.
- Add a Studio theme preview, an English reference, and Indonesian and Simplified Chinese guides.

## 0.1.0-core

- Add the runtime host adapter, capability probes, and cached service lookup.
- Add cleanup scopes, signals, cancellable tasks, and bounded diagnostics.
- Add transactional state, computed values, flags, schemas, and versioned serialization.
- Add a Rojo project and a deterministic Luau CLI test suite.

## Phase 0 · 2026-11-18 (MYT)

- Establishes documented API, ownership, phased integration plan and distribution contracts.
- Adds 159 named component designs, 40 theme definitions, 28 mobile test plans, media capability classes and provider/gateway evidence.
- Captures upstream license sample evidence for Archivo, Open Sans and Share. Verified Feybrume render count is zero.
- Records direct host limitations and distinguishes documented provider pairs, unresolved pairs and live results.
- Published runtime API changes: none. Planned design API baseline is documented in [Architecture](docs/architecture.md).
