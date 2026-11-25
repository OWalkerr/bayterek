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
│   ├── player/  camera/  world/{rooms}/  enemies/  ui/  fx/
│   └── core/                # StateMachine, utilities
├── tests/                   # headless test sahneleri
└── tools/                   # deploy_web.sh (gh-pages)
```

## Autoload'lar (singleton)
| Ad | Görev |
|---|---|
| `EventBus` | Global sinyaller (oyuncu öldü, yetenek kazanıldı, oda değişti, kamera modu…) |
| `GameState` | Yetenekler, bayraklar (flags), toplanabilirler, kayıt/yükleme (JSON, `user://save_X.json`) |
| `SceneRouter` | Oda yükleme/boşaltma, kapı geçişleri, ResourceLoader ile arka planda (threaded) yükleme |
| `CameraDirector` | Aktif kamera modu, geçişler; CameraRig'i yönetir |
| `CutsceneDirector` | Sinematik oynatma, giriş kilitleme, letterbox |
| `AudioDirector` | Bölge müziği katmanları, crossfade, SFX havuzu |
| `Settings` | Grafik, ses, kontrol ayarları (`user://settings.cfg`) |

> Prototipte `EventBus`, `GameState`, `CameraDirector` hazır; diğerleri M2–M6 arasında eklenir.

## Oyuncu Mimarisi
```
Player (CharacterBody3D)  ── player.gd
├── Visual (Node3D)        # AI model + AnimationTree buraya
├── CollisionShape3D       # Kapsül r=0.35 h=1.6
├── GrabArea (Area3D)      # Sarmaşık algılama
├── WhipHitbox (Area3D)    # Kamçı vuruşu (M2)
└── StateMachine           # (M2'de ayrı düğümlere bölünecek)
```
Durumlar: `GROUND`, `AIR`, `SWING`, `CLIMB`, `WALL` (M3+), `HURT`, `DEAD`, `CINEMATIC`.

Prototipte durumlar tek dosyada (`player.gd`, enum + match). Dosya 400 satırı geçince `scripts/player/states/*.gd` olarak bölünür.

## Oda (Room) Sistemi
- Her oda ayrı `.tscn`; kök düğüm `Room` (`room.gd`): `room_id`, `bounds: AABB`, `region`, `map_cell: Vector2i`.
- Kapılar `RoomDoor` (Area3D): hedef oda + hedef kapı id.
- Odalar arası geçiş: kısa karartma (0.25 sn), yeni oda arka planda yüklenir, oyuncu hedef kapıya konur.
- Harita: Metroidvania harita verisi `map_cell` ile üretilir. [MetSys](https://github.com/KoBeWi/Metroidvania-System) 2D sahne odaklı olduğu için M4'te değerlendirilecek; uymazsa `Vector2i` grid tabanlı kendi `MapService`'imiz.
- Oda durumu (kırılan duvar, açılan kapı, alınan eşya) `GameState.flags["room_id/obj_id"]` olarak kalıcı.

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
- Çalıştırma: `godot --headless --fixed-fps 60 --path . res://tests/<sahne>.tscn` → çıkış kodu 0, `SCRIPT ERROR` yok.
  `--fixed-fps 60` gerçek zaman senkronunu kapatır: testler saniyeler yerine anında biter, delta yine 1/60.
- **Girdi simülasyonu tuzağı:** Godot 4.6'da `Input.action_press()` bir sonraki fizik karesinde "just pressed" olur; testte tuş en az 2–3 kare basılı tutulmalı.
- **Bot:** `test_m1.gd` içindeki bot yönü basılı tutar, kenarda/tırmanma sarmaşığı önünde zıplar, sallanırken salınım yönünde pompalar ve açı > 40° & ω > 0 iken bırakır. `BOT_ANGLE=50` ile bırakma açısı, `BOT_ONLY=1` ile yalnızca bot, `BOT_DEBUG=1` ile kare kare iz alınır.
- Her milestone sonunda web export alınır: `tools/deploy_web.sh "mesaj"` → `build/web/` → `gh-pages` dalı (main'e build girmez). Oynanabilir link: https://owalkerr.github.io/bayterek/

## Geliştirme Kısayolları (M1–M3, M4'te kalkar)
| Tuş | İşlev |
|---|---|
| 0–3 | Greybox test odası seç (Kök Ağzı, Savrulma Zinciri, Tırmanma Kuyusu, Çürük Geçit) |
| R | Odayı baştan başlat |
| F1 | Debug bilgisi (durum, konum, coyote/buffer, θ/ω/L, mükemmel pencere) |
| F2 | Canlı tuning paneli (kaydırıcılar, "Kopyala" → .tres metni) |

## Greybox Oda Altyapısı (M1)
- `scripts/world/greybox_level.gd` (main.tscn kökü): ortam, oyuncu, CameraRig, DebugHud ve oda yükleyici (`load_room(i)`).
- `scripts/world/greybox_room.gd` (`GreyboxRoom`): kodla oda kurma yardımcıları (`box`, `platform`, `vine`, `rotten_vine`, `climb_vine`, `glow`, `place_goal`, `camera_zone`).
- `scripts/world/rooms/room_XX_*.gd`: test odaları. Her oda `room_id`, `display_name`, `idea` ("bir oda = bir fikir"), `spawn_point` ve bir `RoomGoal` tanımlar.
- `scripts/ui/`: `DebugHud`, `TuningPanel`, `UiStyle` (docs/08 paleti). `scripts/fx/`: `ReleaseSpark`.

## Performans Bütçesi (PC orta seviye / web)
| Kalem | PC | Web |
|---|---|---|
| Ekrandaki üçgen | ≤ 800k | ≤ 250k |
| Draw call | ≤ 1500 | ≤ 400 |
| Gerçek zamanlı gölgeli ışık | 1 yönlü + 4 omni | 1 yönlü |
| Hedef FPS | 60 | 60 (30 kabul) |
