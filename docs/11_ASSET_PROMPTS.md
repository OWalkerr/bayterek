# Üretim Prompt'ları — Parallax Arka Planlar, Dallar, Bitkiler, Oyun Nesneleri (Kök Dibi)

> Araçlar: **Gemini** (2D görsel) → arka plan katmanları doğrudan oyuna girer; 3D için konsept görseli olur.
> **Tripo** (Image to 3D) → dallar, bitkiler, meşaleler. Genel kurallar: docs/07 §7.
> Bu dosyadaki prompt'lar İngilizce (araçlar daha iyi anlıyor), açıklamalar Türkçe.

## 0. Oyunda nasıl kullanılacak (neden bu boyutlar)
- Oyun 3D ve kamera yandan bakıyor. Arka plan görselleri, kameranın **arkasında farklı derinliklere konan dev düzlemlere** yapıştırılır (−12 m, −25 m, −45 m, −80 m). Kamera hareket edince yakın katman hızlı, uzak katman yavaş kayar. Parallax gerçek derinlikten doğar, ek kod gerekmez.
- Ön plan katmanı (FG) kameranın **önünde** (+4 m) durur, koyu siluettir, oyuncuyu kapatmayacak şekilde ekranın üst ve alt kenarlarında kalır.
- Katmanlar yatayda **döşenebilir** (tileable) olmalı: sol ve sağ kenar birbirine bağlanır, oda boyunca tekrar eder.
- Sis, kıvılcım, spor, ateş gibi efekt dokularını **ben kodla üretiyorum**, onlar için görsel gerekmez.

## 1. Ortak kurallar

### 1.1 Gemini — sabit stil eki (her 2D prompt'un sonuna ekle)
```
stylized hand-painted 2D game background art, soft painterly brush strokes, mythic Turkic forest underworld,
inside the roots of a colossal world tree, limited palette: deep root purple #2B1E3F, dusk violet #4A3550,
mushroom teal glow #4FB3A9, sap gold accents #E8A33D, moss green #5E8C4A,
atmospheric perspective, low contrast in the distance, no characters, no text, no watermark, no frame, no UI
```

### 1.2 Arka planı silinecekler (Photoshop) — hangi renk?
Gemini şeffaf PNG veremez. Silinecek katmanlarda prompt'a **düz tek renk arka plan** istenir:
- **Koyu siluet katmanları** (L1, L2, FG): `on a plain solid pure white background (#FFFFFF), no gradient, no floor`
- **Işıklı / renkli katmanlar** (mantar kümeleri, ışık huzmesi): `on a plain solid pure black background (#000000)` → Photoshop'ta silmek yerine katman modu **Screen** bile yeter (aşağıda).

Her prompt'un başlığında 🧽 = **arka planı silinecek**, 🟦 = **silinmeyecek (opak)** işareti var.

### 1.3 Photoshop adımları (🧽 olanlar)
1. Görseli aç → *Image › Image Size*: hedef boyut (tabloda), *Preserve Details 2.0* ile büyüt.
2. *Select › Subject* (ya da Properties › Quick Actions › **Remove Background**). Beyaz zeminde *Select › Color Range* (beyazı seç, Fuzziness 40) → *Inverse* daha temiz sonuç verebilir.
3. *Select and Mask*: Smooth 2, Feather 0.5 px, **Decontaminate Colors** açık (beyaz hale kalmasın).
4. Kenar kontrolü: koyu bir düz renk katmanı (#2B1E3F) altına koy, beyaz/siyah hale varsa *Layer › Matting › Defringe 1–2 px*.
5. **Döşenebilirlik** (tabloda "döşenir" yazanlar): *Filter › Other › Offset* → yatay +genişlik/2, *Wrap Around*. Ortada çıkan dikişi Spot Healing / Clone ile kapat, sonra Offset'i geri al.
6. Kaydet: *File › Export › Export As* → **PNG**, *Transparency* açık, 8 bit. (🟦 olanlar → JPG kalite 90.)
7. Adı tablodaki gibi koy, yükle: `assets/textures/backgrounds/` (GitHub → Add file → Upload files).

### 1.4 Tripo — 3D ayarları (dallar ve bitkiler)
- Gemini'de konsepti üret (prompt'lar aşağıda, **düz gri arka plan** — Tripo arka planı kendi siler, **Photoshop gerekmez**).
- Tripo → *Image to 3D* → Topoloji **Triangle**, Face limit tablodaki gibi, Doku **1024**, **Rig yok** (sallanmayı shader yapıyor), GLB dışa aktar.
- Önemli: **sallanan nesnelerde orijin, tutunduğu nokta olmalı** (sarkan kökte üst uç, bitkide dip). Tripo orijini alta koyar. Sarkanlarda ben import'ta çeviririm, sen bir şey yapma.
- Yükle: `assets/models/environment/` (bitki/dal) veya `assets/models/props/` (meşale, mangal).

### 1.5 Tripo — sabit stil eki (3D konsept prompt'larının sonuna)
```
stylized, hand-painted textures, soft rounded shapes, clean readable silhouette, game asset,
limited palette: deep root purple #2B1E3F, mushroom teal #4FB3A9, sap gold #E8A33D, moss green #5E8C4A,
single object, centered, plain neutral grey background, no ground shadow, three-quarter view
```

---

## 2. Parallax arka plan katmanları — Kök Dibi (Gemini, 2D)

| Dosya | Katman | Derinlik | Boyut (px) | Döşenir | Sil? |
|---|---|---|---|---|---|
| `bg_kokdibi_l0_far.jpg` | L0 en uzak gök/derinlik | −80 m | 4096×2048 | evet | 🟦 |
| `bg_kokdibi_l1_roots.png` | L1 uzak kök sütunları | −45 m | 4096×2048 | evet | 🧽 |
| `bg_kokdibi_l2_mid.png` | L2 orta kökler + mantarlar | −25 m | 4096×2048 | evet | 🧽 |
| `bg_kokdibi_l3_glow.png` | L3 parlayan mantar kümeleri | −12 m | 2048×1024 | evet | 🧽 (siyah → Screen) |
| `fg_kokdibi_top.png` | FG üstten sarkan kökler | +4 m (ön) | 4096×1024 | evet | 🧽 |
| `fg_kokdibi_bottom.png` | FG alttaki kök/yosun siluetleri | +4 m (ön) | 4096×1024 | evet | 🧽 |
| `bg_kokdibi_lightshafts.png` | Işık huzmeleri (üstten) | −15 m | 2048×1024 | hayır | 🧽 (siyah → Screen) |
| `bg_kokdibi_cave_far.jpg` | Mağara odaları (derinlik modu) uzak duvar | −30 m | 4096×2048 | evet | 🟦 |
| `bg_kokyiyen_arena.jpg` | Kökyiyen'in İni arka duvarı | −35 m | 4096×2048 | hayır | 🟦 |
| `bg_kokdibi_sky_hole.png` | Tavandaki açıklıktan görünen gök (Umay ipucu) | −60 m | 2048×2048 | hayır | 🧽 |

### L0 — en uzak derinlik 🟦 (`bg_kokdibi_l0_far.jpg`)
```
Wide panoramic background, the deepest distance inside an enormous underground root cavern of a colossal world tree,
countless giant tree roots fading into violet mist, soft teal bioluminescent haze far away, faint golden sap veins
glowing deep inside the roots, very low contrast, soft and blurry like distant fog, calm and mysterious mood,
horizontally seamless tileable panorama, left and right edges must match, 2:1 aspect ratio, full frame painted, no empty areas,
[sabit stil eki]
```

### L1 — uzak kök sütunları 🧽 (`bg_kokdibi_l1_roots.png`)
```
Wide panoramic layer of distant giant tree root pillars and arches, tall thick roots rising from bottom to top of the image,
dark dusk-violet silhouettes #4A3550 with soft teal rim light on their edges, slight mist at their bases,
gaps between the pillars so deeper layers are visible, horizontally seamless tileable, 2:1 aspect ratio,
the roots touch the top and bottom edges, on a plain solid pure white background (#FFFFFF), no gradient, no floor,
[sabit stil eki]
```

### L2 — orta kökler ve mantarlar 🧽 (`bg_kokdibi_l2_mid.png`)
```
Wide panoramic middle-ground layer, twisted gnarled tree roots weaving horizontally and diagonally, moss patches,
small clusters of glowing teal mushrooms on the roots, a few hanging thin root strands, darker and more detailed than
the distant layer, deep purple #2B1E3F to violet #4A3550, teal glow accents, the bottom third is a dense root floor mass,
open space in the middle third, horizontally seamless tileable, 2:1 aspect ratio,
on a plain solid pure white background (#FFFFFF), no gradient,
[sabit stil eki]
```

### L3 — parlayan mantar kümeleri 🧽 (`bg_kokdibi_l3_glow.png`)
```
Scattered clusters of small bioluminescent mushrooms and glowing spores, teal #4FB3A9 and a few sap gold #E8A33D caps,
soft glow halos around them, arranged along the bottom edge and a few floating spore motes above,
horizontally seamless tileable, 2:1 aspect ratio, on a plain solid pure black background (#000000), no other objects,
[sabit stil eki]
```
> Photoshop: silmeye gerek yok. Katman modu **Screen** yap, *Merge* et, sonra siyahı *Select › Color Range* ile seçip sil (ya da bana siyah zeminli JPG gönder, oyunda "additive" ile ben karıştırırım: o zaman adı `bg_kokdibi_l3_glow.jpg`).

### FG üst — sarkan kökler 🧽 (`fg_kokdibi_top.png`)
```
Foreground silhouette strip of thick roots and thin root tendrils hanging down from the top edge, very dark almost black
deep purple #1A1228, slight teal rim light, varied lengths, some tendrils with small leaves, the lower half of the image
is completely empty, horizontally seamless tileable, 4:1 aspect ratio,
on a plain solid pure white background (#FFFFFF), no gradient,
[sabit stil eki]
```

### FG alt — kök ve yosun siluetleri 🧽 (`fg_kokdibi_bottom.png`)
```
Foreground silhouette strip along the bottom edge, rounded roots, moss clumps, ferns and small mushrooms,
very dark deep purple #1A1228 with faint teal rim light, the upper two thirds of the image are completely empty,
horizontally seamless tileable, 4:1 aspect ratio, on a plain solid pure white background (#FFFFFF), no gradient,
[sabit stil eki]
```

### Işık huzmeleri 🧽 (`bg_kokdibi_lightshafts.png`)
```
Soft volumetric god rays falling diagonally from the top left, pale warm white and faint teal light beams,
floating dust particles inside the beams, very soft edges, nothing else in the image,
on a plain solid pure black background (#000000), 2:1 aspect ratio,
[sabit stil eki]
```
> L3 gibi: **Screen** ile karıştır ya da siyah zeminli JPG gönder (`.jpg` adıyla).

### Mağara uzak duvarı 🟦 (`bg_kokdibi_cave_far.jpg`)
```
Wide background of the inner wall of a narrow cave carved inside giant tree roots, root bark texture walls curving
around, glowing teal mushroom patches and golden sap veins in the wall, cozy enclosed feeling, soft vignette darker at
the edges, horizontally seamless tileable, 2:1 aspect ratio, full frame painted,
[sabit stil eki]
```

### Kökyiyen'in İni arka duvarı 🟦 (`bg_kokyiyen_arena.jpg`)
```
Huge circular underground arena wall made of rotting black-purple roots, corrupted rot #5A1E5C with sickly yellow-green
glowing pustules #C9D93B, the healthy golden sap veins being devoured by the rot, old carved Turkic stone fragments
half swallowed by roots, ominous but beautiful, deep vertical shaft feeling, 2:1 aspect ratio, full frame painted,
[sabit stil eki]
```

### Tavandaki gök açıklığı 🧽 (`bg_kokdibi_sky_hole.png`)
```
A small opening high above in a ceiling of tangled roots, through it a distant pale sky #9CC9E8 with a single
glowing white feather drifting, soft light pouring down, the roots around the opening are dark silhouettes,
square 1:1 image, everything outside the root ring is plain solid pure white background (#FFFFFF),
[sabit stil eki]
```

---

## 3. Dallar, kökler, bitkiler — 3D (Gemini konsept → Tripo)

Hepsi **rigsiz**, rüzgârı shader veriyor (oyuncu yanından geçince eğilir). Photoshop **gerekmez**.

| Dosya | Boy | Üçgen | Ne yapacak |
|---|---|---|---|
| `env_hanging_root_3m_a.glb` | 3 m (sarkık) | 2k | Tavandan sarkan kalın kök + ince saçaklar, sallanır |
| `env_hanging_root_3m_b.glb` | 3 m | 2k | Varyasyon: yapraklı, uçta küçük mantar |
| `env_branch_3m_a.glb` | 3 m (yatay) | 3k | Duvardan çıkan yaprak/yosunlu dal (arka plan, yüzey değil) |
| `env_fern_1m_a.glb` | 1 m | 1.5k | Eğrelti kümesi, zeminde sallanır |
| `env_grass_tuft_05m_a.glb` | 0.5 m | 600 | Yosunlu ot öbeği (çok sayıda dağıtılır) |
| `env_mushroom_cluster_1m_a.glb` | 1 m | 2k | Parlayan mantar kümesi (ışık eklerim) |
| `env_vine_curtain_4m_a.glb` | 4 m | 3k | Perde gibi sarkan sarmaşık (arkasında sır olabilir) |
| `env_root_wall_4m_a.glb` | 4 m | 4k | Modüler kök duvarı parçası (arka plan dolgu) |
| `prop_brazier.glb` | 1.2 m | 2k | Taş mangal, ateşini kodla yakarım |
| `prop_torch_wall.glb` | 0.8 m | 1k | Duvar meşalesi (ateş kodla) |
| `prop_totem_stone.glb` | 1.8 m | 2k | Göktürk işaretli dikili taş (balbal), süs |

### `env_hanging_root_3m_a` — sarkan kök
```
A single thick twisted tree root hanging straight down from the top, with many thin root tendrils dangling around it,
small moss patches, the top end is cut flat where it attaches to the ceiling, tapering to thin tips at the bottom,
deep purple-brown bark #4A3550, moss green #5E8C4A, faint teal glowing spots,
[Tripo sabit stil eki]
```

### `env_hanging_root_3m_b` — yapraklı sarkan kök
```
A hanging root strand from the top, thinner and longer, with small round leaves along it and a tiny cluster of glowing
teal mushrooms near the bottom tip, the top end is cut flat, graceful slight S-curve,
[Tripo sabit stil eki]
```

### `env_branch_3m_a` — duvar dalı
```
A gnarled tree branch growing horizontally out of a wall, flat cut base on the left side, mossy bark, a few clusters
of soft rounded leaves and two small hanging vines, deep purple-brown bark, moss green leaves, side view,
[Tripo sabit stil eki]
```

### `env_fern_1m_a` — eğrelti
```
A lush cluster of stylized fern fronds growing from a small mossy mound, fronds curling outward, soft rounded leaflets,
moss green #5E8C4A with teal tips, a few tiny glowing spores at the tips,
[Tripo sabit stil eki]
```

### `env_grass_tuft_05m_a` — ot öbeği
```
A small tuft of thick stylized grass blades and moss growing from the ground, rounded chunky blades, moss green with
lighter tips, simple low-poly-friendly shapes,
[Tripo sabit stil eki]
```

### `env_mushroom_cluster_1m_a` — parlayan mantarlar
```
A cluster of five bioluminescent mushrooms of different heights growing from a root knot, wide caps glowing teal
#4FB3A9 from underneath, one golden cap #E8A33D, thin pale stems, tiny glowing dots on the caps,
[Tripo sabit stil eki]
```

### `env_vine_curtain_4m_a` — sarmaşık perdesi
```
A dense curtain of hanging vines and leaves falling from a horizontal root beam at the top, many parallel strands of
different lengths, small leaves and a few teal flowers, front view, flat and wide like a curtain,
[Tripo sabit stil eki]
```

### `env_root_wall_4m_a` — modüler kök duvarı
```
A wall section made of many thick intertwined tree roots packed together, roughly flat front face, square-ish
silhouette, moss in the gaps, a few glowing teal mushrooms and a thin golden sap vein, front view,
[Tripo sabit stil eki]
```

### `prop_brazier` — taş mangal
```
A small round stone brazier on three short carved legs, Turkic geometric ornaments and a wolf motif carved in the
stone, a bowl of glowing embers on top but NO flames, warm golden ember glow #E8A33D, dark purple-grey stone,
[Tripo sabit stil eki]
```

### `prop_torch_wall` — duvar meşalesi
```
A wall-mounted torch made of a wrapped wooden stick in a carved bronze holder with a flat back plate, Turkic
ornament on the plate, the top is charred and glowing faintly, NO flames,
[Tripo sabit stil eki]
```
> Alevi modelde **istemiyoruz**: ateş, kıvılcım ve dumanı oyun hareketli olarak kendisi çiziyor.

### `prop_totem_stone` — balbal / dikili taş
```
An ancient Turkic standing stone (balbal) with a simple carved face and runic Old Turkic inscriptions, partly covered
in moss and small roots, weathered rounded edges, dark purple-grey stone with faint teal glowing runes,
[Tripo sabit stil eki]
```

---

## 4. Diğer 3D modeller — oyun nesneleri, modüler çevre, boss parçaları (Gemini konsept → Tripo)

Şu an oyunda greybox (renkli kutu/küre) duran her şeyin listesi. Tripo ayarları §1.4 ile aynı, Photoshop **gerekmez**.
Rig sütunu "—" olanlar rigsiz. Hareketi (dönme, süzülme, parlama) kod veriyor.

### 4.1 Oyun nesneleri (`assets/models/props/`)
| Dosya | Boy | Üçgen | Rig | Oyunda yerine geçtiği |
|---|---|---|---|---|
| `prop_kut_shard.glb` | 0.5 m | 1k | — | Kut Parçası (toplanabilir, döner) |
| `prop_oz_crystal.glb` | 1.2 m | 1.5k | — | Oda hedefi / Öz kristali (döner, parlar) |
| `prop_ability_shrine.glb` | 2.2 m | 4k | — | Yetenek Sunağı (Kamçı Kancası verilir) |
| `prop_heavy_boulder.glb` | 1.8 m | 1.5k | — | Öz Çekimi kapısı: ağır kök kayası (gizli oda) |
| `prop_root_gate.glb` | 4 m | 3k | — | Yetenek kapısı: dikenli kök örgüsü (açılınca çekilir) |
| `prop_rotten_vine.glb` | 3 m | 1.5k | — | Çürük sarmaşık görseli (kopan). İsteğe bağlı, kodla da güzel durabilir |
| `prop_feather_pendant.glb` | 0.15 m | 800 | — | Alpay'ın Umay tüyü kolyesi (sinematik / menü) |
| `prop_spirit_lantern.glb` | 0.6 m | 1k | — | Asılı kandil (ışık + sallanma), süs |

**`prop_kut_shard`**
```
A small floating crystal shard of sacred spirit light, faceted golden-white crystal #E8A33D with an inner glow,
a tiny Old Turkic rune engraved in the middle, thin golden ribbons of light swirling around it,
[Tripo sabit stil eki]
```
**`prop_oz_crystal`**
```
A tall glowing sap crystal growing out of a root knot, translucent golden amber #E8A33D with a bright core,
small teal mushrooms at its base, hexagonal faceted shape, magical and inviting,
[Tripo sabit stil eki]
```
**`prop_ability_shrine`**
```
An ancient small shrine carved into a giant tree root, a round stone altar with Turkic wolf and tree-of-life
ornaments, a hollow bowl on top where a glowing orb would float, mossy, golden sap veins running into the altar,
sacred and quiet mood,
[Tripo sabit stil eki]
```
**`prop_heavy_boulder`**
```
A huge heavy round boulder tightly wrapped and bound by thick roots, cracked purple-grey stone, a glowing
golden hook ring of sap on its front where something could grab it, looks very heavy,
[Tripo sabit stil eki]
```
**`prop_root_gate`**
```
A gate made of thick thorny tree roots woven tightly together, blocking a doorway, square silhouette, a glowing
teal rune in the center that hints how to open it, mossy, slightly corrupted purple tips, front view,
[Tripo sabit stil eki]
```
**`prop_rotten_vine`**
```
A single hanging vine rotting from inside, dark purple #5A1E5C with sickly yellow-green #C9D93B cracks,
drooping leaves, a fragile looking thin middle part, the top end is cut flat,
[Tripo sabit stil eki]
```
**`prop_feather_pendant`**
```
A small necklace pendant: a single white silver feather tied with a braided leather cord and a tiny golden bead,
soft magical glow on the feather edges, sacred Umay feather,
[Tripo sabit stil eki]
```
**`prop_spirit_lantern`**
```
A small hanging lantern made of woven roots and a hollow seed pod, a soft teal spirit light inside, hanging from
a short cord, the top end is cut flat,
[Tripo sabit stil eki]
```

### 4.2 Modüler çevre seti (`assets/models/environment/`)
Platformlar 4 m ızgarasına uyar. Çarpışmayı ben kutu olarak ekliyorum, model yalnız görünüm.
| Dosya | Boy | Üçgen | Kullanım |
|---|---|---|---|
| `env_root_platform_2m_a.glb` | 2 m geniş | 1.5k | Küçük platform (mevcut 4 m'nin yarısı) |
| `env_root_ledge_1m_a.glb` | 1 m | 1k | Duvar çıkıntısı (tırmanma molası) |
| `env_root_pillar_6m_a.glb` | 6 m | 3k | Dikey kök sütunu (oda kenarı, arka plan) |
| `env_root_bridge_6m_a.glb` | 6 m uzun | 3k | İki platform arası kök köprüsü |
| `env_ceiling_roots_4m_a.glb` | 4 m | 2.5k | Tavan dolgusu (aşağı sarkan kök kütlesi) |
| `env_rock_1m_b.glb` | 1 m | 800 | Küçük kaya varyasyonu |
| `env_cave_mouth_6m_a.glb` | 6 m | 4k | Mağara ağzı çerçevesi (derinlik moduna geçiş kapısı) |
| `env_root_floor_4m_a.glb` | 4 m | 2.5k | Zemin dolgusu (yosunlu kök zemini, üst yüzey düz) |

**`env_root_platform_2m_a`**
```
A modular flat-topped root platform about 2 meters wide, flat mossy top surface, twisted roots forming the body,
short roots and tendrils hanging below, side view friendly,
[Tripo sabit stil eki]
```
**`env_root_ledge_1m_a`**
```
A small ledge of roots and moss sticking out of a wall, flat walkable top, flat back side where it meets the wall,
[Tripo sabit stil eki]
```
**`env_root_pillar_6m_a`**
```
A tall vertical pillar made of several thick tree roots twisted together, flat cut at top and bottom, moss and small
glowing teal mushrooms climbing on it, a thin golden sap vein,
[Tripo sabit stil eki]
```
**`env_root_bridge_6m_a`**
```
A long natural bridge formed by two thick roots growing horizontally side by side, slightly sagging in the middle,
flat walkable top with moss, thin tendrils hanging underneath, side view,
[Tripo sabit stil eki]
```
**`env_ceiling_roots_4m_a`**
```
A dense mass of tangled roots seen from the side, flat top where it attaches to the ceiling, many roots hanging down
unevenly from it, moss and a few glowing teal spots,
[Tripo sabit stil eki]
```
**`env_rock_1m_b`**
```
A small mossy cave rock, rounded stylized stone with a flat bottom, purple-grey with moss on top, one tiny teal crystal,
[Tripo sabit stil eki]
```
**`env_cave_mouth_6m_a`**
```
The entrance of a cave formed by giant arching tree roots and stones, a dark opening in the middle, glowing teal
mushrooms around the frame, Turkic carved stone at the top of the arch, front view,
[Tripo sabit stil eki]
```
**`env_root_floor_4m_a`**
```
A modular square ground tile made of packed roots and soil, perfectly flat mossy top surface, roots visible on the
sides, 4 meters wide and 1 meter thick,
[Tripo sabit stil eki]
```

### 4.3 Boss parçaları (`assets/models/bosses/`)
| Dosya | Boy | Üçgen | Rig | Kullanım |
|---|---|---|---|---|
| `boss_kokyiyen_maw.glb` | 16 m çap | 8k | — | Faz 3 kovalamaca: kuyunun dibinden yükselen dev ağız (yukarıdan görünüm) |
| `boss_rot_sac.glb` | 1.1 m | 1.5k | — | Kökyiyen'in zayıf noktası: çürük kese (nabız gibi atar) |
| `boss_root_rock.glb` | 2 m | 1.5k | — | Faz 3 finali: kancayla çekilen asılı kök kayası |
| `boss_burrow_debris.glb` | 3 m | 2k | — | Kökyiyen yerden fırlarken kırılan zemin parçaları |

**`boss_kokyiyen_maw`**
```
A colossal circular worm maw seen from directly above, ring after ring of root-like teeth spiraling inward into a
dark throat, rotting purple flesh #5A1E5C, sickly yellow-green glowing pustules #C9D93B, wet and terrifying, flat
round silhouette,
[Tripo sabit stil eki]
```
**`boss_rot_sac`**
```
A bulging rotten sac of corruption, round swollen membrane with yellow-green glowing veins #C9D93B, purple rot
#5A1E5C, small root tendrils holding it, flat back side where it attaches to a body, a clear obvious weak spot,
[Tripo sabit stil eki]
```
**`boss_root_rock`**
```
A heavy round rock wrapped by roots, hanging from a few thick roots at the top, a glowing golden hook ring of sap on
its front, cracks in the stone, the top roots end in a flat cut,
[Tripo sabit stil eki]
```
**`boss_burrow_debris`**
```
A scattered cluster of broken ground chunks, root pieces and stones bursting outward, as if a giant worm just
erupted from the floor, flat bottom, dark soil, purple rot,
[Tripo sabit stil eki]
```

### 4.4 Karakter / düşman ekleri
| Dosya | Boy | Üçgen | Rig | Not |
|---|---|---|---|---|
| `enm_rot_crawler_b.glb` | 0.6 m | 8k | Tripo dört ayaklı | Varyasyon: sırtında spor kabarcıkları (aynı davranış, farklı görünüş) |
| `enm_spore_bloater_b.glb` | 1 m | 5k | — | Varyasyon: daha uzun dokunaçlı, altın benekli |

**`enm_rot_crawler_b`**
```
A small corrupted root lizard, low crawling body, purple rot veins, glowing sickly yellow eyes, a row of swollen
spore bubbles along its back, bark-like scales, menacing but small, four short legs, side view friendly,
[Tripo sabit stil eki]
```
**`enm_spore_bloater_b`**
```
A floating bloated spore sac creature, round purple membrane with golden glowing spots, many long thin dangling
tentacles below, a small puckered vent on top, eerie and fragile,
[Tripo sabit stil eki]
```

### 4.5 Öncelik sırası (hepsini birden üretmek gerekmez)
1. **Önce:** sarkan kökler (a, b), eğrelti, ot öbeği, mantar kümesi, mangal, duvar meşalesi → ortam hemen canlanır.
2. **Sonra:** Kut parçası, Öz kristali, Sunak, kök kapısı, ağır kaya → greybox nesneler kalkar.
3. **Modüler set:** platform 2 m, çıkıntı, sütun, tavan kökleri, zemin karosu → odaların kutu görünümü kalkar.
4. **Boss parçaları:** ağız, kese, kök kayası.
5. **İsteğe bağlı:** varyasyonlar, kandil, balbal, kolye, köprü, mağara ağzı.

---

## 5. Teslim kontrol listesi
- [ ] 2D: adı tablodaki gibi, PNG'lerde şeffaflık var, kenarda beyaz/siyah hale yok, döşenenlerde dikiş yok.
- [ ] 2D boyut: tablodaki boyut (daha küçükse sorun değil, oyunda büyütürüm ama bulanıklaşır).
- [ ] 3D: GLB, rigsiz, doku 1024, adı önekli (`env_` / `prop_`). Ölçeği ben import'ta ayarlarım.
- [ ] Yükledikten sonra "yükledim" de: `model_check` + görsel galeri ile kontrol eder, oyuna yerleştiririm.
