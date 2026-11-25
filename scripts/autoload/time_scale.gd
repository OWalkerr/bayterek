extends Node
## Zaman ölçeği aracısı: hit-stop (PlayerCombat) ve kamera geçiş yavaşlaması (CameraDirector)
## aynı anda istenebilir; etkin ölçek = aktif isteklerin en küçüğü. Süreler ölçeksiz zamandır.
## Erişilebilirlik: `slowmo_enabled = false` geçiş yavaşlamasını kapatır (Settings M9'da bağlanır).

var slowmo_enabled: bool = true
var _requests: Dictionary = {}    # StringName -> [scale, kalan_sn]


func request(id: StringName, scale: float, duration: float) -> void:
	if duration <= 0.0:
		return
	_requests[id] = [clampf(scale, 0.01, 1.0), duration]
	_apply()


func clear(id: StringName) -> void:
	_requests.erase(id)
	_apply()


func clear_all() -> void:
	_requests.clear()
	_apply()


func is_active(id: StringName) -> bool:
	return _requests.has(id)


func _process(delta: float) -> void:
	if _requests.is_empty():
		return
	# delta ölçeklidir → ölçeksiz zamana çevir
	var real := delta / maxf(Engine.time_scale, 0.0001)
	for id: StringName in _requests.keys():
		var r: Array = _requests[id]
		r[1] = float(r[1]) - real
		if float(r[1]) <= 0.0:
			_requests.erase(id)
	_apply()


func _apply() -> void:
	var s := 1.0
	for r: Array in _requests.values():
		s = minf(s, float(r[0]))
	Engine.time_scale = s
