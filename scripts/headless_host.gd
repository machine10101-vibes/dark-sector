extends SceneTree

## Same listen sim as Host the dock. No cluster.

var _host = null
var _save_t := 0.0
var _booted := false


func _init() -> void:
	process_frame.connect(_frame)


func _frame() -> void:
	if not _booted:
		_host = root.get_node_or_null("Game")
		if _host == null:
			return
		_booted = true
		var err: String = _host.begin_host("vesper")
		print("DARK SECTOR ONLINE")
		print("listening on %s" % ListenLink.PORT)
		print("world log %s" % ProjectSettings.globalize_path(_host.host_path()))
		if _host.sim != null:
			print(str(_host.sim.defs.system.id))
		if err != "":
			print(err)
			quit(1)
		return
	if _host == null or _host.sim == null or _host.link == null:
		return
	_host.link.take_host(_host.sim)
	_host.sim.tick(0.05, {})
	_host.link.broadcast(_host.sim)
	_save_t += 0.05
	if _save_t >= 2.0:
		_save_t = 0.0
		_host.write_host_log(true)
