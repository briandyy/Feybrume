# Design system, tema, dan kustomisasi

[Registry 40 tema](../design/themes.json) berisi palette utama dari spesifikasi, calculated solid colors, ornament/material, shape, icon treatment, motion, role tipografi, kepadatan dan fallback. Empat signature ialah Cultivation 仙, Memoir 忆, Noir dan Cosmic ✦. Semua menggunakan hierarchy yang sama untuk styling, dengan komposisi berbeda. Cultivation memakai jade/gold seam dan mist statis, Memoir parchment dan ritme editorial dengan typewriter opt-in, Noir aksen merah untuk action, Cosmic violet–teal dengan star field opsional ≤60 dan fallback solid. Design registry mempertahankan warna dasar spesifikasi. Detail warna gradien dan ornament coverage akan diturunkan dari material renderer fase 2 dan baru diklaim setelah visual tes.

| Layer | Kontrak |
|---|---|
| Palette | background/surface/accent/text/stroke sumber. Border dekoratif dapat memakai stroke. Essential boundaries punya essentialStroke sendiri. |
| Semantic states | success/warning/danger/info, selection/focus/hover/pressed/disabled/placeholder, backdrop/shadow dan alpha; title/text/icon dengan paired on-color. |
| Surfaces | base/raised/overlay/input/header/sidebar/tooltip/popup. Gunakan overlay opaque saat media atau noise menurunkan contrast. |
| Scale | spacing 0/2/4/6/8/12/16/20/24/28/32/40/48/56/64; radius presets 0/2/4/6/8/12/16/20/24/999 ditambah specific theme radius; shadow, stroke, opacity, sizes XS–2XL, outline/solid/soft/glass/ghost/neomorphic/brutalist/minimal sesuai scope. |
| Interaction | default/hover/pressed/visible focus/selected/loading/disabled/locked/invalid/success. Variants berbagi semantic state dan hit area. Hover dan efek decorative opsional. |
| Typography | title/body/caption/input/code roles dan fallback native. Typography intent seperti condensed/brush belum menjanjikan font siap render. |
| Motion | instant, snappy/calm/standard/slow, spring, optional drift/typewriter. Reduced motion memilih instant/preserved focus dan glyph; no layout flash. |
| ThemeStudio | register/derive/duplicate, 40 previews, live edit, inspect token node, font/palette compare, 8 palette per profil, undo/redo, rollback dan export/import. Schema+CRC untuk deteksi rusak dan share code, bukan authentication. Sandbox preview scope. |

Theme input normalize validate finite colors, invalid inheritance/cycles dan exact fields, merge by precedence. Side-effects visual dan audio diarahkan token dan subscription; control colors tidak literal-override kecuali melalui props/token resolver. Contrast auto-check normal text ≥4.5:1 pada solid color dan control/focus ≥3:1. Hitung alpha composite aktual untuk backdrop bertumpuk, state hover, gradient stops dan sampled image regions; fallback solid scrim bila media tidak memenuhi standard. Saat autoContrast off, beri warning dan pakai clear focus ring sesuai accessibility choice. Status text + icon/shape. AccentOn pilih hitam/putih kontras tertinggi; primary text over surface tetap dari brief. Static assertion di verifier hanya mengesahkan solid pairs, modal composition/motion dan screenshot semua 40 adalah THEME-01–40 pending. [WCAG contrast guidance](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html)

Mobile nav/spacing/collapse mengikuti [Mobile](mobile.md), dan `RegisterTheme` + `Theme:Derive` bisa membuat theme orisinal, custom fonts/icons, gradient, motion, spacing, SFX dan art slots. Desktop/mouse hover, gamepad focus dan touch states berbagi token dengan accessibility overlay. Test sweep per theme harus cek warna tiap state, RTL/CJK fallback sesuai coverage, EN/ID panjang, 160% text, 200% stress, density mode, reduced motion dan screenshot dari build actual.

## English handoff

The registry defines forty original visual directions, four signature themes, static contrast tokens and responsive defaults. Designers can combine and override geometry, typography, materials and component states without changing control behavior. Runtime screenshots and layered contrast verification are planned in later phases.
