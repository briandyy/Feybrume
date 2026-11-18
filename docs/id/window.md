# Jendela dan workspace

[English](../window.md) · [Bahasa Indonesia](window.md) · [简体中文](../zh-CN/window.md)

Workspace menampung beberapa jendela Roblox. Masing-masing menyimpan tab aktif, posisi, ukuran, dan pilihan tema sendiri. Tab dapat diisi dengan GUI native Roblox. Section menyediakan enam slot, dan grid menyesuaikan jumlah kolom dengan lebar panel.

## Coba di Studio

1. Buka file preview Fase 3, lalu tekan **F5**. Alternatif untuk proyek sendiri ada di [panduan pemasangan](core.md) dan [skrip preview](../../examples/window-preview.client.luau).
2. Seret judul sampai bingkai menempel di tiap tepi area main, lalu tarik kembali. Panel bisa naik ke tepi atas di samping tombol Roblox jika seluruh lebarnya muat. Di area yang kepakai tombol Roblox, panel berhenti di bawah top bar. Seret ikon kanan bawah untuk resize. Pilih **Dock left**, **Dock right**, atau **Max** untuk docking. Pilih **Floating layout** atau **Restore** untuk kembali. Aktifkan `dockable = true` untuk docking dengan seret mouse atau `touchDock = true` untuk sentuhan.
3. Buka tab **Preferences** dan tekan **Hide**. Seret bubble **UI** ke tengah, lepas, lalu ketuk untuk membuka lagi. Bubble seharusnya tetap di tempat yang kosong dan window kembali ke tab yang sama. Untuk mencoba window kedua, pilih **Open second window** di **Preferences**. Bubble **2** muncul saat window kedua disembunyikan.
4. Di **Home**, pilih **Open sheet**. Coba buka sheet kedua dan tutup kembali. Scroll sampai ke kolom ketik untuk mengecek apakah tombol **Done** masih bisa dijangkau saat keyboard muncul.
5. Untuk tes HP, coba portrait dan landscape di Device Emulator. Di layar sempit, tab pindah ke bawah. Di landscape yang cukup lebar, tab bisa tampil di sisi kiri supaya isi tetap punya ruang.

Di desktop, klik kanan judul pada tab **Help** untuk membuka menu aksi. Di layar sentuh, tekan dan tahan judul yang sama. Tombol **Open actions** juga tersedia. **Move bubble to side** pada tab **Preferences** memindahkan bubble ke sisi lain. Pilih `reopenMode = "edge"` jika ingin bubble otomatis menempel ke tepi.

Atur `initialPosition` saat membuat jendela. Default-nya `"center"`. Pilihan lain meliputi `"top-left"`, `"top"`, `"top-right"`, `"left"`, `"right"`, `"bottom-left"`, `"bottom"`, dan `"bottom-right"`. Untuk koordinat sendiri, pakai `initialPosition = { x = 64, y = 48 }`.

Ubah `title` untuk mengganti nama header. Gunakan `titleLogo` dengan Roblox image asset ID dan `titleLogoPosition` dengan `"before"` atau `"after"` untuk mengatur urutan. Isi `title = ""` kalau mau logo saja. Untuk tombol Max, Restore, dan Hide, pakai `chromeButtons.max`, `chromeButtons.restore`, dan `chromeButtons.hide` untuk mengganti ikon, teks, atau warna latarnya. [Contoh konfigurasi header](../window.md)


Di **Controller Emulator**, pilih **Navigation: drawer** di Preferences. Pindahkan fokus ke **Tabs** dengan **D-pad**, lalu tekan **A** untuk membuka daftar dan memilih tab. Buka sheet kedua dan tekan **B** sekali untuk kembali ke sheet pertama. Saat semua window disembunyikan, **Select/View** memilih bubble untuk membuka ulang.

## Ubah tampilan window

Di **Preferences**, tekan **Window appearance** untuk mencoba perubahan tanpa membuka ulang window. Pembuat skrip bisa memakai `window:SetProps({ subtitle = "Tools", cornerRadius = 18, sidebarWidth = 152, statusBarHeight = 24 })` dan `window:SetBounds({ x = 24, y = 30, width = 520, height = 360 })`. `window:GetSlot(namaSlot)` menyediakan `TopbarLeading`, `TopbarTrailing`, `StatusBar`, `Background`, dan `Overlay` untuk konten Roblox native. [Opsi lengkap](../window.md)

## Ubah bubble

Di **Preferences**, pilih ukuran bubble, bentuk, dan ukuran gambar. Tekan **Try CDN logo**, lalu **Hide** untuk melihat PNG dari CDN. Untuk tes di experience yang sudah dipublish, aktifkan **Allow HTTP Requests** dan **Allow Mesh / Image APIs** di **Experience Settings → Security**, lalu mulai ulang sesi. Untuk link sendiri, tambahkan URL PNG ke `approvedUrls` pada [skrip server preview](../../examples/reopen-logo.server.luau), lalu masukkan URL itu di Preferences. Kolom yang sama juga menerima ID aset Roblox.

Dari skrip, tentukan `reopenBubble` saat membuat workspace atau window, atau pakai `Window:SetReopenBubble(options)` saat berjalan. Bentuk yang tersedia adalah `square`, `rounded`, dan `circle`. Gunakan `image = false` untuk kembali ke label. Preview memakai `reopenEdge = "screen"` agar bubble bisa mencapai tepi fisik kiri dan kanan. Default library `"device"` mengikuti batas aman perangkat. Keduanya menempatkan bubble di bawah topbar secara bawaan.

Tes Luau mencakup perhitungan layout, gesture, dan pemulihan fokus. Perilaku langsung di Studio dan perangkat fisik masih perlu dicek. [Referensi API lengkap (Inggris)](../window.md) · [Hasil uji](../../evidence/phase3-checks.json)
