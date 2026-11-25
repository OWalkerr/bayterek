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
- Tetikleyici: `CameraZone` (Area3D, maske "player"). Girişte hedef mod ve geçiş süresi (varsayılan 1.0 sn, ease in-out). Bölge **düşüş sınırına kadar aşağı** uzatılmalı; yoksa uçuruma düşerken kamera SIDE'a savrulur.
- Geçiş sırasında:
  1. Kamera pozisyon + rotasyon + FOV aynı anda tween edilir.
  2. Oyuncu girişi **kesintisiz**: tutulan yön tuşu geçiş boyunca eski anlamını korur ("input continuity"), tuş bırakılınca yeni eksene geçer. Uygulama: `CameraDirector` geçiş anındaki girdi eksenlerini saklar; yön girdisi 0.15'in altına düşene kadar onları döndürür. (Test: 90° yaw'lı DEPTH'e geçişte sağa basılı → +X sürer; bırakıp yeniden basınca → -Z.)
  3. Kısa bir zaman yavaşlaması (0.85x, 0.3 sn) dramatik his verir — `TimeScale.slowmo_enabled` ile kapatılır (Ayarlar menüsü M9). Hit-stop ile çakışmaz: `TimeScale` autoload'u aktif isteklerin en küçüğünü uygular.
- DEPTH'ten çıkarken oyuncu, x aralığı kendisini kapsayan en yakın `SideRail`'e (yoksa odanın başlangıç rayı, Z=0) ~0.4 sn'de yumuşakça çekilir (üstel, `rail_pull` 10, en fazla `rail_max_speed` 12 m/s). Bu sayede mağaradan **farklı bir derinlik katmanına** çıkılabilir (Oda 5: arka koridor Z=-24).

## Uygulama Stratejisi (M3 kararı, 2026-11-25)
- **Beyin = kendi `CameraRig`'imiz** (`scripts/camera/camera_rig.gd`): her mod için hedef dönüşümü hesaplar — ölü bölge, look-ahead, dikey odak, hızlı sallanma geri çekilmesi, oda sınırları. Phantom Camera'da 3D oda sınırı ve look-ahead olmadığı için bu kısım zaten bizde olmak zorunda.
- **Blend = [Phantom Camera](https://github.com/ramokz/phantom-camera) v0.9.4.2** (`addons/phantom_camera`, MIT, yalnızca GDScript dosyaları; C# dosyaları ve örnekler çıkarıldı): her mod bir `PhantomCamera3D` (follow_mode NONE, dönüşümünü CameraRig her karede yazar), mod değişince öncelik değişir, `PhantomCameraHost` konum + rotasyon + FOV'u SINE ease-in-out ile tween eder. Arka uç: `scripts/camera/phantom_camera_backend.gd`.
- **Yedek = yerleşik blend** (`CameraRig.use_phantom_camera = false`): aynı hedef dönüşümler arasında smoothstep. `BAYTEREK_CAMERA_BACKEND=rig` ortam değişkeniyle zorlanır; **tüm test takımı iki arka uçta da yeşil**. Eklentide sorun çıkarsa: bayrağı kapat, `addons/phantom_camera` + backend dosyasını sil, project.godot'tan autoload/eklenti satırlarını kaldır.
- Neden PCam kalıyor: web (tek iş parçacıklı) ve headless'ta sorunsuz, pck'ye ~0.7 MB; ileride kamera sarsıntısı (`PhantomCameraNoiseEmitter3D`), Path3D takip (C05) ve editörde görsel önizleme hazır.
- `CameraDirector` API'si değişmedi: `set_mode`, `reset_to_side`, `is_side_mode`, `get_input_basis`, + `set_room_bounds`, `is_input_continuity_active`.

## SIDE Mod Detayları
- **Ölü bölge (dead zone):** Yatay 1.5 m, dikey 1.0 m (toplam; karakter ±0.75 / ±0.5 m kutuda kaldıkça odak kımıldamaz, çıkınca çıktığı kadar kayar).
- **Bakış yönü öne kayma (look-ahead):** Hız yönünde 2.5 m (7 m/s'de tam), 0.4 sn yumuşatma zaman sabiti.
- **Dikey odak:** Yukarı tırmanış oyunu olduğu için kamera karakteri ekranın **alt üçte birinde** tutar (bakış noktası +3 m). Düşerken (vy < -8 m/s) bakış +0.6 m'ye iner → karakter alt yarıya kayar, aşağısı görünür.
- **Sallanma zinciri:** Hız > 9 m/s ise kamera 2 m geri çekilir.
- **Oda sınırları:** Her oda bir AABB tanımlar (`GreyboxRoom.bounds`; boşsa statik kutulardan otomatik + 1 m pay). SIDE'da görüş dikdörtgeni (mesafe × tan(FOV/2) × en-boy) bu sınırın dışına taşmaz; oda görüşten darsa ortalanır. DEPTH'te sınır uygulanmaz.

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
