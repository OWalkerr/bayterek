# Arayüz & Deneyim (UI/UX)

## İlkeler
1. **Ekran dünyaya ait.** HUD minimum; bilgi mümkünse dünyada (karakterin parlaması, kolyenin ışığı).
2. **Okunabilirlik > süs.** Mitolojik süsler çerçevelerde; metinlerde değil.
3. **Gamepad önce.** Tüm menüler yön tuşlarıyla gezilebilir; odak her zaman görünür.
4. **Erişilebilirlik ilk günden:** Metin boyutu, renk körü modu, ekran sarsıntısı kapatma, zaman yavaşlatma kapatma, otomatik/manuel tutunma, tuş atama.

## Renk Paleti
| Rol | Renk | Kullanım |
|---|---|---|
| Öz Altını | `#E8A33D` | Vurgular, Öz barı, seçili öğe |
| Yosun | `#5E8C4A` | Can yaprakları, pozitif |
| Kök Gölgesi | `#2B1E3F` | Panel arka planları |
| Mantar Işığı | `#4FB3A9` | Etkileşim ipuçları |
| Çürüklük | `#5A1E5C` + `#C9D93B` (göz sarısı) | Düşman/tehlike |
| Gök Beyazı | `#F4EFE3` | Metin |
| Gök Mavisi | `#9CC9E8` | Gök bölgesi, rüya |

## Tipografi
- **Başlık:** Göktürk yazısından ilham alan, köşeli, özel çizilmiş bir başlık logotipi ("BAYTEREK"). Menü başlıkları için sert hatlı bir serif (ör. *Cinzel* benzeri, Türkçe karakter destekli bir aile seçilecek).
- **Metin:** Okunaklı, Türkçe karakter destekli sans: *Nunito* veya *Inter* (ğ, ş, ı, İ kontrolü şart).
- Metin boyutu min. 24 px @1080p; ayardan %75–150 arası.

## HUD (sol üst, kompakt)
```
 🍃🍃🍃🍃🍂     ← Can yaprakları (dolu yeşil / boş kuru)
 ▰▰▰▰▱▱       ← Öz barı (altın, damar dokulu)
 ◆ 128         ← Öz damlası (para) — sadece değişince 3 sn görünür
```
- **M2 durumu:** Yapraklar `GameHud` ile çiziliyor (dolu `#5E8C4A`, kuru `#7A5A3A`, kaybedilen yaprak 0.3 sn büyür). Öz barı ve para M5+.
- **M5:** Yaprakların altında **Öz barı** (200×12 px, altın dolgu, her 33'te bir iyileşme eşiği çizgisi). Yetenek kazanınca ekran ortasında "YENİ YETENEK" kartı (ad + tek cümle + tuş ipucu, 3.5 sn, oyun durmaz). Kanca hedefi: çiçek altın parlar.
- **M4:** Sağ altta kayıt anında 1.5 sn "Kaydedildi"; Ocak yanında dünyada "W · Dinlen" (Label3D).
- **Font notu:** Web'deki varsayılan fontta ◆ ● ★ gibi simgeler yok (kutu görünür) → simgeler şekil olarak çizilir ya da düz metin kullanılır; asıl fontlar M9'da (Nunito/Inter, Türkçe karakterler).
- Sağ alt: yetenek kazanıldığında veya kanca hedefi görüldüğünde küçük tuş ipucu.
- Mini harita yok (keşfi öldürmesin); harita menüde. İsteğe bağlı mini harita ayarı.

## Menüler
| Ekran | İçerik |
|---|---|
| **Ana menü** | Arka planda canlı Bayterek sahnesi (kamera yavaşça yukarı kayar). Devam / Yeni Oyun / Ayarlar / Çıkış. **M4 greybox:** Yeni Oyun / Devam (kayıt varsa) + geliştirici test odaları |
| **Duraklatma** | Sekmeler: Harita · Yetenekler · Bitig (günlük/ansiklopedi) · Tohumlar · Ayarlar |
| **Harita** | Dikey ağaç silüeti üzerinde keşfedilmiş odalar; Ocak'lar, kapılar, işaretler. Bölgeler ağaç katmanı olarak açılır. **M4 greybox:** `MapScreen` — ziyaret edilen oda kutuları (kök gölgesi dolgu), kapı bağlantıları (mantar ışığı çizgi), bulunulan oda altın çerçeve + elmas, Ocak altın nokta; açıkken oyun durur. |
| **Bitig** | Yaratıklar, karakterler, mitoloji; Göktürk esintili sayfa tasarımı |
| **Ocak ekranı** | Kayıt + dinlenme; tohum takma |
| **Yetenek kazanma** | Tam ekran kısa an: yeteneğin adı + tek cümle + kısa gösterim animasyonu |
| **Boss isim kartı** | Alt-orta, iki satır: *"KÖKYİYEN — Köklerin Açlığı"* |

## Diyalog Balonları
- Konuşanın başının üstünde küçük balon (oyun içi) veya alt-orta kart (sinematik).
- Karakter portresi yok; karakter rengi ile ince çerçeve (Alpay: altın, Kocabaş: yosun, Gökbike: gök beyazı).
- Metin harf harf akar (atlanabilir).

## Geri Bildirim (Juice) Listesi
- Sallanma bırakmada "mükemmel bırakma" ışıltısı + kısa ses.
- Kamçı vuruşunda hit-stop + yaprak parçacıkları.
- Can kaybında ekran kenarında kısa mor damar efekti.
- Yetenek kazanımında Öz akışı karakterin damarlarında parlar.
- Ocak'a oturunca müzik yumuşar, ateş sesi.

## Lokalizasyon
- Tüm metinler `tr()` ile; `data/localization/strings.csv` (keys, tr, en).
- Diyaloglar Dialogue Manager'ın çeviri desteğiyle CSV'ye aktarılır.
