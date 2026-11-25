# BAYTEREK — Vizyon Dokümanı

> **Tek cümle:** Kökler arasında büyümüş bir yetim, sarmaşıktan sarmaşığa savrularak Hayat Ağacı Bayterek'in dibinden göğün katlarına tırmanır ve kendisini oraya kimin, neden attığını öğrenir.

## Künye
| Alan | Karar |
|---|---|
| Tür | Dikey metroidvania + aksiyon platformer |
| Perspektif | Tam 3D dünya, **yandan kamera (2.5D)**; mağaralarda ve özel anlarda **3D derinlik kamerası** |
| Motor | Godot 4.6.x (GDScript, Jolt fizik) |
| Hedef platform | PC / Steam (gamepad öncelikli, klavye+fare tam destek) |
| Test build | Web (HTML5, Compatibility renderer) — tarayıcıdan oynanabilir |
| Ton | Stilize, renkli, büyülü; ama karanlık ve ürkütücü anları olan (Ori × Hollow Knight) |
| Süre hedefi | Tam oyun 6–8 saat; **ilk hedef: dikey dilim (Kök Dibi bölgesi)** |
| Sanat | Kendi ürettiğimiz AI 3D modeller (bkz. `07_ART_PIPELINE.md`) |
| Dil | Türkçe (ana) + İngilizce (ilk günden lokalizasyon altyapısı) |

## Tasarım Sütunları (her karar bunlara göre verilir)
1. **Akış hissi — "Savrulmak keyifli olmalı."** Sarmaşıktan sarmaşığa geçiş oyunun kalbi. Hareket, momentum ve zamanlama her şeyden önce gelir. Bir oda sadece içinden geçmek bile zevkli olmalı.
2. **Yukarı = umut, aşağı = geçmiş.** Dünya dikey. Her katman görsel, müzikal ve hikaye olarak bir öncekinden farklı. Oyuncu "yukarıda ne var?" merakıyla ilerler.
3. **Tek alet, bin kullanım.** Sarmaşık kamçısı hem silah, hem kanca, hem anahtar, hem bulmaca aracıdır. Her yeni yetenek kamçıya yeni bir fiil ekler.
4. **Derinlik bir sırdır.** Kamera 3D'ye döndüğünde oyuncu "bu dünyanın arkası da varmış" der. Derinlik modu nadir, anlamlı ve şaşırtıcı kullanılır.
5. **Mitoloji yaşayan bir dünya.** Türk-Altay mitolojisi (Bayterek, Ülgen, Erlik, Umay, Kut, Karakuş, Tepegöz…) süs değil, dünyanın kurallarıdır.

## Referans Oyunlar (ne alıyoruz?)
| Oyun | Aldığımız şey |
|---|---|
| Ori and the Will of the Wisps | Akışkan hareket, duygusal sinematikler, ışıklı orman estetiği |
| Hollow Knight | Dünya bağlantısı, boss tasarım disiplini, keşif ödülü |
| Celeste | Hassas kontrol hissi (coyote time, jump buffer), oda bazlı zorluk |
| Rayman Legends / DKC Tropical Freeze | Sarmaşık/sallanma ritmi, canlı animasyonlar |
| Trine / Little Nightmares | 2.5D'de 3D dünya, derinlik ve ölçek hissi |
| Metroid Dread | Yetenek kapılı geçitler, boss odaları |

## Kilit Kararlar Kaydı
| Tarih | Karar | Gerekçe |
|---|---|---|
| 2026-11-24 | Tam 3D + yandan kamera | AI 3D model hattı tek, mağara 3D geçişi aynı sahnede kamera değişimiyle yapılır |
| 2026-11-24 | Dünya: Bayterek / Hayat Ağacı | Katmanlı dikey yapı = doğal bölge ayrımı + Türk mitolojisi |
| 2026-11-24 | Kahraman: ormanda büyümüş yetim (Tarzan ruhu) | Sarmaşık hareketine doğal gerekçe |
| 2026-11-24 | Savaş: sarmaşık kamçısı + yakın dövüş | Hareket ve savaş aynı mekaniği paylaşır (Sütun 3) |
| 2026-11-24 | Hikaye kancası: Düşüş ve dönüş; kahramanı annesi korumak için aşağı bırakmış | Duygusal çekirdek + büyük büküm |
| 2026-11-24 | Önce dikey dilim | Riskli mekanikleri (sallanma, kamera geçişi, AI sanat) erken kanıtlamak |
| 2026-11-24 | Saf GDScript çekirdek, GDExtension zorunlu değil | Web test build'i bozmamak için |
| 2026-11-25 | Mükemmel bırakma = ileri-yukarı kolda 35°–70° (tepe ±8° değil) | Tepede hız ≈ 0, bonus anlamsızdı; 35°–70° en uzun atış açısına denk gelir (Sütun 1) |
| 2026-11-25 | Havada koşu hızı üstündeki momentum kırpılmaz | Sallanmadan çıkan hız 0.06 sn'de 7 m/s'ye düşüyordu; akış hissini öldürüyordu (Sütun 1) |
| 2026-11-25 | Sarmaşık zincirleri yükselen dizilir (+2.5 m / 6 m) | Bırakma zıplama bonusu yayı yukarı taşır; zincir doğal olarak yukarı akar (Sütun 2) |
| 2026-11-25 | M1–M3 test odaları kodla kurulan greybox (`GreyboxRoom`), 0–3 tuşu ile seçilir | Oda/kapı sistemi M4'te; şimdilik web build'de hızlı erişim |
| 2026-11-25 | Debug HUD'da canlı tuning paneli (F2) + "Kopyala" | Hareket hissi web build'de oynanarak ayarlanır, değerler .tres'e taşınır |
| 2026-11-25 | M3'te Phantom Camera denenecek; sorun çıkarsa kendi CameraRig'imizle devam | Kullanıcı kararı; CameraDirector API'si sabit kalır |
| 2026-11-25 | Çukura düşüş = güvenli noktaya dönüş + 1 yaprak | Kullanıcı kararı; docs/02 Oda Kuralı 3 ile uyumlu |
| 2026-11-25 | Can 0 → oda baştan, tam can, düşmanlar yeniden doğar (M4'te son Ocak) | Kullanıcı kararı; Ocak sistemi gelene kadar basit ve adil |
| 2026-11-25 | Savrulma Saldırısı M2'ye alındı (≥ 8 m/s → 2 hasar) | Kullanıcı kararı; Sütun 3: kamçı + sallanma aynı fiil |
| 2026-11-25 | Yol açan düşmanlar yeniden doğar (`respawn_time`) | Pogo basamağı Şişkin'i yanlış öldürmek odayı kilitlemesin (soft-lock yok) |
| 2026-11-25 | Oyuncu durum makinesi `scripts/player/states/` altında RefCounted durum nesneleri | player.gd 400 satırı geçti (docs/06 kuralı); düğüm yerine nesne → sahne ağacı sade |
| 2026-11-25 | **Phantom Camera kalıyor** (blend arka ucu), beyin kendi CameraRig'imiz | Web + headless sorunsuz, iki arka uçta tüm testler yeşil; PCam'da 3D oda sınırı / look-ahead yok → bu kısım bizde. Yedek arka uç bayrakla açılır |
| 2026-11-25 | `TimeScale` autoload'u (hit-stop + geçiş yavaşlaması aracısı) | İki sistem aynı anda Engine.time_scale yazıp birbirini bozuyordu |
| 2026-11-25 | Raya çekilme hız sınırı 12 m/s | Büyük Z farkında oyuncu bir karede 4 m ışınlanıp duvar delebiliyordu |
| 2026-11-25 | Mağaradan farklı derinlik katmanına çıkış (SideRail) | Sütun 4: "bu dünyanın arkası da varmış" — Oda 5 arka koridor |
| 2026-11-25 | Kayıt: Ocak'ta tam kayıt + her kapı geçişinde otomatik kayıt | Kullanıcı kararı; tarayıcı kapanınca ilerleme kaybolmasın |
| 2026-11-25 | Ölümde son Ocak'ta tam canla dirilme | Kullanıcı kararı; docs/03 planı, Ocak'lar sık |
| 2026-11-25 | M4'ün 6 odası = mevcut test odaları + Ocak Odası merkezi | Kullanıcı kararı; M4 altyapıya odaklanır, gerçek Kök Dibi M5'te |
| 2026-11-25 | Her oda .tscn (kimlik, harita hücresi, kapılar) + geometri kodda | Kullanıcı kararı; editör açılmıyor, M7'de modeller aynı sahneye |
| 2026-11-25 | Harita: MetSys yerine kendi ızgaramız (MapService, SceneState'ten okur) | MetSys 2D sahne odaklı; tek veri kaynağı oda sahneleri |
| 2026-11-25 | Geliştirici oda seçici (0–5) web build'inde kalır, kayıt almaz | Oynanış testleri web'de; oyuncu kaydını kirletmesin |
| 2026-11-25 | Kamçı Kancası bölge ortasında (Sunak Odası); Kökyiyen'in ödülü başka (Kut/hikaye) | Kullanıcı kararı; gör → kazan → geri dön döngüsü M5'te test edilir |
| 2026-11-25 | Mevcut 6 oda kalır + 7 yeni oda (toplam 13) | Kullanıcı kararı; test edilmiş odalar bölgenin ilk yarısı |
| 2026-11-25 | Öz barı + iyileşme (L 1 sn = 1 yaprak, 33 Öz) M5'te; para Yuva Dalları'nda | Kullanıcı kararı; savaşın risk/ödül döngüsü |
| 2026-11-25 | Gizli oda = derinlik sırrı (sahte duvar, kamera dönünce kaybolur) | Kullanıcı kararı; Sütun 4 |
| 2026-11-25 | Kapı gereksinimi veride (`RoomDoor.requires`) + botla fiziksel doğrulama | Soft-lock ve kapı sızıntısı otomatik yakalansın |
