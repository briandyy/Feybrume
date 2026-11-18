# QA, risiko, dan backlog fase

**Status pengujian.** PASS untuk bukti yang benar-benar dilaksanakan; PASS_WITH_LIMITATION untuk bukti yang lebih sempit dari target; IMPLEMENTED_UNTESTED untuk fitur sudah ada tanpa bukti test yang dibutuhkan; BLOCKED jika prerequisite di luar scope tidak terpenuhi; FAIL untuk tes dijalankan dan gagal; NOT_IMPLEMENTED untuk runtime belum ditulis. Core lulus uji Luau CLI dengan host palsu. Integrasi Roblox Studio dan perangkat tercatat sebagai IMPLEMENTED_UNTESTED. [Tes core](../evidence/phase1-checks.json). Bukti design lint menggunakan [tooling/verify_phase0.py](../tooling/verify_phase0.py). Scorecard per entri untuk QA otomatis ada di [traceability](../design/traceability.json).

| Area | Bobot rilis | Acceptance dan bukti yang diperlukan |
|---|---:|---|
| Correctness | 20 | API fixtures/common handles, zero-config keyless, schema validations, duplicate/shared flags, cancel/destroy, version contract and single bundle parity. |
| Mobile UX | 15 | Seluruh MOB-01–28, 159 component scenarios, touch/desktop/gamepad accessibility dan real device evidence. |
| Kustomisasi | 15 | 40 themes smoke + per-state visual/contrast + localization, per-level override, motion policy, custom font/media/slot dan theme/editor round-trip. |
| Component breadth | 10 | 159 registry entries, contract, schema, behavior, executable example, explicit unsupported methods. |
| Media/audio | 10 | MED-01–10, asset grant/timeout/permission playback tests, source verdict, safe fallback and scene/SFX limits. |
| Typography | 10 | FONT-01 license/dedup, FONT-02 native render, 03 atlas coverage/proof, 04 denied fallback test, 05 active cache/memory and browser stress, 06 1.000 family receipts. |
| Auth security | 10 | AUTH-01–15, entitlement server trust, provider/gateway live sandboxes, replay/failover/expiry/SSRF guards, policy compliance. |
| Docs/testing | 10 | 31 pages, ≥25 runnable examples, pinned release checksums, tested upgrades, migration and novice runbook. |

Tidak ada skor rilis final karena semua kategori runtime belum diuji. Referensi UI-REF-01 (WindUI), 02–03 (Rayfield), 04–06 (Fluent), 07–08 (Linoria), 10 (MacLib) dan 09,11–24 ditautkan di [matriks](research.md). Register mencatat masing-masing test ID, outcome runtime dan gap. Incoming bug reports harus memuat symptoms, capability profile/host version, device, reproduction, expected/actual, earliest version dan evidence link, tanpa key atau PII.

## Metode uji

1. **Design / host-agnostic.** Jalankan verifier dari root. Nanti lint Luau/strict types, unit tests dengan fake scheduler dan host adapters, then fixture integration. First failing test menghalangi status PASS. Satu negatif test per code path (permission, validation, cancellation, teardown).
2. **PC Studio dan experience test.** Jalankan zero-config quickstart melalui LocalScript + require. Uji satu tab/3 kontrol, pointer/keyboard, tab switching, modal close dan focus restore, rotate emulator, media allowed/denied, reset/config roundtrip. Perubahan tema dan reflow menjaga ID dan state. Setelah `Destroy`, koneksi/tugas/instance/tween/voice kembali ke baseline. Ulangi stress; resource dari test harus scope-milik.
3. **Perangkat nyata.** Jalankan 28 skenario [Mobile](mobile.md) dan smoke seluruh 159. Screenshot hanya dari UI aktual. Uji protected assets pada game/group owner dan secondary account yang tepat. Measure cold start/first draw, latency drag p50/p95, theme switch 300 controls, 1.000 virtual rows/visible font previews, GIF cost, video load/error, crossfade, SFX burst cap, login transition, 5 windows, 50 notices, 1.000 cycle create/destroy dan 30 FPS stress. Dev baseline warm/cold minimal 3 run per device config. Laporkan device/model, OS, Roblox build, network if relevant, asset permissions, budget config, median/tails, resource evidence. 60 FPS midrange/30 fallback adalah target desain, validasi budget setelah baseline. No global per-widget heartbeat.
4. **Backend.** Sandbox accounts yang authorized, synthetic credentials, true/false fixtures; verify signature/expiry/latest authority dan no accidental data logging. No writes ke integrasi production tanpa konfigurasi owner. Validate optional backend route deployment/warmup and retry.
5. **Rilis.** Run source/bundle parity, deterministic build dua kali dari input identik, release manifest hash dan actual compatibility, pinned assets, no dead doc links, examples against exported types, QR/link policy, legal/licensing check. Artifact check redacts app IDs/credentials bila private.

## Risiko, gap, dan keputusan

| ID | Risiko / limit | Dampak dan mitigasi/exit |
|---|---|---|
| R-01 | Studio/native runtime belum dipakai pada fase desain | Harness CLI memakai host palsu. Pengukuran dan smoke test pada Studio serta perangkat desktop dan mobile masih diperlukan. |
| R-02 | Native font count/permission dan 1.000 atlas keluarga | Overhead glyph GUI/texture, notice + RFN review dan uploads; pilot 10 di fase 8, bedakan sumber kandidat dan verifikasi. Goal 1.000 BLOCKED saat ini. |
| R-03 | Moderasi/permission media dan biaya/kuota upload | Per-asset availability manifest, explicit denied, poster/silent fallback, asset owner grant dan place test. |
| R-04 | YouTube inline, URL CDN/path lokal, handoff/QR | Native direct unsupported sesuai kelas; build transform asset berizin atau policy-vetted host handoff, fallback teks/poster. |
| R-05 | Auth vendor undocumented, API/version churn dan plan | Registry availability gating, structured error, permit only verified flow and entitlement authority; keyless works in release first. Roblox policy constrains adgate links. |
| R-06 | Client tampering, expiry/replay, plugin permission scope | Enforce server, cache/grace constraints, never log secrets, minimal session payload. Plugins require compiler/host trusted author; registry scope cannot sandbox arbitrary trusted Luau. |
| R-07 | Touch conflict/keyboard inset/platform clipboard and haptics | Safe zones, scoped capture, fallback UI and capability predicates, real device tests. |
| R-08 | Icon counts/library provenance/license | Verify each approved icon, keep original skin designs, avoid using unverified references as evidence. |
| R-09 | Focus loss, transient leak or reentrancy after rotation/async | Scope and generation ownership, atomic store props, stable IDs, stress and live overlays. |
| R-10 | Bundle parity and Luau vs legacy runtime | Primary Studio ModuleScript, only documented host support; optional parser-backed transpilation gated by tests. |
| R-11 | Versioned config migration and remote content | Immutable pinned JSON and size/allowlist, schema migrations backups and no eval. |
| R-12 | 159 API compatibility / model ambiguity | Reserved names + variant identities in catalog, aliases not counted, regression snapshots each phase. |
| R-13 | Pembuatan repositori (selesai) | GitHub MCP sempat menolak pembuatan. Pemilik membuat repositori publik secara manual dan mengizinkan unggahan Fase 0. |
| R-14 | Project license belum dipilih | Tunda lisensi reuse source dan distribusi aset hingga owner memilih. Link evidence upstream tidak memberi lisensi Feybrume. |

Bug runtime observed: tidak ada test runtime yang memungkinkan observasi; status bugs runtime `NOT_IMPLEMENTED`. R-13 mencatat kendala pembuatan repositori yang telah diselesaikan pemilik. Keputusan desain: kode utama native ModuleScript, istilah canonical di schema, nama publik `Viewport3D` dan `ApprovedIcon` untuk label yang bukan identifier legal, 40 preset art IDs terpisah dari UI, 48/8 touch defaults, dan Pelinda sebagai compatibility adapter Panda. Semua dipertahankan pada iterasi berikutnya kecuali perubahan teknis terdokumentasi.

## Interaksi fase dan release map

| Fase | Kontrak implementasi | Exit gate |
|---:|---|---|
| 0 | Riset/arsitektur/registry, manifest, QA dan backlog. | Verifikasi katalog, kontras warna solid, dan sumber riset. |
| 1 | Services/capabilities, scope, Signal/Result/Schema, Promise cancellation, Store/Computed/Flags, errors/logger/harness. | Tes CLI untuk cleanup sekali, kegagalan, pemanggilan ulang, dan hitungan resource. Smoke test Roblox belum dijalankan. |
| 2 | Resolver dan state tokens, 40 presets, contrast, native typography/fallback, motion/accessibility. | Theme golden data dan actual GUI visual smoke. |
| 3 | Window/root/overlay/context/menu/input/focus, layout, multi-window/nav, docking/snap, slots/sheets. | MOB baseline, keyboard/focus restore dan hide/reopen. |
| 4 | Foundation components, handle/state bindings, labels/actions/toggles. | Set/Get/Reset, show/lock/serialize/destroy, callback source. |
| 5 | Form & advanced controls. | Slider/dropdown/picker/keybind touch, validation, input ranges/focus. |
| 6 | Notifications, navigation/data/charts, command palette/search. | Virtual rows/stable keys, capped history, interaction/callback focus. |
| 7 | Media resolver, asset renderer, sprites/video/audio, consent/YouTube/R2. | MED playback with permissioned test assets and negative paths. |
| 8 | Fonts/icons, audited native + atlas pilot, proof count and permission pipeline. | Proof-led actual coverage, 1.000/2.500 gates reported exactly. |
| 9 | ThemeStudio/config/profiles/managers, customization editor, extensions. | Undo/redo, versioned import/export, plugin permission/scope cleanup. |
| 10 | keyless/local/provider/adgate and hybrid routing, verified adapters, optional backend. | Server entitlement proof, policy-safe routes, live adapter evidence and blocked rows. |
| 11 | Hub/PlaceId, EN/ID, onboarding, announcements, devtools/diagnostics/perf/privacy. | No remote exec, locale edge cases, diagnostic redaction. |
| 12 | Completion audit of every 159 component and public variant. | Every component reached by factory with scope, required options, mobile acceptance, example. |
| 13 | Studio/devices/security/load/permissions/coverage measurement. | Results recorded by device and capability; regressions blocked or accepted with written rationale. |
| 14 | Deterministic bundle, checksum, licenses, 31 docs, ≥25 examples and release. | Verified artifact parity/hash, novice walkthrough and documented live status. |

Scope source trace: §§00–04 architecture/module contracts plus truth registry; §§05–07 public API/mobile; §§08–09 design system/themes; §§10–11 typography/icons; §§12–13 media/components; §§14–15 state/search/workspace contracts; §16 auth, §17 persist; §§18–20 remote content/extensions/hub; §§21–22 locale/errors in core/systems; §§23–24 this test plan and feature truth; §§25–28 [release doc map](release-doc-map.md); §§29–31 this backlog/manifest. New phases add actual implementation files, tests, changelog and hashes while preserving stable API or recording a migration with its rationale.

## English handoff

Phase 0 records design verification and Phase 1 records CLI core tests. Roblox acceptance requires Studio and real devices, permissioned assets, sandbox services, and measured results. The backlog names phase exit gates. The risk register records the resolved GitHub repository creation issue and the remaining upstream dependencies.
