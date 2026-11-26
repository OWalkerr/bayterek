class_name RigSmoother
extends RefCounted
## Oto-rig ağırlık yumuşatıcı. AI oto-rig'leri (Tripo) çoğu köşeyi tek kemiğe sert bağlar;
## eklem bükülünce mesh yırtılır. Burada ağırlıklar mesh komşuluğu üzerinde Laplace ile
## yayılır: w ← (1-α)·w + α·ort(komşular). UV dikişindeki kopya köşeler konumdan kaynaklanır
## (aynı ağırlığı alır, dikiş açılmaz). Köşe başına en büyük 4 etki tutulur, toplam 1'e normalize.
## docs/07 §7.6.

const MAX_INFLUENCES := 4


## Deri bağlı MeshInstance3D'nin mesh'ini yumuşatılmış ağırlıklarla yeniden kurar (yerinde).
static func smooth_instance(mi: MeshInstance3D, iterations: int = 8, alpha: float = 0.5) -> void:
	if mi.skin == null or mi.mesh == null:
		return
	var src := mi.mesh
	var out := ArrayMesh.new()
	for s in src.get_surface_count():
		var arrays := src.surface_get_arrays(s)
		if (arrays[Mesh.ARRAY_BONES] as Variant) != null and not (arrays[Mesh.ARRAY_BONES] as PackedInt32Array).is_empty():
			_smooth_arrays(arrays, iterations, alpha)
		var flags := Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if (arrays[Mesh.ARRAY_BONES] as PackedInt32Array).size() == (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() * 8 else 0
		out.add_surface_from_arrays(src.surface_get_primitive_type(s), arrays, [], {}, flags)
		out.surface_set_material(s, src.surface_get_material(s))
		out.surface_set_name(s, src.surface_get_name(s))
	out.resource_name = src.resource_name
	mi.mesh = out


## Kemik birleştirme: `merge` = {kaynak_kemik: hedef_kemik}. Kaynağın ağırlıkları hedefe aktarılır
## (ör. kaplumbağa kabuğu iki kardeş kemiğe bölünmüşse ikisi de köke → kabuk katı kalır).
## Hedef kemiğin deride bağı yoksa (ölü kemik) dinlenme pozundan yeni bağ eklenir. Skin kopyalanır.
static func merge_bones(mi: MeshInstance3D, merge: Dictionary) -> int:
	if mi.skin == null or mi.mesh == null or merge.is_empty():
		return 0
	var skeleton := mi.get_node_or_null(mi.skeleton) as Skeleton3D
	if skeleton == null:
		return 0
	var skin := mi.skin.duplicate() as Skin
	var bind_of := {}   # kemik adı → bağ indeksi
	for b in skin.get_bind_count():
		var bname := String(skin.get_bind_name(b))
		if bname == "" and skin.get_bind_bone(b) >= 0:
			bname = skeleton.get_bone_name(skin.get_bind_bone(b))
		bind_of[bname] = b
	var remap := {}     # kaynak bağ → hedef bağ
	for src: String in merge:
		var dst: String = merge[src]
		if not bind_of.has(src):
			continue
		if not bind_of.has(dst):
			var bone := skeleton.find_bone(dst)
			if bone < 0:
				continue
			skin.add_named_bind(dst, skeleton.get_bone_global_rest(bone).affine_inverse() * _bind_offset(skin, skeleton))
			bind_of[dst] = skin.get_bind_count() - 1
		remap[int(bind_of[src])] = int(bind_of[dst])
	if remap.is_empty():
		return 0
	var src_mesh := mi.mesh
	var out := ArrayMesh.new()
	var moved := 0
	for s in src_mesh.get_surface_count():
		var arrays := src_mesh.surface_get_arrays(s)
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		if not bones.is_empty():
			var nv := (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			var per := bones.size() / nv
			for v in nv:
				var d := {}
				for k in per:
					var w := weights[v * per + k]
					if w <= 0.0:
						continue
					var b := bones[v * per + k]
					if remap.has(b):
						b = int(remap[b])
						moved += 1
					d[b] = float(d.get(b, 0.0)) + w
				var top := _top(d)
				var k2 := 0
				for b: int in top:
					bones[v * per + k2] = b
					weights[v * per + k2] = float(top[b])
					k2 += 1
				while k2 < per:
					bones[v * per + k2] = 0
					weights[v * per + k2] = 0.0
					k2 += 1
			arrays[Mesh.ARRAY_BONES] = bones
			arrays[Mesh.ARRAY_WEIGHTS] = weights
		out.add_surface_from_arrays(src_mesh.surface_get_primitive_type(s), arrays)
		out.surface_set_material(s, src_mesh.surface_get_material(s))
		out.surface_set_name(s, src_mesh.surface_get_name(s))
	out.resource_name = src_mesh.resource_name
	mi.mesh = out
	mi.skin = skin
	return moved


## Bağ pozları mesh uzayı → kemik uzayı. Mevcut bir bağdan mesh↔iskelet ofsetini çıkarır
## (bağ = global_rest⁻¹ · ofset ⇒ ofset = global_rest · bağ); ofset genelde birim dönüşümdür.
static func _bind_offset(skin: Skin, skeleton: Skeleton3D) -> Transform3D:
	for b in skin.get_bind_count():
		var bone := skin.get_bind_bone(b)
		if bone < 0:
			bone = skeleton.find_bone(skin.get_bind_name(b))
		if bone >= 0:
			return skeleton.get_bone_global_rest(bone) * skin.get_bind_pose(b)
	return Transform3D.IDENTITY


static func _smooth_arrays(arrays: Array, iterations: int, alpha: float) -> void:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var nv := verts.size()
	var per := bones.size() / nv
	# 1) Konuma göre kaynak: aynı noktadaki kopyalar tek "düğüm".
	var key_of := {}
	var node_of := PackedInt32Array()
	node_of.resize(nv)
	var node_count := 0
	for v in nv:
		var k := Vector3i((verts[v] * 10000.0).round())
		if not key_of.has(k):
			key_of[k] = node_count
			node_count += 1
		node_of[v] = int(key_of[k])
	# 2) Düğüm komşuluğu (üçgen kenarları).
	var nbr: Array[PackedInt32Array] = []
	nbr.resize(node_count)
	var seen := {}
	for t in range(0, idx.size(), 3):
		for e in 3:
			var a := node_of[idx[t + e]]
			var b := node_of[idx[t + (e + 1) % 3]]
			if a == b:
				continue
			var ek := mini(a, b) * node_count + maxi(a, b)
			if seen.has(ek):
				continue
			seen[ek] = true
			nbr[a].append(b)
			nbr[b].append(a)
	# 3) Düğüm başına seyrek ağırlık sözlüğü {kemik: w} (ilk kopyadan).
	var w_of: Array[Dictionary] = []
	w_of.resize(node_count)
	for v in nv:
		var n := node_of[v]
		if not w_of[n].is_empty():
			continue
		var d := {}
		for k in per:
			var w := weights[v * per + k]
			if w > 0.0:
				d[bones[v * per + k]] = float(d.get(bones[v * per + k], 0.0)) + w
		w_of[n] = d
	# 4) Laplace yayılımı.
	for _it in iterations:
		var next: Array[Dictionary] = []
		next.resize(node_count)
		for n in node_count:
			var cnt := nbr[n].size()
			if cnt == 0:
				next[n] = w_of[n]
				continue
			var d := {}
			for b: int in w_of[n]:
				d[b] = float(w_of[n][b]) * (1.0 - alpha)
			var share := alpha / float(cnt)
			for m in nbr[n]:
				for b: int in w_of[m]:
					d[b] = float(d.get(b, 0.0)) + float(w_of[m][b]) * share
			next[n] = _top(d)
		w_of = next
	# 5) Geri yaz.
	var out_b := PackedInt32Array()
	var out_w := PackedFloat32Array()
	out_b.resize(nv * per)
	out_w.resize(nv * per)
	for v in nv:
		var d := w_of[node_of[v]]
		var k := 0
		for b: int in d:
			if k >= per:
				break
			out_b[v * per + k] = b
			out_w[v * per + k] = float(d[b])
			k += 1
	arrays[Mesh.ARRAY_BONES] = out_b
	arrays[Mesh.ARRAY_WEIGHTS] = out_w


## En büyük MAX_INFLUENCES etkiyi tutar, normalize eder (büyükten küçüğe sıralı).
static func _top(d: Dictionary) -> Dictionary:
	var pairs: Array = []
	for b: int in d:
		pairs.append([b, float(d[b])])
	pairs.sort_custom(func(a: Array, c: Array) -> bool: return float(a[1]) > float(c[1]))
	var out := {}
	var total := 0.0
	for i in mini(MAX_INFLUENCES, pairs.size()):
		if float(pairs[i][1]) < 0.01:
			break
		total += float(pairs[i][1])
	for i in mini(MAX_INFLUENCES, pairs.size()):
		if float(pairs[i][1]) < 0.01:
			break
		out[int(pairs[i][0])] = float(pairs[i][1]) / total
	return out
