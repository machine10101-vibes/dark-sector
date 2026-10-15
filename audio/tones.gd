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
		"gun_inc": _gun_crack_hot(),
		"gun_tung": _gun_crack_hard(),
		"heavy": _heavy_boom(),
		"stake": _stake_snap(),
		"laser": _laser_hiss(),
		"laser_ir": _laser_hiss_ir(),
		"laser_uv": _laser_hiss_uv(),
		"missile": _missile_whoosh(),
		"missile_siege": _missile_whoosh_heavy(),
		"missile_breacher": _missile_whoosh_sharp(),
		"pd": _pd_chatter(),
		"hit": _hit_brass(),
		"hit_heavy": _hit_crunch(),
		"hit_stake": _hit_spark(),
		"hit_laser": _hit_sizzle(),
		"hit_laser_ir": _hit_sizzle_deep(),
		"hit_laser_uv": _hit_sizzle_thin(),
		"hit_missile": _hit_blast(),
		"hit_missile_siege": _hit_blast_heavy(),
		"hit_missile_breach": _hit_blast_sharp(),
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
		loud = -1.2
	elif kind == "missile" or kind == "missile_siege":
		loud = -2.2
	elif kind == "missile_breacher":
		loud = -2.8
	elif kind == "laser":
		loud = -5.0
	elif kind == "laser_ir":
		loud = -4.4
	elif kind == "laser_uv":
		loud = -5.4
	elif kind == "pd":
		loud = -4.0
	elif kind == "stake":
		loud = -3.0
	elif kind == "gun_inc":
		loud = -3.6
	elif kind == "gun_tung":
		loud = -3.8
	elif kind == "hit_missile" or kind == "hit_missile_siege":
		loud = -1.8
	elif kind == "hit_missile_breach":
		loud = -2.2
	elif kind == "hit_heavy":
		loud = -2.0
	elif kind == "hit_laser" or kind == "hit_laser_ir":
		loud = -4.0
	elif kind == "hit_laser_uv":
		loud = -4.6
	voice.volume_db = loud
	voice.stream = clips[kind]
	voice.play()


func _tone(freq: float, duration: float, volume: float, decay: float) -> AudioStreamWAV:
	return _render(duration, func(t: float, env: float) -> float:
		return sin(TAU * freq * t) * volume * env
	, decay)


func _gun_crack() -> AudioStreamWAV:
	return _render(0.26, func(t: float, env: float) -> float:
		var bang: float = _noise(t * 1600.0) * exp(-t * 58.0)
		var body: float = sin(TAU * 148.0 * t) * exp(-t * 12.0)
		var brass: float = sin(TAU * 2480.0 * t) * exp(-t * 30.0)
		var slap: float = sin(TAU * 390.0 * t) * exp(-t * 18.0)
		var case_ping: float = 0.0
		if t > 0.042:
			case_ping = sin(TAU * 3340.0 * (t - 0.042)) * exp(-(t - 0.042) * 20.0)
		var eject: float = 0.0
		if t > 0.06:
			eject = _noise((t - 0.06) * 2600.0) * exp(-(t - 0.06) * 26.0)
		var bolt: float = 0.0
		if t > 0.11 and t < 0.16:
			bolt = _noise(t * 520.0) * 0.7 + sin(TAU * 180.0 * t) * 0.35
		return (bang * 0.86 + body * 0.58 + brass * 0.42 + slap * 0.24 + case_ping * 0.28 + eject * 0.18 + bolt * 0.2) * env * 0.86
	, 1.28)


func _gun_crack_hot() -> AudioStreamWAV:
	return _render(0.28, func(t: float, env: float) -> float:
		var bang: float = _noise(t * 1320.0) * exp(-t * 46.0)
		var body: float = sin(TAU * 132.0 * t) * exp(-t * 10.0)
		var hiss: float = _noise(t * 2100.0) * exp(-t * 8.0)
		var brass: float = sin(TAU * 1980.0 * t) * exp(-t * 24.0)
		return (bang * 0.8 + body * 0.5 + hiss * 0.32 + brass * 0.22) * env * 0.84
	, 1.15)


func _gun_crack_hard() -> AudioStreamWAV:
	return _render(0.22, func(t: float, env: float) -> float:
		var bang: float = _noise(t * 2100.0) * exp(-t * 70.0)
		var body: float = sin(TAU * 210.0 * t) * exp(-t * 16.0)
		var ring: float = sin(TAU * 2860.0 * t) * exp(-t * 28.0)
		var slap: float = sin(TAU * 540.0 * t) * exp(-t * 22.0)
		return (bang * 0.9 + body * 0.48 + ring * 0.36 + slap * 0.22) * env * 0.82
	, 1.5)


func _heavy_boom() -> AudioStreamWAV:
	return _render(0.68, func(t: float, env: float) -> float:
		var thump: float = sin(TAU * (28.0 - t * 14.0) * t) * exp(-t * 3.6)
		var blast: float = _noise(t * 180.0) * exp(-t * 6.4)
		var ring: float = sin(TAU * 168.0 * t) * exp(-t * 5.8)
		var room: float = _noise(t * 36.0 + 3.0) * exp(-t * 2.8)
		var breech: float = sin(TAU * 520.0 * t) * exp(-t * 14.0)
		var cycle: float = 0.0
		if t > 0.1:
			cycle = _noise((t - 0.1) * 80.0) * exp(-(t - 0.1) * 7.4)
		var door: float = 0.0
		if t > 0.2 and t < 0.28:
			door = _noise(t * 340.0) * 0.7
		var brake: float = _noise(t * 90.0) * exp(-t * 9.0)
		return (thump * 1.38 + blast * 0.7 + ring * 0.22 + room * 0.36 + breech * 0.2 + cycle * 0.26 + door * 0.22 + brake * 0.18) * env * 0.92
	, 0.68)


func _stake_snap() -> AudioStreamWAV:
	return _render(0.32, func(t: float, env: float) -> float:
		var charge: float = 0.0
		if t < 0.08:
			charge = sin(TAU * (720.0 + t * 34000.0) * t) * (t / 0.08)
		var snap: float = 0.0
		if t >= 0.07:
			snap = _noise((t - 0.07) * 3600.0) * exp(-(t - 0.07) * 52.0)
		var iron: float = sin(TAU * 1620.0 * t) * exp(-t * 22.0)
		var coil: float = sin(TAU * 3180.0 * t) * exp(-t * 32.0)
		var low: float = sin(TAU * 78.0 * t) * exp(-t * 11.0)
		var trail: float = sin(TAU * 2360.0 * t) * exp(-t * 16.0)
		var whine: float = sin(TAU * (1100.0 + t * 4200.0) * t) * exp(-t * 9.0)
		return (charge * 0.7 + snap * 0.58 + iron * 0.38 + coil * 0.32 + low * 0.36 + trail * 0.18 + whine * 0.2) * env * 0.8
	, 1.32)


func _laser_hiss() -> AudioStreamWAV:
	return _render(0.48, func(t: float, env: float) -> float:
		var tick: float = _noise(t * 3800.0) * exp(-t * 36.0)
		var hz: float = 980.0 - t * 380.0
		var arc: float = sin(TAU * hz * t)
		var hiss: float = _noise(t * 2700.0) * (0.2 + 0.8 * absf(sin(TAU * 52.0 * t)))
		var hum: float = sin(TAU * 68.0 * t) * 0.58
		var zip: float = sin(TAU * 1680.0 * t) * exp(-t * 7.0)
		var cool: float = 0.0
		if t > 0.26:
			cool = sin(TAU * 480.0 * t) * exp(-(t - 0.26) * 7.0)
		var cap: float = 0.0
		if t < 0.035:
			cap = _noise(t * 900.0) * 0.7
		return (tick * 0.3 + arc * 0.24 + hiss * 0.86 + hum + zip * 0.16 + cool * 0.2 + cap * 0.22) * env * 0.5
	, 0.44)


func _laser_hiss_ir() -> AudioStreamWAV:
	return _render(0.58, func(t: float, env: float) -> float:
		var tick: float = _noise(t * 1400.0) * exp(-t * 22.0)
		var hz: float = 340.0 - t * 110.0
		var arc: float = sin(TAU * hz * t)
		var hiss: float = _noise(t * 1100.0) * (0.34 + 0.66 * absf(sin(TAU * 18.0 * t)))
		var hum: float = sin(TAU * 36.0 * t) * 0.82
		var throb: float = sin(TAU * 12.0 * t) * 0.38
		var whoom: float = sin(TAU * (22.0 - t * 8.0) * t) * exp(-t * 3.2)
		return (tick * 0.16 + arc * 0.28 + hiss * 0.64 + hum + throb + whoom * 0.42) * env * 0.56
	, 0.36)


func _laser_hiss_uv() -> AudioStreamWAV:
	return _render(0.28, func(t: float, env: float) -> float:
		var tick: float = _noise(t * 6200.0) * exp(-t * 62.0)
		var hz: float = 1980.0 - t * 740.0
		var arc: float = sin(TAU * hz * t)
		var hiss: float = _noise(t * 4400.0) * (0.14 + 0.86 * absf(sin(TAU * 118.0 * t)))
		var sting: float = sin(TAU * 2860.0 * t) * exp(-t * 9.0)
		var hum: float = sin(TAU * 140.0 * t) * 0.22
		return (tick * 0.4 + arc * 0.18 + hiss * 0.9 + sting * 0.28 + hum) * env * 0.48
	, 0.7)


func _missile_whoosh() -> AudioStreamWAV:
	return _render(0.64, func(t: float, env: float) -> float:
		var clunk: float = 0.0
		if t < 0.08:
			clunk = _noise(t * 160.0) * exp(-t * 18.0) + sin(TAU * 78.0 * t) * exp(-t * 14.0)
		var ignite: float = 0.0
		if t > 0.055:
			ignite = sin(TAU * (32.0 + (t - 0.055) * 110.0) * t) * exp(-(t - 0.055) * 3.2)
		var rush: float = 0.0
		if t > 0.09:
			rush = _noise(t * 220.0 + 9.0) * (0.2 + (t - 0.09) * 2.1)
		var hiss: float = _noise(t * 980.0) * exp(-t * 4.6)
		var rumble: float = sin(TAU * 20.0 * t) * (0.26 + t * 0.6)
		var tube: float = 0.0
		if t < 0.05:
			tube = sin(TAU * 186.0 * t) * 0.55
		return (clunk * 0.42 + ignite * 0.74 + rush * 0.7 + hiss * 0.22 + rumble * 0.4 + tube * 0.28) * env * 0.8
	, 0.56)


func _missile_whoosh_heavy() -> AudioStreamWAV:
	return _render(0.78, func(t: float, env: float) -> float:
		var clunk: float = 0.0
		if t < 0.12:
			clunk = _noise(t * 90.0) * exp(-t * 10.0) + sin(TAU * 48.0 * t) * exp(-t * 8.0)
		var ignite: float = 0.0
		if t > 0.08:
			ignite = sin(TAU * (22.0 + (t - 0.08) * 60.0) * t) * exp(-(t - 0.08) * 2.4)
		var rush: float = 0.0
		if t > 0.12:
			rush = _noise(t * 140.0 + 4.0) * (0.28 + (t - 0.12) * 1.6)
		var rumble: float = sin(TAU * 14.0 * t) * (0.4 + t * 0.5)
		return (clunk * 0.55 + ignite * 0.86 + rush * 0.62 + rumble * 0.55) * env * 0.86
	, 0.48)


func _missile_whoosh_sharp() -> AudioStreamWAV:
	return _render(0.48, func(t: float, env: float) -> float:
		var pop: float = _noise(t * 420.0) * exp(-t * 28.0)
		var ignite: float = 0.0
		if t > 0.03:
			ignite = sin(TAU * (48.0 + (t - 0.03) * 160.0) * t) * exp(-(t - 0.03) * 4.4)
		var rush: float = 0.0
		if t > 0.05:
			rush = _noise(t * 360.0 + 6.0) * (0.16 + (t - 0.05) * 2.6)
		var zip: float = sin(TAU * 720.0 * t) * exp(-t * 10.0)
		return (pop * 0.5 + ignite * 0.66 + rush * 0.74 + zip * 0.22) * env * 0.78
	, 0.7)


func _pd_chatter() -> AudioStreamWAV:
	return _render(0.22, func(t: float, env: float) -> float:
		var pulse := 0.06
		if t < 0.01 or (t > 0.018 and t < 0.028) or (t > 0.036 and t < 0.046) or (t > 0.054 and t < 0.064) or (t > 0.072 and t < 0.082) or (t > 0.09 and t < 0.1) or (t > 0.11 and t < 0.12) or (t > 0.13 and t < 0.14):
			pulse = 1.0
		var tick: float = _noise(t * 3800.0) * pulse
		var ping: float = sin(TAU * 4600.0 * t) * pulse * exp(-t * 26.0)
		var body: float = sin(TAU * 580.0 * t) * pulse * 0.32
		var zip: float = sin(TAU * 2500.0 * t) * pulse * 0.2
		var spin: float = sin(TAU * 42.0 * t) * 0.12
		return (tick * 0.64 + ping * 0.48 + body + zip + spin) * env * 0.74
	, 1.85)


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
	return _render(0.22, func(t: float, env: float) -> float:
		var hiss: float = _noise(t * 2400.0) * (0.28 + 0.72 * absf(sin(TAU * 44.0 * t)))
		var pop: float = _noise(t * 980.0) * exp(-t * 16.0)
		var hum: float = sin(TAU * 86.0 * t) * exp(-t * 7.0)
		return (hiss * 0.74 + pop * 0.3 + hum * 0.32) * env * 0.6
	, 0.85)


func _hit_sizzle_deep() -> AudioStreamWAV:
	return _render(0.3, func(t: float, env: float) -> float:
		var hiss: float = _noise(t * 1200.0) * (0.4 + 0.6 * absf(sin(TAU * 16.0 * t)))
		var pop: float = _noise(t * 420.0) * exp(-t * 10.0)
		var hum: float = sin(TAU * 48.0 * t) * exp(-t * 5.0)
		return (hiss * 0.62 + pop * 0.36 + hum * 0.48) * env * 0.64
	, 0.7)


func _hit_sizzle_thin() -> AudioStreamWAV:
	return _render(0.16, func(t: float, env: float) -> float:
		var hiss: float = _noise(t * 3600.0) * (0.2 + 0.8 * absf(sin(TAU * 90.0 * t)))
		var tick: float = _noise(t * 2800.0) * exp(-t * 28.0)
		var sting: float = sin(TAU * 2200.0 * t) * exp(-t * 14.0)
		return (hiss * 0.78 + tick * 0.32 + sting * 0.28) * env * 0.56
	, 1.15)


func _hit_blast() -> AudioStreamWAV:
	return _render(0.34, func(t: float, env: float) -> float:
		var boom: float = sin(TAU * (38.0 - t * 14.0) * t) * exp(-t * 5.0)
		var grit: float = _noise(t * 160.0) * exp(-t * 6.2)
		var room: float = _noise(t * 44.0 + 2.0) * exp(-t * 3.4)
		return (boom * 1.12 + grit * 0.5 + room * 0.32) * env * 0.86
	, 0.78)


func _hit_blast_heavy() -> AudioStreamWAV:
	return _render(0.46, func(t: float, env: float) -> float:
		var boom: float = sin(TAU * (24.0 - t * 10.0) * t) * exp(-t * 3.6)
		var grit: float = _noise(t * 110.0) * exp(-t * 4.8)
		var room: float = _noise(t * 28.0 + 1.5) * exp(-t * 2.6)
		return (boom * 1.28 + grit * 0.56 + room * 0.4) * env * 0.9
	, 0.62)


func _hit_blast_sharp() -> AudioStreamWAV:
	return _render(0.24, func(t: float, env: float) -> float:
		var pop: float = _noise(t * 320.0) * exp(-t * 12.0)
		var boom: float = sin(TAU * (56.0 - t * 22.0) * t) * exp(-t * 7.0)
		var zip: float = sin(TAU * 640.0 * t) * exp(-t * 16.0)
		return (pop * 0.7 + boom * 0.86 + zip * 0.28) * env * 0.82
	, 1.05)


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
