extends Node

## Thin proxies for the live sim. The dictionary ship stays the helm.
## Rebase moves these nodes only. sim.pos and sim velocity stay.

var _proxies: Dictionary = {}


func _ready() -> void:
	process_physics_priority = 1
	bind_sector()


func bind_sector() -> void:
	if FloatingOrigin == null or Game.sim == null:
		return
	var sim = Game.sim
	FloatingOrigin.system_id = str(sim.defs.system.id)
	var body := str(sim.body_id)
	if body == "":
		body = "aegis_prime"
	FloatingOrigin.body_id = body
	FloatingOrigin.layer = int(sim.layer)
	FloatingOrigin.origin_id = _origin_name(body)
	var here: Vector2 = sim.view_focus()
	FloatingOrigin.origin_m = here
	FloatingOrigin.settle_left = 0.0
	FloatingOrigin.armed = true
	_sync()


func _physics_process(_delta: float) -> void:
	if Game.sim == null or Game.mode != "sector":
		return
	_sync()


func _sync() -> void:
	var sim = Game.sim
	FloatingOrigin.system_id = str(sim.defs.system.id)
	var body := str(sim.body_id)
	if body == "":
		body = "aegis_prime"
	FloatingOrigin.body_id = body
	FloatingOrigin.layer = int(sim.layer)
	FloatingOrigin.origin_id = _origin_name(body)
	var live: Dictionary = {}
	var helm := _proxy("player")
	helm.world_m = sim.view_focus()
	helm.snap_to_world()
	FloatingOrigin.set_focus(helm)
	live["player"] = true
	for mate in sim.captains:
		var mate_row: Dictionary = mate
		var mate_key := "captain:%s" % str(mate_row.get("player_id", mate_row.get("agent_id", "")))
		live[mate_key] = true
		var mate_node := _proxy(mate_key)
		var mate_pos: Vector2 = mate_row.pos
		mate_node.world_m = mate_pos
		mate_node.snap_to_world()
	var craft_i := 0
	for item in sim.craft:
		var craft_row: Dictionary = item
		var craft_key := "craft:%s" % str(craft_row.get("uid", craft_i))
		live[craft_key] = true
		var craft_node := _proxy(craft_key)
		var craft_pos: Vector2 = craft_row.pos
		craft_node.world_m = craft_pos
		craft_node.snap_to_world()
		craft_i += 1
	var actor_i := 0
	for actor in sim.actors:
		var actor_row: Dictionary = actor
		var actor_key := "actor:%s" % str(actor_row.get("agent_id", actor_i))
		live[actor_key] = true
		var actor_node := _proxy(actor_key)
		var actor_pos: Vector2 = actor_row.pos
		actor_node.world_m = actor_pos
		actor_node.snap_to_world()
		actor_i += 1
	var wreck_i := 0
	for wreck in sim.wrecks:
		var wreck_row: Dictionary = wreck
		var wreck_key := "wreck:%s" % str(wreck_row.get("id", wreck_i))
		live[wreck_key] = true
		var wreck_node := _proxy(wreck_key)
		var wreck_pos: Vector2 = wreck_row.pos
		wreck_node.world_m = wreck_pos
		wreck_node.snap_to_world()
		wreck_i += 1
	var rock_i := 0
	for rock in sim.asteroids:
		var rock_row: Dictionary = rock
		var rock_key := "belt:%d" % rock_i
		live[rock_key] = true
		var rock_node := _proxy(rock_key)
		var rock_pos: Vector2 = rock_row.pos
		rock_node.world_m = rock_pos
		rock_node.snap_to_world()
		rock_i += 1
	var stale: Array = []
	for key in _proxies.keys():
		if live.has(key) == false:
			stale.append(key)
	for key in stale:
		var gone: Node = _proxies[key]
		_proxies.erase(key)
		if is_instance_valid(gone):
			gone.queue_free()


func _proxy(key: String) -> RebasingBody2D:
	if _proxies.has(key):
		return _proxies[key]
	var node := RebasingBody2D.new()
	node.name = "Live_%s" % key.replace(":", "_")
	_proxies[key] = node
	add_child(node)
	return node


func _origin_name(body: String) -> String:
	if body == "" or body == "aegis_prime":
		return "aegis_orbital_band"
	return "%s_band" % body
