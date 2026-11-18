# Komponen dasar

[English](../components.md)

Fase 4 menambah 18 komponen ke Feybrume. Kontrol bisa ditambahkan langsung ke tab, section, grid, atau isi panel dialog. Setelah [memasang modul di Studio](core.md), taruh kode ini di LocalScript.

```luau
local storage = game:GetService("ReplicatedStorage")
local Fey = require(storage:WaitForChild("Feybrume"))
local workspace = Fey:CreateWorkspace({ theme = "cosmic", flagNamespace = "practice" })
local window = workspace:Window({ title = "Alat latihan" })
local home = window:Tab({ id = "home", title = "Beranda" })
local section = home:Section()
local tips = section:Toggle({ name = "Tampilkan tips", flag = "tips", default = true, persist = true })
section:Paragraph({
    text = "Pilih tingkat kesulitan sebelum mulai.",
    visibleIf = function(flags) return flags.tips == true end,
})
section:Button({
    name = "Reset tips",
    onClick = function() tips:Reset() end,
})
```

- **Teks dan konten** mencakup Label, Heading, Subheading, Paragraph, RichText, Caption, TextDivider, IconText, Statistic, Quote, Tag, dan Badge.
- **Aksi** mencakup Button dan IconButton. Beri `onClick` untuk menjalankan fungsi game.
- **Pilihan** mencakup Toggle, Checkbox, Radio, dan RadioGroup. RadioGroup menyimpan ID opsi yang aktif. Toggle dan Checkbox menyimpan boolean.

Panggil `Get()` untuk membaca `result.value` setelah mengecek `result.ok`. Gunakan `Set` atau `Reset` untuk mengubah nilai, `SetProps` untuk mengganti tampilan, dan `OnChanged` untuk mendengar perubahan. `Hide`, `Disable`, dan `Lock` membatasi interaksi pemain. `Destroy` membersihkan GUI, koneksi, dan callback tertunda. RichText mendukung warna hex seperti `<font color="#BBA8FF">Tip</font>`. Opsi dan metode untuk setiap komponen ada di [referensi lengkap](../components.md).

## Konfigurasi antarkontrol

Dua kontrol boolean bisa memakai nilai yang sama jika keduanya memakai `flag` yang sama, `shared = true`, dan opsi `persist` yang sama. `visibleIf`, `enabledIf`, dan `lockedIf` berubah saat flag berubah.

```luau
local preset = workspace:ExportFlags()
tips:Set(false)
local restored = workspace:RestoreFlags(preset)
assert(restored.ok)
```

Export mengambil flag aktif dengan `persist = true`. Restore memvalidasi nilai yang dikenal sebelum menerapkan perubahan sebagai satu transaksi. Snapshot bisa diteruskan ke adapter penyimpanan. Preview menyimpan setting selama sesi.

## Coba di Studio dan HP

```sh
rojo build foundation-preview.project.json -o Feybrume-Foundation.rbxlx
```

1. Buka file di Studio dan tekan **F5**. Tekan **Record lap** dan cek jumlah lap bertambah sekali.
2. Tekan **Load hard preset**. Difficulty berubah ke **Hard**, tips hilang, dan **Hard mode reminder** tampil aktif. Buka tab **Guide** dan cek toggle tips ikut berubah.
3. Di Controller Emulator, pindahkan fokus pakai D-pad dan aktifkan kontrol dengan **A**. Di HP, uji menekan seluruh baris dan putar layar. Di landscape, seret ikon resize di title bar dan cek konten tetap memakai lebar sampai mendekati tepi kanan. Pastikan tab, nilai, dan kontrol masih bisa diakses.

[Source demo](../../examples/foundation-preview.client.luau) · [Hasil tes CLI dan status tes perangkat](../../evidence/phase4-checks.json)
