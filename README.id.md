# Feybrume

[English](README.md) · [简体中文](README.zh-CN.md)

Feybrume menambahkan jendela yang bisa digeser di experience Roblox. Jendela bisa menempel ke tepi, menampung tab, dan dibuka lagi lewat tombol melayang. Isi tab bisa memakai objek GUI Roblox.

## Coba demo di Studio

Pasang [Rojo](https://rojo.space/), lalu jalankan perintah ini dari folder utama repo.

```sh
rojo build foundation-preview.project.json -o Feybrume.rbxlx
```

Buka `Feybrume.rbxlx` di Roblox Studio dan tekan **F5**. Coba **Record lap**, lalu **Load hard preset**. Cek apakah toggle tips ikut berubah di tab Guide.

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

[Komponen dasar](docs/id/components.md) · [Panduan jendela](docs/id/window.md) · [Tema](docs/id/design-system.md) · [Dokumentasi](docs/id/index.md)

## Status preview

**v0.4.0** menambah 18 komponen dasar dan flag. Mesin jendelanya memakai dasar v0.3.5 yang sudah dites di Android. [Hasil tes komponen](evidence/phase4-checks.json) · [Tes jendela di HP](docs/qa-and-backlog.md#window-preview-checks)

## Tes lokal

Jalankan pemeriksaan dengan [Luau CLI](https://github.com/luau-lang/luau/releases).

```sh
luau tests/core.luau
luau tests/theme.luau
luau tests/window.luau
luau tests/components.luau
luau-analyze src tests examples/foundation-preview.client.luau examples/window-preview.client.luau examples/reopen-logo.server.luau examples/theme-preview.client.luau
```

[Riwayat perubahan](CHANGELOG.md) · [Catatan build Fase 4](phase4-manifest.json)
