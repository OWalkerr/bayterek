# Yol Haritası

## Dikey Dilim — "Kök Dibi" (hedef: oynanabilir 20–30 dk)
Her milestone sonunda: headless testler geçer + web build tarayıcıda oynanır + bu dosyada durum güncellenir.

| # | Milestone | Kapsam | Bitti sayılır… | Durum |
|---|---|---|---|---|
| **M0** | Kurulum & Greybox | Proje iskeleti, autoload'lar, kapsül oyuncu, greybox oda, sarkaç sallanma, kamera modları | Kapsülle koşup zıplayıp sarmaşıklar arası sallanılabiliyor; mağara bölgesinde kamera 3D'ye dönüyor | ✅ Prototip hazır |
| **M1** | Hareket hissi | Tuning, coyote/buffer, tırmanma sarmaşığı, çürük sarmaşık, mükemmel bırakma, debug HUD | 3 test odası "sadece hareket" ile keyifli | ✅ 2026-11-25 — 3 oda (Savrulma Zinciri, Tırmanma Kuyusu, Çürük Geçit), bot ile baştan sona geçiliyor; F2 canlı tuning. Oynanış hissi kullanıcı testini bekliyor |
| **M2** | Savaş temeli | Kamçı 3'lü kombo, pogo, hasar/can, 2 düşman (Çürük Sürüngen, Spor Şişkini), durum makinesi bölme | Düşmanlı oda oynanabilir | ✅ 2026-11-25 — Oda 4 "Çürük Yuvası": kombo, Savrulma Saldırısı (eklendi), pogo kapısı; yaprak HUD'u; durum makinesi `states/` altına bölündü; bot odayı bitiriyor |
| **M3** | Kamera & Derinlik | Input continuity, SideRail dönüşü, oda sınırları, look-ahead; Phantom Camera kararı | 1 mağara (derinlik modu) tam oynanış | ✅ 2026-11-25 — Oda 5 "Yankı Mağarası" (yan → derinlik → 3D sarkaç → arka koridor); input continuity, SideRail, oda sınırları, ölü bölge, look-ahead, düşüş odağı, geçiş yavaşlaması; **Phantom Camera kullanılıyor** (yedek arka uç testli) |
| **M4** | Dünya altyapısı | Room/RoomDoor/SceneRouter, kayıt (Ocak), harita verisi, GameState kalıcılığı | 6 oda arası gezinti + kayıt/yükleme | ✅ 2026-11-25 — Kök Dibi greybox: Ocak Odası + 5 oda, 10 kapı geçişi (karartma, hız korunur), 2 Ocak, kalıcı Kut parçası, kayıt v2 (Ocak + kapıda oto), ölümde son Ocak, harita ekranı (Tab); test_m4 tüm kapıları fiziksel doğruluyor |
| **M5** | Kök Dibi greybox | 12–15 oda, Kamçı Kancası yeteneği, kapılar, gizli oda, 2 Kut parçası | Bölge baştan sona greybox oynanır | ✅ 2026-11-25 — 13 oda (7 yeni), Kamçı Kancası (Sunak), kanca kapıları (Ocak Odası tavanı, Kanca Bahçesi, Çiçek Kuyusu), derinlik sırrı → Gizli Oda, 2 Kut parçası, 3 Ocak (boss eşiği dahil), Öz barı + iyileşme; botlar kancalı geçişleri ve kancasız engelleri doğruluyor |
| **M6** | Boss: Kökyiyen | 3 faz, 3D arena → yan mod kovalamaca | Boss yenilebilir, adil | ⬜ |
| **M7** | Sanat geçişi | Alpay + Kocabaş + 4 düşman + boss AI modelleri, modüler çevre seti, stilize shader, ışık | Bölge "son görünüm"e %70 yakın | ⬜ |
| **M8** | Hikaye & Sinematik | C01 açılış, C02, C03, Dialogue Manager, letterbox, atlama | Dilim başı-sonu hikaye ile bağlanır | ⬜ |
| **M9** | Ses & Cila | Müzik katmanları, SFX, juice listesi, ana menü, ayarlar, erişilebilirlik | Dışarıdan biri oynayıp bitirebiliyor | ⬜ |
| **M10** | Dilim teslimi | Web + Windows build, 3 kişilik playtest, düzeltmeler | Steam sayfası / trailer için kullanılabilir | ⬜ |

## Web build
Her milestone sonunda `tools/deploy_web.sh` → `gh-pages` dalı → https://owalkerr.github.io/bayterek/

## Dilim Sonrası (taslak)
| Faz | İçerik |
|---|---|
| Üretim 1 | Öz Damarları + Kabuk Duvarı (2 bölge, 2 boss, 2 yetenek) |
| Üretim 2 | Yuva Dalları (köy, NPC'ler, yan görevler) + Erlik bölümü |
| Üretim 3 | Taç + Gök Katları + final + iki son |
| Cila | Dengeleme, lokalizasyon (EN), Steam entegrasyonu (başarımlar, bulut kayıt) |

## Riskler
| Risk | Etki | Önlem |
|---|---|---|
| Sallanma hissi "yüzer" veya "sert" çıkar | Yüksek | M1'i uzun tut, debug HUD + canlı tuning |
| AI modellerin stil tutarsızlığı | Yüksek | Ortak stilize shader + palet + prompt şablonu |
| Kamera geçişinde yön karmaşası | Orta | Input continuity + az ve anlamlı derinlik modu |
| Web build performansı | Orta | Erken ve sık web testi; LOD; ışık bütçesi |
| Kapsam büyümesi | Yüksek | Dilimi bitirmeden yeni bölge yok |
