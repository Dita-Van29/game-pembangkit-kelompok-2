# Gravebound: Legion of the Fallen - Stage 1 (Desa Lumen)

Proyek Godot 4 (diuji secara desain untuk Godot 4.2 atau lebih baru, renderer Forward+).

## Cara membuka
1. Ekstrak zip ini.
2. Buka Godot 4.2+, klik **Import**, pilih file `project.godot`.
3. Saat pertama dibuka Godot akan meng-import aset (sebentar). Tekan **F5** untuk main.
   Jika GPU-mu tidak mendukung Vulkan: Project Settings > Rendering > Renderer > Compatibility
   (game tetap jalan, hanya efek tilt-shift/DOF yang tidak muncul).

## Melihat semua aset di editor 3D (tanpa menjalankan game)
Semua aset adalah scene `.tscn` berisi node nyata (Sprite3D, mesh, collider, lampu), jadi langsung terlihat di viewport 3D
begitu scene dibuka dan muncul di panel Scene. Tidak ada yang bergantung pada script untuk tampil di editor.
- **`scenes/Stage1.tscn`** - buka ini: seluruh level, Mira, Pip, Old Bram, dan contoh Slime, Tikus, Shade, serta Soul Orb
  (node `PreviewOnly`, dihapus otomatis saat game jalan) terlihat. Semuanya bisa digeser/diedit di editor.
- **`scenes/Workspace.tscn`** - etalase semua aset berlabel. F6 = jalankan dengan kamera bebas
  (WASD gerak, Q/E turun/naik, klik kanan + mouse menengok, roda mouse maju/mundur).
- `scenes/levels/Stage1Level.tscn`, `scenes/props/`, `scenes/characters/`, `scenes/enemies/` - tiap aset terpisah.
Tips editor: di toolbar viewport aktifkan Preview Sun dan Preview Environment bila tampak gelap.
`tools/build_scenes.py` dan `tools/make_assets.py` meregenerasi scene dan sprite (Python + Pillow).

## Kontrol
| Tombol | Fungsi |
|---|---|
| WASD / Panah | Bergerak |
| Klik kiri / J | Serangan sabit, combo 3 pukulan (10, 10, 15 damage). Bidik dengan mouse |
| Spasi / K | Dash Bayangan (cooldown 1,2 dtk, kebal 0,25 dtk) |
| E | Raise (bangkitkan Soul Orb), terbuka lewat tutorial |
| 1 / 2 / 3 | Panggil Shade dari Soul Bank (10 Essence, jeda 4 dtk setelah gugur) |
| E (dekat Papan Developer) | Buka papan identitas tim pengembang (tutup dengan E / Esc / Spasi) |
| T | Tilt-shift on/off |
| Esc | Jeda |

## Isi Stage 1 (sesuai GDD)
- Cutscene dialog Old Bram dan Pip, tutorial gerak, serang, dash, lalu **Raise pertama yang dipaksa lewat skrip cerita**.
- 3 area: Halaman Desa (6 musuh), Kebun Desa (8), Gerbang Desa (10), dengan 2-3 gelombang tiap area.
- Penghitung "Bersihkan monster di area ini (k/N)"; setelah habis gerbang roboh, Pip menunjuk arah.
- Musuh: Slime Lumut (HP 20, tank), Tikus Gerogot (HP 15, striker). Telegraph garis merah sebelum menyerang.
- Raise: biaya 10 Essence, peluang 70% + 5% per level Soul Tether. Soul Orb hilang dalam 6 detik. Gagal = jiwa lenyap.
- Shade: Slime = Tank (Taunt), Tikus = Striker (Lunge). Batas awal 3 Shade.
- Soul Bank (tampil di HUD), panggil ulang Shade dengan tombol angka. Bank tersimpan saat mati dan saat stage selesai.
- **Papan Developer**: setelah Area 1 selesai dan gerbang terbuka, papan kecil muncul di lorong. Dekati lalu tekan E untuk
  melihat papan karakter + identitas tim pengembang (Ivan Pramudita Hanggara, Gilang Eka Saputra, Hafidz Qandis Fitrarobi).
  Gambar: `assets/sprites/dev_team.jpg`, data nama/NIM: konstanta `DEV_TEAM` di `scripts/hud.gd`, scene: `scenes/props/dev_sign.tscn`.
- Bahaya: api kecil di tanah (melukai Mira dan Shade).
- Mati: ulangi dari awal area terakhir, Soul Bank tetap.
- Akhir stage: pilih 1 dari 3 upgrade acak (gratis) atau beli sisanya dengan Soul Shard, lalu save ke `user://gravebound_save.json`.
- Visual: sprite billboard 2D di dunia 3D, kamera miring 50 derajat, bayangan real-time, DOF tilt-shift, vinyet, glow.

## Struktur
```
scenes/Main.tscn      layar judul
scenes/Stage1.tscn    stage yang dimainkan (memuat levels/Stage1Level.tscn + logika scripts/stage_1.gd)
scenes/Workspace.tscn etalase semua aset
scenes/levels|props|characters|enemies/   scene tiap aset
scripts/              player, enemy, shade, soul_orb, pip, fire_hazard, hud, util, game_state
data/enemies/*.tres   data musuh (HP, kecepatan, damage, peluang Raise, stat sebagai Shade)
assets/sprites/       sprite PLACEHOLDER pixel art (dibuat otomatis)
```

## Menambah musuh baru
1. Duplikat `data/enemies/slime_lumut.tres`, ubah `id`, angka, dan `sprite_path`.
2. Tambahkan id-nya ke `ENEMY_IDS` dan ke `AREA_WAVES` di `scripts/stage_1.gd`.

## Mengganti aset
Semua gambar di `assets/sprites/` adalah placeholder satu frame (animasi gerak dibuat lewat kode: bob, squash,
flip). Ganti file PNG dengan nama sama (kaki karakter di dasar gambar, kanvas 64x64) atau ubah `sprite_path`.
Belum ada audio. Tweak angka gameplay ada di konstanta atas `player.gd`, file `.tres` musuh, dan `AREA_WAVES`.
