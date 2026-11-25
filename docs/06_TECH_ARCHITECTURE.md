# Teknik Mimari

## Sürüm ve Ayarlar
- **Godot 4.6.x (stable)**, GDScript. Sürüm `project.godot` içinde sabitlenir; izinsiz yükseltilmez.
- **Fizik:** Jolt (Godot 4.6 varsayılanı).
- **Renderer:** PC → Forward+; Web → Compatibility (web export otomatik olarak Compatibility kullanır). Görseller iki renderer'da da test edilir; Forward+'a özel efektler (SDFGI, volumetric fog) "yüksek kalite" ayarı arkasında tutulur.
- **Web kısıtları:** C# yok, GDExtension'lar web derlemesi yoksa çalışmaz → **çekirdek oyun saf GDScript**. Web export "Thread Support" kapalı (itch.io'da SharedArrayBuffer derdi olmasın).

## Klasör Yapısı
```
res://
├── addons/                  # 3. parti eklentiler (dialogue_manager, phantom_camera…)
├── assets/
│   ├── models/{characters,enemies,props,environment}/
│   ├── animations/          # Mixamo / retarget kütüphaneleri (.res)
│   ├── textures/  materials/  shaders/
│   ├── audio/{music,sfx,ambience}/
│   └── fonts/
├── data/
│   ├── tuning/              # PlayerTuning vb. .tres kaynakları
│   ├── abilities/  enemies/
│   ├── dialogue/            # .dialogue dosyaları
│   └── localization/        # tr/en CSV
├── scenes/
│   ├── main/                # main.tscn (giriş), boot
│   ├── player/  enemies/  bosses/
│   ├── world/
│   │   ├── components/      # VineAnchor, CameraZone, Ocak, Door…
│   │   └── regions/kok_dibi/rooms/room_01.tscn …
│   ├── cinematics/
│   └── ui/
├── scripts/
│   ├── autoload/            # EventBus, GameState, CameraDirector, SceneRouter…
│   ├── player/{states}/  camera/  world/{rooms}/  enemies/  ui/  fx/
│   └── core/                # Layers (fizik katmanları), yardımcılar
├── tests/                   # headless test sahneleri
└── tools/                   # deploy_web.sh (gh-pages)
```

## Autoload'lar (singleton)
| Ad | Görev |
|---|---|
| `EventBus` | Global sinyaller (oyuncu öldü, yetenek kazanıldı, oda değişti, kamera modu…) |
| `GameState` | Yetenekler, bayraklar (flags), toplanabilirler, kayıt/yükleme (JSON, `user://save_X.json`) |
| `SceneRouter` | Oda yükleme/boşaltma, kapı geçişleri (karartma + arka planda yükleme), Ocak dinlenmesi, son Ocak'ta dirilme — M4 |
| `TimeScale` | Zaman ölçeği aracısı: hit-stop + kamera geçiş yavaşlaması (en küçük ölçek kazanır) — M3 |
| `PhantomCameraManager` | Phantom Camera eklentisinin autoload'u (eklenti kendi ister) — M3 |
| `CameraDirector` | Aktif kamera modu, geçişler, girdi sürekliliği, oda sınırları; CameraRig'i yönetir |
| `CutsceneDirector` | Sinematik oynatma, giriş kilitleme, letterbox |
| `AudioDirector` | Bölge müziği katmanları, crossfade, SFX havuzu |
| `Settings` | Grafik, ses, kontrol ayarları (`user://settings.cfg`) |

> M4 itibarıyla `InputSetup`, `EventBus`, `GameState`, `TimeScale`, `PhantomCameraManager`, `CameraDirector`, `SceneRouter` hazır; diğerleri M5–M9 arasında eklenir. Sıra önemli: `PhantomCameraManager`, `CameraDirector`'dan önce yüklenir.

## Kamera Mimarisi (M3)
```
CameraRig (Node3D)  ── camera_rig.gd: "beyin" (ölü bölge, look-ahead, dikey odak, geri çekilme, oda sınırı)
├── Camera3D
│   └── PhantomCameraHost          # PCam arka ucu açıksa
├── PCamSide  (PhantomCamera3D)    # follow NONE; dönüşümü her karede CameraRig yazar
├── PCamDepth (PhantomCamera3D)
└── PhantomBackend (Node)          # phantom_camera_backend.gd: öncelik + tween süresi
```
Yedek arka uç: `use_phantom_camera = false` (veya `BAYTEREK_CAMERA_BACKEND=rig`) → aynı hedefler arasında yerleşik blend.

## Oyuncu Mimarisi
```
Player (CharacterBody3D)  ── player.gd (bağlam: zamanlayıcılar, girdi, tutunma seçimi, can/hasar)
├── Visual (Node3D)        # AI model + AnimationTree buraya
├── CollisionShape3D       # Kapsül r=0.35 h=1.6 — katman "player" (2), maske "world" (1)
└── WhipCombat (Node3D)    # player_combat.gd — kombo, yukarı/aşağı (pogo), Savrulma Saldırısı, hit-stop
```
Durumlar: `GROUND`, `AIR`, `SWING`, `CLIMB`, `HURT`, `DEAD`, `CINEMATIC`, `HEAL` (M5) (`WALL` sonra).

**Durum makinesi (M2'de bölündü):** `scripts/player/states/*.gd`, taban `PlayerState` (RefCounted: `enter`, `exit`, `physics_update`, `can_attack`).
| Durum nesnesi | Enum | Görev |
|---|---|---|
| `PlayerMoveState` | GROUND, AIR | Koşma, zıplama, coyote/buffer, momentum koruma, havada yakalama |
| `PlayerSwingState` | SWING | Kinematik sarkaç, bırakma, mükemmel bırakma |
| `PlayerClimbState` | CLIMB | Tırmanma, yana zıplama |
| `PlayerHurtState` | HURT | Geri itilme |
| `PlayerDeadState` | DEAD | Kontrol kilidi; kabuk odayı yeniden başlatır |
| `PlayerCinematicState` | CINEMATIC | Kilit |
| `PlayerHealState` | HEAL | L basılı iyileşme (M5) |
Kamçı Kancası hedeflemesi `Player._update_grapple()` içinde (her kare hedef seçilir, `GrappleFlower.set_targeted`), tutunma `PlayerSwingState.begin(çiçek, grapple=true)`.
Tek geçiş noktası `Player.change_state()`; aynı nesneye geçişte (GROUND↔AIR) `enter/exit` çağrılmaz.

## Düşman Mimarisi
```
Enemy (CharacterBody3D) ── enemy.gd  katman "enemy" (3), maske "world"
├── Visual (Node3D)
├── CollisionShape3D
└── Hurtbox (Area3D)     # katman "hurtbox" (4), maske "player": kamçı sorgusu + temas hasarı
```
Alt sınıflar: `RotCrawler`, `SporeBloater` (kendi `enum State` + `match`). Tehlike alanları (`SporeCloud`) katman "hazard" (5).

## Boss Mimarisi (M6)
- `scripts/bosses/`: `Rooteater` (faz + eylem durum makinesi, kendi `BossPhaseController` mantığı tek dosyada), `BossWeakPoint` (Enemy alt sınıfı → oyuncunun kamçı sistemi değişmeden çalışır), `BossHazard`, `RisingMaw`, `RootRock`.
- Boss odası script'i (`room_19_kokyiyen_ini.gd`) boss'u yalnızca `kokyiyen_ini/boss_defeated` bayrağı yoksa kurar; tetik alanı dövüşü başlatır ve kapıları kilitler; `defeated` → bayrak + Kut + tam can + kayıt + `EventBus.story_requested`.
- UI: `BossCard` (EventBus.boss_intro), `StoryCard` (EventBus.story_requested; M8'de Dialogue Manager'a taşınır).
- EventBus (M6): `boss_intro`, `boss_phase_changed`, `boss_phase_message`, `boss_defeated`, `story_requested`, `story_finished`.

## Oda (Room) Sistemi (M4 — uygulandı)
- **Her oda ayrı `.tscn`** (`scenes/world/regions/<bölge>/rooms/<oda_id>.tscn`). Kök düğüm script'i odanın greybox script'i (`scripts/world/rooms/room_XX_*.gd`, `GreyboxRoom` → `Room`). Sahnede: `room_id`, `display_name`, `idea`, `region`, `map_cell`, `map_size`, `spawn_point`, (isteğe bağlı) `bounds` + kapı/Ocak/toplanabilir düğümleri. Geometri şimdilik kodda (`_build()`); M7'de modeller aynı .tscn'e eklenir (karar 2026-11-25).
- `RoomRegistry` (`scripts/world/room_registry.gd`): oda kimliği → sahne yolu, `START_ROOM`, geliştirici oda listesi. **Yeni oda = .tscn + registry satırı.**
- Oda sahneleri `tools/gen_rooms.py` tablosundan üretilir (kimlik, hücre, kapılar + `requires`, Ocak, toplanabilir, sunak). Elle düzenleme yerine tabloyu değiştir → `python3 tools/gen_rooms.py`.
- Kapılar `RoomDoor` (Area3D, maske "player"): `door_id`, `target_room`, `target_door`, `arrive_offset` (bu kapıdan GİRİLİRKEN oyuncunun konacağı nokta, odanın içine doğru ≥ 1.5 m — kapı alanının dışında olmalı ki geri sekmesin). Kapı düğümü eşiğin alt ortasında; alan yukarı 3 m.
- `SceneRouter` (autoload): kapı geçişi = karartma 0.25 sn → `ResourceLoader.load_threaded_request` ile arka planda yükleme (web'de tek iş parçacığında da çalışır) → `host.swap_room()` → oyuncu hedef kapıya **hızı korunarak** → `GameState.enter_room()` + otomatik kayıt → kamera sınırı/SIDE → aydınlanma. Ayrıca `enter_room_immediate()` (yeni oyun, devam, geliştirici seçici), `respawn_at_last_ocak()`, `rest_at_ocak()`. Host = `main.tscn` kabuğu (`greybox_level.gd`).
- **Ocak** (`scripts/world/ocak.gd`): yanında yerdeyken W → dinlen: can dolar, son Ocak işaretlenir, tam kayıt, oda yeniden yüklenir (düşmanlar yeniden doğar). Ölümde son Ocak'ta tam canla dirilinir; hiç Ocak yoksa mevcut odanın başında.
- Yeni dünya bileşenleri (M5): `GrappleFlower`, `AbilityShrine`, `GreyboxRoom.illusion_box()` (çarpışmasız sahte duvar), `RoomDoor.requires`.
- Oda durumu kalıcılığı: `GameState.flags["oda_id/nesne_id"]` (`Room.flag_key()`); örnek `Collectible` (Kut parçası) bir kez alınır, bir daha doğmaz. Normal düşmanlar odaya her girişte yeniden doğar.
- **Harita:** MetSys yerine kendi ızgaramız (karar 2026-11-25). `MapService` oda sahnelerini örneklemeden `SceneState`'ten okur (hücre, boyut, Ocak, kapılar). `MapScreen` (Tab / Select) yalnızca ziyaret edilen odaları, kapı bağlantılarını, bulunulan odayı ve Ocak'ları çizer; açıkken oyun duraklar.

### Kayıt (GameState, `user://save_<yuva>.json`, sürüm 2)
| Ne zaman | Ne |
|---|---|
| Ocak'ta dinlenme | Tam kayıt + son Ocak (oda + kimlik) |
| Her kapı geçişi | Otomatik kayıt (ziyaret edilen odalar, bayraklar, mevcut oda) |
| Toplanabilir alınca | Otomatik kayıt |
| Geliştirici oda seçici (0–7) | **Kayıt yok** (`autosave_enabled = false`) |
İçerik: yetenekler, bayraklar, ziyaret edilen odalar, Kut/Öz, can, mevcut oda, son Ocak. Web'de `user://` tarayıcının IndexedDB'sidir. Testler 99 numaralı yuvayı kullanır. `to_dict()` bayrakların **kopyasını** döndürür (sıfırlama anlık görüntüyü bozmasın).

## Kodlama Kuralları
- Tanımlayıcılar **İngilizce** (`swing_angle`, `VineAnchor`), yorumlar ve dokümanlar **Türkçe**.
- Statik tipleme zorunlu (`var speed: float = 7.0`, fonksiyon dönüş tipleri).
- Ayarlanabilir sayılar `@export` ya da `Resource` (`PlayerTuning`) — sihirli sayı yok.
- Sahneler arası iletişim: yukarı sinyal, aşağı fonksiyon çağrısı; global olaylar `EventBus`.
- `class_name` her yeniden kullanılabilir bileşende.
- Dosya teslimi: değişen dosyalar **tam dosya** olarak yazılır (diff değil).

## Test
- `tests/` altında headless test sahneleri:
  | Sahne | Kapsam |
  |---|---|
  | `validate_scripts.tscn` | `scripts/` altındaki tüm .gd dosyaları derleniyor mu |
  | `test_movement.tscn` | M0 duman testi: koşma, zıplama, sallanma, mağara kamerası, güvenli nokta |
  | `test_m1.tscn` | Coyote, jump buffer, tırmanma, çürük sarmaşık, mükemmel bırakma + **bot ile 3 odanın geçilmesi** |
  | `test_m3.tscn` | Arka uç, mod geçişi (konum/FOV), geçiş yavaşlaması, girdi sürekliliği, SideRail (arka koridor + Z=0'a 0.4 sn), oda sınırları, look-ahead, ölü bölge, düşüşte dikey odak, **bot ile mağara odası** |
  | `test_m4.tscn` | Harita verisi (karşılıklı kapılar, çakışmayan hücreler, erişilebilirlik), yeni oyun, kapı geçişi (hız + kayıt), **tüm kapıların fiziksel varışı**, Ocak, ölümde son Ocak, kalıcı toplanabilir, kayıt turu, Devam, harita ekranı |
  | `test_m5.tscn` | Bölge verisi (13 oda, 2 Kut, yeteneksiz/yetenekli erişilebilirlik), kanca (yeteneksiz çalışmaz, hedef, ip), sunak, **botla**: Kanca Bahçesi, Ocak Odası tavanı, Çiçek Kuyusu (kancalı geçer / kancasız geçemez), derinlik sırrı → Gizli Oda; Öz + iyileşme |
  | `test_m6.tscn` | Boss: giriş (kart, kilit), çatlak uyarısı ≥ 0.4 sn, zayıf nokta, fırlama/süpürme (zıplayınca kaçılır), Faz 2 (Şişkin, sınır, tüm arena), kovalamaca (zemin ağızla çöker, değince hasar + fırlatma, ölüm yok), final, ödüller, hikaye, boss geri gelmez; **bot ile tam dövüş denemeleri** (`TRIALS=5`, `HIT_LOG=1`) |
  | `test_m2.tscn` | Kombo 1–1–2, kombo penceresi, yukarı vuruş, pogo, Savrulma Saldırısı, hit-stop, temas hasarı/dokunulmazlık/geri itilme, düşüş cezası, ölüm → oda başı, spor bulutu, **bot ile savaş odası** |
- Çalıştırma: `godot --headless --fixed-fps 60 --path . res://tests/<sahne>.tscn` → çıkış kodu 0, `SCRIPT ERROR` yok.
  `--fixed-fps 60` gerçek zaman senkronunu kapatır: testler saniyeler yerine anında biter, delta yine 1/60.
- **Tip tuzağı:** `Array[Node].filter(...)` türsüz `Array` döndürür → türlü değişkene atama SCRIPT ERROR; lambda içinde serbest bırakılmış nesneye dokunmak da hata. Elle döngüyle ayıkla.
- **Serbest bırakılmış düğüm tuzağı:** Ölüp `queue_free` olan düşmanın metodunu çağırmak (ör. `is_dead()`) motoru çökertir (signal 11) → önce `is_instance_valid()`.
- **Girdi simülasyonu tuzağı:** Godot 4.6'da `Input.action_press()` bir sonraki fizik karesinde "just pressed" olur; testte tuş en az 2–3 kare basılı tutulmalı.
- **Bot:** `test_m1.gd` içindeki bot yönü basılı tutar, kenarda/tırmanma sarmaşığı önünde zıplar, sallanırken salınım yönünde pompalar ve açı > 40° & ω > 0 iken bırakır. `BOT_ANGLE=50` ile bırakma açısı, `BOT_ONLY=1` ile yalnızca bot, `BOT_DEBUG=1` ile kare kare iz alınır.
- İki kamera arka ucu: `BAYTEREK_CAMERA_BACKEND=rig` ile tüm testler yedek blend'le de koşulur (milestone sonunda ikisi de yeşil olmalı).
- Her milestone sonunda web export alınır: `tools/deploy_web.sh "mesaj"` → `build/web/` → `gh-pages` dalı (main'e build girmez). Oynanabilir link: https://owalkerr.github.io/bayterek/

## Geliştirme Kısayolları (web test build'inde kalır)
| Tuş | İşlev |
|---|---|
| 0–7 | Greybox test odası seç (Kök Ağzı, Savrulma Zinciri, Tırmanma Kuyusu, Çürük Geçit, Çürük Yuvası, Yankı Mağarası, **6 Kökyiyen Eşiği**, **7 Kökyiyen'in İni**). 6–7 Kamçı Kancası'nı verir ve boss bayrağını sıfırlar (her seferinde yeniden dövüş) |
| R | Odayı baştan başlat |
| F1 | Debug bilgisi (durum, konum, coyote/buffer, θ/ω/L, mükemmel pencere) |
| F2 | Canlı tuning paneli (kaydırıcılar, "Kopyala" → .tres metni) |

## Greybox Oda Altyapısı (M1)
- `scripts/world/greybox_level.gd` (main.tscn kökü): ortam, oyuncu, CameraRig, HUD'lar, harita; SceneRouter host'u (`swap_room`, `place_player`); menü akışı (`new_game`, `continue_game`, geliştirici `load_room(i)`).
- `scripts/world/greybox_room.gd` (`GreyboxRoom`): kodla oda kurma yardımcıları (`box`, `platform`, `vine`, `rotten_vine`, `climb_vine`, `crawler`, `bloater`, `glow`, `place_goal`, `camera_zone`, `side_rail`) + kamera sınırı (`bounds`, otomatik `compute_bounds()`).
- `scripts/world/rooms/room_XX_*.gd`: odaların geometrisi; kimlik/kapılar .tscn'de. M1–M3 test odalarında `RoomGoal` kristali (botlar ve oda süresi için) kalır.
- `scripts/ui/`: `DebugHud`, `TuningPanel`, `UiStyle` (docs/08 paleti). `scripts/fx/`: `ReleaseSpark`.

## Performans Bütçesi (PC orta seviye / web)
| Kalem | PC | Web |
|---|---|---|
| Ekrandaki üçgen | ≤ 800k | ≤ 250k |
| Draw call | ≤ 1500 | ≤ 400 |
| Gerçek zamanlı gölgeli ışık | 1 yönlü + 4 omni | 1 yönlü |
| Hedef FPS | 60 | 60 (30 kabul) |
