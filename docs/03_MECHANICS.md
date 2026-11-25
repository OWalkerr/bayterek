# Mekanikler

> Tüm sayılar başlangıç değerleridir; `res://data/tuning/player_tuning.tres` üzerinden ayarlanır. Kod içine sabit sayı gömülmez.

## 1. Temel Hareket (Yan Mod / 2.5D)
Oyuncu `CharacterBody3D`; yan modda **Z ekseni 0'a kilitli**, hareket X (yatay) ve Y (dikey) ekseninde.

| Parametre | Değer | Not |
|---|---|---|
| Koşma hızı | 7.0 m/s | |
| Hızlanma / yavaşlama (yerde) | 60 / 70 m/s² | Çabuk tepki |
| Havada kontrol | %65 | |
| Havada momentum koruma | Koşu hızının üstündeyken ve girdi aynı yöndeyse hız kırpılmaz; 3 m/s² sürtünme | `air_overspeed_drag` — sallanma çıkışı hızı korunur (Sütun 1) |
| Zıplama yüksekliği | 2.2 m | Zıplama hızı yükseklikten hesaplanır |
| Yerçekimi (yükselirken / düşerken) | 24 / 42 m/s² | Düşüş daha hızlı → tok his |
| Değişken zıplama | Tuş bırakılınca dikey hız × 0.45 | |
| Coyote time | 0.12 sn | Kenardan düştükten sonra zıplama hakkı |
| Jump buffer | 0.12 sn | Yere değmeden basılan zıplama hatırlanır |
| Maks. düşüş hızı | 22 m/s | |

## 2. Sarmaşık Sistemi (oyunun kalbi)

### 2.1 Sarmaşık türleri
| Tür | Davranış |
|---|---|
| **Sallanma Sarmaşığı** (`VineAnchor`) | Sabit bir noktadan sarkan sarmaşık. Tutunulunca sarkaç fiziği. |
| **Tırmanma Sarmaşığı** (`ClimbVine`) | Dikey sarmaşık; yukarı/aşağı tırmanma, yana zıplama (bkz. §2.3). |
| **Kanca Çiçeği** (`GrappleFlower`) | Kamçı Kancası ile uzaktan tutulur, sarkaç başlar. |
| **Çürük Sarmaşık** (`RottenVine`) | İlk tutunmadan 1.5 sn sonra kopar (bırakılsa da sayaç durmaz), 4 sn sonra yeniden büyür. Kopmaya yaklaştıkça titrer, mordan göz sarısına döner. |
| **Diken Sarmaşık** | Tutunulursa hasar verir; ancak kamçıyla temizlenir. |
| **Yetiştirilen Sarmaşık** | Tohum Atışı ile oyuncunun yarattığı geçici sallanma noktası. |

### 2.2 Sallanma fiziği — "Sarkaç Kontrolcüsü"
Fizik motoruna bırakılmaz; **kinematik sarkaç** kullanılır (tam kontrol, tutarlı his):

```
θ  : dikeye göre açı      ω : açısal hız      L : ip uzunluğu
α  = -(g / L) · sin(θ) + pump · input_x / L - damping · ω
ω += α · dt
θ += ω · dt
pozisyon = anchor + L · (sin θ, -cos θ)
```

| Parametre | Değer |
|---|---|
| Tutunma yarıçapı (otomatik yakalama) | 1.4 m |
| Tutturma noktasının altında olma şartı | El, tutturma noktasının en az 0.6 m altında olmalı (üstten yakalama momentumu sıfırlıyordu) |
| İp uzunluğu | Tutunma anındaki mesafe (min 2, maks 7 m) |
| Pompalama kuvveti (input ile) | 9 m/s² |
| Sönümleme | 0.15 |
| Maks. açı | 100° |
| Bırakma: momentum | Teğet hız × 1.1 |
| Bırakma: zıplama bonusu | +6 m/s yukarı |
| Yeniden yakalama bekleme süresi | Aynı sarmaşık 0.35 sn, başka sarmaşık 0 sn |
| Yukarı/aşağı ile ip kısaltma/uzatma | 3 m/s |
| Duvara/zemine çarpma | Açısal hız × -0.25 (sekme) |
| Mükemmel bırakma penceresi | Salınımın ileri-yukarı kolunda (θ ile ω aynı işaretli) **35°–70°** |
| Mükemmel bırakma bonusu | Hız × 1.15 + altın ışıltı (`ReleaseSpark`) |

**His kuralları:**
- Tutunma anında oyuncunun mevcut hızı açısal hıza çevrilir → momentum kaybolmaz.
- Zıplayarak bırakma salınımın ileri-yukarı kolunda 35°–70° arasındaysa "mükemmel bırakma": ekstra %15 hız + küçük ışık efekti. (Eski tarif "tepe noktası ±8°" idi; tepede hız ≈ 0 olduğu için ödülsüz kalıyordu → karar 2026-11-25.)
- Bot ölçümü (M1): Savrulma Zinciri odası 30°–70° arası her bırakma açısıyla geçilebiliyor → zamanlama toleransı geniş; Çürük Geçit 50°'de bekleyen oyuncuyu cezalandırıyor (tasarım gereği).
- Sarmaşıktan sarmaşığa zincir geçişlerde kamera hafifçe uzaklaşır (hız hissi).

### 2.3 Tırmanma sarmaşığı
| Parametre | Değer | Not |
|---|---|---|
| Tutunma yarıçapı | 0.7 m | Havadayken el sarmaşık çizgisine bu kadar yaklaşınca |
| Tırmanma hızı | 3.5 m/s | Yukarı/aşağı; uçlarda 0.15 m pay |
| Yana zıplama | 6.5 m/s yatay + 1.8 m yükseklik | Yön tuşu basılıyken zıpla |
| Yana zıplama girdi kilidi | 0.15 sn | Celeste tarzı; zıplama yönü bozulmaz |
| Yön tuşsuz zıplama | Yukarı sıçrama | Aynı sarmaşığa 0.25 sn sonra tekrar tutunulur → hızlı tırmanma |
| Aşağı + alt uç / yere değme | Sarmaşığı bırakır | |

## 3. Savaş — Sarmaşık Kamçısı "Çatal"
| Hamle | Girdi | Etki |
|---|---|---|
| Kamçı vuruşu | Saldırı | 3'lü kombo; menzil 2.5 m; 1–1–2 hasar |
| Yukarı / aşağı vuruş | Yön + Saldırı | Aşağı vuruş (yalnız havada) düşmana değerse **zıplatır** (pogo) |
| Kamçı Kancası | Kanca tuşu | 8 m menzil; kanca çiçeğine yapışır veya küçük düşmanı sersemletir |
| Öz Çekimi | Kanca (basılı tut) | Hafif düşman/nesneyi oyuncuya çeker; ağır nesneye oyuncuyu çeker |
| Savrulma Saldırısı | Sallanırken Saldırı | Oyuncu çevresinde 2 m yarıçap; sarmaşık hızı ≥ 8 m/s ise 2, değilse 1 hasar (M2'de eklendi) |
| Kök Darbesi | Havada aşağı + Saldırı (basılı) | Yere çakılma, alan hasarı (sonradan) |

### 3.1 Kamçı sayıları (M2, `PlayerTuning` "Kamçı")
| Parametre | Değer | Not |
|---|---|---|
| Vuruş süresi | 0.26 sn | İsabet yalnızca 0.05–0.16 sn arası aktif |
| İsabet hacmi (ileri) | 2.5 × 1.2 × 1.2 m kutu | Gövde ortasından bakış yönüne |
| İsabet hacmi (yukarı / aşağı) | 1.2 × 2.5 × 1.2 m kutu | Aşağı: ayak tabanının 0.3 m üstünden aşağı |
| Kombo penceresi | 0.30 sn | Vuruş bittikten sonra; geç basılırsa kombo 1. vuruşa döner |
| Saldırı tamponu | 0.15 sn | Erken basılan saldırı hatırlanır |
| 3. vuruş sonrası bekleme | 0.30 sn | |
| Pogo hızı | 10 m/s yukarı | ≈ normal zıplama (10.3 m/s) |
| Düşman geri itme | 5 m/s | + 0.2 sn sersemleme |
| Hit-stop | 50 ms, zaman ölçeği 0.05 | Gerçek zamanlı zamanlayıcı ile geri döner |
| Fizik katmanları | world 1 · player 2 · enemy 3 · hurtbox 4 · hazard 5 | `scripts/core/layers.gd`; kamçı yalnızca **hurtbox** katmanını sorgular |

### 3.2 Can (M2, `PlayerTuning` "Can")
- **Can sistemi:** Can "yaprak" olarak gösterilir; başlangıç 5 yaprak (`GameState.leaves` / `max_leaves`).
- **Öz (enerji):** Düşman vurdukça dolar; iyileşme (basılı tut, 1 sn) ve özel yeteneklerde harcanır. *(M5+)*
- **Hasar alma:** 0.8 sn dokunulmazlık (yanıp sönme), 0.25 sn kontrolsüz geri itilme (6 m/s yatay, 5 m/s yukarı).
- **Çukura düşüş:** Son güvenli noktaya dönüş + **1 yaprak** (karar 2026-11-25), geri itilme yok.
- **Ölüm (0 yaprak):** "Alpay düştü…" → 1.2 sn sonra **oda baştan, tam can**, düşmanlar yeniden doğar (karar 2026-11-25). M4'te "son Ocak'a dön" olur.
- **Hit-stop:** Vuruşta 50 ms, boss'a kritik vuruşta 100 ms; kamera titremesi küçük.

## 4. Yetenek Ağacı (kazanılma sırası)
| # | Yetenek | Fiil | Bölge |
|---|---|---|---|
| 0 | Koş / Zıpla / Tutun / Sallan / Kamçı | temel | Başlangıç |
| 1 | **Kamçı Kancası** | uzaktan tutun | Kök Dibi |
| 2 | **Öz Çekimi** | çek / çekil | Öz Damarları |
| 3 | **Kabuk Pençesi** | duvara tutun, duvar zıplaması | Kabuk Duvarı |
| 4 | **Yaprak Pelerin** | süzül, rüzgârla yüksel | Yuva Dalları |
| 5 | **Tohum Atışı** | kendi sarmaşığını yetiştir | Taç |
| 6 | **Kök Dalışı** | yumuşak köklerden geç (kısa ışınlanma) | Erlik (Perde 2) |
| 7 | **Umay Tüyü** | çift zıplama | Gizli / Gök |
| 8 | **Gök Kamçısı** | yıldırımlı kamçı, metal/kehribar kırar | Gök Katları |

## 5. Derinlik Modu (3D kamera)
Mağaraya girince veya özel tetikleyicide kamera karakterin arkasına döner:
- Hareket **X-Z düzleminde serbest**, kameraya göre (ileri = kameradan uzağa).
- Zıplama, kamçı ve sallanma aynı çalışır; sarkaç hesabı 3D'de anchor'a doğru düzlemde yapılır.
- Tetik çıkışında karakter en yakın yan-mod rayına (Z=0 veya tanımlı ray) yumuşakça geri çekilir.
- Derinlik modunda kullanılacak içerikler: mağara keşfi, gizli geçitler, boss arenaları, perspektif bulmacaları (yandan bakınca kapalı görünen yolların arkadan açık olması).

## 6. Bulmaca Türleri
1. **Özsu akışı:** Kapak ve vanalarla özsu yönlendirme → platform yükselir, kehribar erir.
2. **Işık-mantar:** Kamçıyla vurulan mantarlar geçici ışık verir; bazı platformlar sadece ışıkta görünür.
3. **Ağırlık sarmaşıkları:** Bir sarmaşıkta asılı kalınca karşı taraftaki kapı açılır.
4. **Büyüme zamanlaması:** Tohumla yetişen sarmaşık 6 sn yaşar; sırayla dikilerek yol kurulur.
5. **Derinlik bulmacası:** Yan görünümde kapalı yol, 3D modda arkadan dolaşılarak açılır.
6. **Düşman kullanma:** Öz Çekimi ile şişkin spor düşmanını çekip patlatarak kapı kırmak.

## 7. Kontroller
| Eylem | Gamepad | Klavye |
|---|---|---|
| Hareket | Sol çubuk | A/D (derinlikte W/S de) |
| Zıpla | A / Çarpı | Space |
| Saldırı (kamçı) | X / Kare | J / Sol tık (W+J yukarı, havada S+J aşağı) |
| Kanca / Öz Çekimi | RT | K / Sağ tık |
| Tutun / Bırak | LT (veya otomatik) | Shift |
| İyileş | B / Daire (basılı) | L |
| Harita | Select | Tab |
| Duraklat | Start | Esc |

**Otomatik tutunma** varsayılan açık: havadayken tutunma yarıçapındaki sarmaşık otomatik yakalanır; bırakmak için zıpla. Ayarlardan "manuel tutunma"ya geçilebilir.
