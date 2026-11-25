---
name: bayterek-dev
description: Use when working on the BAYTEREK Godot 4.6 project (2.5D vertical metroidvania with vine swinging and 3D cave camera): session start, rules, tests, docs to update.
---

# BAYTEREK geliştirme skill'i

## 1. Oturum başlangıcı
1. `CLAUDE.md` ve `docs/09_ROADMAP.md` oku → aktif milestone.
2. Godot 4.6.3'ü kur (CLAUDE.md'deki komut), `--import` çalıştır.
3. `validate_scripts.tscn` ve `test_movement.tscn` çalıştır; ikisi de çıkış 0 vermeli.
4. Kullanıcıya tek satırda durumu söyle: "M_x aktif, testler yeşil/kırmızı."

## 2. Yeni özellik eklerken
- Önce ilgili dokümandaki tasarım ve sayıları oku; doküman yoksa/eksikse **önce tasarımı kullanıcıyla netleştir**, sonra dokümana yaz, sonra kodla.
- Yeni dünya bileşeni → `scripts/world/` + `class_name` + grup adı sabiti (`const GROUP`).
- Yeni oyuncu yeteneği → `GameState.ABILITIES` listesine id, `has_ability()` kontrolü, docs/03 tablosu.
- Yeni ayarlanabilir sayı → `PlayerTuning` veya `@export`, docs/03 tablosu.
- Kamera davranışı → yalnızca `CameraRig` / `CameraDirector`.
- Her özellik için `tests/` altına en az bir headless kontrol ekle (sahne + script, `[TEST] OK/FAIL` çıktısı, hata varsa `quit(1)`).

## 3. Hareket hissi işleri (M1)
- Sallanma: kinematik sarkaç; tutunurken hız → açısal hız; bırakırken teğet hız × boost (+ zıplama bonusu).
- Oynanabilirliği bot ile doğrula: bot sağa basılı tutar, açı > 40° ve ω > 0 iken zıplar; hedef platforma ulaşıyor mu?
- Oda geometrisi ölçekleri: docs/02 §Oda Tasarım Kuralları.

## 4. Sanat entegrasyonu
- docs/07 kontrol listesi: 1 birim = 1 m, origin ayak tabanı, +Z'ye bakış, bütçe.
- Mixamo retarget: BoneMap + SkeletonProfileHumanoid, ortak `bonemap_mixamo.tres`.
- Model `Player/Visual` altına; kapsül görseli kaldırılır, çarpışma kapsülü kalır.

## 5. Bilinen tuzaklar
- `godot --check-only -s` autoload'ları tanımaz → validator sahnesini kullan.
- Işınlanma sonrası `is_on_floor()` bayattır; güvenli nokta yalnızca `move_and_slide()` sonrası güncellenir.
- Kapanışta Area3D `body_exited` tetiklenir; ağaçtan çıkmış düğümlere dokunmadan önce `is_inside_tree()` / `is_instance_valid()`.
- Yan mod ile derinlik zemini arasında boşluk bırakma (oyuncu araya düşer) — mağara zemini ana zeminle birleşik olmalı.
- Web build: GDExtension/thread yok; Forward+'a özel efektleri "yüksek kalite" ayarı arkasında tut.

## 6. Bitiş raporu (Türkçe, kısa)
```
✅ Yapılan: …
🧪 Test: validate (N/N), movement (N/N), + yeni testler
📄 Güncellenen dokümanlar: …
➡️ Sıradaki: …
```
