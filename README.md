# Feybrume

A customizable, mobile-first Luau UI framework for Roblox experiences, with responsive components, themes, and capability-aware media support.

Framework UI Luau mobile-first untuk Roblox experience berizin. Desain mengutamakan touch, komposisi, token dan lifecycle yang jelas. English readers can start with the English handoff sections linked from the documentation index.

**Fase 0 · 18 November 2026** — riset dan desain. Katalog mendefinisikan **159 tipe komponen** dan **40 tema**, termasuk empat signature. Batas native/optional untuk font, media, auth dan gateway ditetapkan per kemampuan. Runtime berfungsi yang telah diuji pada Studio/perangkat: **0**. Font yang terverifikasi render di Feybrume: **0/1.000**. Ada tiga sampel upstream untuk audit awal metadata/lisensi.

- [Mulai dari indeks dokumen](docs/index.md)
- [Matriks library dan bukti](docs/research.md)
- [Kontrak API dan modul](docs/architecture.md)
- [Inventaris 159 komponen](design/components.json) dan [40 tema](design/themes.json)
- [Auth × 17 gateway](docs/auth.md) dengan 11 adapter yang direncanakan
- [QA, risiko, backlog](docs/qa-and-backlog.md), [hasil design checks](evidence/phase0-checks.json) dan [manifest](phase0-manifest.json)

## Verifikasi desain secara lokal

Python 3.10+, dari folder repo:

```bash
python3 tooling/verify_phase0.py
```

Opsi `--spec /path/to/Feybrume_Master_Prompt_v5_Research_Edition.md` memeriksa checksum dokumen asal dan kesesuaian label/palette. Verifier memeriksa registry, kontras solid, skor desain, link lokal dan file hashes. Uji Studio/PC/HP, publish asset, live auth dan bundle menunggu fase pemiliknya. Project belum menetapkan lisensi distribusi ulang kode. Aset pihak ketiga hanya direferensikan.

[FASE 0 SELESAI — ketik LANJUT]
