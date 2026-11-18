# Mobile-first UX dan penerimaan perangkat

Ukuran memakai safe rect pada GUI dalam unit layout Roblox. Sumber: `ScreenGui.ScreenInsets=CoreUISafeInsets`, ukuran area root dan pembaruan `GuiService`/viewport. Backdrop dekoratif dapat memakai layer device-safe terpisah, tanpa interaksi. Thumbstick/jump dan kontrol experience di-reserve melalui zona layout yang ditetapkan host dan diuji di real device, karena safe insets sendiri tidak mencakup semua overlay touch. `PreferredInput` dan perubahan keyboard/pointer/gamepad relevan bahkan jika TouchEnabled juga true. Pantau properti keyboard yang didukung dan fokus TextBox; jika geometri keyboard tak tersedia gunakan scroll/focus fallback dan validasi tap. [ScreenGui](https://create.roblox.com/docs/reference/engine/classes/ScreenGui) · [ScreenInsets](https://create.roblox.com/docs/reference/engine/enums/ScreenInsets) · [GuiService](https://create.roblox.com/docs/reference/engine/classes/GuiService) · [UserInputService](https://create.roblox.com/docs/reference/engine/classes/UserInputService) · [Mobile input](https://create.roblox.com/docs/input/mobile)

| Profil safe width | Default komposisi | Tinggi pendek / landscape |
|---|---|---|
| Micro <360 | satu kolom, full safe area, bottom nav 2–3 aksi + More | drawer/rail sempit, potong ornament, body scroll |
| Compact 360–480 | bottom nav 3–4 aksi + More, stack cards, bottom sheet | rail/drawer, actions tetap reachable |
| PhoneLarge >480–640 | bottom nav 4–5 inkl. More, satu kolom utama | split jika lebar cukup, sheet menjadi dialog scrollable |
| Tablet >640–1000 | 1–2 kolom, rail jika horizontal | dua pane kondisional dan docking opsional |
| Desktop >1000 | beberapa windows, sidebar/rail, 1–4 kolom menurut konten | min height menahan global chrome dan tetap scroll |

Usulan short-height = safe rect ≤400. Breakpoint dan nav dapat diganti. Mobile default hit target 48×48, minimum primary 44×44, spacing 8, opt-in density 48–56 sesuai kebutuhan. Clamp drag/resize terhadap hasil safe rect terbaru; saat rotate, reflow ID tetap, simpan scroll anchor, restore focused item jika hidup. Input router global sekali per root, capture per pointer hanya ketika awal gesture di node UI eligible; window drag dari handle intentional, vertical scroll menang sebelum klaim horizontal slider. Setelah slider klaim drag, suspend scrolling parent yang terkait hingga up/cancel/modal/destroy, lalu restore. Sliders punya step, +/- atau numeric fallback, tooltip di atas jari. Color picker sheet punya SV plane besar, hue/alpha lebar, HEX/RGB/HSV/HSL, swatch/history dan Cancel/DONE. Dropdown selection memakai snapshot draft, pencarian yang cancellable, list virtual (>100), header/action footer terjangkau dan support chips wrap. Keyboard tinggi pendek menahan footer dan menggulir focus ke dalam safe content. Bebaskan pointer saat orientation/focus change.

Long press/context menu atau alternatif tombol; swipe tab dan dua jari hide default off, hanya untuk region UI bila diaktifkan. Bubble default 52 dan edge snap, bisa pindah/buka via keyboard/controller, pilihan sisi kanan/kiri, tidak menutup Core UI, virtual controls atau tombol navigasi. Focus trap pada top modal mengikuti keyboard/gamepad selection, Back/Escape menutup overlay teratas, fokus kembali ke asal. Jangan memalsukan screen-reader semantics yang tidak didukung engine. System reduced motion dan manual; battery saver menahan partikulat/efek/media; haptics opt-in dan device/capability probe. Font 80–160% terpisah dari density dan scale; 200% dipakai sebagai stress fixture, overflow harus bisa dibaca via wrap/scroll.

## Skenario (semua NOT_IMPLEMENTED)

| ID | Langkah | Kriteria lulus |
|---|---|---|
| MOB-01 | 320×568, buka window/nav | Semua aksi primer reachable, layout satu kolom |
| MOB-02 | 360×640, tap batas dua baris | Tidak ada aktivasi silang dengan gap 8 |
| MOB-03 | 393×870 dan 430×932, buka daftar banyak tab | Overflow mempertahankan tab aktif |
| MOB-04 | 640×360 dengan editor terbuka | Body scroll dan Done/Cancel bisa dicapai |
| MOB-05 | 740×360, jalankan game dengan thumbstick | Bubble tidak menghalangi thumbstick/jump |
| MOB-06 | Rotate 870×393↔393×870 saat drag | Gesture dibatalkan, nilai commit lama terpelihara |
| MOB-07 | 768×1024, resize split | Kolom collapse tanpa ID/flag berubah |
| MOB-08 | Ubah area sempit→lebar ala foldable | Preserve satu focused child dan scroll anchor |
| MOB-09 | Buka keyboard EN/ID pada TextBox bawah | Caret dan aksi konfirmasi tetap terlihat |
| MOB-10 | Tutup keyboard saat sheet terbuka | Footer kembali ke safe rect tanpa duplikasi |
| MOB-11 | Tap slider dan drag diagonal | Hanya gesture yang melewati threshold menangkap |
| MOB-12 | Swipe vertikal dari slider row | Scroll bekerja sebelum slider klaim |
| MOB-13 | Slider numeric +/- | Validasi langkah dan batas, fallback saat drag off |
| MOB-14 | Color picker finger-cover | Tooltip di atas jari, rails mudah ditekan, Cancel rollback |
| MOB-15 | Dropdown 150 item, filter cepat | Hasil terbaru saja, footer tetap dan row recycled |
| MOB-16 | Multiselect banyak lalu Cancel | Draft tidak mengubah nilai, chips wrap |
| MOB-17 | Drag bubble di layar notched | Bisa diakses kembali, edge snap di luar reservasi |
| MOB-18 | Switch ke one-handed left/right | Posisi bubble/nav dan aksi bawah sesuai sisi |
| MOB-19 | Long press lalu Cancel | Context menu tidak memicu aksi bawah |
| MOB-20 | Swipe/dua jari di luar GUI | Kamera dan gameplay tetap menerima input |
| MOB-21 | Ubah keyboard/mouse/touch/gamepad live | Fokus dan navigasi menggunakan preferred input, bucket ukuran tetap |
| MOB-22 | Modal bertumpuk, tekan Back | Satu overlay tutup, fokus kembali |
| MOB-23 | 80/160/200% text EN dan ID panjang | Teks tidak menyatu dengan aksi; 200% bisa scroll |
| MOB-24 | Reduced motion + battery saver dan low FPS | Aksi tetap berfungsi, efek mahal dan hidden animation berhenti |
| MOB-25 | Haptics hardware hadir/tidak hadir | No vibration sebelum opt-in; visual berlaku untuk keduanya |
| MOB-26 | Login dengan keyboard, offline atau revoked | State faktual, close dan retry reachable |
| MOB-27 | Drag, hide lalu Destroy dengan pointer turun | Release capture, timer, input dan audio scope |
| MOB-28 | Bandingkan tap pertama pada target kecil dan 48 px UI | Rekam missed/adjacent activations dan finger occlusion dengan fixture, tanpa benchmark asumsi |

Studio Device Emulator untuk semua resolusi dan simulasi orientasi, lalu PC keyboard/pointer/controller dan minimal satu Android low-end, Android midrange, iOS/iPad nyata jika tersedia. Ukur/log device, OS, Roblox version, profil, fps/memori, route input, timestamp, expected/actual. Ulangi rotate/keyboard notch dan gerak simultan dalam experience test terbit supaya permission dan zona Core UI nyata. Ringkasan fokus/haptics/UX belum ada karena tahap runtime belum dibangun.

## English handoff

Layout changes with usable viewport size and input preference. Touch controls default to 48 logical UI pixels with eight pixels of separation. Modal actions stay reachable above the keyboard, and touch capture is scoped to gestures that start inside Feybrume. Studio emulation is followed by signed-off real-device checks.
