# BAYTEREK

*Kökten göğe bir tırmanış.*

Kökler arasında büyümüş yetim **Alpay**, sarmaşık kamçısıyla Hayat Ağacı Bayterek'in dibinden göğün katlarına tırmanır; çürüklüğün kaynağını ve kendisini aşağıya kimin, neden bıraktığını öğrenir.

- **Tür:** Dikey metroidvania / aksiyon platformer
- **Motor:** Godot 4.6 (GDScript)
- **Görünüm:** 3D dünya, yandan kamera; mağaralarda 3D derinlik kamerası
- **Hedef:** PC / Steam · test için Web build

## Şu an ne var? (M5 — Kök Dibi greybox)
**Oyna:** https://owalkerr.github.io/bayterek/ (tarayıcı, klavye)

Menüden **Yeni Oyun** → Kök Dibi: 13 oda. Doğuya ilerle, Sunak Odası'nda **Kamçı Kancası**'nı al (K / sağ tık), kanca çiçekleriyle Kanca Bahçesi ve Çiçek Kuyusu'nu aşıp Kökyiyen Eşiği'ne ulaş; sonra Ocak Odası'na dönüp tavandaki çiçekle Üst Kökler'e çık ve duvarın sırrını bul. Ocak'ta (W) dinlen/kaydet; **L** basılı = Öz'le iyileş; **Tab** harita; 2 Kut parçası.

Geliştirici test odaları (0–5 tuşu, kayıt almaz):
- **0 Kök Ağzı** — M0 prototipi: sallanma, mağarada 3D derinlik kamerası, yukarı zincir
- **1 Savrulma Zinciri** — yere basmadan yükselen sarmaşık zinciri, mükemmel bırakma
- **2 Tırmanma Kuyusu** — tırmanma sarmaşıkları arası yana zıplama
- **3 Çürük Geçit** — 1.5 sn'de kopan çürük sarmaşıklar, durmadan akış
- **4 Çürük Yuvası** — Çürük Sürüngen + Spor Şişkini; kombo, Savrulma Saldırısı, pogo kapısı
- **5 Yankı Mağarası** — yandan mağaraya gir, derinlikte uçurumu sarmaşıkla aş, arka katmandaki koridordan çık

Kamera: Phantom Camera ile SIDE↔DEPTH geçişi (konum + FOV tween, 0.85x yavaşlama), girdi sürekliliği, ölü bölge, look-ahead, alt üçte bir odak / düşerken alt yarı, oda sınırları, SideRail.

Mekanikler: koşma, değişken zıplama, coyote time, jump buffer, kinematik sarkaç sallanma (pompalama, ip kısaltma, momentumlu bırakma, mükemmel bırakma ışıltısı), tırmanma, çürük sarmaşık, havada momentum koruma, güvenli noktaya dönüş.

Savaş: kamçı 3'lü kombo (1–1–2), yukarı vuruş, havada aşağı vuruş = pogo, sallanırken Savrulma Saldırısı, 5 yaprak can, hasar/dokunulmazlık, çukura düşüş = −1 yaprak, ölüm = oda baştan.

Kontroller: **A/D** hareket · **Space** zıpla / bırak · **W/S** ip kısalt-uzat, tırman (mağarada ileri-geri) · **J / sol tık** kamçı (W+J yukarı, havada S+J aşağı) · **R** odayı yeniden başlat · **F1** debug · **F2** canlı tuning.

## Belgeler
Tüm tasarım `docs/` altında; başlangıç noktası `docs/00_VISION.md`. Claude ile çalışırken `CLAUDE.md` ve `.claude/skills/bayterek-dev/` kullanılır.

## Test
```bash
godot --headless --path . --import
godot --headless --fixed-fps 60 --path . res://tests/validate_scripts.tscn
godot --headless --fixed-fps 60 --path . res://tests/test_movement.tscn
godot --headless --fixed-fps 60 --path . res://tests/test_m1.tscn
godot --headless --fixed-fps 60 --path . res://tests/test_m2.tscn
godot --headless --fixed-fps 60 --path . res://tests/test_m3.tscn
godot --headless --fixed-fps 60 --path . res://tests/test_m4.tscn
godot --headless --fixed-fps 60 --path . res://tests/test_m5.tscn
```
