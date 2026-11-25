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
