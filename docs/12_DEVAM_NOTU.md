# Devam Notu — Kaldığımız Yer (2026-11-26)

> Proje kullanıcının bilgisayarına taşınıyor. Yeni oturumda (bulutta ya da PC'de) **önce bu dosyayı oku**,
> sonra `docs/09_ROADMAP.md`. Kurallar: `CLAUDE.md`.

## 1. Durum özeti
- **Aktif milestone: M7 (Sanat geçişi)** — büyük kısmı bitti, eksik varlıklar bekleniyor.
- M0–M6 tamam: hareket, sallanma, savaş, kamera (yan + derinlik), 15 oda, kapılar, Ocak/kayıt, harita, kanca, sır oda, Kökyiyen boss'u.
- Son commit: `c1e10e3` (main). Web build: https://owalkerr.github.io/bayterek/ (sürüm etiketi `c1e10e3-…`).
- Testler (hepsi yeşil): validate_scripts, test_movement, test_m1…test_m7, model_check, test_m3 (rig arka ucu).

## 2. Oyunda olan modeller
| Model | Dosya | Nerede / nasıl |
|---|---|---|
| Alpay (yeni, Mixamo FBX) | `assets/models/characters/alpay/char_alpay.fbx` | `scenes/player/player.tscn` → Visual/Model. 13 Mixamo klibi `alpay/anims/` (idle "With Skin", diğerleri "Without Skin") |
| Kocabaş | `characters/npc_kocabas.glb` | Kök Ağzı (eğitim odası), `KocabasNpc` |
| Çürük Sürüngen, Spor Şişkini | `enemies/` | `RotCrawler`, `SporeBloater` |
| Kapan Çiçek, Kök Yılanı | `enemies/` | `TrapFlower`, `RootSnake` — Spor Mahzeni |
| Kökyiyen | `bosses/boss_kokyiyen.glb` | `Rooteater` |
| Kanca çiçeği, Ocak | `props/` | `GrappleFlower`, `Ocak` (alev/kıvılcım/duman) |
| Çevre seti (17) | `environment/` | `RoomDressing` otomatik yerleşim + `GreyboxRoom.decor()` elle |

İnsansı olmayanların hepsi **kodla canlandırılıyor** (`ModelVisual.add_rotation`), klip yok.

## 3. Bekleyen işler (sırayla)
1. **Kullanıcıdan gelecek varlıklar** (prompt'lar `docs/11_ASSET_PROMPTS.md`):
   - Not (2026-11-26): kullanıcı "yükledim" dedi ama GitHub'a hiçbir dosya gelmedi (dallar ve PR'lar da boş) — PC'de klasöre koyup push etmemiş olabilir.
   - [ ] Parallax görselleri → `assets/textures/backgrounds/` (`bg_kokdibi_l0_far.jpg`, `_l1_roots.png`, `_l2_mid.png`, `_l3_glow`, `fg_kokdibi_top/bottom.png`, `_lightshafts`, `_cave_far.jpg`, `bg_kokyiyen_arena.jpg`, `_sky_hole.png`)
   - [ ] Sarkan kök `env_hanging_root_3m_a/b.glb`
   - [ ] Prop'lar: `prop_brazier`, `prop_torch_wall`, `prop_totem_stone`, `prop_kut_shard`, `prop_oz_crystal`, `prop_ability_shrine`, `prop_heavy_boulder`, `prop_root_gate`, (isteğe bağlı) `prop_rotten_vine`, `prop_spirit_lantern`, `prop_feather_pendant`
   - [ ] Boss parçaları: `boss_kokyiyen_maw`, `boss_rot_sac`, `boss_root_rock`, `boss_burrow_debris`
   - [ ] Düşman varyasyonları: `enm_rot_crawler_b`, `enm_spore_bloater_b`
   - [ ] Eğrelti ve sarmaşık perdesini 8k üçgenle yeniden üretmek (şu an 19k / 15.5k, istisna tablosunda)
2. **Gelince yapılacak kod:**
   - **Parallax sistemi (henüz yazılmadı):** her bölge için `ParallaxBackdrop` düğümü — görselleri kameranın arkasında −12/−25/−45/−80 m'deki dev düzlemlere (unshaded, saydam PNG; L3 ve ışık huzmesi additive), FG katmanı +4 m önde; yatayda döşenir (UV tekrar). Parallax gerçek 3D derinlikten gelir. Derinlik (mağara) modunda gizle ya da yalnız uzak katmanları göster. docs/11 §0.
   - **Mangal / meşale:** model + `FxLibrary.fire/embers/smoke` + titreyen ışık (Ocak'taki `_build_model_visual` örneği). Odalara `GreyboxRoom` yardımcısı (`brazier(at)`, `torch(at, facing)`).
   - **Oyun nesneleri:** `Collectible` (Kut parçası) → `prop_kut_shard`, `RoomGoal` → `prop_oz_crystal`, `AbilityShrine` → `prop_ability_shrine`, `RootRock` → `boss_root_rock`, `BossWeakPoint` → `boss_rot_sac`, `RisingMaw` → `boss_kokyiyen_maw`. Kalıp: `ModelVisual.spawn(...)`, greybox yedeği kalsın (`ResourceLoader.exists`).
   - Sarkan kökler → `RoomDressing._hang_strands` içinde prosedürel iplik yerine model (sarkık rüzgâr modu `&"hang"`).
3. **Açık tasarım soruları** (kullanıcıya sorulacak):
   - Kapan Çiçek ve Kök Yılanı başka odalara da dağıtılsın mı? (Botların geçtiği odalarda bot yolları ayarlanmalı.)
   - `env_root_ledge_1m_a` (çıkıntı) nerede kullanılsın — tırmanma duvarlarında görsel mi, yeni platform mu?
4. Sonra: M8'e geçiş (`docs/09_ROADMAP.md`).

## 4. Yeni varlık gelince kontrol listesi
1. `godot --headless --path . --import` → `godot --headless --path . res://tests/model_check.tscn`
2. Tripo çıktısı en büyük kenarı 1 m'ye indirir → `.glb.import` içinde `nodes/root_scale` = hedef boy. Orijin ortadaysa `import_script/path="res://tools/import/align_base_import.gd"`. Oto-rig yırtılıyorsa `smooth_rig_import.gd` (docs/07 §7.6).
3. Doku: `_basecolor` 1024 (boss/Alpay 2048), normal/metal 256 (`process/size_limit`).
4. Galeri + web ekran görüntüsü ile gözle kontrol (headless'ta GPU yok). Geçici galeri sahnesi `scenes/dev/` altına yazılıp silinir; web build'i `project.godot` main_scene geçici değiştirilerek alınır.
5. Testler yeşil → docs (07, 08, 09, 00) → commit → `tools/deploy_web.sh`.

## 5. PC'de çalışma notları
- **`BASLAT.bat` (kök klasör):** çift tıkla → Godot 4.6.3'ü bulur (proje klasörü, üst klasör, İndirilenler, Masaüstü, Belgeler; bulamazsa exe'yi pencereye sürükle, yol `godot_yolu.txt`'ye kaydedilir), sürümü denetler, ilk açılışta içe aktarmayı konsolda yapar, menü: oyun / oyun (uyumluluk: OpenGL) / editör / editör (uyumluluk) / içe aktarmayı yenile. Çıktılar `log/` (git dışı). Kullanıcı "Godot gri ekranda kalıyor" dedi (2026-11-26) — olası nedenler: Vulkan desteklemeyen ekran kartı (→ uyumluluk modu), yanlış Godot sürümü, ilk içe aktarmanın sürmesi. Bir sonraki oturumda `log/oyun.txt` istenecek.
- **Godot 4.6.3** (sürüm yükseltme yok). Windows: `Godot_v4.6.3-stable_win64.exe`. Projeyi "Import" → `project.godot`. İlk açılışta tüm modeller içe aktarılır (birkaç dakika); `tools/import/*.gd` içe aktarma betikleri o sırada çalışır (Kökyiyen/Kocabaş/sürüngen rig düzeltmesi, eğrelti/perde taban hizası) — normal.
- Testler PC'de: `godot_console.exe --headless --fixed-fps 60 --path . res://tests/test_m7.tscn` (Windows'ta `_console` sürümü çıktı verir).
- Oynamak: F5 (ana sahne `scenes/main/main.tscn`). Menüde 0–7 geliştirici odaları; F1 bilgi, F2 canlı tuning, F3 animasyon önizleme, R oda baştan.
- Web export: Proje → Dışa Aktar → "Web" ön ayarı (şablonlar Editör → Dışa aktarma şablonlarını yönet). `tools/deploy_web.sh` bash betiği (Windows'ta Git Bash ile).
- PC'de değişiklik yaparsan **GitHub'a geri yükle** (GitHub Desktop ya da `git push`), yoksa bir sonraki bulut oturumu eski sürümle başlar.
