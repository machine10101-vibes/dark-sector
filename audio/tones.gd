extends Node

var voices: Array = []
var clips: Dictionary = {}
var ready_audio := false


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	for i in 6:
		var node := AudioStreamPlayer.new()
		node.volume_db = -7.0
		add_child(node)
		voices.append(node)
	clips = {
		"gun": _gun_crack(),
		"heavy": _heavy_boom(),
		"stake": _stake_snap(),
		"laser": _laser_hiss(),
		"missile": _missile_whoosh(),
		"pd": _pd_chatter(),
		"launch": _tone(420.0, 0.12, 0.3, 0.8),
		"dock": _tone(540.0, 0.1, 0.28, 1.0),
		"hit": _tone(150.0, 0.09, 0.4, 1.4),
		"hail": _tone(660.0, 0.22, 0.25, 0.6),
		"extract": _tone(280.0, 0.16, 0.3, 0.7),
		"scan_done": _tone(740.0, 0.18, 0.28, 0.5),
		"install": _tone(190.0, 0.2, 0.4, 0.6),
		"destroyed": _tone(80.0, 0.28, 0.45, 0.5),
		"thrust": _tone(110.0, 0.14, 0.22, 0.8),
		"save": _tone(360.0, 0.12, 0.22, 0.9),
		"lock": _tone(1180.0, 0.16, 0.2, 0.4),
		"shield": _tone(240.0, 0.12, 0.3, 1.0),
		"dry": _tone(70.0, 0.1, 0.3, 1.6),
	}
	ready_audio = true


func play(kind: String) -> void:
	if not ready_audio:
		return
	if not clips.has(kind):
		return
	var voice: AudioStreamPlayer = voices[0]
	for node in voices:
		var slot := node as AudioStreamPlayer
		if not slot.playing:
			voice = slot
			break
	voice.stream = clips[kind]
	voice.play()


func _tone(freq: float, duration: float, volume: float, decay: float) -> AudioStreamWAV:
	return _render(duration, func(t: float, env: float) -> float:
		return sin(TAU * freq * t) * volume * env
	, decay)


func _gun_crack() -> AudioStreamWAV:
	return _render(0.12, func(t: float, env: float) -> float:
		var bang: float = _noise(t * 980.0) * exp(-t * 52.0)
		var body: float = sin(TAU * 190.0 * t) * exp(-t * 20.0)
		var brass: float = sin(TAU * 1860.0 * t) * exp(-t * 42.0)
		var slap: float = sin(TAU * 420.0 * t) * exp(-t * 28.0)
		return (bang * 0.6 + body * 0.62 + brass * 0.32 + slap * 0.22) * env * 0.74
	, 1.55)


func _heavy_boom() -> AudioStreamWAV:
	return _render(0.26, func(t: float, env: float) -> float:
		var thump: float = sin(TAU * (62.0 - t * 28.0) * t) * exp(-t * 7.5)
		var blast: float = _noise(t * 360.0) * exp(-t * 14.0)
		var ring: float = sin(TAU * 310.0 * t) * exp(-t * 11.0)
		var shell: float = _noise(t * 88.0 + 4.0) * exp(-t * 6.0)
		return (thump * 1.05 + blast * 0.48 + ring * 0.2 + shell * 0.16) * env * 0.82
	, 1.05)


func _stake_snap() -> AudioStreamWAV:
	return _render(0.1, func(t: float, env: float) -> float:
		var tick: float = _noise(t * 1680.0) * exp(-t * 62.0)
		var iron: float = sin(TAU * 1240.0 * t) * exp(-t * 34.0)
		var coil: float = sin(TAU * 2480.0 * t) * exp(-t * 48.0)
		var low: float = sin(TAU * 140.0 * t) * exp(-t * 22.0)
		return (tick * 0.38 + iron * 0.5 + coil * 0.28 + low * 0.3) * env * 0.7
	, 1.75)


func _laser_hiss() -> AudioStreamWAV:
	return _render(0.22, func(t: float, env: float) -> float:
		var hz: float = 820.0 - t * 460.0
		var arc: float = sin(TAU * hz * t)
		var hiss: float = _noise(t * 2600.0) * (0.3 + 0.7 * absf(sin(TAU * 70.0 * t)))
		var hum: float = sin(TAU * 96.0 * t) * 0.42
		var zip: float = sin(TAU * 1480.0 * t) * exp(-t * 12.0)
		return (arc * 0.28 + hiss * 0.72 + hum + zip * 0.18) * env * 0.52
	, 0.62)


func _missile_whoosh() -> AudioStreamWAV:
	return _render(0.3, func(t: float, env: float) -> float:
		var ignite: float = sin(TAU * (48.0 + t * 55.0) * t) * exp(-t * 5.2)
		var rush: float = _noise(t * 240.0 + 11.0) * (0.18 + t * 1.7)
		var hiss: float = _noise(t * 1100.0) * exp(-t * 7.0)
		var rumble: float = sin(TAU * 36.0 * t) * (0.35 + t * 0.4)
		return (ignite * 0.68 + rush * 0.58 + hiss * 0.2 + rumble * 0.28) * env * 0.72
	, 0.78)


func _pd_chatter() -> AudioStreamWAV:
	return _render(0.09, func(t: float, env: float) -> float:
		var pulse: float = 0.12
		if t < 0.016 or (t > 0.026 and t < 0.04) or (t > 0.05 and t < 0.064):
			pulse = 1.0
		var tick: float = _noise(t * 2700.0) * pulse
		var ping: float = sin(TAU * 3400.0 * t) * pulse * exp(-t * 36.0)
		var body: float = sin(TAU * 520.0 * t) * pulse * 0.35
		return (tick * 0.52 + ping * 0.42 + body) * env * 0.64
	, 2.1)


func _noise(seed: float) -> float:
	return fposmod(sin(seed * 12.9898) * 43758.5453, 1.0) * 2.0 - 1.0


func _render(duration: float, voice: Callable, decay: float) -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in count:
		var t := float(i) / float(rate)
		var env := pow(1.0 - float(i) / float(count), decay)
		var sample := float(voice.call(t, env))
		var iv := int(clampf(sample * 32767.0, -32767.0, 32767.0))
		bytes[i * 2] = iv & 255
		bytes[i * 2 + 1] = (iv >> 8) & 255
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = bytes
	return wav
