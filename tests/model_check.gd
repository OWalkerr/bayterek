extends Node
## AI model kalite kontrolü: assets/models altındaki her .glb/.gltf/.fbx'i ModelValidator ile ölçer.
## Çalıştır (önce --import): godot --headless --path . res://tests/model_check.tscn
## Hata varsa çıkış kodu 1. Model yoksa bilgi verip 0 ile çıkar.

const MODELS_DIR: String = "res://assets/models"


func _ready() -> void:
	var paths := ModelValidator.find_models(MODELS_DIR)
	print("[MODEL] %d model bulundu (%s)" % [paths.size(), MODELS_DIR])
	var failures := 0
	for path: String in paths:
		var packed := load(path) as PackedScene
		if packed == null:
			print("[MODEL] ✗ %s — yüklenemedi (import edildi mi?)" % path)
			failures += 1
			continue
		var inst := packed.instantiate() as Node3D
		if inst == null:
			print("[MODEL] ✗ %s — kök düğüm Node3D değil" % path)
			failures += 1
			continue
		add_child(inst)
		var r := ModelValidator.validate_scene(inst, path)
		print(ModelValidator.format_report(r))
		if not r["ok"]:
			failures += 1
		_rig_line(inst, path)
		inst.queue_free()
	print("[MODEL] bitti — hatalı: %d" % failures)
	get_tree().quit(1 if failures > 0 else 0)


## Deri bağlı modeller için rig özeti: kemik sayısı, ölü kemik, bağsız köşe, 20° bükmede yırtılma.
## Bilgi amaçlı (çıkış kodunu etkilemez); bağsız köşe / sol-sağ sızıntısı zaten validate_scene'de değil, burada uyarı.
func _rig_line(inst: Node3D, path: String) -> void:
	if ModelValidator.kind_of(path) == &"anim":
		return
	var rr := ModelValidator.rig_report(inst)
	if (rr["bones"] as Array).is_empty():
		return
	var bt := ModelValidator.bend_test(inst, 20.0)
	var torn := float(bt.get("worst_torn", 0.0)) * 100.0
	var verdict := "iyi" if torn < 0.1 else ("kabul (sert gövde eklemi)" if torn < 0.6 else "SORUNLU — ağırlık düzelt")
	print("[RIG]   %s: %d kemik, ölü %d, bağsız köşe %d, 20° bükmede yırtık %%%.2f (%s) → %s%s" % [
			ModelValidator.name_of(path), (rr["bones"] as Array).size(), (rr["dead"] as Array).size(), rr["unweighted"],
			torn, bt.get("worst_torn_bone", "-"), verdict,
			"" if (rr["errors"] as PackedStringArray).is_empty() else " | " + "; ".join(rr["errors"])])
