extends Node3D

## The whole Haven chart as a 3D reach: every named system, every lane, and
## the eight regions, lit so the full map reads as one piece of sky.

const Atlas = preload("res://ui/chart_atlas.gd")
const UNIT := 480.0

var systems: Dictionary = {}
var lanes: Array = []
var labels: Dictionary = {}
var planets: Array = []
var beacons: Dictionary = {}
var _spin := 0.0


func rebuild(atlas: Dictionary) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	systems = {}
	lanes = []
	labels = {}
	planets = []
	beacons = {}
	_spin = 0.0
	_sky()
	_stars()
	_light()
	var regions: Array = atlas.get("regions", [])
	for raw in regions:
		var row: Dictionary = raw
		_region(row)
	var hops: Array = atlas.get("lanes", [])
	for raw_lane in hops:
		var lane: Dictionary = raw_lane
		_lane(atlas, lane)
	var rows: Array = atlas.get("systems", [])
	for raw_sys in rows:
		var spec: Dictionary = raw_sys
		_system(spec)


func system_count() -> int:
	return systems.size()


func lane_count() -> int:
	return lanes.size()


func world_of(pos: Vector2) -> Vector3:
	return Vector3(pos.x * UNIT, _lift(pos), -pos.y * UNIT)


func tick(delta: float, here: String, selected: String, view_span: float) -> void:
	_spin += delta
	for entry in planets:
		var row: Dictionary = entry
		var ball: Node3D = row.node
		if ball == null:
			continue
		var phase := float(row.phase) + _spin * float(row.speed)
		var reach := float(row.reach)
		ball.position = Vector3(cos(phase) * reach, sin(phase * 0.35) * reach * 0.12, sin(phase) * reach)
	var show_names := view_span < 2.6
	for key in labels.keys():
		var sid := str(key)
		var tag: Label3D = labels[sid]
		if tag == null:
			continue
		var keep := show_names or sid == here or sid == selected or int(systems.get(sid, {}).get("slot", 1)) == 1
		tag.visible = keep
	for key in beacons.keys():
		var sid := str(key)
		var mark: Node3D = beacons[sid]
		if mark == null:
			continue
		mark.visible = sid == here or sid == selected
		var glow := 1.0
		if sid == here:
			glow = 1.15 + 0.12 * sin(_spin * 2.4)
		mark.scale = Vector3.ONE * glow


func _sky() -> void:
	var env := WorldEnvironment.new()
	var world := Environment.new()
	world.background_mode = Environment.BG_COLOR
	world.background_color = Color("05070c")
	world.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.ambient_light_color = Color(0.42, 0.5, 0.62)
	world.ambient_light_energy = 0.28
	world.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.glow_enabled = true
	world.glow_intensity = 0.62
	world.glow_strength = 0.9
	world.glow_bloom = 0.16
	world.glow_hdr_threshold = 0.72
	world.fog_enabled = true
	world.fog_light_color = Color("081018")
	world.fog_density = 0.00009
	world.fog_aerial_perspective = 0.4
	env.environment = world
	add_child(env)


func _light() -> void:
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(0.92, 0.88, 0.78)
	sun.light_energy = 1.15
	sun.rotation_degrees = Vector3(-42.0, 28.0, 0.0)
	add_child(sun)
	var fill := OmniLight3D.new()
	fill.light_color = Color(0.55, 0.72, 0.95)
	fill.light_energy = 2.4
	fill.omni_range = UNIT * 8.0
	fill.position = Vector3(0.0, UNIT * 0.8, 0.0)
	add_child(fill)


func _stars() -> void:
	var ball := SphereMesh.new()
	ball.radius = 1.4
	ball.height = 2.8
	ball.radial_segments = 6
	ball.rings = 4
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = ball
	mm.instance_count = 260
	var spread := UNIT * 9.0
	for i in mm.instance_count:
		var x := _hash(i, 3) * spread - spread * 0.5
		var y := _hash(i, 5) * spread * 0.45 - spread * 0.12
		var z := _hash(i, 7) * spread - spread * 0.5
		var s := 0.6 + _hash(i, 11) * 2.4
		var xform := Transform3D(Basis.from_scale(Vector3(s, s, s)), Vector3(x, y, z))
		mm.set_instance_transform(i, xform)
	var field := MultiMeshInstance3D.new()
	field.multimesh = mm
	field.material_override = _mat(Color(0.78, 0.86, 0.95), 2.4, 1.0, true)
	add_child(field)


func _region(row: Dictionary) -> void:
	var at := world_of(Vector2(float(row.get("x", 0.0)), float(row.get("y", 0.0))))
	var disc := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = UNIT * 0.74
	mesh.bottom_radius = UNIT * 0.74
	mesh.height = 3.2
	mesh.radial_segments = 36
	disc.mesh = mesh
	disc.position = at + Vector3(0.0, -18.0, 0.0)
	disc.material_override = _mat(Color(0.22, 0.38, 0.42, 0.16), 0.18, 0.16, false)
	add_child(disc)
	var rim := MeshInstance3D.new()
	var hoop := TorusMesh.new()
	hoop.inner_radius = UNIT * 0.7
	hoop.outer_radius = UNIT * 0.76
	hoop.rings = 28
	hoop.ring_segments = 10
	rim.mesh = hoop
	rim.position = at + Vector3(0.0, -16.0, 0.0)
	rim.material_override = _mat(Color(0.55, 0.72, 0.64, 0.35), 0.45, 0.35, false)
	add_child(rim)
	var tag := Label3D.new()
	tag.text = str(row.get("name", ""))
	tag.font_size = 42
	tag.modulate = Color(0.78, 0.7, 0.5, 0.7)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.position = at + Vector3(0.0, 86.0, 0.0)
	add_child(tag)


func _lane(atlas: Dictionary, lane: Dictionary) -> void:
	var a: Dictionary = Atlas.system_named(atlas, str(lane.get("from", "")))
	var b: Dictionary = Atlas.system_named(atlas, str(lane.get("to", "")))
	if a.is_empty() or b.is_empty():
		return
	var from_at := world_of(Vector2(a.get("pos", Vector2.ZERO)))
	var to_at := world_of(Vector2(b.get("pos", Vector2.ZERO)))
	var delta := to_at - from_at
	var length := delta.length()
	if length < 8.0:
		return
	var rod := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 3.6
	mesh.bottom_radius = 3.6
	mesh.height = length
	mesh.radial_segments = 8
	rod.mesh = mesh
	rod.position = (from_at + to_at) * 0.5
	_aim_y(rod, delta)
	var ink: Color = Atlas.lane_color(str(lane.get("color", "amber")))
	rod.material_override = _mat(ink, 1.8, 0.92, true)
	add_child(rod)
	var haze := MeshInstance3D.new()
	var fog := CylinderMesh.new()
	fog.top_radius = 11.0
	fog.bottom_radius = 11.0
	fog.height = length
	fog.radial_segments = 8
	haze.mesh = fog
	haze.position = rod.position
	haze.basis = rod.basis
	var mist := ink
	mist.a = 0.18
	haze.material_override = _mat(mist, 0.55, 0.18, false)
	add_child(haze)
	lanes.append(rod)


func _system(spec: Dictionary) -> void:
	var sid := str(spec.get("id", ""))
	var at := world_of(Vector2(spec.get("pos", Vector2.ZERO)))
	var slot := int(spec.get("slot", 1))
	var hold := Node3D.new()
	hold.name = sid
	hold.position = at
	add_child(hold)
	var star_r := 28.0 if slot == 1 else 18.0
	var star := _ball(star_r, Color("f0c27a"), 3.4, 1.0, true)
	hold.add_child(star)
	var halo := _ball(star_r * 1.7, Color(0.95, 0.78, 0.42, 0.22), 1.1, 0.22, false)
	hold.add_child(halo)
	var world_r := star_r * 0.42
	var planet := _ball(world_r, _world_tint(sid), 0.35, 1.0, false)
	var reach := star_r * 2.4
	planet.position = Vector3(reach, 0.0, 0.0)
	hold.add_child(planet)
	planets.append({
		"node": planet,
		"reach": reach,
		"speed": 0.18 + float(slot) * 0.04,
		"phase": _hash(sid.length() + slot, 13) * TAU,
	})
	if slot == 1:
		var moon := _ball(world_r * 0.45, Color(0.7, 0.76, 0.8), 0.2, 1.0, false)
		moon.position = Vector3(-reach * 0.55, world_r * 0.8, reach * 0.35)
		hold.add_child(moon)
	var tag := Label3D.new()
	tag.text = str(spec.get("name", sid))
	tag.font_size = 28 if slot == 1 else 22
	tag.outline_size = 6
	tag.outline_modulate = Color(0.02, 0.04, 0.06, 0.85)
	tag.modulate = Color("e7f3f6")
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.position = Vector3(0.0, star_r + 22.0, 0.0)
	hold.add_child(tag)
	labels[sid] = tag
	var ring := MeshInstance3D.new()
	var hoop := TorusMesh.new()
	hoop.inner_radius = star_r * 2.05
	hoop.outer_radius = star_r * 2.28
	hoop.rings = 20
	hoop.ring_segments = 8
	ring.mesh = hoop
	ring.rotation_degrees = Vector3(72.0, 0.0, 0.0)
	ring.material_override = _mat(Color("9eecf5"), 2.2, 0.95, true)
	ring.visible = false
	hold.add_child(ring)
	beacons[sid] = ring
	systems[sid] = {"node": hold, "slot": slot, "pos": spec.get("pos", Vector2.ZERO)}


func mark_visited(visited: Dictionary, here: String) -> void:
	for key in systems.keys():
		var sid := str(key)
		var row: Dictionary = systems[sid]
		var hold: Node3D = row.node
		if hold == null or hold.get_child_count() < 1:
			continue
		var star: MeshInstance3D = hold.get_child(0)
		var ink := Color(0.38, 0.48, 0.52)
		var energy := 1.2
		if visited.has(sid):
			ink = Color("cbb892")
			energy = 1.8
		if sid == here:
			ink = Color("9eecf5")
			energy = 3.2
		star.material_override = _mat(ink, energy, 1.0, true)


func _ball(radius: float, color: Color, emit: float, alpha: float, unshaded: bool) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 10
	node.mesh = mesh
	node.material_override = _mat(color, emit, alpha, unshaded)
	return node


func _mat(color: Color, emit: float, alpha: float, unshaded: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if unshaded else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.albedo_color = color
	if alpha < 0.999:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = alpha
	if emit > 0.0:
		mat.emission_enabled = true
		mat.emission = Color(color.r, color.g, color.b)
		mat.emission_energy_multiplier = emit
	return mat


func _aim_y(node: Node3D, dir: Vector3) -> void:
	if dir.length() < 0.001:
		return
	var y := dir.normalized()
	var x := Vector3.UP.cross(y)
	if x.length() < 0.001:
		x = Vector3.RIGHT.cross(y)
	x = x.normalized()
	var z := x.cross(y).normalized()
	node.basis = Basis(x, y, z)


func _world_tint(sid: String) -> Color:
	var n: int = sid.length() + sid.hash()
	var t := float(absi(n) % 1000) / 1000.0
	if t < 0.33:
		return Color(0.42, 0.62, 0.78)
	if t < 0.66:
		return Color(0.62, 0.48, 0.36)
	return Color(0.55, 0.7, 0.52)


func _lift(pos: Vector2) -> float:
	return (sin(pos.x * 1.3) + cos(pos.y * 1.1)) * 22.0


func _hash(seed: int, salt: int) -> float:
	var n: int = absi(seed * 1103515245 + salt * 12345)
	return float(n % 10000) / 10000.0
