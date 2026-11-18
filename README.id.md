# Feybrume

[English](README.md) · [简体中文](README.zh-CN.md)

Feybrume menambahkan jendela yang bisa digeser di experience Roblox. Jendela bisa menempel ke tepi, menampung tab, dan dibuka lagi lewat tombol melayang. Isi tab bisa memakai objek GUI Roblox.

## Coba demo di Studio

Pasang [Rojo](https://rojo.space/), lalu jalankan perintah ini dari folder utama repo.

```sh
rojo build window-preview.project.json -o Feybrume.rbxlx
```

Buka `Feybrume.rbxlx` di Roblox Studio dan tekan **F5**. Coba geser jendela, buka panel dialog, atau ganti profil layar ke HP di Device Emulator.

## Pasang di game sendiri

Sinkronkan proyek dengan Rojo agar modul `Feybrume` masuk ke `ReplicatedStorage`. Masukkan contoh ini ke `LocalScript` di `StarterPlayerScripts`. [Panduan pemasangan](docs/id/core.md)

```luau
local Fey = require(game:GetService("ReplicatedStorage"):WaitForChild("Feybrume"))

local window = Fey:Window({ id = "tools", title = "Game tools", theme = "cosmic" })
local home = window:Tab({ id = "home", title = "Home" })

local label = Instance.new("TextLabel")
label.Size = UDim2.new(1, 0, 0, 40)
label.Text = "Siap bermain"
home:Add(label)
```

[Panduan jendela](docs/id/window.md) · [Tema](docs/id/design-system.md) · [Dokumentasi](docs/id/index.md)

## Status preview

Source di `main` menghasilkan **v0.3.4**. Preview **v0.3.5** diuji terpisah di Roblox. Di Android, pemilik proyek memastikan bubble bisa sampai ke tepi kiri dan kanan, bergeser dari area Jump, dan menampilkan logo contoh dari CDN. Fase berikutnya menambah kontrol dasar dan pengikatan nilai. [Catatan tes perangkat](docs/qa-and-backlog.md#window-preview-checks)

## Tes lokal

Jalankan pemeriksaan dengan [Luau CLI](https://github.com/luau-lang/luau/releases).

```sh
luau tests/core.luau
luau tests/theme.luau
luau tests/window.luau
luau-analyze src tests examples
```

[Riwayat perubahan](CHANGELOG.md) · [Catatan build Fase 3](phase3-manifest.json)
