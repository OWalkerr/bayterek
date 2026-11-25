# BAYTEREK

*Kökten göğe bir tırmanış.*

Kökler arasında büyümüş yetim **Alpay**, sarmaşık kamçısıyla Hayat Ağacı Bayterek'in dibinden göğün katlarına tırmanır; çürüklüğün kaynağını ve kendisini aşağıya kimin, neden bıraktığını öğrenir.

- **Tür:** Dikey metroidvania / aksiyon platformer
- **Motor:** Godot 4.6 (GDScript)
- **Görünüm:** 3D dünya, yandan kamera; mağaralarda 3D derinlik kamerası
- **Hedef:** PC / Steam · test için Web build

## Şu an ne var? (M0 — greybox prototip)
`scenes/main/main.tscn` çalıştırıldığında:
- Kapsül Alpay: koşma, değişken yükseklikte zıplama, coyote time, jump buffer
- Sarmaşıktan sarmaşığa **kinematik sarkaç sallanma** (pompalama, ip kısaltma/uzatma, momentumlu bırakma, "mükemmel bırakma")
- Mağara ağzında kameranın **3D derinlik moduna** dönmesi; mağarada X-Z serbest hareket, çıkışta raya geri dönüş
- Çukura düşünce son güvenli noktaya dönüş
- Debug HUD (F1)

Kontroller: **A/D** hareket · **Space** zıpla / sarmaşığı bırak · **W/S** ip kısalt-uzat (mağarada ileri-geri) · **F1** debug.

## Belgeler
Tüm tasarım `docs/` altında; başlangıç noktası `docs/00_VISION.md`. Claude ile çalışırken `CLAUDE.md` ve `.claude/skills/bayterek-dev/` kullanılır.

## Test
```bash
godot --headless --path . --import
godot --headless --path . res://tests/validate_scripts.tscn
godot --headless --path . res://tests/test_movement.tscn
```
