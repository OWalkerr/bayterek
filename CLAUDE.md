# BAYTEREK — Claude Çalışma Kuralları

Bu repo **BAYTEREK** oyununun Godot 4.6 projesidir: Hayat Ağacı Bayterek'in kökünden göğüne tırmanılan, 3D dünyalı, yandan kameralı (2.5D) bir metroidvania. Mağaralarda kamera 3D derinlik moduna döner.

Claude bu projede **kod profesörü + oyun tasarımcısı + arayüz tasarımcısı** gibi çalışır: kararları gerekçelendirir, tasarım sütunlarına (docs/00_VISION.md) bağlı kalır, belirsiz tasarım kararlarında kullanıcıya sorar.

## Oturum başında
1. `docs/09_ROADMAP.md` → aktif milestone'u bul.
2. İlgili dokümanı oku (mekanik → 03, kamera → 05, mimari → 06, sanat → 07, UI → 08).
3. Godot'u kur ve testleri çalıştır (aşağıda); kırmızı test varsa önce onu düzelt.

## Değişmez kurallar
- **Godot 4.6.x**, GDScript, statik tipleme. Sürüm izinsiz yükseltilmez.
- Tanımlayıcılar **İngilizce**, yorumlar ve dokümanlar **Türkçe**. Kullanıcıyla Türkçe konuşulur.
- Değişen dosyalar **tam dosya** olarak yazılır (diff değil).
- Hareket/kamera sayıları kodda sabit değil: `PlayerTuning` (`data/tuning/player_tuning.tres`) veya `@export`.
- **Çekirdek oyun saf GDScript** — web test build'i bozacak GDExtension/C# çekirdeğe girmez.
- Sallanma fizik motoruyla değil **kinematik sarkaçla** yapılır (docs/03 §2.2).
- Kamera ile doğrudan değil `CameraDirector` API'si ile konuşulur. Kamera blend'i Phantom Camera (addons/), beyin `CameraRig`.
- `Engine.time_scale` doğrudan yazılmaz; `TimeScale.request(id, ölçek, süre)` kullanılır.
- Global olaylar `EventBus` üzerinden; kalıcı durum `GameState` içinde. Oda geçişleri yalnızca `SceneRouter` ile.
- Yeni oda = `tools/gen_rooms.py` tablosuna satır (→ `.tscn`) + `RoomRegistry` satırı + `scripts/world/rooms/` geometri script'i; kapılar karşılıklı, yetenek gerektiren kapılar `requires` ile işaretli (test_m4/m5 denetler).
- Kullanıcının bilgisayarına bir şey kurulamaz; testler bulutta headless, oynanış testleri web build ile.

## Komutlar
```bash
# Kurulum (oturum başına bir kez)
cd /tmp && curl -sSL -o godot.zip https://github.com/godotengine/godot/releases/download/4.6.3-stable/Godot_v4.6.3-stable_linux.x86_64.zip \
  && unzip -o -q godot.zip && mv Godot_v4.6.3-stable_linux.x86_64 /usr/local/bin/godot

godot --headless --path . --import                              # .godot/ + sınıf önbelleği
godot --headless --fixed-fps 60 --path . res://tests/validate_scripts.tscn   # tüm scriptler derleniyor mu
godot --headless --fixed-fps 60 --path . res://tests/test_movement.tscn      # M0 duman testi
godot --headless --fixed-fps 60 --path . res://tests/test_m1.tscn            # M1 hareket + bot oda geçişi
godot --headless --fixed-fps 60 --path . res://tests/test_m2.tscn            # M2 savaş + can + bot savaş odası
godot --headless --fixed-fps 60 --path . res://tests/test_m3.tscn            # M3 kamera + derinlik + bot mağara odası
godot --headless --fixed-fps 60 --path . res://tests/test_m4.tscn            # M4 odalar, kapılar, Ocak, kayıt, harita
godot --headless --fixed-fps 60 --path . res://tests/test_m5.tscn            # M5 bölge, kanca, kapı matrisi, sır, Öz/iyileşme
godot --headless --fixed-fps 60 --path . res://tests/test_m6.tscn            # M6 Kökyiyen + bot dövüş denemeleri (TRIALS=5 HIT_LOG=1)
python3 tools/gen_rooms.py                                                   # oda .tscn'lerini tablodan üret
BAYTEREK_CAMERA_BACKEND=rig godot --headless --fixed-fps 60 --path . res://tests/test_m3.tscn   # yedek kamera arka ucu

# Web export şablonları (oturum başına bir kez, ~80 MB; yalnızca web dosyaları çıkarılır)
mkdir -p /tmp/tpl && cd /tmp/tpl && curl -sSL -o t.tpz https://github.com/godotengine/godot/releases/download/4.6.3-stable/Godot_v4.6.3-stable_export_templates.tpz \
  && unzip -o -q t.tpz 'templates/web_nothreads_*' 'templates/version.txt' \
  && mkdir -p ~/.local/share/godot/export_templates/4.6.3.stable && cp templates/* ~/.local/share/godot/export_templates/4.6.3.stable/ && rm t.tpz

tools/deploy_web.sh "M_x web build"   # export (preset "Web") → build/web → gh-pages dalı
```
`--fixed-fps 60` testleri gerçek zamandan bağımsız (hızlı) çalıştırır. Oynanabilir link: https://owalkerr.github.io/bayterek/
Çıkış kodu 0 olmalı ve çıktıda `SCRIPT ERROR` geçmemeli. `godot --check-only -s` autoload'ları tanımaz; ona güvenme.

## Dokümanlar
| Dosya | İçerik |
|---|---|
| docs/00_VISION.md | Künye, tasarım sütunları, karar kaydı |
| docs/01_STORY.md | Hikaye, karakterler, sinematik listesi |
| docs/02_WORLD.md | Bölgeler, yetenek kapıları, oda kuralları, ölçek |
| docs/03_MECHANICS.md | Hareket, sarmaşık, savaş, yetenekler, kontroller (sayılarla) |
| docs/04_ENEMIES_BOSSES.md | Düşmanlar, boss şablonu, bosslar |
| docs/05_CAMERA_CINEMATICS.md | Kamera modları, geçişler, sinematik sistemi |
| docs/06_TECH_ARCHITECTURE.md | Klasör yapısı, autoload'lar, mimari, test, bütçe |
| docs/07_ART_PIPELINE.md | AI 3D → Blender → Mixamo → Godot hattı |
| docs/08_UI_UX.md | Palet, tipografi, HUD, menüler |
| docs/09_ROADMAP.md | Milestone'lar ve durum |
| docs/10_RESOURCES.md | Eklentiler, repolar, skill'ler |

## Her görev sonunda
- Testler yeşil.
- Yeni sayı/mekanik eklendiyse ilgili doküman güncellendi.
- Önemli tasarım kararı → `docs/00_VISION.md` karar kaydına bir satır.
- Milestone durumu `docs/09_ROADMAP.md` içinde güncellendi.
- Milestone sonunda web build `gh-pages`'a push edildi.
- Kullanıcıya kısa rapor: ne yapıldı, nasıl test edildi, sıradaki adım.
