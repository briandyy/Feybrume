# Ringkasan teknis

[English](../index.md) · [Bahasa Indonesia](reference.md) · [简体中文](../zh-CN/reference.md)

- **Struktur.** Inti Luau menangani layanan, event, tugas yang dapat dibatalkan, kepemilikan resource, dan perubahan state. Mesin tema membaca registry dan menghasilkan gaya kontrol yang konsisten. Rencana jendela menyimpan ID dan state saat tata letak berubah. [Arsitektur (Inggris)](../architecture.md)
- **Touch.** Preset menetapkan target sentuh minimal 48×48. Desain jendela memperhitungkan area aman, notch, rotasi, tombol sistem, dan keyboard layar. Cakupan input, dialog, dan navigasi sentuh masih harus diuji di perangkat. [Profil dan skenario uji (Inggris)](../mobile.md)
- **Font.** Mesin tema memakai font native Roblox dan fallback berbasis peran. Katalog atlas font masih direncanakan. Font yang sudah dibuktikan render di Feybrume saat ini berjumlah 0 dari target 1.000. [Rencana font dan lisensi (Inggris)](../typography.md)
- **Media.** Gambar, video, dan suara native memerlukan aset Roblox yang jenis dan izinnya cocok. GIF memerlukan konversi ke sprite. URL YouTube tidak diputar langsung oleh VideoFrame. Penggunaan CDN dan file lokal mengikuti aturan host dan pipeline impor. [Matriks media (Inggris)](../media.md)
- **Akses.** Desain menyediakan mode keyless, lokal, provider, gateway, dan hybrid. Server memverifikasi akses istimewa. Semua pasangan provider dan gateway masih menunggu uji langsung. [Autentikasi dan gateway (Inggris)](../auth.md)
- **Verifikasi.** Uji CLI memeriksa inti, preset, kontras, dan pengurangan animasi. Hasil perangkat Roblox masih menunggu smoke test. [QA dan roadmap (Inggris)](../qa-and-backlog.md)
