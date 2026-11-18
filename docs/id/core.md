# Inti runtime

[English](../core.md) · [Bahasa Indonesia](core.md) · [简体中文](../zh-CN/core.md)

Inti Feybrume dapat memakai layanan Roblox atau host yang disediakan pengembang. Modul ini mengatur perubahan state dan pembersihan resource.

## Roblox Studio

Jalankan `rojo serve` dari direktori utama repo dan hubungkan plugin Rojo di Studio. Proyek memetakan `src` ke `ReplicatedStorage.Feybrume`. Untuk pemasangan manual, buat ModuleScript bernama `Feybrume` dengan isi `src/init.luau`. Tambahkan folder `core`, `engine`, dan `ui` di bawahnya. Masukkan setiap file dari folder `src` yang sesuai ke folder masing-masing sebagai ModuleScript dengan nama file tanpa ekstensi.

Jalankan skrip uji singkat ini dari LocalScript di StarterPlayerScripts.

```luau
local replicatedStorage = game:GetService("ReplicatedStorage")
local Core = require(replicatedStorage:WaitForChild("Feybrume"))
local runtime = Core.Runtime.Create()
local store = runtime:CreateStore({ opened = false })

runtime.Scope:Give(store:Observe({ "opened" }, function(state, change)
    print(state.opened, change.revision)
end))

local changed = store:Set("opened", true, "user")
assert(changed.ok)
assert(runtime:GetCapabilities()["host.client"].state == "available")

local job = runtime:Spawn(function()
    return "ready"
end)
local result = job:Await(5)
assert(result.ok and result.value == "ready")

runtime:Dispose()
assert(runtime.Scope:GetCounts().resources == 0)
```

Tekan Play dan pastikan Output menampilkan `true 1`, tugas selesai, dan hitungan resource kembali ke 0. Ulangi di Device Emulator dan di ponsel lewat pengalaman uji yang diizinkan. Uji Studio dan perangkat nyata masih tertunda. Uji otomatis memakai Luau CLI dan host simulasi.

| Modul | Fungsi |
|---|---|
| Runtime dan Services | Menyediakan layanan yang di-cache, scope resource, dan deteksi Studio, client, atau server |
| Janitor dan Signal | Membersihkan resource dalam urutan terbalik serta mengirim dan menunggu event |
| Promise, Clock, dan Throttle | Menjalankan tugas yang bisa dibatalkan, menjadwalkan callback, dan membatasi frekuensinya |
| Result, Error, dan Logger | Mengembalikan hasil terstruktur dan menyaring informasi diagnostik |
| Schema, Store, dan Computed | Memvalidasi data dan memproses perubahan state dalam transaksi |
| Flags dan Serializer | Mengelola flag per namespace dan migrasi data antarversi |

Transaksi, validator, listener signal, dan cleanup berjalan sinkron. Panggil `Await` atau `Wait` dari konteks yang boleh jeda. Periksa pembatalan melalui `token:IsCancelled()`, dan daftarkan pembersihan lewat `token:OnCancelled(callback)`. Simpan data biasa untuk nilai seperti Color3. Gunakan skema yang hanya mengizinkan kolom yang ingin disimpan.

[Referensi API (Inggris)](../core.md#api) · [Hasil uji](../../evidence/phase1-checks.json)
