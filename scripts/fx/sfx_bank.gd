class_name SfxBank
extends RefCounted
## Kodla üretilen geçici ses efektleri (docs/08 §Ses). Dosya gerektirmez; açılışta bir kez sentezlenir
## (22 kHz mono, 16 bit) ve önbellekte tutulur. Gerçek ses dosyası gelince `OVERRIDE_DIR` altına aynı
## adla (`jump.ogg`, `whip.wav` …) konur; varsa sentez yerine o yüklenir.
##
## Sesler bilinçli olarak kısa, yumuşak ve "kartun" tonda: mağara/orman atmosferini bastırmasın.

const MIX_RATE: int = 22050
const OVERRIDE_DIR: String = "res://assets/audio/sfx/"
## Tüm ses adları (Juice bunları kullanır; testler hepsinin üretildiğini denetler).
const NAMES: Array[StringName] = [&"jump", &"land", &"step", &"whip", &"hit", &"kill", &"hurt", &"grab",
		&"release", &"perfect", &"pickup", &"heal", &"break", &"rumble", &"climb", &"swing_wind"]

static var _cache: Dictionary = {}


static func get_stream(sfx_name: StringName) -> AudioStream:
	if _cache.has(sfx_name):
		return _cache[sfx_name]
	var stream: AudioStream = _load_override(sfx_name)
	if stream == null:
		stream = _synth(sfx_name)
	_cache[sfx_name] = stream
	return stream


static func _load_override(sfx_name: StringName) -> AudioStream:
	for ext: String in [".ogg", ".wav", ".mp3"]:
		var path := OVERRIDE_DIR + String(sfx_name) + ext
		if ResourceLoader.exists(path):
			return load(path) as AudioStream
	return null


static func _synth(sfx_name: StringName) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(sfx_name)
	match sfx_name:
		&"jump":
			# Yukarı kayan yumuşak "fuup" + hafif hava
			return _render(0.16, func(t: float, k: float, n: float) -> float:
				return sin(TAU * _sweep(t, 260.0, 560.0, 0.16)) * 0.35 * _env(k, 0.05, 2.5) + n * 0.12 * _env(k, 0.1, 3.0), rng, 0.35)
		&"land":
			# Alçak gümleme + toprak hışırtısı
			return _render(0.2, func(t: float, k: float, n: float) -> float:
				return sin(TAU * _sweep(t, 110.0, 45.0, 0.2)) * 0.8 * _env(k, 0.01, 4.0) + n * 0.35 * _env(k, 0.005, 6.0), rng, 0.25)
		&"step":
			return _render(0.06, func(_t: float, k: float, n: float) -> float:
				return n * 0.5 * _env(k, 0.02, 5.0), rng, 0.2)
		&"whip":
			# Hava yaran kamçı: tize kayan gürültü + sonda çat
			return _render(0.18, func(t: float, k: float, n: float) -> float:
				var swish := n * 0.45 * _env(k, 0.5, 2.0)
				var crack := n * 0.9 * (1.0 if k > 0.55 and k < 0.62 else 0.0)
				return swish + crack + sin(TAU * _sweep(t, 900.0, 1800.0, 0.18)) * 0.08 * _env(k, 0.6, 3.0), rng, 0.85)
		&"hit":
			# Tok vuruş: kısa alçak darbe + tık
			return _render(0.14, func(t: float, k: float, n: float) -> float:
				return sin(TAU * _sweep(t, 180.0, 60.0, 0.14)) * 0.9 * _env(k, 0.005, 5.0) + n * 0.5 * _env(k, 0.002, 12.0), rng, 0.45)
		&"kill":
			# Pof + aşağı inen ton (çürük dağılıyor)
			return _render(0.32, func(t: float, k: float, n: float) -> float:
				return sin(TAU * _sweep(t, 520.0, 160.0, 0.32)) * 0.4 * _env(k, 0.01, 3.0) + n * 0.4 * _env(k, 0.01, 4.0), rng, 0.3)
		&"hurt":
			# Boğuk, titreşimli inen ton
			return _render(0.28, func(t: float, k: float, n: float) -> float:
				var f := _sweep(t, 240.0, 110.0, 0.28) + sin(TAU * 30.0 * t) * 0.002
				return _soft_square(TAU * f) * 0.4 * _env(k, 0.01, 2.5) + n * 0.15 * _env(k, 0.0, 6.0), rng, 0.3)
		&"grab":
			# Sarmaşık gerilmesi: kısa kalın gıcırtı
			return _render(0.1, func(t: float, k: float, n: float) -> float:
				return _soft_square(TAU * (170.0 + 20.0 * sin(TAU * 60.0 * t)) * t) * 0.3 * _env(k, 0.05, 4.0) + n * 0.2 * _env(k, 0.0, 8.0), rng, 0.3)
		&"release":
			# Savrulma: kabaran ve sönen hava
			return _render(0.26, func(_t: float, k: float, n: float) -> float:
				return n * 0.55 * _env(k, 0.35, 2.0), rng, 0.6)
		&"perfect":
			# Parlak çan: iki kısmi ton (oktav + beşli), uzun sönüm
			return _render(0.6, func(t: float, k: float, _n: float) -> float:
				return (sin(TAU * 988.0 * t) * 0.3 + sin(TAU * 1480.0 * t) * 0.18 + sin(TAU * 1976.0 * t) * 0.08) * _env(k, 0.005, 3.5), rng, 0.0)
		&"pickup":
			# Yukarı arpej (Kut parçası, Öz)
			return _render(0.36, func(t: float, k: float, _n: float) -> float:
				var f := 660.0 if t < 0.09 else (880.0 if t < 0.18 else 1320.0)
				return sin(TAU * f * t) * 0.35 * _env(k, 0.01, 2.0), rng, 0.0)
		&"heal":
			return _render(0.5, func(t: float, k: float, _n: float) -> float:
				var f := _sweep(t, 440.0, 880.0, 0.5)
				return (sin(TAU * f) * 0.25 + sin(TAU * f * 1.5) * 0.1) * _env(k, 0.2, 2.0), rng, 0.0)
		&"break":
			# Çürük sarmaşık kopması: çatırtı
			return _render(0.22, func(_t: float, k: float, n: float) -> float:
				var crackle := n * (1.0 if fposmod(k * 37.0, 1.0) < 0.35 else 0.15)
				return crackle * 0.7 * _env(k, 0.0, 3.0), rng, 0.7)
		&"rumble":
			# Boss / çöküş gümbürtüsü
			return _render(0.9, func(t: float, k: float, n: float) -> float:
				return (sin(TAU * 42.0 * t) * 0.5 + n * 0.5) * _env(k, 0.1, 1.5), rng, 0.04)
		&"climb":
			return _render(0.07, func(_t: float, k: float, n: float) -> float:
				return n * 0.35 * _env(k, 0.1, 4.0), rng, 0.4)
		&"swing_wind":
			# Döngü: sallanma hızıyla sesi açılan rüzgâr (Juice ses düzeyini sürer)
			var w := _render(1.0, func(t: float, _k: float, n: float) -> float:
				return n * (0.5 + 0.2 * sin(TAU * 2.0 * t)), rng, 0.5)
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = int(MIX_RATE * 1.0) - 1
			return w
	push_warning("SfxBank: bilinmeyen ses %s" % sfx_name)
	return _render(0.01, func(_t: float, _k: float, _n: float) -> float: return 0.0, rng, 0.0)


## Örnekleri üretir. `fn(t sn, k 0..1 ilerleme, n süzülmüş gürültü)`. `brightness` gürültü süzgeci
## (0 = çok boğuk, 1 = ham beyaz gürültü).
static func _render(duration: float, fn: Callable, rng: RandomNumberGenerator, brightness: float) -> AudioStreamWAV:
	var count := maxi(1, int(duration * MIX_RATE))
	var data := PackedByteArray()
	data.resize(count * 2)
	var lp := 0.0
	var a := clampf(brightness, 0.02, 1.0)
	for i in count:
		var t := float(i) / MIX_RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * a
		var v := clampf(float(fn.call(t, float(i) / count, lp)), -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = MIX_RATE
	w.stereo = false
	w.data = data
	return w


## Sönüm zarfı: `attack` (0..1, sürenin oranı) içinde açılır, sonra üstel söner.
static func _env(k: float, attack: float, decay: float) -> float:
	if attack > 0.0 and k < attack:
		return k / attack
	return exp(-decay * (k - attack) * 3.0)


## Doğrusal frekans kaymasının faz integrali (döngü sayısı): sin(TAU * _sweep(...)).
static func _sweep(t: float, f0: float, f1: float, duration: float) -> float:
	return f0 * t + (f1 - f0) * t * t / (2.0 * duration)


static func _soft_square(phase: float) -> float:
	return tanh(sin(phase) * 3.0)
