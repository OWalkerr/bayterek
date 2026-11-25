# BAYTEREK

*Kökten göğe bir tırmanış.*

Kökler arasında büyümüş yetim **Alpay**, sarmaşık kamçısıyla Hayat Ağacı Bayterek'in dibinden göğün katlarına tırmanır; çürüklüğün kaynağını ve kendisini aşağıya kimin, neden bıraktığını öğrenir.

- **Tür:** Dikey metroidvania / aksiyon platformer
- **Motor:** Godot 4.6 (GDScript)
- **Görünüm:** 3D dünya, yandan kamera; mağaralarda 3D derinlik kamerası
- **Hedef:** PC / Steam · test için Web build

## Şu an ne var? (M2 — savaş temeli)
**Oyna:** https://owalkerr.github.io/bayterek/ (tarayıcı, klavye)

`scenes/main/main.tscn` çalıştırıldığında 5 greybox oda (0–4 tuşu):
- **0 Kök Ağzı** — M0 prototipi: sallanma, mağarada 3D derinlik kamerası, yukarı zincir
- **1 Savrulma Zinciri** — yere basmadan yükselen sarmaşık zinciri, mükemmel bırakma
- **2 Tırmanma Kuyusu** — tırmanma sarmaşıkları arası yana zıplama
- **3 Çürük Geçit** — 1.5 sn'de kopan çürük sarmaşıklar, durmadan akış
- **4 Çürük Yuvası** — Çürük Sürüngen + Spor Şişkini; kombo, Savrulma Saldırısı, pogo kapısı

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
```
