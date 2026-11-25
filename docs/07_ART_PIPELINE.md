# Sanat Üretim Hattı (AI 3D → Godot)

> Amaç: AI ile üretilen modellerin **tutarlı tek bir sanat stili** gibi görünmesi. Bunun anahtarı: sabit ölçek kuralları + ortak stilize shader + kısıtlı renk paleti.

## Genel Akış
```
1. Konsept görsel  ─►  2. Görselden 3D  ─►  3. Blender temizlik  ─►  4. Rig  ─►  5. Animasyon  ─►  6. Godot import
 (Gemini/MJ vb.)      (Meshy/Tripo/         (ölçek, origin,           (Mixamo)    (Mixamo FBX)     (BoneMap retarget,
                       Hunyuan3D/Rodin)       decimate, UV)                                          stilize materyal)
```

## 1. Konsept Görsel
- Her model için **tek nesne, düz arka plan, ön veya 3/4 görünüm, T-poz/A-poz** (karakterler için).
- Stil anahtar sözcükleri (prompt'lara sabit eklenir):
  `stylized, hand-painted textures, soft shapes, slightly exaggerated proportions, Ori and the Blind Forest meets Hollow Knight, mythic Turkic ornament details, clean silhouette`
- Renk paleti (bkz. 08_UI_UX.md) prompt'a verilir.

## 2. Görselden 3D
- Araç seçimi serbest (Meshy, Tripo, Hunyuan3D, Rodin…). Öneri: karakterler için **topoloji/rig desteği** iyi olan aracı, prop'lar için en hızlısını kullan.
- Dışa aktar: **GLB** (doku gömülü) — prop'lar için doğrudan Godot'a; karakterler için Blender'a.

## 3. Blender Temizlik (kontrol listesi)
- [ ] Ölçek: **1 birim = 1 m**. Alpay 1.6 m, Kocabaş ~3 m, Kökyiyen 12–15 m.
- [ ] Origin: karakterlerde **ayak tabanı ortası**, prop'larda tabanın ortası.
- [ ] Yön: karakter **+Z'ye bakar** (Mixamo ve Godot import uyumu).
- [ ] Transform uygula (Ctrl+A → All Transforms).
- [ ] Üçgen bütçesine indir (Decimate): aşağıdaki tablo.
- [ ] Tek materyal hedefi (gerekirse doku atlası).
- [ ] Gereksiz iç yüzleri/yüzen parçaları sil.
- [ ] Çevre parçaları **modüler**: 1, 2, 4 m ızgaraya oturan kök/kaya/dal parçaları.

| Tür | Üçgen | Doku |
|---|---|---|
| Alpay (kahraman) | 15–25k | 2048 |
| Boss | 30–60k | 2048 |
| Düşman | 5–15k | 1024 |
| NPC | 8–15k | 1024 |
| Prop | 0.5–5k | 512–1024 |
| Modüler çevre parçası | 1–8k | 1024 (atlas) |

## 4. Rig
- **İnsansı (Alpay, NPC'ler, Kam Ana, Tüykes):** [Mixamo](https://www.mixamo.com) otomatik rig. FBX yükle → işaretçileri yerleştir → "With Skin" indir.
- **İnsansı olmayan (kaplumbağa, solucan, kuş, çiçek):**
  - Önce AI aracının otomatik rig özelliğini dene (dört ayaklı vb.).
  - Olmazsa Blender'da basit kemik zinciri (solucan/çiçek için 6–12 kemiklik zincir yeterli).
  - Çok basit yaratıklar (spor şişkini) kemiksiz: Godot'da tween/shader ile canlandırma (nefes, sallanma).

## 5. Animasyon
- Mixamo'dan animasyonları **"Without Skin"** FBX olarak indir (karakter başına tek skin + N animasyon).
- Alpay için minimum liste (dikey dilim):
  `idle, run, jump_up, fall, land, swing_hang (loop), swing_forward/back, climb_up/down, whip_attack_1/2/3, whip_up, whip_down, hurt, death, heal`
  Sallanma/kamçı Mixamo'da tam karşılığı yoksa: en yakın (ör. "Hanging Idle", "Sword Slash") + Godot'da kemik ofsetleri veya Blender'da düzenleme.
- **Kök hareket (root motion) kapalı** — hareketi kod yönetir.

## 6. Godot Import
1. FBX/GLB'yi `assets/models/...` altına koy.
2. Advanced Import → Skeleton3D → **Retarget → BoneMap → SkeletonProfileHumanoid** (bütün kemikler yeşil olmalı). BoneMap'i `assets/animations/bonemap_mixamo.tres` olarak kaydet ve her dosyada yeniden kullan.
3. Animasyon dosyalarını **Animation Library** olarak import et → karakterin `AnimationPlayer`'ına ekle.
4. Hızlandırıcı: [MixaBridge](https://godotengine.org/asset-library/asset/5096) eklentisi (Godot 4.4+) bu adımları otomatikleştirir — çok sayıda klipte kullan.
5. Model sahnesi "inherited scene" olarak açılır, `Visual` düğümü altına `player.tscn` içine yerleştirilir.
6. Materyal: AI dokusu **ortak stilize shader'a** bağlanır (`assets/shaders/stylized_lit.gdshader` — M7):
   - 3 basamaklı ışık rampası (toon), yumuşak kenar ışığı (rim light), palet tonlama (doygunluğu bölge paletine çeker). Bu, farklı AI çıktılarını aynı aileye sokar.

## İsimlendirme
- Dosya: `kind_name_variant` → `char_alpay.glb`, `enm_spore_puffer.glb`, `env_root_arch_4m_a.glb`, `prop_ocak.glb`, `anim_alpay_run.fbx`.
- Godot düğümleri PascalCase, dosyalar snake_case.

## Klasör
```
assets/models/characters/alpay/char_alpay.glb
assets/models/characters/alpay/anims/anim_alpay_*.fbx
assets/models/enemies/  environment/kok_dibi/  props/
```

## Kalite Kontrol (her model için)
- [ ] Oyun kamerasından (14 m, FOV 40) siluet okunuyor mu?
- [ ] Bölge paletine uyuyor mu (stilize shader ile)?
- [ ] Üçgen/doku bütçesi içinde mi?
- [ ] Web build'de görünüm kabul edilebilir mi?
