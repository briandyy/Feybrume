# Tipografi, 1.000 font dan 2.500 ikon

Fase 0 membuktikan tiga kandidat sumber lewat metadata dan audit lisensi sampel. Jumlah render Roblox yang telah dibuktikan untuk Feybrume adalah **0**. Tidak ada file TTF, atlas berizin upload, atau asset ID yang dimasukkan sebagai font siap pakai. Dokumentasi Roblox menyebut lebih dari 80 font di Creator Store dan tidak menyediakan impor font bebas. Jumlah itu tidak dipakai sebagai hasil verifikasi Feybrume. [Roblox assets](https://create.roblox.com/docs/projects/assets) · [Font](https://create.roblox.com/docs/reference/engine/datatypes/Font) · [Enum.Font](https://create.roblox.com/docs/reference/engine/enums/Font)

## Backend dan UX

| Backend | Target | Bentuk dukungan dan fallback |
|---|---|---|
| NativeFontFace | TextLabel/TextButton/TextBox | Family URI/ID yang sah, resolve via Font API, preserve selection/focus, engine menangani RichText/layout sesuai jenis GUI dan dukungan engine. |
| VerifiedGlyphAtlas | Label display dan preview opsional | Raster dan shaping terbatas/per script pack, cropping atlas berizin, cache + pool. TextBox, teks selektabel, kompleks/RTL yang belum terbukti dan missing glyph beralih ke native dengan diagnostik. |
| RegisteredCustomFontResolver | Kustom per developer | `RegisterFont`/Fonts:Register menerima referensi native sah, atlas yang lolos schema, atau adapter renderer yang telah diuji. URL TTF/OTF mentah menghasilkan `FONT_NOT_RENDERABLE` atau instruksi konversi. |

`FontDescriptor={family,face?,weight?,style?,renderer?,fallback?}`. `Resolve` menerima name/descriptor, mengembalikan resolved descriptor plus provenance, fallback dan status. `Preload(ids)` memberi task terbatas, `GetStatus` memuat availability dan reason, `Register` atomic, `List` filter/paginasi, `Compare` 2–4 preview, `UnloadUnused` tidak melepaskan active refs. `SetFont`/SetTypography memakai layer runtime dan kotak input native. Roles display, heading1–6, body, small body, caption, button, input, table, code, label, notification, login, sidebar dan title. Style size/leading/tracking/wrap/align/stroke/gradient hanya dipilih bila backend mendukung; beri warning saat fallback. Preview memakai virtual rows, lazy load visible/nearby, pin aktif, batasi decode workers, LRU by bytes, fallback emoji/CJK dan localized samples. Pencarian fuzzy/kategori/coverage/favorites/recent/featured, custom sample, pembanding dan indikator izin. Semua pasangan tema diregistrasi sebagai intent tipografi, pemetaan face final menunggu uji.

## Audit sumber dan lisensi

Repo Google Fonts menyimpan font per keluarga, metadata, dan file lisensi. Snapshot rujukan [google/fonts 7af0d90](https://github.com/google/fonts/commit/7af0d90b4d532ffa4b041937b560c6df4e7b1e95). Sampel berikut memisahkan kelayakan lisensi dari akses aset. [Metadata format](https://github.com/googlefonts/googlefonts.github.io/blob/main/gf-guide/metadata.md) · [SIL OFL FAQ](https://openfontlicense.org/ofl-faq/)

| Keluarga | Bukti | Implikasi kerja |
|---|---|---|
| Archivo | [Metadata](https://github.com/google/fonts/blob/main/ofl/archivo/METADATA.pb) · [OFL](https://github.com/google/fonts/blob/main/ofl/archivo/OFL.txt) | Weight dan width axes pada regular/italic tetap satu keluarga. Bawa notice saat redistribusi software font. |
| Open Sans | [Metadata](https://github.com/google/fonts/blob/main/ofl/opensans/METADATA.pb) · [OFL](https://github.com/google/fonts/blob/main/ofl/opensans/OFL.txt) | Font variable normal/italic tetap satu keluarga. Jangan duplikasi sebagai entri atlas dan native. |
| Share | [Metadata](https://github.com/google/fonts/blob/main/ofl/share/METADATA.pb) · [OFL](https://github.com/google/fonts/blob/main/ofl/share/OFL.txt) | Bukti Reserved Font Name pada notice sumber. Catat kebijakan penamaan untuk font software versi modifikasi. |

Pra-upload, klasifikasikan keluaran atlas: fixture screenshot/raster text biasa berbeda dari paket reusable yang memuat seluruh glyph dan metrics sebagai renderer font. Pakai perlakuan konservatif untuk paket reusable: inventory sumber dan turunannya, salin notice/lisensi per family, cek RFN dan rename bila syaratnya berlaku, dan review persyaratan distribusi/moderasi Roblox sebelum publikasi. Jangan masukkan proprietary font atau font tanpa izin yang bisa dibuktikan. OFL sampel tidak berarti seluruh katalog memiliki lisensi sama. Aset native hanya direferensikan sesuai izin Roblox, font file-nya tidak disalin. Uji supply chain tahap 8 pakai pipeline berikut.

1. Pin commit. Enumerasi direktori, baca METADATA + font names/OpenType + license file; reject missing/mismatch, catat per keluarga dan audit duplikasi face/outline.
2. Normalisasi identitas family dengan NFKC/casefold dan alias manual. Collapse styles/weights/variable axes dan backend duplikat. Pertahankan rekam versi nama/asal dan digest. Fingerprint sampel glyph untuk deteksi alias/collision, bukan satu-satunya identitas.
3. Mulai pilot 10 keluarga dengan Basic Latin dan kumpulan diakritik/nama EN/ID yang dinyatakan. Raster menggunakan FreeType dan shaping HarfBuzz terpin, metrics, kerning, advance, bearings, line height dan glyph map. Buat probe visual berbeda dan catat missing glyph. Grapheme/kerning complex-script butuh pack terpisah; fallback native.
4. Pack gambar dan metadata per group/sheet berukuran diuji, license + hash. Submit pilot untuk moderasi pada owner yang berhak, grant ke place tes terbit, probe permission dengan test account. Catat pending/denied tanpa menempel ID dummy.
5. Per family simpan artifact bukti Device/Studio version, manifest version/hash, image/face load sukses, render string sampel beserta visual snapshot/matching, kode fallback dan existing evidence ID. Jalankan baseline desktop dan mobile target, ukur first paint/scroll/memori. Jika rendering jatuh ke fallback, keluarga gagal gate sekalipun string muncul.
6. Bila pilot lolos, lanjutkan 100 lalu batch ke 1.000. Published catalog count = jumlah family ID unik dengan lisensi valid, izin, render proof pada setiap target rilis, dan tanpa fallback untuk coverage yang dijanjikan. Rilis bisa melaporkan count aktual yang lebih kecil dengan gate 1.000 BLOCKED. Volume storage contoh per atlas PNG 50 KiB × 1.000 ≈ 49 MiB transfer jika semuanya diambil; RGBA decode 512² × 4 bytes = 1 MiB/page sebelum overhead. Ini ilustrasi kapasitas, tanpa pengukuran. Jangan muat semua pack bersamaan.

Rekaman manifest `id,familyName,displayName,category,subfamily,nativeFamilyOrId?,atlasManifest?,license,licenseURL,licenseNoticeHash,assetOwner,permissionStatus,sourceURL,version,supportedUnicodeRanges,supportedWeights,supportedStyles,previewAsset,memoryCostEstimate,availability,fallback,renderEvidence[]`. Kategori serif/sans/slab/mono/display/blackletter/calligraphic/brush/handwriting/script/pixel/retro/futuristic/editorial/rounded/condensed/wide/geometric/decorative/CJK/readability. Pack terpisah versioned dan terpin hash; katalog dasar offline versi rilis. Gallery, perbandingan, Font Licenses dan Atlas Pipeline dirilis bersama bukti aktual. Existing native labels dan accessible fallback harus tetap berfungsi saat pack tidak tersedia.

## Ikon

Kandidat Lucide, Material (reuse aktual hanya sesudah review), Solar, Phosphor, Heroicons, aset owner dan simbol Feybrume; pelajari license notices tiap pack. ID namespaced, ukuran/stroke/warna hanya sesuai renderer, alias pencarian tidak menambah hitungan. Upload sprite pack yang berizin, verifikasi setiap glyph/crop/provenance, lazy preview, fallback text (termasuk pada icon-only button), icon data atau aset approved. Target >=2.500 glyph verified, hasil proyek Fase 0 **0**. SVG mentah dan HTTPS bukan native icon rendering. [Lucide license](https://lucide.dev/license) · [Heroicons](https://github.com/tailwindlabs/heroicons) · [Phosphor](https://github.com/phosphor-icons/core)

## English handoff

Three families have been sampled for upstream license evidence. No Feybrume family has been rendered and verified in Roblox. Native text is the default. The optional atlas track adds audited licenses, uploaded asset grants, per-family visual evidence and measured mobile memory costs. The release count only includes distinct families that pass the declared profiles.
