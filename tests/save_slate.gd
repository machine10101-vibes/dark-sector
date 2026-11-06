extends SceneTree

var fails := 0
var frames := 0


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 3:
		return false
	_run()
	if fails == 0:
		print("SAVE SLATE PASS")
	else:
		print("SAVE SLATE FAIL %d" % fails)
	quit(fails)
	return true


func check(cond: bool, message: String) -> void:
	if cond:
		print("ok: %s" % message)
	else:
		fails += 1
		print("FAIL: %s" % message)


func _wipe(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _run() -> void:
	var host: Node = root.get_node("Game")
	var live := str(host.call("save_path"))
	var staged := str(host.call("save_next_path"))
	var prev := str(host.call("save_prev_path"))
	_wipe(live)
	_wipe(staged)
	_wipe(prev)
	check(not bool(host.call("has_save")), "a fresh machine has no log")
	host.call("begin_new", "vesper")
	var sim = host.get("sim")
	sim.quest_flags.slate_mark = 41
	check(str(host.call("write_save")) == "Log written.", "the first log lands")
	check(host.call("_read_log", staged) != null, "the staged log reads back before it replaces the slate")
	sim = host.get("sim")
	sim.quest_flags.slate_mark = 77
	check(str(host.call("write_save")) == "Log written.", "the second log lands beside the first")
	check(str(host.call("try_load")) == "", "Continue opens the latest log")
	sim = host.get("sim")
	check(int(sim.quest_flags.get("slate_mark", 0)) == 77, "the latest log keeps the later mark")
	var torn := FileAccess.open(live, FileAccess.WRITE)
	check(torn != null, "the live log can be torn")
	if torn != null:
		torn.store_string("{")
		torn.close()
	check(bool(host.call("has_save")), "Continue stays lit when the previous slate is still good")
	check(str(host.call("try_load")) == "", "a torn log opens the previous slate")
	sim = host.get("sim")
	check(int(sim.quest_flags.get("slate_mark", 0)) == 41, "the previous slate keeps the earlier mark")
	var said := false
	for line in sim.lines:
		if str(line.get("text", "")).contains("previous slate"):
			said = true
	check(said, "the helm says the previous slate opened")
	_wipe(live)
	_wipe(staged)
	_wipe(prev)
