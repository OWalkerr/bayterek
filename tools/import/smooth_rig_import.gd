@tool
extends EditorScenePostImport
## İçe aktarma sonrası: AI oto-rig'li modellerin deri ağırlıklarını RigSmoother ile yumuşatır.
## `.glb.import` → `import_script/path="res://tools/import/smooth_rig_import.gd"`.
## Yineleme sayısı dosya adına göre (sert ağırlık ne kadar sorunluysa o kadar). docs/07 §7.6.
## Yalnız editör/içe aktarmada çalışır; dışa aktarılan oyun zaten işlenmiş sahneyi taşır.

const ITERATIONS := {
	"boss_kokyiyen": 12,
	"enm_rot_crawler": 8,
	"npc_kocabas": 8,
}
const DEFAULT_ITERATIONS := 6
## class_name yerine preload: temiz klonda ilk içe aktarmada sınıf önbelleği henüz hazır olmayabilir.
const Smoother := preload("res://scripts/art/rig_smoother.gd")
## Katı olması gereken parçayı bölen kemikler → hedef. Kocabaş (kaplumbağa): Tripo kabuğu ön/arka
## gövde ve kabuk çıkıntısı kemiklerine bölmüş; bükülünce kabuk ortadan yırtılıyordu → hepsi köke.
## Bacaklar, boyun, kafa, kuyruk serbest kalır.
const MERGE := {
	"npc_kocabas": {
		"tripo__Spine_0": "tripo__Root", "bone_11": "tripo__Root", "bone_20": "tripo__Root",
		"bone_22": "tripo__Root", "bone_23": "tripo__Root", "bone_26": "tripo__Root",
		"bone_24": "tripo__Root", "bone_25": "tripo__Root", "bone_27": "tripo__Root",
	},
}


func _post_import(scene: Node) -> Object:
	var base := get_source_file().get_file().get_basename()
	var it: int = ITERATIONS.get(base, DEFAULT_ITERATIONS)
	for n: Node in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.skin != null:
			if MERGE.has(base):
				mi.set_meta(&"rig_merged", Smoother.merge_bones(mi, MERGE[base]))
			Smoother.smooth_instance(mi, it)
			mi.set_meta(&"rig_smoothed", it)
	return scene
