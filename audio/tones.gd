extends Node

var voices: Array = []
var clips: Dictionary = {}
var ready_audio := false


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	for i in 8:
		var node := AudioStreamPlayer.new()
		node.volume_db = -4.0
		add_child(node)
		voices.append(node)
	clips = {
		"gun": _gun_crack(),
		"heavy": _heavy_boom(),
		"stake": _stake_snap(),
		"laser": _laser_hiss(),
		"laser_ir": _laser_hiss_ir(),
		"laser_uv": _laser_hiss_uv(),
		"missile": _missile_whoosh(),
		"pd": _pd_chatter(),
		"hit": _hit_brass(),
		"hit_heavy": _hit_crunch(),
		"hit_stake": _hit_spark(),
		"hit_laser": _hit_sizzle(),
		"hit_missile": _hit_blast(),
		"hit_pd": _hit_flak(),
		"launch": _tone(420.0, 0.12, 0.3, 0.8),
		"dock": _tone(540.0, 0.1, 0.28, 1.0),
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
		loud = -1.6
	elif kind == "missile":
		loud = -2.6
	elif kind == "laser":
		loud = -5.2
	elif kind == "laser_ir":
		loud = -4.8
	elif kind == "laser_uv":
		loud = -5.6
	elif kind == "pd":
		loud = -4.4
	elif kind == "stake":
		loud = -3.4
	elif kind == "hit_missile":
		loud = -2.0
	elif kind == "hit_heavy":
		loud = -2.4
	elif kind == "hit_laser":
		loud = -4.2
	voice.volume_db = loud
	voice.stream = clips[kind]
	voice.play()


func _tone(freq: float, duration: float, volume: float, decay: float) -> AudioStreamWAV:
	return _render(duration, func(t: float, env: float) -> float:
		return sin(TAU * freq * t) * volume * env
	, decay)


func _gun_crack() -> AudioStreamWAV:
	return _render(0.2, func(t: float, env: float) -> float:
		var bang: float = _noise(t * 1400.0) * exp(-t * 52.0)
		var body: float = sin(TAU * 156.0 * t) * exp(-t * 14.0)
		var brass: float = sin(TAU * 2280.0 * t) * exp(-t * 32.0)
		var slap: float = sin(TAU * 410.0 * t) * exp(-t * 20.0)
		var case_ping: float = 0.0
		if t > 0.038:
			case_ping = sin(TAU * 3120.0 * (t - 0.038)) * exp(-(t - 0.038) * 22.0)
		var eject: float = 0.0
		if t > 0.055:
			eject = _noise((t - 0.055) * 2400.0) * exp(-(t - 0.055) * 28.0)
		return (bang * 0.78 + body * 0.62 + brass * 0.38 + slap * 0.22 + case_ping * 0.22 + eject * 0.14) * env * 0.82
	, 1.35)


func _heavy_boom() -> AudioStreamWAV:
	return _render(0.52, func(t: float, env: float) -> float:
		var thump: float = sin(TAU * (36.0 - t * 18.0) * t) * exp(-t * 4.4)
		var blast: float = _noise(t * 220.0) * exp(-t * 7.6)
		var ring: float = sin(TAU * 198.0 * t) * exp(-t * 6.8)
		var room: float = _noise(t * 42.0 + 3.0) * exp(-t * 3.4)
		var breech: float = sin(TAU * 640.0 * t) * exp(-t * 18.0)
		var cycle: float = 0.0
		if t > 0.08:
			cycle = _noise((t - 0.08) * 90.0) * exp(-(t - 0.08) * 9.0)
		var door: float = 0.0
		if t > 0.16 and t < 0.22:
			door = _noise(t * 380.0) * 0.55
		return (thump * 1.22 + blast * 0.62 + ring * 0.2 + room * 0.28 + breech * 0.16 + cycle * 0.22 + door * 0.18) * env * 0.88
	, 0.78)


func _stake_snap() -> AudioStreamWAV:
	return _render(0.22, func(t: float, env: float) -> float:
		var charge: float = 0.0
		if t < 0.045:
			charge = sin(TAU * (900.0 + t * 28000.0) * t) * (t / 0.045)
		var snap: float = 0.0
		if t >= 0.04:
			snap = _noise((t - 0.04) * 3200.0) * exp(-(t - 0.04) * 48.0)
		var iron: float = sin(TAU * 1480.0 * t) * exp(-t * 26.0)
		var coil: float = sin(TAU * 2960.0 * t) * exp(-t * 38.0)
		var low: float = sin(TAU * 96.0 * t) * exp(-t * 14.0)
		var trail: float = sin(TAU * 2140.0 * t) * exp(-t * 20.0)
		return (charge * 0.55 + snap * 0.5 + iron * 0.42 + coil * 0.28 + low * 0.32 + trail * 0.16) * env * 0.78
	, 1.45)


func _laser_hiss() -> AudioStreamWAV:
	return _render(0.4, func(t: float, env: float) -> float:
		var tick: float = _noise(t * 3600.0) * exp(-t * 40.0)
		var hz: float = 920.0 - t * 420.0
		var arc: float = sin(TAU * hz * t)
		var hiss: float = _noise(t * 2600.0) * (0.22 + 0.78 * absf(sin(TAU * 58.0 * t)))
		var hum: float = sin(TAU * 76.0 * t) * 0.52
		var zip: float = sin(TAU * 1540.0 * t) * exp(-t * 8.0)
		var cool: float = 0.0
		if t > 0.22:
			cool = sin(TAU * 540.0 * t) * exp(-(t - 0.22) * 8.0)
		return (tick * 0.28 + arc * 0.22 + hiss * 0.82 + hum + zip * 0.14 + cool * 0.18) * env * 0.48
	, 0.48)


func _laser_hiss_ir() -> AudioStreamWAV:
	return _render(0.46, func(t: float, env: float) -> float:
		var tick: float = _noise(t * 1800.0) * exp(-t * 28.0)
		var hz: float = 420.0 - t * 160.0
		var arc: float = sin(TAU * hz * t)
		var hiss: float = _noise(t * 1400.0) * (0.3 + 0.7 * absf(sin(TAU * 28.0 * t)))
		var hum: float = sin(TAU * 48.0 * t) * 0.7
		var throb: float = sin(TAU * 18.0 * t) * 0.28
		return (tick * 0.18 + arc * 0.3 + hiss * 0.7 + hum + throb) * env * 0.52
	, 0.42)


func _laser_hiss_uv() -> AudioStreamWAV:
	return _render(0.32, func(t: float, env: float) -> float:
		var tick: float = _noise(t * 5200.0) * exp(-t * 55.0)
		var hz: float = 1680.0 - t * 620.0
		var arc: float = sin(TAU * hz * t)
		var hiss: float = _noise(t * 3800.0) * (0.18 + 0.82 * absf(sin(TAU * 96.0 * t)))
		var sting: float = sin(TAU * 2440.0 * t) * exp(-t * 10.0)
		var hum: float = sin(TAU * 110.0 * t) * 0.28
		return (tick * 0.34 + arc * 0.2 + hiss * 0.86 + sting * 0.22 + hum) * env * 0.46
	, 0.62)


func _missile_whoosh() -> AudioStreamWAV:
	return _render(0.56, func(t: float, env: float) -> float:
		var clunk: float = 0.0
		if t < 0.07:
			clunk = _noise(t * 180.0) * exp(-t * 22.0) + sin(TAU * 90.0 * t) * exp(-t * 18.0)
		var ignite: float = 0.0
		if t > 0.05:
			ignite = sin(TAU * (36.0 + (t - 0.05) * 90.0) * t) * exp(-(t - 0.05) * 3.8)
		var rush: float = 0.0
		if t > 0.08:
			rush = _noise(t * 240.0 + 9.0) * (0.18 + (t - 0.08) * 1.9)
		var hiss: float = _noise(t * 1100.0) * exp(-t * 5.4)
		var rumble: float = sin(TAU * 24.0 * t) * (0.22 + t * 0.55)
		var tube: float = 0.0
		if t < 0.04:
			tube = sin(TAU * 210.0 * t) * 0.45
		return (clunk * 0.34 + ignite * 0.7 + rush * 0.66 + hiss * 0.2 + rumble * 0.36 + tube * 0.22) * env * 0.78
	, 0.62)


func _pd_chatter() -> AudioStreamWAV:
	return _render(0.18, func(t: float, env: float) -> float:
		var pulse := 0.08
		if t < 0.012 or (t > 0.02 and t < 0.032) or (t > 0.04 and t < 0.052) or (t > 0.062 and t < 0.074) or (t > 0.084 and t < 0.096) or (t > 0.108 and t < 0.12):
			pulse = 1.0
		var tick: float = _noise(t * 3400.0) * pulse
		var ping: float = sin(TAU * 4100.0 * t) * pulse * exp(-t * 28.0)
		var body: float = sin(TAU * 520.0 * t) * pulse * 0.36
		var zip: float = sin(TAU * 2200.0 * t) * pulse * 0.18
		return (tick * 0.58 + ping * 0.44 + body + zip) * env * 0.7
	, 1.75)


func _hit_brass() -> AudioStreamWAV:
	return _render(0.14, func(t: float, env: float) -> float:
		var slap: float = _noise(t * 1600.0) * exp(-t * 40.0)
		var ring: float = sin(TAU * 980.0 * t) * exp(-t * 16.0)
		var body: float = sin(TAU * 210.0 * t) * exp(-t * 14.0)
		return (slap * 0.55 + ring * 0.4 + body * 0.45) * env * 0.8
	, 1.5)


func _hit_crunch() -> AudioStreamWAV:
	return _render(0.22, func(t: float, env: float) -> float:
		var thud: float = sin(TAU * (70.0 - t * 30.0) * t) * exp(-t * 8.0)
		var plate: float = _noise(t * 420.0) * exp(-t * 12.0)
		var ring: float = sin(TAU * 340.0 * t) * exp(-t * 10.0)
		return (thud * 0.9 + plate * 0.5 + ring * 0.22) * env * 0.86
	, 1.1)


func _hit_spark() -> AudioStreamWAV:
	return _render(0.12, func(t: float, env: float) -> float:
		var zip: float = sin(TAU * (2400.0 + t * 800.0) * t) * exp(-t * 22.0)
		var tick: float = _noise(t * 2800.0) * exp(-t * 36.0)
		return (zip * 0.55 + tick * 0.5) * env * 0.72
	, 1.7)


func _hit_sizzle() -> AudioStreamWAV:
	return _render(0.2, func(t: float, env: float) -> float:
		var hiss: float = _noise(t * 2200.0) * (0.3 + 0.7 * absf(sin(TAU * 40.0 * t)))
		var pop: float = _noise(t * 900.0) * exp(-t * 18.0)
		var hum: float = sin(TAU * 90.0 * t) * exp(-t * 8.0)
		return (hiss * 0.7 + pop * 0.28 + hum * 0.3) * env * 0.58
	, 0.9)


func _hit_blast() -> AudioStreamWAV:
	return _render(0.3, func(t: float, env: float) -> float:
		var boom: float = sin(TAU * (42.0 - t * 16.0) * t) * exp(-t * 5.5)
		var grit: float = _noise(t * 180.0) * exp(-t * 7.0)
		var room: float = _noise(t * 50.0 + 2.0) * exp(-t * 4.0)
		return (boom * 1.05 + grit * 0.48 + room * 0.28) * env * 0.84
	, 0.85)


func _hit_flak() -> AudioStreamWAV:
	return _render(0.1, func(t: float, env: float) -> float:
		var pop: float = _noise(t * 2100.0) * exp(-t * 30.0)
		var ping: float = sin(TAU * 1900.0 * t) * exp(-t * 24.0)
		return (pop * 0.7 + ping * 0.4) * env * 0.7
	, 1.8)


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
