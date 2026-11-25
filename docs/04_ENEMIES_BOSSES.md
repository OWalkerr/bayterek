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
- **Öğrettiği:** Sallanma + kamçı + iki kamera modunun birlikte kullanımı.
- **Ödül:** Kamçı Kancası + Kocabaş'ın ilk mesajı.

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
