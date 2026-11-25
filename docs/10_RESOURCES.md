# Kaynaklar: Eklentiler, Repolar, Skill'ler

## Kullanılacak Eklentiler (öncelik sırası)
| Eklenti | Repo | Ne için | Ne zaman | Web uyumu |
|---|---|---|---|---|
| **Dialogue Manager 3** | https://github.com/nathanhoad/godot_dialogue_manager | Diyalog + sinematik betikleri. v3.x Godot 4.4+; v4 Godot 4.6+ için (yayın durumu kontrol edilmeli) | M8 | ✅ GDScript |
| **Phantom Camera** | https://github.com/ramokz/phantom-camera | Cinemachine benzeri 2D/3D kamera, öncelik + tween geçiş | M3 (değerlendirme) | ✅ GDScript |
| **MixaBridge** | https://godotengine.org/asset-library/asset/5096 | Mixamo animasyon retarget otomasyonu (editör eklentisi) | M7 | Editör-only |
| **Metroidvania System (MetSys)** | https://github.com/KoBeWi/Metroidvania-System | Harita editörü, oda geçişi, kayıt | M4 (değerlendirme; 2D odaklı) | ✅ GDScript |
| **LimboAI** | https://github.com/limbonaut/limboai | Davranış ağacı + HSM (boss AI). Godot 4.6+ sürümü var | Opsiyonel | ⚠️ GDExtension — web build'i doğrulanmalı |

## İncelenecek Örnek Repolar (kod okumak için)
| Repo | Neden |
|---|---|
| https://github.com/bennbollay/godot-rope | Fizik tabanlı 2D ip örnekleri (görsel sarmaşık için) |
| https://github.com/mphe/gdnative-ropesim | Verlet ip simülasyonu (görsel sarmaşık sallanması) |
| https://github.com/Elij4hMartin/Godot4-PinJoint-RopePhysics | 3D PinJoint ip, Path3D geometri |
| https://github.com/JPTeasdale/VineClimber | Sarmaşık tırmanma oyunu örneği |
| https://github.com/quiver-dev/template-beat-em-up | Godot 4 düzenli dövüş/durum makinesi mimarisi |
| https://github.com/Maaack/Godot-Game-Template | Menü, ayarlar, sahne yükleyici şablonu (M9'da UI için) |

> **Not:** Sarmaşık *oynanışı* kendi kinematik sarkaç kodumuzla; ip kütüphaneleri sadece **görsel** sarmaşığın sallanması için.

## Claude Skill'leri
| Skill | Kaynak | Kullanım |
|---|---|---|
| `bayterek-dev` | Bu repo: `.claude/skills/bayterek-dev/SKILL.md` | Oturum başı tarama, kurallar, test komutları, doküman güncelleme |
| `godot-genre-metroidvania` | https://github.com/thedivergentai/game-dev-agentic-skills — `npx skills add https://github.com/thedivergentai/game-dev-agentic-skills --skill godot-genre-metroidvania` | Metroidvania anti-pattern listesi (soft-lock, boş çıkmaz sokak, kaydedilmeyen oda durumu) |
| `godot-headless-test` | Hesaptaki mevcut skill | Bulutta Godot kurulumu + headless test |

## Dokümantasyon
- Godot 4.6 belgeleri: https://docs.godotengine.org/en/4.6/
- 3D iskelet retarget: https://docs.godotengine.org/en/4.6/tutorials/assets_pipeline/retargeting_3d_skeletons.html
- Web export: https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_web.html
