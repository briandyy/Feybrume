# Jendela dan workspace

[English](../window.md) · [Bahasa Indonesia](window.md) · [简体中文](../zh-CN/window.md)

Workspace menampung beberapa jendela Roblox. Masing-masing menyimpan tab aktif, posisi, ukuran, dan pilihan tema sendiri. Tab dapat diisi dengan GUI native Roblox. Section menyediakan enam slot, dan grid menyesuaikan jumlah kolom dengan lebar panel.

## Coba di Studio

1. Buka file preview Fase 3, lalu tekan **F5**. Alternatif untuk proyek sendiri ada di [panduan pemasangan](core.md) dan [skrip preview](../../examples/window-preview.client.luau).
2. Seret judul jendela untuk memindahkannya. Seret **Resize** di kanan bawah untuk mengubah ukurannya. Lepas dekat tepi kiri, kanan, atau atas untuk docking. Pilih **Floating layout** atau **Restore** untuk kembali ke jendela mengambang. Pastikan teks **Resize** dan **Restore** terbaca penuh.
3. Buka tab **Preferences** dan tekan **Hide**. Tekan bubble **UI** untuk membuka lagi. Tab yang sama seharusnya tetap aktif. Bubble **2** membuka jendela kedua.
4. Di **Home**, pilih **Open sheet**. Coba buka sheet kedua dan tutup kembali. Scroll sampai ke kolom ketik untuk mengecek apakah tombol **Done** masih bisa dijangkau saat keyboard muncul.
5. Untuk tes HP, coba portrait dan landscape di Device Emulator. Di layar sempit, tab pindah ke bawah. Kalau layarnya pendek, tab dapat dibuka lewat tombol **Tabs**.

Di desktop, klik kanan judul pada tab **Help** untuk membuka menu aksi. Di layar sentuh, tekan dan tahan judul yang sama. Tombol **Open actions** juga tersedia. **Move reopen bubble** pada tab **Preferences** mengubah sisi bubble.

Tes Luau mencakup perhitungan layout, gesture, dan pemulihan fokus. Perilaku langsung di Studio dan perangkat fisik masih perlu dicek. [Referensi API lengkap (Inggris)](../window.md) · [Hasil uji](../../evidence/phase3-checks.json)
