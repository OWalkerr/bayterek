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
6. Materyal: AI dokusu **ortak stilize shader'a** bağlanır (`assets/shaders/stylized_lit.gdshader` — ✅ M7):
   - 3 basamaklı ışık rampası (toon), yumuşak kenar ışığı (rim light), palet tonlama (doygunluğu bölge paletine çeker). Bu, farklı AI çıktılarını aynı aileye sokar.
   - **Elle bağlamak gerekmez:** `Stylizer.apply(düğüm)` çalışma zamanında her opak StandardMaterial3D'yi (GLB'nin kendi materyali dahil) stilize shader'a çevirir; albedo dokusu ve ışıma korunur. Odalar, oyuncu ve düşmanlar otomatik geçer.
   - Bölge tonları `RegionPalette` (`data/art/palette_kok_dibi.tres`): gölge moru, palet tonu, kenar ışığı, gökyüzü, sis, güneş. Ortam `RegionEnvironment` ile aynı paletten kurulur (web: 1 gölgeli yönlü ışık; Forward+: + SSAO + hacimsel sis).
   - Rengi çalışma zamanında değişen materyaller `set_meta("no_stylize", true)` ile hariç tutulur; saydam/gölgesiz efektler zaten çevrilmez.

## 7. AI aracı seçimi ve üretim şablonları (M7)

### Önerilen araç (karar 2026-11-25)
| Araç | Ne için | Neden |
|---|---|---|
| **Tripo** (ana araç) | Düşmanlar, Kocabaş, Kökyiyen, prop'lar, çevre parçaları | İnsansı olmayan iskeletler (dört ayaklı, yılan/solucan, kuş) için otomatik rig; **Smart Mesh** ile hedef üçgen sayısı seçilebiliyor (bütçemize birebir); animasyon için quad topoloji |
| **Meshy** (Alpay için karşılaştırma) | Alpay (insansı) | **Mixamo uyumlu iskelet şablonu** → hattımız (BoneMap + SkeletonProfileHumanoid) doğrudan çalışır |
| Rodin | İsteğe bağlı: çok detaylı prop | Detay iyi; otomatik rig 2026 ortasında hâlâ yoktu |
| Hunyuan3D | — | Açık kaynak ama yerel kurulum ister (kullanıcı makinesine kurulum yok) |
- **Lisans:** Steam için **ücretli plan** şart (Meshy ücretsiz plan = CC BY 4.0, atıf zorunlu; ücretli planda model sizin). Tripo'nun plan koşulunu satın almadan önce kontrol et.
- **İlk adım = kıyas:** Alpay'ı iki araçta da üret → ikisini repoya yükle → `model_check` ölçer → kararı sayılarla ver.
- Stil tutarlılığını **araç değil ortak shader** sağlar (`stylized_lit`); yine de bölge başına tek araç tercih et.

### Üretim akışı (her model)
1. **Konsept görsel** (Gemini / Midjourney / ChatGPT görsel): aşağıdaki prompt + sabit stil eki. Tek nesne, düz gri arka plan, karakterlerde **T-poz / A-poz**, önden veya 3/4.
2. **Görselden 3D** (Tripo "Image to 3D" önerilir — metinden daha tutarlı):
   - Topoloji: **Quad** (animasyonlu) / Triangle (statik prop)
   - Smart Mesh / Face limit: tablodaki üçgen hedefi
   - Doku: 1024 (düşman/prop) · 2048 (Alpay, boss)
   - Rig: tablodaki iskelet türü (Alpay: Meshy'de "Mixamo" şablonu ya da rigsiz indir → Mixamo)
   - Dışa aktar: **GLB** (doku gömülü)
3. **Adlandır:** `char_alpay.glb`, `enm_rot_crawler.glb` … (aşağıdaki "İsimlendirme"). Önek zorunlu — `model_check` türü ve bütçeyi bundan okur.
4. **Yükle:** GitHub'da repo → `assets/models/<klasör>/` → *Add file → Upload files* → *Commit changes* (dosya başına ≤ 25 MB; daha büyükse dokuyu 1024'e indir).
5. Bana "yükledim" de: `model_check` çalışır (ölçek 1 m, orijin ayak tabanı, +Z bakış, üçgen/doku bütçesi, Mixamo kemikleri). Hata varsa hangi adımda düzeltileceğini söylerim (çoğu Tripo/Meshy ayarı ya da Blender'da tek tık: ölçek / Apply Transforms / 180° döndür).

### Sabit stil eki (her konsept prompt'unun sonuna)
```
stylized, hand-painted textures, soft rounded shapes, slightly exaggerated proportions,
Ori and the Blind Forest meets Hollow Knight, mythic Turkic ornament details, clean readable silhouette,
limited palette: deep root purple #2B1E3F, mushroom teal #4FB3A9, sap gold #E8A33D, moss green #5E8C4A,
single object, centered, plain neutral grey background, full body, no shadow on ground
```

### Model listesi (dikey dilim) ve prompt'lar
| Dosya | Klasör | Boy | Üçgen hedefi | Doku | Rig | Konsept prompt (İngilizce, araçlar daha iyi anlar) |
|---|---|---|---|---|---|---|
| `char_alpay.glb` | characters/alpay | 1.6 m | 20k | 2048 | İnsansı (Mixamo) | `teenage boy, 16 years old, lean and agile, barefoot, clothes woven from roots and leaves, a silver feather necklace glowing softly, living vine whip coiled on his shoulder, wild dark hair, A-pose, front view` |
| `npc_kocabas.glb` | characters/kocabas | ~3 m | 12k | 1024 | Dört ayaklı | `giant ancient root turtle, wise and gentle, mossy shell overgrown with roots and tiny glowing mushrooms, long neck, kind old eyes, slow and heavy, side 3/4 view` |
| `enm_rot_crawler.glb` | enemies | 0.6 m | 8k | 1024 | Dört ayaklı (alçak) | `small corrupted root lizard, low crawling body, purple rot veins, glowing sickly yellow eyes, bark-like scales, menacing but readable, side 3/4 view` |
| `enm_spore_bloater.glb` | enemies | 1 m | 5k | 1024 | **Rigsiz** (shader ile nefes) | `floating bloated spore sac creature, round translucent purple membrane, glowing yellow spore spots, small dangling tendrils, cute but dangerous` |
| `enm_trap_flower.glb` | enemies | 1.5 m | 8k | 1024 | Zincir / Tripo otomatik | `carnivorous trap flower hanging from a ceiling root, disguised as a vine, hidden jaws of petals, purple rot, yellow eye in the center` |
| `enm_root_snake.glb` | enemies | 3 m uzunluk | 8k | 1024 | Yılan | `root serpent bursting from a wall hole, body made of twisted roots, rot-purple glow between the roots, yellow eyes, snake-like` |
| `boss_kokyiyen.glb` | bosses | 13.5 m | 45k | 2048 | Yılan / solucan zinciri | `colossal root-eating worm boss, segmented body of fused roots and rot, huge circular maw ringed with root teeth, glowing yellow rot sacs on its back, intimidating, side view` |
| `prop_ocak.glb` | props | 1 m | 2k | 1024 | — | `small sacred stone hearth with a warm golden fire, Turkic carved stones in a ring, cozy save point` |
| `prop_grapple_flower.glb` | props | 0.8 m | 1.5k | 512 | — | `glowing teal grapple flower bud hanging from a root, ring of petals, magical hook point` |
| `env_root_arch_4m_a.glb` | environment/kok_dibi | 4 m | 4k | 1024 (atlas) | — | `modular root arch, thick twisted tree roots forming an arch, mossy, fits a 4 meter grid` |
| `env_root_platform_4m_a.glb` | environment/kok_dibi | 1 m kalınlık | 3k | 1024 (atlas) | — | `modular flat-topped root platform 4 meters wide, mossy top surface, roots hanging below` |
| `env_rock_2m_a.glb` | environment/kok_dibi | 2 m | 1.5k | 1024 (atlas) | — | `mossy cave rock, rounded stylized boulder, purple shadows, glowing mushrooms` |

**Animasyonlar (Alpay, Mixamo "Without Skin"):** `PlayerAnimator` mantıksal adları → Mixamo klip eşlemesi `clip_map` ile yapılır. Önerilen klipler: idle → "Idle", run → "Running", jump_up → "Jump", fall → "Falling Idle", land → "Landing", swing → "Hanging Idle", climb_up → "Climbing Ladder", whip_attack_1/2/3 → "Sword And Shield Slash" (3 farklı), whip_up/down, hurt → "Hit Reaction", heal → "Praying"/"Crouch Idle", death → "Dying".

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
Otomatik: `godot --headless --path . --import && godot --headless --path . res://tests/model_check.tscn` (`ModelValidator`: tür öneki, üçgen/doku bütçesi, materyal ≤ 2, orijin ayak tabanı ortası, beklenen boy, insansıda Mixamo kemikleri ve +Z bakış). Elle:
- [ ] Oyun kamerasından (14 m, FOV 40) siluet okunuyor mu?
- [ ] Bölge paletine uyuyor mu (stilize shader ile)?
- [ ] Üçgen/doku bütçesi içinde mi?
- [ ] Web build'de görünüm kabul edilebilir mi?
