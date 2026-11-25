extends Node
## Tüm scripts/ altındaki .gd dosyalarını yükler; derlenemeyen varsa çıkış kodu 1.
## Çalıştır: godot --headless --path . res://tests/validate_scripts.tscn


func _ready() -> void:
	var files: Array[String] = []
	_collect("res://scripts", files)
	var failures := 0
	for path: String in files:
		var script := load(path) as Script
		if script == null or not script.can_instantiate():
			print("[VALIDATE] FAIL ", path)
			failures += 1
		else:
			print("[VALIDATE] OK   ", path)
	print("[VALIDATE] total=%d failures=%d" % [files.size(), failures])
	get_tree().quit(1 if failures > 0 else 0)


func _collect(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_collect(dir_path.path_join(sub), out)
	for file: String in dir.get_files():
		if file.ends_with(".gd"):
			out.append(dir_path.path_join(file))
