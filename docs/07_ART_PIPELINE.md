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

### Tripo çıktısı — bilinen durumlar (Alpay'dan öğrenilen, 2026-11-25)
- **Ölçek:** Tripo modeli **1 birim yüksekliğe normalize** ederek dışa aktarır → Godot'da `.glb.import` içinde `nodes/root_scale` = gerçek boy (Alpay: **1.6**). Blender gerekmez; `model_check` boyu doğrular.
- **Yön:** iskelet −90° döndürülmüş bir ara düğümün (`node_0`) altında; sonuç +Z'ye bakıyor (doğru). `ModelValidator` artık üst düğüm dönüşlerini hesaba katıyor.
- **İskelet:** Mixamo adları (`mixamorig_*`) → Mixamo animasyonları doğrudan uyar.
- **Tripo animasyonlu dışa aktarım (2026-11-26):** Tripo'nun hazır animasyonlarıyla (idle, run) indirilen GLB aynı mesh + 65 kemik + klipler içerir; oyunda bu dosya kullanılıyor (`char_alpay_tripo.glb`). Klipler **döngüsüz** ve koşu **kök hareketli** (Hips ≈ 2.8 m ileri) gelir → `PlayerAnimator` çalışma zamanında döngüyü açar, kökün yatay hareketini siler (yerinde: ileri eğilim çıkarılır ve kalça **iskeletin dinlenme konumuna** oturtulur — Tripo koşusu kalçayı dinlenmeden 0.8 m ileride başlatıyor; ilk kareye sabitlemek koşuya geçişte öne fırlama / durunca geri kayma / dönüşte savrulma yapıyordu, test_m7 "kalça merkezde ≤ 0.3 m" ile denetlenir), koşu klibinin doğal hızını ölçer (3.56 m/s) ve oynatma hızını oyuncu hızına eşler (7 m/s → ×1.96). Klibi olmayan durumlar `idle` + yordamsal poz ile oynar.
- **Mixamo klipleri (2026-11-26, 12 klip oyunda):** Tripo modeli Mixamo'ya yüklenip "Without Skin" FBX indirildi → `assets/models/characters/alpay/anims/anim_alpay_<mantıksal ad>.fbx`. `PlayerAnimator._load_external_clips()` çalışma zamanında: klibi `ext/<ad>` olarak modelin AnimationPlayer'ına ekler, iz yollarını modelin iskeletine yönlendirir, konum izlerini kalça dinlenme boyu oranıyla ölçekler (×1.6), ölçek izlerini atar. Mixamo'nun yeniden kurduğu iskeletin bind pozu Tripo'nunkinden farklı (kollar ≈ 40°) ama kemik yerel pozları aynı hiyerarşide doğrudan geçiyor — web'de F3 önizlemesiyle her klip görsel olarak doğrulandı.
  - **InPlace olmayanlar** (death, land, whip_attack_3; ayrıca güvence için run, jump_up, hurt, climb_up, whip_attack_1/2) kodla yerinde yapılır.
  - **Hedef süreler** (`target_lengths`): Mixamo vuruşları 1.3–1.7 sn, oyunda kamçı 0.26 sn → klip 0.45 sn'de oynar (vuruş anı aktif pencereye denk gelir); zıplama 0.5, iniş 0.3, hasar 0.45, ölüm 1.4 sn.
  - **"With Skin" indirilen FBX** (idle) Z-yukarı iskeletle geldiği için atlanır (uyarı verir); Tripo'nun kendi idle'ı kullanılır. Dış klip aynı adlı model klibinden önceliklidir (`prefer_external`).
  - **F3 = animasyon önizleme:** yüklü tüm klipler sırayla oynar (yeni klip gelince görsel kontrol).
- **Yeni klip eklemek:** Tripo'da başka hazır animasyon (jump, climb …) seçip yeniden dışa aktar → aynı adla yükle; ya da Mixamo FBX'leri `anims/`'e. Klip adları mantıksal adlardan farklıysa `PlayerAnimator.clip_map`.
- Alpay: 18 988 üçgen, 1 materyal, 2048 doku — bütçe içinde. Meshy kıyas modeli (`char_alpay_meshy.glb`, 10k üçgen, 1.7 m, Running/Walking klipli) referans olarak repoda kalır, web build'den hariç (`*_meshy.glb`).

### Tripo oto-rig'li modeller — teslim kontrolü ve rig düzeltmesi (§7.6, 2026-11-26)
Yüklenen set: Kocabaş (dev kaplumbağa), Çürük Sürüngen, Spor Kesesi, Tuzak Çiçek (tavandan sarkar), Kök Yılanı, Kanca Çiçeği, kaya / kök kemer / kök platform, Kökyiyen. Hepsi galeride 3 açıdan görüntülendi; ölçek/yön doğru.
- **Ölçek** (`.glb.import` → `nodes/root_scale`, Tripo 1 birime normalize ediyor): Kocabaş 5.17 (boy 3.0 m, boy 5.2 m), sürüngen 1.3, spor kesesi 1.1, tuzak çiçek 1.5, kök yılanı 3.0, Kökyiyen 10 (8 m), kanca çiçeği 0.8, kaya 2.0, kemer 4.0, platform 4.0.
- **Doku:** düşman/prop/çevre `_basecolor.jpg.import` → `process/size_limit=1024`; Alpay ve boss 2048.
- **Rig ölçümü** (`model_check` → `[RIG]` satırı, `ModelValidator.rig_report` + `bend_test`): her kemik sırayla 20° bükülür, mesh CPU'da deri ağırlıklarıyla deforme edilir, kenarı ×1.6'dan fazla uzayan (yırtılan) üçgen kenarlarının oranı ölçülür. Referans: Mixamo rig'li Alpay **%0.01**. < %0.1 iyi, < %0.6 kabul, üstü sorunlu.
- **Bulunan sorunlar ve düzeltme** (içe aktarma sonrası betik `tools/import/smooth_rig_import.gd`, `RigSmoother`):
  | Model | Önce | Sorun | Düzeltme | Sonra |
  |---|---|---|---|---|
  | Kocabaş | %0.48 (30°'de %1.3) | Oto-rig kabuğu ön gövde (`Spine_0`), arka gövde (`bone_11`) ve kabuk çıkıntısı kemiklerine bölmüş → gövde bükülünce kabuk ortadan yırtılıyor | Gövde/kabuk kemikleri köke birleştirildi (kabuk katı); bacak, boyun, kafa, kuyruk serbest; + 8 tur ağırlık yumuşatma | **%0.07** |
  | Kökyiyen | %0.76 (30°) | Kuyruk/kafa halkalarında sert (tek kemik) ağırlık | 12 tur Laplace yumuşatma | **%0.07** |
  | Çürük Sürüngen | %0.41 (30°) | Gövde ekleminde sert sınır | 8 tur yumuşatma | %0.15 (kabul) |
  | Tuzak Çiçek, Kök Yılanı | %0.02 / %0.00 | — | — | iyi |
- **Ağırlık yumuşatma:** `w ← (1−α)·w + α·ort(komşu)`, UV dikişindeki kopya köşeler konumdan birleştirilir (dikiş açılmaz), köşe başına en büyük 4 etki, Σ=1. Bir modele uygulamak: `.glb.import` → `import_script/path="res://tools/import/smooth_rig_import.gd"`, tur sayısı / kemik birleştirme betikteki tablolarda.
- **Bağsız köşe 0, sol/sağ sızıntı yok** — hiçbir modelde Blender'da elle rig düzeltmesi gerekmedi.
- Modellerin hiçbirinde animasyon klibi yok (yalnız iskelet) → insansı olmayanlar yordamsal kemik animasyonuyla oynatılır (§7.7).
- `env_rock_2m_a` dokusunun adı `prop_ocak_basecolor` (Tripo projesinden kalma ad); model bir kaya (yosunlu, mavi kristalli) — Ocak (ateşli taş ocak) modeli henüz yok.

### Modelleri oyuna bağlama (§7.7, 2026-11-26)
`ModelVisual` (scripts/art/model_visual.gd) tek giriş noktası: yükle → stilize et → (düşmanlarda) materyali örneğe özel kopyala → yön → yordamsal kemik pozu.
| Model | Yer | "İleri" ekseni (model uzayı) | Canlandırma |
|---|---|---|---|
| `enm_rot_crawler` | `RotCrawler` | +X | çapraz adım (bacak ±0.55 rad, diz), omurga ±0.14, kuyruk ±0.35 gecikmeli, kafa arama; sersemleyince kafa kalkar |
| `enm_spore_bloater` | `SporeBloater` (rigsiz) | — | ölçek nefesi ±%6, yalpalama, sürüklenirken eğilme, vurulunca şişme |
| `enm_trap_flower` | `TrapFlower` | — | sap 3 kemikte iki eksen salınım, uyarıda titreme + taç açılması, ısırıkta kapanma; ısırıkta model iner, arada sap uzar |
| `enm_root_snake` | `RootSnake` | −X | 9 kemik dikey + yan gövde dalgası; uyarıda titrek, fırlarken kafa kalkar |
| `boss_kokyiyen` | `Rooteater` | (0.5, 0, 1) | gövde/kafa nefesi, 17 kemikli kuyruk kıvrımı, 16 ağız dokunacı; yerden yükselir (ölçeklenmez) |
| `npc_kocabas` | `KocabasNpc` (Kök Ağzı) | +X | nefes, boyun + kafa oyuncuyu izler (±0.7 rad), ara sıra baş sallama, ayak kıpırtısı, kuyruk |
| `prop_grapple_flower` | `GrappleFlower` | — | sap üstünden sarkaç salınımı; hedeflenince hale + nabız (model dokusu değişmez) |
| `prop_ocak` | `Ocak` | — | taş halka + alev/kıvılcım/duman parçacıkları, titreşen ışık (ölçek 1.6, boy 0.56 m) |
| `env_*` | `GreyboxRoom.decor()` | — | çarpışmasız arka plan süsü |
- Yeni model eklemek: kemik adlarını `model_check` çıktısından ya da `ModelVisual.bone()` ile al; eksenleri model uzayında ver (Vector3.UP = sağa-sola dönüş, yan eksen = öne-arkaya eğilme).
- Sıradaki üretim listesi (parallax katmanları, dallar, bitkiler, oyun nesneleri, modüler set, boss parçaları): **docs/11_ASSET_PROMPTS.md**.

### Yeni Alpay modeli ve çevre seti (2026-11-26, ikinci teslim)
- **Alpay modeli değişti:** kullanıcı Mixamo'dan "With Skin" FBX indirdi (`y_.fbx` → `characters/alpay/char_alpay.fbx`). Boy 1.7 m → `root_scale 0.9412` ile 1.6 m; 10.4k üçgen, 66 Mixamo kemiği, rig bükme testi %0.01. Ayrıca yüklenen 4 doku (Running/normal/roughness/metallic) FBX içindekilerle birebir aynıydı → kopyalar silindi; normal/roughness/metallic 256 px'e indirildi (stilize shader yalnız rengi kullanır). Eski Tripo modeli repoda yedek, web build'den hariç (`*/char_alpay_tripo*`).
- **Animasyonlar aynı kaldı:** 12 Mixamo klibi kemik adlarıyla doğrudan bağlanıyor. Yeni modelde idle olmadığı için daha önce atlanan "With Skin" idle FBX'i kullanılıyor: dinlenme iskeleti Z-yukarı ama klip anahtarları Y-yukarı (ölçüldü) → kalça ölçek oranı ilk anahtardan alınır, anahtarlar olduğu gibi geçer. 13 klip.
- **Çevre seti (14 model):** Tripo yine en büyük kenarı 1 m'ye indiriyor → `root_scale` = hedef boy (eğrelti 0.6, perde 2.15, çıkıntı 1.5, diğerleri adındaki boy). Doku 1024, normal 256. Eğrelti ve perdenin orijini mesh ortasındaydı → `tools/import/align_base_import.gd` tabanı y=0'a oturtur. Eğrelti 19k, perde 15.5k üçgen → `ModelValidator.TRI_OVERRIDES` istisnası, oda başına ≤ 3 / ≤ 1 (yeniden üretimde 8k hedefle).
- **Yerleşim (`RoomDressing._place_models`, otomatik):** yürünen zeminler `env_root_floor_4m_a` karolarıyla kaplanır (x'e ölçekli, %12 bindirme, rastgele 180°, renk ×0.65), ≤ 3.2 m süzülen platformlar `env_root_platform_2m_a` ile; arka sırada ot (≤ 8), eğrelti (≤ 3), mantar kümesi (≤ 3, ışıklı) — rüzgârlı; tavanlara kök kütlesi (≤ 4) + sarmaşık perdesi (≤ 1) — sarkık rüzgâr (tepe sabit); duvarlardan dal (≤ 3); arka planda kök sütunu (≤ 3), arka duvar dibinde kök duvarı kümesi (≤ 3), küçük kaya (≤ 2). Zemindeki `glow()` küreleri mantar kümesi modeline döndü. Elle: mağara ağzı Kök Ağzı ve Yankı mağara girişlerinde, kök köprüsü Kanca Bahçesi'nde yukarıda. Çıkıntı (`env_root_ledge_1m_a`) henüz kullanılmadı.

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
| `char_alpay_tripo.glb` ✅ (oyunda) | characters/alpay | 1.6 m | 20k | 2048 | İnsansı (Mixamo) | `teenage boy, 16 years old, lean and agile, barefoot, clothes woven from roots and leaves, a silver feather necklace glowing softly, living vine whip coiled on his shoulder, wild dark hair, A-pose, front view` |
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
Otomatik: `godot --headless --path . --import && godot --headless --path . res://tests/model_check.tscn` (`ModelValidator`: tür öneki, üçgen/doku bütçesi, materyal ≤ 2, orijin ayak tabanı ortası, beklenen boy, insansıda Mixamo kemikleri ve +Z bakış; deri bağlı modellerde `[RIG]` satırı: ölü kemik, bağsız köşe, 20° bükme yırtığı — §7.6). Elle:
- [ ] Oyun kamerasından (14 m, FOV 40) siluet okunuyor mu?
- [ ] Bölge paletine uyuyor mu (stilize shader ile)?
- [ ] Üçgen/doku bütçesi içinde mi?
- [ ] Web build'de görünüm kabul edilebilir mi?
