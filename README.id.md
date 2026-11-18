# Feybrume

[English](README.md) · [Bahasa Indonesia](README.id.md) · [简体中文](README.zh-CN.md)

Framework UI Luau untuk pengalaman Roblox, dengan tampilan yang bisa dikustomisasi dan kontrol yang dirancang untuk perangkat sentuh.

Kode saat ini mencakup inti runtime dan mesin tema dengan 40 preset, pengaturan gaya per bagian, kontrol kontras, fallback font bawaan Roblox, dan pengaturan pengurangan animasi. Pratinjau Studio menampilkan preset pada sebuah kontrol contoh. Sistem jendela dan tata letak direncanakan untuk tahap berikutnya.

## Coba

- [Pasang inti runtime di Roblox Studio](docs/id/core.md)
- [Jalankan pratinjau atau buat tema sendiri](docs/id/design-system.md)
- [Lihat indeks dokumentasi](docs/id/index.md)

Pasang [Luau CLI](https://github.com/luau-lang/luau/releases), lalu jalankan perintah ini dari direktori utama repo.

```sh
luau tests/core.luau
luau tests/theme.luau
luau-analyze src tests examples
```

[Lihat riwayat perubahan](CHANGELOG.md) dan [hasil uji](evidence/phase2-checks.json).
