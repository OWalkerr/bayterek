@tool
extends EditorScenePostImport
## İçe aktarma sonrası: modelin tabanını orijine oturtur (AABB alt yüzü y = 0, yatayda orta).
## Tripo bazen orijini mesh ortasına koyuyor (ör. env_fern_1m_a: taban −0.36 m) → yerleştirince
## yere gömülür. `.glb.import` → `import_script/path="res://tools/import/align_base_import.gd"`.


func _post_import(scene: Node) -> Object:
	var root := scene as Node3D
	if root == null:
		return scene
	var box := AABB()
	var first := true
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var t := Transform3D.IDENTITY
		var p: Node = mi
		while p != null and p != root:
			if p is Node3D:
				t = (p as Node3D).transform * t
			p = p.get_parent()
		var b := t * mi.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if first:
		return scene
	var shift := Vector3(-box.get_center().x, -box.position.y, -box.get_center().z)
	for c: Node in root.get_children():
		if c is Node3D:
			(c as Node3D).position += shift
	return scene
