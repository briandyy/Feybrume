# Release documentation map

This map assigns release pages and examples to the phases that provide their APIs and evidence. The release includes runnable examples, actual screenshots, and tested fallback paths.

| Release page | Contents and evidence phase |
|---|---|
| 00-READ-ME-FIRST.md | Summary, actual screenshots, performance scope, 13–14. |
| 01-INSTALL-AND-LOADSTRING.md | Studio require, permissioned hosts, version pins, errors, 1/14. |
| 02-QUICKSTART.md | Zero-config first tab and 3-tab hub, 4/14. |
| 03-ARCHITECTURE.md | [Ownership and module graph](architecture.md), 1. |
| 04-WINDOWS-AND-TABS.md | Window presets, layouts, slots, focus/docking, 3. |
| 05-COMPONENT-REFERENCE.md | [159 named types](../design/components.json), all schemas/examples, 4–12. |
| 06-STATE-FLAGS-REACTIVITY.md | Flags/state/computed/collision/restore, 1. |
| 07-ALL-40-THEMES.md | [40 themes](../design/themes.json), actual screenshots, 2. |
| 08-CREATE-CUSTOM-THEMES.md | Overrides, ThemeStudio, import/export/migrations, 2/9. |
| 09-FONTS-1000.md | [Native and atlas count/legal proof](typography.md), 8. |
| 10-ICONS.md | Licensed packs, custom images/sprites and search, 8. |
| 11-IMAGES-AND-GIFS.md | [Assets and sprites](media.md), R2 conversion, 7. |
| 12-VIDEOS-AND-YOUTUBE.md | Native VideoFrame, lawful handoff and poster/consent, 7. |
| 13-AUDIO-MUSIC-AND-SFX.md | Music scenes, playlists, consent, SFX routing and clips, 7. |
| 14-MOBILE-RESPONSIVE.md | [Mobile profiles and test cases](mobile.md), 3–13. |
| 15-AUTH-MODES.md | [Auth trust model](auth.md), 10. |
| 16-PROVIDER-SETUP.md | Live verified adapters, statuses/errors, 10. |
| 17-AD-NETWORKS-AND-CHECKPOINTS.md | Actual vendor/age/policy-supported links and choices, 10. |
| 18-CONFIG-PROFILES.md | JSON schema, save/export/migration, 9. |
| 19-PLUGINS-AND-CUSTOM-COMPONENTS.md | Register/load lifecycle, scoped APIs, 9. |
| 20-HUB-MULTI-GAME.md | Hub manifest, PlaceId routing, safe commands, 11. |
| 21-DIAGNOSTICS-AND-DEBUG.md | Scope counts, events, sanitized export, 11. |
| 22-COMPATIBILITY-MATRIX.md | Platform feature and actual versions/host probes, 13. |
| 23-SECURITY-PRIVACY.md | Auth/media/network boundaries and licenses, 10/13. |
| 24-PERFORMANCE-TUNING.md | Cold/first paint, low-end effects/cache budgets, 13. |
| 25-DEPLOY-VERSION-UPDATE.md | GitHub immutable release pins, checksum, rollback, 14. |
| 26-FAQ-TROUBLESHOOTING.md | Diagnosed phase gaps and fixes, 14. |
| 27-MIGRATE-FROM-OTHERS.md | Migration from [reference patterns](research.md) into stable API, 14. |
| 28-API-TYPINGS.md | Exported Luau types from actual code, 1–14. |
| 29-EXAMPLES-GALLERY.md | At least 25 tested projects, 14. |
| 30-RELEASE-CHECKLIST.md | [Acceptance](qa-and-backlog.md), provenance/bundle and triage, 14. |

Each release page covers purpose, a runnable example, property types and defaults, callbacks, desktop and touch behavior, capabilities, errors, fallbacks, cleanup and migration. English is the canonical reference. Indonesian and Simplified Chinese guides live in their own directories. CI checks example dependencies, exported signatures and smoke execution. A quickstart uses valid assets and URLs.

Example coverage: barebones one-tab, mobile 3-tab, control showcase, left-handed mode, 40 theme gallery, native custom typography, font browser/compare, theme studio, image asset card, converted GIF, native video, YouTube fallback/on permitted host, R2 pipeline, login→main audio, explosion SFX, control variants, local demo auth, Luarmor, Panda, approved gateway choice, 3-step supported checkpoints, free/premium tiers, multiple window dock, slots, custom component, custom extension, config import/export, scope destroy, integrated ultimate-showcase. Vendor examples require a verified sandbox and operator configuration. The phase documents mark examples pending runnable APIs.
