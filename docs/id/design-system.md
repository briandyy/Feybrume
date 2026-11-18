# Tema dan pengaturan gaya

[English](../design-system.md) · [Bahasa Indonesia](design-system.md) · [简体中文](../zh-CN/design-system.md)

[Katalog](../../design/themes.json) memuat 40 preset. Setiap preset memiliki palet, warna tiap kondisi kontrol, radius, jarak desktop dan sentuh, peran font, gradien dekoratif, serta profil animasi. Empat tema utama adalah Cultivation 仙 dengan aksen emas, Memoir 忆 dengan nuansa kertas, Noir dengan aksen merah gelap, dan Cosmic ✦ dengan gradien ungu ke hijau kebiruan. Efek seperti tekstur dan bintang masih direncanakan.

## Coba di Studio

Ikuti [panduan instalasi](core.md). Salin [contoh pratinjau](../../examples/theme-preview.client.luau) ke LocalScript di StarterPlayerScripts dan jalankan Play. Tekan **Next theme** untuk menelusuri 40 tema. Periksa perubahan warna, bentuk sudut, font, dan gradien. Coba layar 320×568, putar ke lanskap, dan pastikan tombol masih bisa ditekan. Saat pengurangan animasi aktif, perubahan sudut gradien seharusnya langsung terlihat. Foto versi 0.2.0 menunjukkan semua tema bisa ditelusuri di Studio. Versi 0.2.1 memakai ikon Cosmic terpisah, meratakan judul dan isi ke atas, serta mengganti Garamond dengan Bodoni. Hasil visual versi perbaikan dan uji perangkat nyata masih tertunda.

## Buat tema turunan

```luau
local Fey = require(game:GetService("ReplicatedStorage"):WaitForChild("Feybrume"))
local themes = Fey.Theme.new({ initial = "noir" })
assert(themes:Register({
    id = "plum",
    name = "Plum",
    inherits = "noir",
    palette = { accent = "#B274D8" },
}).ok)
assert(themes:Set("plum").ok)

local style = Fey.StyleResolver.Resolve(themes:Get(), {
    input = "touch",
    states = { selected = true, focused = true },
    overrides = { component = { variant = "outline", size = "S" } },
    accessibility = { fontScale = 1.2, reducedMotion = "system" },
})
assert(style.ok)
print(style.value.foreground, style.value.minHeight)
themes:Destroy()
```

`Derive` menghasilkan tema baru yang dapat dipakai tanpa masuk ke registry. `Register` menambahkan ID tema baru, dan `Subscribe` memberi tahu bagian yang berubah ketika tema dipilih. Warna turunan dapat diganti menggunakan `tokens`.

Pengaturan gaya mengikuti urutan global, jendela, kontainer, komponen, lalu kondisi kontrol. Fokus diproses terpisah. Input sentuh tidak memakai kondisi hover, dan target sentuh preset minimal 48×48. Kontras teks biasa memakai rasio 4,5:1, dengan perhitungan terhadap warna latar yang disediakan. `autoContrast = false` mempertahankan warnamu dan melaporkan peringatan. Tata letak dengan gradien atau gambar di belakang teks perlu pengecekan visual tersendiri.

`Typography:Resolve` mencoba font pilihan lalu font tema dan fallback Roblox. Preview mencoba mengukur sampel teks dan pindah ke font cadangan jika gagal. Uji ini belum membuktikan semua karakter tersedia. `reducedMotion = "always"` menghapus jeda animasi, sementara `"system"` mengikuti preferensi sistem.

[Referensi opsi lengkap (Inggris)](../design-system.md) · [Hasil uji](../../evidence/phase2-checks.json)
