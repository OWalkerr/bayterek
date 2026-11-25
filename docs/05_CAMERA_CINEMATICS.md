# Kamera & Sinematik Sistemi

## Kamera Modları
| Mod | Kullanım | Kamera | Oyuncu hareketi |
|---|---|---|---|
| `SIDE` | Varsayılan oynanış | Perspektif, FOV 40°, karakterin 14 m önünde (+Z), hafif yukarıdan | X-Y, Z kilitli |
| `DEPTH` | Mağaralar, boss arenaları, gizli geçitler | 3. şahıs, karakterin 6 m arkası, 2.5 m yukarı, FOV 60° | X-Z serbest + Y |
| `CINEMATIC` | Ara sahneler | Path3D rayı / sabit açılar | Kilitli |
| `FOCUS` | Boss intro, önemli nesne | Hedefe kısa zoom | Kilitli veya yavaş |

**Neden perspektif (ortografik değil)?** 3D modeller parallax ile derinlik kazanır, SIDE→DEPTH geçişi aynı kamerayla kesintisiz tween edilebilir.

## Mod Geçişi
- Tetikleyici: `CameraZone` (Area3D). Girişte hedef mod ve geçiş süresi (varsayılan 1.0 sn, ease in-out).
- Geçiş sırasında:
  1. Kamera pozisyon + rotasyon + FOV aynı anda tween edilir.
  2. Oyuncu girişi **kesintisiz**: tutulan yön tuşu geçiş boyunca eski anlamını korur ("input continuity"), tuş bırakılınca yeni eksene geçer.
  3. Kısa bir zaman yavaşlaması (0.85x, 0.3 sn) dramatik his verir — ayarlardan kapatılabilir.
- DEPTH'ten çıkarken oyuncu, odadaki `SideRail`'e (varsayılan Z=0) 0.4 sn'de yumuşakça çekilir.

## Uygulama Stratejisi
- **Prototip (şimdi):** Kendi `CameraRig` sınıfımız (`scripts/camera/camera_rig.gd`) — bağımlılıksız, web'de çalışır.
- **Üretim:** [Phantom Camera](https://github.com/ramokz/phantom-camera) eklentisine geçiş değerlendirilir: her mod bir `PhantomCamera3D`, öncelik değiştirerek tween. Karar M3 sonunda verilir. `CameraDirector` API'si aynı kalır, böylece oyun kodu etkilenmez.

## SIDE Mod Detayları
- **Ölü bölge (dead zone):** Yatay 1.5 m, dikey 1.0 m.
- **Bakış yönü öne kayma (look-ahead):** Hız yönünde 2.5 m, 0.4 sn yumuşatma.
- **Dikey odak:** Yukarı tırmanış oyunu olduğu için kamera karakteri ekranın **alt üçte birinde** tutar (yukarıyı daha çok gösterir). Düşerken alt yarıya kayar.
- **Sallanma zinciri:** Hız > 9 m/s ise kamera 2 m geri çekilir.
- **Oda sınırları:** Her oda bir `RoomBounds` (AABB) tanımlar; kamera dışına çıkmaz.

## Sinematik Sistemi
- **Araçlar:**
  - `AnimationPlayer` — kamera, karakter animasyonları, ışık, ses, olay çağrıları tek zaman çizelgesinde.
  - `Path3D` + `PathFollow3D` — uzun kamera uçuşları (C05 "Erlik'in Gösterdiği").
  - [Dialogue Manager](https://github.com/nathanhoad/godot_dialogue_manager) (v3.x, Godot 4.4+) — diyalog betikleri `.dialogue` dosyalarında; diyalog içinden `do CutsceneDirector.play("C02")` gibi çağrılar.
- **CutsceneDirector** (autoload): `play(id)`, `skip()`, oyuncu girişini kilitler, letterbox (sinema bantları) açar, bitince durumu geri verir, `GameState.flags` içine `seen_C02 = true` yazar.
- **Atlama:** Her sinematik basılı tut (1 sn) ile atlanabilir; ilk izlemede bile.
- **Rüya sinematikleri:** Özel post-process (bloom yüksek, doygunluk düşük, altın tonu) + yavaş kamera.

## Sinematik Üretim Akışı
1. `01_STORY.md` listesinden sinematik seçilir.
2. Storyboard: 6–12 kare (Claude ile yazılı + AI görsel taslak).
3. Godot'da `scenes/cinematics/C0X_*.tscn` oluşturulur; oyun içi modeller kullanılır (ayrı render yok).
4. Zaman çizelgesi AnimationPlayer'da; diyalog satırları Dialogue Manager'dan.
5. Web build'de test → süre ve okunabilirlik kontrolü.
