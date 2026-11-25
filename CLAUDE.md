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
- Kamera ile doğrudan değil `CameraDirector` API'si ile konuşulur.
- Global olaylar `EventBus` üzerinden; kalıcı durum `GameState` içinde.
- Kullanıcının bilgisayarına bir şey kurulamaz; testler bulutta headless, oynanış testleri web build ile.

## Komutlar
```bash
# Kurulum (oturum başına bir kez)
cd /tmp && curl -sSL -o godot.zip https://github.com/godotengine/godot/releases/download/4.6.3-stable/Godot_v4.6.3-stable_linux.x86_64.zip \
  && unzip -o -q godot.zip && mv Godot_v4.6.3-stable_linux.x86_64 /usr/local/bin/godot

godot --headless --path . --import                              # .godot/ + sınıf önbelleği
godot --headless --path . res://tests/validate_scripts.tscn     # tüm scriptler derleniyor mu
godot --headless --path . res://tests/test_movement.tscn        # hareket/sallanma/kamera duman testi
```
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
- Kullanıcıya kısa rapor: ne yapıldı, nasıl test edildi, sıradaki adım.
