# Jendela dan workspace

[English](../window.md) · [Bahasa Indonesia](window.md) · [简体中文](../zh-CN/window.md)

Workspace menampung beberapa jendela Roblox. Masing-masing menyimpan tab aktif, posisi, ukuran, dan pilihan tema sendiri. Tab dapat diisi dengan GUI native Roblox. Section menyediakan enam slot, dan grid menyesuaikan jumlah kolom dengan lebar panel.

## Coba di Studio

1. Buka file preview Fase 3, lalu tekan **F5**. Alternatif untuk proyek sendiri ada di [panduan pemasangan](core.md) dan [skrip preview](../../examples/window-preview.client.luau).
2. Seret judul jendela untuk memindahkannya. Seret **Resize** di kanan bawah untuk mengubah ukurannya. Di desktop, lepas dekat tepi kiri, kanan, atau atas untuk docking. Di HP, pilih **Dock left** atau **Dock right**. Di landscape pendek, pegangan resize berbentuk sudut. Pilih **Floating layout** atau **Restore** untuk kembali ke jendela mengambang. Pastikan teks **Resize** dan **Restore** terbaca penuh.
3. Buka tab **Preferences** dan tekan **Hide**. Seret bubble **UI** ke tengah, lepas, lalu ketuk untuk membuka lagi. Bubble seharusnya tetap di tempat yang kosong dan window kembali ke tab yang sama. Untuk mencoba window kedua, pilih **Open second window** di **Preferences**. Bubble **2** muncul saat window kedua disembunyikan.
4. Di **Home**, pilih **Open sheet**. Coba buka sheet kedua dan tutup kembali. Scroll sampai ke kolom ketik untuk mengecek apakah tombol **Done** masih bisa dijangkau saat keyboard muncul.
5. Untuk tes HP, coba portrait dan landscape di Device Emulator. Di layar sempit, tab pindah ke bawah. Di landscape yang cukup lebar, tab bisa tampil di sisi kiri supaya isi tetap punya ruang.

Di desktop, klik kanan judul pada tab **Help** untuk membuka menu aksi. Di layar sentuh, tekan dan tahan judul yang sama. Tombol **Open actions** juga tersedia. **Move bubble to side** pada tab **Preferences** memindahkan bubble ke sisi lain. Posisi bebas dibatasi area aman Roblox. Pilih `reopenMode = "edge"` jika ingin bubble selalu mendekati tepi.

Di **Controller Emulator**, pilih **Navigation: drawer** di Preferences. Pindahkan fokus ke **Tabs** dengan **D-pad**, lalu tekan **A** untuk membuka daftar dan memilih tab. Buka sheet kedua dan tekan **B** sekali untuk kembali ke sheet pertama. Saat semua window disembunyikan, **Select/View** memilih bubble untuk membuka ulang.

## Ubah bubble

Di **Preferences**, pilih ukuran bubble, bentuk, dan ukuran gambar. Aktifkan gambar contoh lewat **Bubble image** atau masukkan ID gambar Roblox sendiri. Tekan **Hide** untuk melihat hasilnya.

Dari skrip, tentukan `reopenBubble` saat membuat workspace atau window. Saat berjalan, contoh pemakaiannya adalah `window:SetReopenBubble({ size = 68, shape = "rounded", radius = 14, image = 14304828123, imageScale = 0.72 })`. Bentuk yang tersedia adalah `square`, `rounded`, dan `circle`. Gunakan `image = false` untuk menghapus gambar. Bubble berhenti di area aman perangkat dan berada di bawah top bar secara bawaan.

Tes Luau mencakup perhitungan layout, gesture, dan pemulihan fokus. Perilaku langsung di Studio dan perangkat fisik masih perlu dicek. [Referensi API lengkap (Inggris)](../window.md) · [Hasil uji](../../evidence/phase3-checks.json)
