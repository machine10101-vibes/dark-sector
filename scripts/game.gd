extends Node

var defs: Dictionary = {}
var sim: SectorSim
var link: ListenLink
var verbs: Dictionary = {}
var flight := {
	"thrust": 0.0,
	"retro": 0.0,
	"rot": 0.0,
	"strafe": 0.0,
	"fire": false,
	"boost": false,
}
var mode := "menu"
var paused := false
var zoom := 0.58
## Keys seen in _input before any focused control can eat them.
var key_down: Dictionary = {}
## True while a helm line edit owns the keys, so flight chords do not type or move.
var text_entry := false
## True while the sector chart covers the helm. Flight input is quiet until it closes.
var map_open := false
## Seconds of thrust after the Cast off control, so one click leaves the pad.
var cast_pulse := 0.0


func _ready() -> void:
	defs = Catalog.boot()


func save_path() -> String:
	return "user://dark_sector_save.json"


func host_path() -> String:
	return "user://dark_sector_host.json"


func has_save() -> bool:
	return FileAccess.file_exists(save_path())


func begin_new(class_id: String) -> void:
	_drop_link()
	sim = SectorSim.new(defs)
	sim.new_game(class_id)
	Catalog.arm_yards(sim)
	zoom = 0.58
	paused = false
	map_open = false
	mode = "sector"


func begin_host(class_id: String) -> String:
	_drop_link()
	sim = SectorSim.new(defs)
	var resumed := _resume_host_log()
	if not resumed:
		sim.new_game(class_id)
	Catalog.arm_yards(sim)
	zoom = 0.58
	paused = false
	map_open = false
	link = ListenLink.new()
	var err := link.open_host()
	if err != "":
		var down := link.no_port()
		_drop_link()
		if down:
			print(ListenLink.SOLO_LINE)
			sim.say(ListenLink.SOLO_LINE)
			mode = "sector"
			return ""
		sim = null
		mode = "menu"
		return err
	mode = "sector"
	if resumed:
		sim.say("Host is back on port %s. The world log kept the claim. A second captain joins with that code." % link.code)
	else:
		sim.say("Host is up on port %s. The spine is on this board: Helion Dock, Brass Lantern, Lease, Towline, First Soil, Perimeter, Marchport, Black Quay. Gyre is the hatch. A second captain joins with that code." % link.code)
	return ""


func begin_join(class_id: String, address: String) -> String:
	_drop_link()
	var probe := ListenLink.new()
	var who := "captain-%d" % int(Time.get_unix_time_from_system())
	var err := probe.join(address, class_id, who)
	if err != "":
		probe.close()
		sim = null
		mode = "menu"
		return err
	link = probe
	sim = SectorSim.new(defs)
	sim.new_game(class_id)
	Catalog.arm_yards(sim)
	sim.player.player_id = who
	zoom = 0.58
	paused = false
	map_open = false
	mode = "sector"
	sim.say("Joining %s. The host keeps the world." % address)
	return ""


func tap(action: String, value = true) -> void:
	verbs[action] = value


func take_verbs() -> Dictionary:
	var out := verbs.duplicate()
	verbs = {}
	return out


func clear_flight() -> void:
	flight = {
		"thrust": 0.0,
		"retro": 0.0,
		"rot": 0.0,
		"strafe": 0.0,
		"fire": false,
		"boost": false,
	}


func note_flight_key(code: Key, down: bool) -> void:
	if text_entry:
		return
	if code == KEY_NONE:
		return
	if down:
		key_down[int(code)] = true
	else:
		key_down.erase(int(code))


func clear_flight_keys() -> void:
	key_down = {}


func set_map_open(open: bool) -> void:
	map_open = open
	if open:
		clear_flight_keys()
		clear_flight()
		cast_pulse = 0.0


func flight_down(code: Key) -> bool:
	if text_entry or map_open:
		return false
	if key_down.has(int(code)):
		return true
	if Input.is_key_pressed(code):
		return true
	return Input.is_physical_key_pressed(code)


func request_cast_off() -> void:
	tap("cast_off", true)
	cast_pulse = maxf(cast_pulse, 0.55)


func request_dock() -> void:
	tap("dock", true)


func _drop_link() -> void:
	if link != null:
		link.close()
	link = null
	verbs = {}
	clear_flight()


func write_host_log(quiet: bool = true) -> String:
	if sim == null:
		return ""
	if link != null and str(link.role) == "client":
		return ""
	var data: Dictionary = sim.to_dict()
	var file := FileAccess.open(host_path(), FileAccess.WRITE)
	if file == null:
		return "The world log would not take."
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	if not quiet:
		sim.say("World log written.")
	return ""


func _resume_host_log() -> bool:
	if not FileAccess.file_exists(host_path()):
		return false
	var file := FileAccess.open(host_path(), FileAccess.READ)
	if file == null:
		return false
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(data) != TYPE_DICTIONARY:
		return false
	if int(data.get("version", 0)) != 1:
		return false
	if not data.has("player") or not data.has("claim") or not data.has("system_id"):
		return false
	sim.from_dict(data)
	return true


func write_save() -> String:
	if sim == null:
		return "Nothing to write."
	if link != null and str(link.role) == "client":
		return "The host keeps the log."
	var data: Dictionary = sim.to_dict()
	data["camera_zoom"] = zoom
	var file := FileAccess.open(save_path(), FileAccess.WRITE)
	if file == null:
		return "The slate would not take the log."
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	sim.say("Log written.")
	sim.sfx("save")
	return "Log written."


func try_load() -> String:
	if not has_save():
		return "No log on the slate."
	var file := FileAccess.open(save_path(), FileAccess.READ)
	if file == null:
		return "The log would not open."
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(data) != TYPE_DICTIONARY:
		return "The log did not parse."
	if int(data.get("version", 0)) != 1:
		return "That log is from another keel."
	sim = SectorSim.new(defs)
	sim.from_dict(data)
	zoom = clampf(float(data.get("camera_zoom", 0.58)), 0.05, 1.55)
	paused = false
	map_open = false
	mode = "sector"
	return ""


func abandon() -> void:
	_drop_link()
	paused = false
	map_open = false
	mode = "menu"
