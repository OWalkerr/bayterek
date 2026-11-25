# Dünya & Bölgeler

Dünya **dikey bir kule** gibidir: aşağıdan yukarı 6 ana bölge. Metroidvania yapısı gereği bölgeler arasında yatay sapmalar, kısayollar ve geri dönüş yolları vardır.

```
            ┌──────────────────────────┐
   6        │   GÖK KATLARI  (final)   │  bulut platformlar, Ülgen'in sarayı
            ├──────────────────────────┤
   5        │   TAÇ                    │  dev çiçekler, biyolüminesans
            ├────────────┬─────────────┤
   4        │ YUVA DALLARI│  (yan dal)  │  kuş halkının dal şehri
            ├────────────┴─────────────┤
   3        │   KABUK DUVARI           │  dış kabuk, rüzgâr, fırtına
            ├──────────────────────────┤
   2        │   ÖZ DAMARLARI           │  gövde içi, altın özsu nehirleri
            ├──────────────────────────┤
   1        │   KÖK DİBİ  ◄ DİKEY DİLİM│  kök mağaraları (3D derinlik), Erlik sınırı
            └──────────────────────────┘
```

## Bölge Kartları

### 1. Kök Dibi — *"Doğduğun yer değil, büyüdüğün yer"*
- **Atmosfer:** Mor-mavi gölgeler, parlayan mantarlar, yosun, sarkan kökler. Derinden gelen nabız sesi.
- **Mekanik odağı:** Temel sallanma, kök tırmanma, ilk kamçı savaşları, **ilk 3D mağara geçişleri**.
- **Kazanılan yetenek:** Kamçı Kancası (bölge sonu).
- **Boss:** Kökyiyen (3D arena).
- **Oda sayısı (dikey dilim):** 12–15 oda + 2 mağara (derinlik modu) + 1 boss odası + 1 gizli oda.
- **Renk:** `#2B1E3F` (gölge moru), `#4FB3A9` (mantar ışığı), `#E8A33D` (Öz altını, vurgu).

### 2. Öz Damarları
- **Atmosfer:** Gövdenin içi; kehribar duvarlar, akan altın özsu, içinde donmuş eski yaratıklar.
- **Mekanik:** Özsu akışını kapaklarla yönlendirme bulmacaları; özsu üzerinde kayma; kehribara gömülü platformlar.
- **Yetenek:** Öz Çekimi (kamçıyla nesne/düşman çekmek).
- **Boss:** Kehribar Bekçisi.

### 3. Kabuk Duvarı
- **Atmosfer:** Ağacın dış yüzü; uçsuz bucaksız dikey kabuk duvarları, uzakta bulutlar, fırtınalar.
- **Mekanik:** Rüzgâr akımları, duvar tırmanma, yıldırım zamanlamalı geçişler.
- **Yetenek:** Kabuk Pençesi (duvara tutunma/tırmanma).
- **Boss:** Yel Ana.

### 4. Yuva Dalları
- **Atmosfer:** Dal üstüne kurulu kuş halkı şehri; asma köprüler, sıcak ışıklar. Oyunun "köyü": NPC'ler, tüccar, yan görevler.
- **Mekanik:** Asma köprülerde ağırlık bulmacaları, uzun sallanma zincirleri.
- **Yetenek:** Yaprak Pelerin (süzülme).
- **Boss:** Tepegöz (dalları kıran dev).

### 5. Taç
- **Atmosfer:** Dev çiçekler, polen bulutları, renk patlaması; ama çürüklüğün en yoğun olduğu yer.
- **Mekanik:** Etçil bitkilere yem verme, polen bulutlarıyla yükselme, Tohum Atışı ile kendi sarmaşığını yetiştirme.
- **Yetenek:** Tohum Atışı.
- **Boss:** Etçil Çiçek Kraliçesi.

### 6. Gök Katları
- **Atmosfer:** Beyaz-altın, sessiz, bulut platformlar; Ülgen'in uyuyan sarayı.
- **Mekanik:** Tüm yeteneklerin birleşik kullanımı; ters yerçekimi odaları.
- **Yetenek:** Umay Tüyü (çift zıplama) — aslında oyunun ortasında gizli bir yoldan da alınabilir.
- **Final:** Karakuş + Kalp.

## Yetenek Kapıları (Gating Matrisi)
| Engel | Açan yetenek | İlk göründüğü bölge |
|---|---|---|
| Uzak kanca çiçekleri | Kamçı Kancası | Kök Dibi (görünür ama ulaşılamaz) |
| Ağır kütük/kayalar | Öz Çekimi | Kök Dibi (gizli oda) |
| Pürüzsüz yüksek duvar | Kabuk Pençesi | Öz Damarları |
| Geniş uçurum | Yaprak Pelerin | Kabuk Duvarı |
| Sarmaşıksız boşluk | Tohum Atışı | Yuva Dalları |
| Yüksek çıkıntı | Umay Tüyü | Kök Dibi (en baştan görünür!) |
| Yumuşak kök duvarı | Kök Dalışı (Erlik'ten) | Her bölgede gizli yollar |

**Kural:** Her kapı, açılmadan en az bir bölge önce oyuncuya **gösterilir**. Oyuncu "buraya sonra döneceğim" demeli.

## Toplanabilirler
- **Kut Parçaları (24 adet):** Gizli; 4'ü = +1 can yaprağı. Hepsi = gerçek son.
- **Öz Damlaları:** Para birimi (Yuva Dalları'ndaki tüccar ve Ocak'larda yükseltme).
- **Bitig Sayfaları:** Lore; yaratıklar ve mitoloji ansiklopedisi.
- **Tohumlar:** Kamçıya modifiye takılan "tılsımlar" (Hollow Knight charm sistemi benzeri, sade).

## Kayıt Noktaları — "Ocak"
- Küçük ateş ocakları; oturunca can dolar, düşmanlar yeniden doğar, harita güncellenir.
- Bölge başına 3–5 adet. Boss odasının hemen öncesinde mutlaka bir Ocak.

## Oda Tasarım Kuralları
1. Bir oda = bir fikir. (Ör: "aralıklı yanan mantarlar arası sallanma".)
2. Her odada en az bir **dikey hedef** görünür olmalı (yukarıda bir ışık, bir kapı).
3. Ölüm cezası düşük: dikey düşüşlerde oyuncu son güvenli platforma döner, sadece biraz can kaybeder.
4. Derinlik modu (3D) oda başına en fazla **bir** kez ve her zaman bir sebeple: gizli geçit, boss arenası, mağara keşfi.
5. Birim ölçeği: **1 Godot birimi = 1 metre**. Alpay ≈ 1.6 m. Standart zıplama yüksekliği ≈ 2.2 m. Sallanma noktaları arası tipik mesafe 4–7 m.
