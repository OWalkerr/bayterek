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
		inst.queue_free()
	print("[MODEL] bitti — hatalı: %d" % failures)
	get_tree().quit(1 if failures > 0 else 0)
