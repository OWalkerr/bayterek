# BAYTEREK

*Kökten göğe bir tırmanış.*

Kökler arasında büyümüş yetim **Alpay**, sarmaşık kamçısıyla Hayat Ağacı Bayterek'in dibinden göğün katlarına tırmanır; çürüklüğün kaynağını ve kendisini aşağıya kimin, neden bıraktığını öğrenir.

- **Tür:** Dikey metroidvania / aksiyon platformer
- **Motor:** Godot 4.6 (GDScript)
- **Görünüm:** 3D dünya, yandan kamera; mağaralarda 3D derinlik kamerası
- **Hedef:** PC / Steam · test için Web build

## Şu an ne var? (M1 — hareket hissi)
**Oyna:** https://owalkerr.github.io/bayterek/ (tarayıcı, klavye)

`scenes/main/main.tscn` çalıştırıldığında 4 greybox oda (0–3 tuşu):
- **0 Kök Ağzı** — M0 prototipi: sallanma, mağarada 3D derinlik kamerası, yukarı zincir
- **1 Savrulma Zinciri** — yere basmadan yükselen sarmaşık zinciri, mükemmel bırakma
- **2 Tırmanma Kuyusu** — tırmanma sarmaşıkları arası yana zıplama
- **3 Çürük Geçit** — 1.5 sn'de kopan çürük sarmaşıklar, durmadan akış

Mekanikler: koşma, değişken zıplama, coyote time, jump buffer, kinematik sarkaç sallanma (pompalama, ip kısaltma, momentumlu bırakma, mükemmel bırakma ışıltısı), tırmanma, çürük sarmaşık, havada momentum koruma, güvenli noktaya dönüş.

Kontroller: **A/D** hareket · **Space** zıpla / bırak · **W/S** ip kısalt-uzat, tırman (mağarada ileri-geri) · **R** odayı yeniden başlat · **F1** debug · **F2** canlı tuning.

## Belgeler
Tüm tasarım `docs/` altında; başlangıç noktası `docs/00_VISION.md`. Claude ile çalışırken `CLAUDE.md` ve `.claude/skills/bayterek-dev/` kullanılır.

## Test
```bash
godot --headless --path . --import
godot --headless --fixed-fps 60 --path . res://tests/validate_scripts.tscn
godot --headless --fixed-fps 60 --path . res://tests/test_movement.tscn
godot --headless --fixed-fps 60 --path . res://tests/test_m1.tscn
```
