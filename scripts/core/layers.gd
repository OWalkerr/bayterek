class_name Layers
extends RefCounted
## Fizik katmanları (project.godot [layer_names] ile aynı sırada). Bit değerleri.

const WORLD: int = 1        # 1: statik dünya
const PLAYER: int = 2       # 2: oyuncu gövdesi
const ENEMY: int = 4        # 3: düşman gövdeleri
const HURTBOX: int = 8      # 4: düşman isabet alanları (kamçı bunları sorgular)
const HAZARD: int = 16      # 5: tehlike alanları (spor bulutu, diken…)
