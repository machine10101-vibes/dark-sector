extends Node

var voices: Array = []
var clips: Dictionary = {}
var ready_audio := false


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	for i in 6:
		var node := AudioStreamPlayer.new()
		node.volume_db = -4.0
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
	var loud := -4.0
	if kind == "heavy":
		loud = -2.2
	elif kind == "missile":
		loud = -3.0
	elif kind == "laser":
		loud = -5.0
	elif kind == "pd":
		loud = -4.6
	voice.volume_db = loud
	voice.stream = clips[kind]
	voice.play()


func _tone(freq: float, duration: float, volume: float, decay: float) -> AudioStreamWAV:
	return _render(duration, func(t: float, env: float) -> float:
		return sin(TAU * freq * t) * volume * env
	, decay)


func _gun_crack() -> AudioStreamWAV:
	return _render(0.16, func(t: float, env: float) -> float:
		var bang: float = _noise(t * 1100.0) * exp(-t * 46.0)
		var body: float = sin(TAU * 168.0 * t) * exp(-t * 16.0)
		var brass: float = sin(TAU * 2140.0 * t) * exp(-t * 36.0)
		var slap: float = sin(TAU * 390.0 * t) * exp(-t * 22.0)
		var case_ping: float = sin(TAU * 2680.0 * t) * exp(-t * 18.0)
		if t < 0.04:
			case_ping = 0.0
		return (bang * 0.7 + body * 0.68 + brass * 0.3 + slap * 0.24 + case_ping * 0.16) * env * 0.8
	, 1.45)


func _heavy_boom() -> AudioStreamWAV:
	return _render(0.38, func(t: float, env: float) -> float:
		var thump: float = sin(TAU * (48.0 - t * 22.0) * t) * exp(-t * 5.8)
		var blast: float = _noise(t * 280.0) * exp(-t * 10.0)
		var ring: float = sin(TAU * 240.0 * t) * exp(-t * 8.5)
		var room: float = _noise(t * 54.0 + 3.0) * exp(-t * 4.2)
		var breech: float = sin(TAU * 720.0 * t) * exp(-t * 20.0)
		return (thump * 1.12 + blast * 0.55 + ring * 0.22 + room * 0.2 + breech * 0.12) * env * 0.86
	, 0.92)


func _stake_snap() -> AudioStreamWAV:
	return _render(0.14, func(t: float, env: float) -> float:
		var charge: float = sin(TAU * (2100.0 + t * 900.0) * t) * exp(-t * 28.0)
		var tick: float = _noise(t * 1880.0) * exp(-t * 58.0)
		var iron: float = sin(TAU * 1360.0 * t) * exp(-t * 30.0)
		var coil: float = sin(TAU * 2740.0 * t) * exp(-t * 42.0)
		var low: float = sin(TAU * 118.0 * t) * exp(-t * 18.0)
		return (charge * 0.32 + tick * 0.36 + iron * 0.48 + coil * 0.3 + low * 0.28) * env * 0.74
	, 1.6)


func _laser_hiss() -> AudioStreamWAV:
	return _render(0.34, func(t: float, env: float) -> float:
		var hz: float = 880.0 - t * 380.0
		var arc: float = sin(TAU * hz * t)
		var hiss: float = _noise(t * 2800.0) * (0.28 + 0.72 * absf(sin(TAU * 62.0 * t)))
		var hum: float = sin(TAU * 88.0 * t) * 0.48
		var zip: float = sin(TAU * 1620.0 * t) * exp(-t * 9.0)
		var beat: float = sin(TAU * 42.0 * t) * 0.2
		return (arc * 0.26 + hiss * 0.78 + hum + zip * 0.16 + beat) * env * 0.5
	, 0.55)


func _missile_whoosh() -> AudioStreamWAV:
	return _render(0.44, func(t: float, env: float) -> float:
		var clunk: float = _noise(t * 140.0) * exp(-t * 28.0)
		var ignite: float = sin(TAU * (42.0 + t * 70.0) * t) * exp(-t * 4.4)
		var rush: float = _noise(t * 210.0 + 9.0) * (0.12 + t * 1.85)
		var hiss: float = _noise(t * 1240.0) * exp(-t * 6.2)
		var rumble: float = sin(TAU * 28.0 * t) * (0.28 + t * 0.5)
		return (clunk * 0.22 + ignite * 0.64 + rush * 0.62 + hiss * 0.18 + rumble * 0.32) * env * 0.76
	, 0.7)


func _pd_chatter() -> AudioStreamWAV:
	return _render(0.13, func(t: float, env: float) -> float:
		var pulse: float = 0.1
		if t < 0.014 or (t > 0.024 and t < 0.038) or (t > 0.048 and t < 0.062) or (t > 0.074 and t < 0.088):
			pulse = 1.0
		var tick: float = _noise(t * 2900.0) * pulse
		var ping: float = sin(TAU * 3600.0 * t) * pulse * exp(-t * 32.0)
		var body: float = sin(TAU * 480.0 * t) * pulse * 0.4
		return (tick * 0.55 + ping * 0.4 + body) * env * 0.68
	, 1.9)


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
