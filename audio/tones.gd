extends Node

var player: AudioStreamPlayer
var clips: Dictionary = {}
var ready_audio := false


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	player = AudioStreamPlayer.new()
	player.volume_db = -8.0
	add_child(player)
	clips = {
		"gun": _tone(880.0, 0.07, 0.35, 1.2),
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
	}
	ready_audio = true


func play(kind: String) -> void:
	if not ready_audio:
		return
	if not clips.has(kind):
		return
	player.stream = clips[kind]
	player.play()


func _tone(freq: float, duration: float, volume: float, decay: float) -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var phase := 0.0
	var step := TAU * freq / float(rate)
	for i in count:
		var env := pow(1.0 - float(i) / float(count), decay)
		var sample := sin(phase) * volume * env
		var iv := int(clampf(sample * 32767.0, -32767.0, 32767.0))
		bytes[i * 2] = iv & 255
		bytes[i * 2 + 1] = (iv >> 8) & 255
		phase += step
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = bytes
	return wav
