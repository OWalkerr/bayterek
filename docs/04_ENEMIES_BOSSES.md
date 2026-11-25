# Düşmanlar & Bosslar

## Düşman Tasarım İlkeleri
- Her düşman bir **soru** sorar; cevabı bir hareket/yetenektir.
- Okunabilir hazırlık animasyonu (telegraph): saldırıdan en az 0.4 sn önce görsel + ses ipucu.
- Çürüklük dokunuşu: bozulmuş düşmanlar mor damarlı, gözleri sarı.

## Düşman Kataloğu (ilk sürüm)
| Ad | Bölge | Davranış | Sorduğu soru |
|---|---|---|---|
| **Çürük Sürüngen** | Kök Dibi | Zeminde yürür, kenarda döner | "Vurabiliyor musun?" (öğretici) |
| **Spor Şişkini** | Kök Dibi | Havada süzülür, vurulunca patlar, zehirli bulut | "Mesafeni koruyabiliyor musun?" |
| **Kapan Çiçek** | Kök Dibi | Tavandan sarkar, yaklaşınca ısırır; sarmaşık gibi görünür | "Dikkat ediyor musun?" |
| **Kök Yılanı** | Kök Dibi | Duvar deliklerinden fırlar | "Zamanlama?" |
| **Kehribar Böceği** | Öz Damarları | Kabuğu var; arkadan veya aşağı vuruşla kırılır | "Pogo / konumlanma?" |
| **Özsu Balçığı** | Öz Damarları | İkiye bölünür | "Önceliklendirme?" |
| **Kabuk Akbabası** | Kabuk Duvarı | Dalış saldırısı; sallanırken saldırır | "Havada savaşabilir misin?" |
| **Rüzgâr İnsi** | Kabuk Duvarı | Oyuncuyu iter | "Kontrolünü korur musun?" |
| **Kuzgun Kam** | Yuva / Taç | Uzaktan büyü atar, ışınlanır | "Kanca ile yakalayabilir misin?" |
| **Polen Kovanı** | Taç | Böcek sürüsü üretir | "Kaynağı yok edebilir misin?" |

### Uygulanan düşmanlar (M2, greybox)
| Düşman | Sınıf | Can | Davranış (sayılar) | Durumlar |
|---|---|---|---|---|
| Çürük Sürüngen | `RotCrawler` | 3 | 2 m/s yürür; duvarda ve 0.6 m önünde zemin yoksa döner; temas 1 hasar | WALK, STAGGER |
| Spor Şişkini | `SporeBloater` | 1 | Yuvasında süzülür (±0.25 m); 6 m içindeki oyuncuya yatayda 1 m/s sürüklenir (yuvadan en fazla 5 m); temas 1 hasar; ölünce **Spor Bulutu** | IDLE, DRIFT, STAGGER |
| Spor Bulutu | `SporeCloud` | – | 1.8 m yarıçap; 0.3 sn büyür (uyarı), sonra 2 sn içindeki oyuncuya 1 hasar. Kamçı menzili 2.5 m > 1.8 m → uzaktan vurmak güvenli | – |

- Ortak taban: `Enemy` (`scripts/enemies/enemy.gd`) — can, Hurtbox (katman 4), temas hasarı, geri itilme, beyaz parlama, ölüm ve isteğe bağlı **yeniden doğma** (`respawn_time`). Yol açmak için gereken düşmanlar (ör. pogo basamağı Şişkin) yeniden doğar → soft-lock yok.

AI uygulaması: Basit düşmanlar GDScript durum makinesi (`EnemyStateMachine`). Karmaşık bosslar için LimboAI (yalnızca PC build'inde test edilmişse) veya kendi `BossPhaseController`'ımız.

## Boss Tasarım Şablonu
Her boss için doldurulacak:
1. **Fantezi:** Oyuncu ne hissetmeli?
2. **Arena:** Yan mod mu, derinlik modu mu, ikisi arası mı?
3. **Fazlar:** 2–3 faz; her faz yeni bir saldırı + arena değişimi.
4. **Öğrettiği şey:** Bu boss hangi yeteneğin ustalığını sınar?
5. **Ödül:** Yetenek / hikaye bilgisi.

## Bosslar

### B1 — Kökyiyen (Dikey dilim boss'u)
- **Fantezi:** "Köklerin içinden gelen dev bir solucan, mağarayı yutuyor."
- **Arena:** Dairesel mağara — **derinlik modu (3D)**; Faz 3'te tavan çöker, kamera yan moda döner ve dövüş dikey sallanma kovalamacasına dönüşür.
- **Faz 1 (3D):** Zeminden çıkıp dalış yapar; oyuncu sırtındaki parlayan çürük keselerine kamçıyla vurur. Saldırılar: yerden fırlama (zemin çatlak ipucu), kuyruk süpürmesi (zıpla).
- **Faz 2 (3D):** Mağara duvarlarına girip çıkar; arenaya Spor Şişkinleri çağırır. Tavandaki sarmaşıklara tutunup ondan kaçmak gerekir.
- **Faz 3 (Yan mod, kovalamaca):** Tavan çöker; Kökyiyen aşağıdan yükselirken oyuncu sarmaşıktan sarmaşığa yukarı kaçar, son anda ağzına kamçıyla bir kök kayası çekerek bitirir.
- **Öğrettiği:** Sallanma + kamçı + kanca + iki kamera modunun birlikte kullanımı.
- **Ödül (karar 2026-11-25):** Kocabaş'ın ilk mesajı (hikaye anı) + **Kut parçası** + can tam dolar. (Kamçı Kancası M5'te Sunak'a taşındı.)

#### B1 uygulaması (M6, greybox) — `scripts/bosses/`
| Parça | Sınıf | Not |
|---|---|---|
| Boss + faz denetleyici | `Rooteater` | `enum Phase {DORMANT, INTRO, ONE, TWO, CHASE, FINALE, DEFEATED}` × `enum Action {BURROWED, TELEGRAPH, ERUPT, EXPOSED, SWEEP_TELL, SWEEP, BURROW}`; tüm süreler @export |
| Çürük kesesi (zayıf nokta) | `BossWeakPoint` (Enemy) | Yalnızca açıktayken vurulur → kamçı, Öz, hit-stop, pogo aynen çalışır |
| Hasar hacimleri | `BossHazard` | Gövde, fırlama sütunu, süpürme halkası; katman "hazard" |
| Faz 3 ağız | `RisingMaw` | Öldürmez; lastik bant hız |
| Final kayası | `RootRock` (GrappleFlower) | Kancayla tutulunca kopar, ağza düşer |

| Sayı | Faz 1 | Faz 2 |
|---|---|---|
| Gömülü bekleme | 0.8 sn | 0.5 sn |
| **Çatlak uyarısı** (oyuncunun altında) | 1.0 sn | 0.8 sn |
| Fırlama (sütun, r 1.6 m) | 0.5 sn | 0.5 sn |
| Açıkta (kese vurulabilir) | 2.8 sn | 3.0 sn |
| Oyuncuya dönüş hızı (kese sırtta → etrafından dolaş) | 40°/sn | 50°/sn |
| Süpürme uyarısı → süpürme (yerde 1 m yükseklik) | 0.7 → 0.35 sn, r 6 m | 0.7 → 0.35 sn, **tüm arena** (zıpla / tavan sarmaşığı) |
| Ek | — | Her döngüde 2 Spor Şişkini (en çok 3, 1.8 m yükseklikte — derinlikte ileri kamçıyla vurulabilir) |
| Kese canı | 8 | 8 |

**Faz 3 kovalamaca:** "Tavan çöküyor!" → karartma → kuyunun dibi (SIDE). Ağız −6 m'den yükselir; kuyu zemini **ağız gelince** kırılır (≈ 3 sn tırmanma payı). Hız 2.2 m/s; oyuncu 14 m'den uzaksa 4.0, 4 m'den yakınsa 1.0. **Ağız öldürmez** (karar 2026-11-25): değerse 1 yaprak + 16 m/s yukarı fırlatma, ağız 1.5 sn durur ve 3 m geri çekilir (ölüm döngüsü yok). Yol: tırmanma A → kanca çiçeği → tırmanma B → çiçek → tırmanma C → tepe çıkıntısı → **kök kayasına kanca** → kaya ağza düşer → yenilgi.

**Zorluk denemeleri (bot, test_m6):** mükemmel zamanlamalı bot 3/3–5/5 kazanır, ort. ≈ 60 sn, 0–1 yaprak kaybı (faz 1 ≈ 7 sn, faz 2 ≈ 20–50 sn, kovalamaca ≈ 16 sn). Bot uyarıları "bilerek" oynadığı için bu bir **alt sınır**; gerçek zorluk kullanıcı denemeleriyle ayarlanır (tüm sayılar `Rooteater`/`RisingMaw` @export). Ayarlama sırasında bulunanlar: Faz 2'de 2.4 sn/65°/sn'de keseye hiç ulaşılamıyordu; Şişkinler 3 m'de kamçı menzili dışındaydı; kovalamaca zemini 1.2 sn'de çöküp ağız+fırlatma ölüm döngüsü yaratıyordu.

### B2 — Kehribar Bekçisi
Kehribara gömülü eski bir golem; özsu akışını boss sırasında değiştirerek zayıf noktasını eritmek gerekir. Öz Çekimi ile kehribar parçaları fırlatılır.

### B3 — Yel Ana
Fırtına ruhu kadın; arena sürekli rüzgârlı dikey bir şaft. Oyuncu rüzgâr yönüne göre sallanma ritmini ayarlar; yıldırım düşen sarmaşıklar yanar.

### B4 — Tepegöz
Dalları kıran tek gözlü dev. Arena yatay; dev dalı kırdıkça arena daralır. Gözüne ulaşmak için Kabuk Pençesi ile vücuduna tırmanılır (Shadow of the Colossus anı, **derinlik modu**).

### B5 — Etçil Çiçek Kraliçesi
Arena ortasında dev çiçek; kökleri platform, yaprakları kapan. Tohum Atışı ile kendi sarmaşıklarını yetiştirip ağzına ulaşmak gerekir.

### B6 — Karakuş (Final)
- **Faz 1 (Yan):** Gök katlarında bulutların arasında dalışlar; sırtına kanca atılarak tutunulur.
- **Faz 2 (Derinlik):** Kanatlarının üstünde, uçarken 3D dövüş.
- **Faz 3 (Yan, dikey düşüş):** Birlikte ağacın kalbine düşülür; düşerken sallanma ve saldırı.
- **Faz 4 (Hikaye):** Anne Gökbike'nin ışığıyla birleşik son vuruş.

## Mini-bosslar (dikey dilim)
- **Kapan Çiçek Anası:** Kök Dibi ortasında; 3 kapan başı, sarmaşık zincirinin ortasında.
