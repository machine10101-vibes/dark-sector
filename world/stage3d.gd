extends Node3D

## Sim-space meshes. X is chart X, Y is up, Z is negative chart Y.

const PLANET_SHADER := "shader_type spatial;
varying vec3 wnorm;
uniform vec4 albedo : source_color = vec4(0.6, 0.65, 0.62, 1.0);
uniform vec3 to_star = vec3(1.0, 0.05, 0.0);
uniform float city = 0.0;
void vertex() {
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	vec3 n = normalize(wnorm);
	vec3 sun = normalize(to_star);
	float ndl = dot(n, sun);
	float day = smoothstep(-0.12, 0.28, ndl);
	vec3 col = albedo.rgb * (0.2 + 0.85 * day);
	col *= 0.88 + 0.12 * sin(n.y * 24.0 + n.x * 5.0);
	float lamps = 0.0;
	if (city > 0.5) {
		for (int i = 0; i < 7; i++) {
			vec3 lamp = normalize(vec3(sin(float(i) * 1.7), -0.25, cos(float(i) * 2.4)));
			lamps += smoothstep(0.96, 0.995, dot(n, lamp));
		}
		lamps *= clamp(-ndl, 0.0, 1.0);
	}
	float rim = pow(clamp(1.0 - max(ndl, 0.0), 0.0, 1.0), 2.2);
	ALBEDO = col;
	EMISSION = albedo.rgb * pow(clamp(ndl, 0.0, 1.0), 2.4) * 0.35 + vec3(1.0, 0.78, 0.4) * lamps * 1.4 + vec3(0.7, 0.82, 0.9) * rim * 0.22;
	ROUGHNESS = 0.78;
	METALLIC = 0.02;
}
"

var _bodies: Dictionary = {}
var _ships: Dictionary = {}
var _craft: Dictionary = {}
var _props: Dictionary = {}
var _mesh_cache: Dictionary = {}
var tags: Array = []
var _star_mesh: MeshInstance3D
var _star_glow: MeshInstance3D
var _sky: MultiMeshInstance3D
var _grid: MeshInstance3D
var _sun: DirectionalLight3D
var _planet_shader: Shader
var _used: Dictionary = {}


func _ready() -> void:
	_planet_shader = Shader.new()
	_planet_shader.code = PLANET_SHADER
	_build_grid()
	_sun = DirectionalLight3D.new()
	_sun.name = "Sun"
	_sun.light_color = Color("fff0d4")
	_sun.light_energy = 1.35
	_sun.shadow_enabled = false
	add_child(_sun)


func _process(_delta: float) -> void:
	if Game.sim == null or Game.mode != "sector":
		return
	_used.clear()
	tags.clear()
	_sync_star(Game.sim)
	_sync_planets(Game.sim)
	_sync_ships(Game.sim)
	_sync_craft(Game.sim)
	_sync_sky(Game.sim)
	_sync_props(Game.sim)
	_aim_sun(Game.sim)
	_hide_stale(_bodies)
	_hide_stale(_ships)
	_hide_stale(_craft)
	_hide_stale(_props)


func chart(p: Vector2, height: float = 0.0) -> Vector3:
	return Vector3(p.x, height, -p.y)


func _sync_props(sim) -> void:
	var index := 0
	for rock in sim.asteroids:
		var row: Dictionary = rock
		var chunk := _prop("rock%d" % index)
		index += 1
		if str(chunk.get_meta("built", "")) != "yes":
			var verts: PackedVector2Array = row.verts
			var center := Vector2.ZERO
			for point in verts:
				center += point
			if verts.size() > 0:
				center /= float(verts.size())
			var local := PackedVector2Array()
			for point in verts:
				local.append(point - center)
			var span := float(row.get("size", 12.0))
			chunk.mesh = _prism(local, maxf(8.0, span * 0.62))
			chunk.transform = _flat_xform(center, float(absi(hash(str(index))) % 7) * 0.2, 0.0)
			var stone := _metal(Color(str(row.get("tint", "#6a6258"))))
			stone.metallic = 0.05
			stone.roughness = 0.94
			chunk.material_override = stone
			chunk.set_meta("built", "yes")
		chunk.visible = chunk.mesh != null
	index = 0
	for hull in sim.trash:
		var row: Dictionary = hull
		var scrap := _prop("trash%d" % index)
		index += 1
		if str(scrap.get_meta("built", "")) != "yes":
			var scale := float(row.get("scale", 1.0))
			var poly := _trash_poly(int(row.get("kind", 0)), scale)
			scrap.mesh = _prism(poly, maxf(4.0, 5.5 * scale))
			var rust := _metal(Color("6a5344"))
			rust.metallic = 0.35
			rust.roughness = 0.72
			scrap.material_override = rust
			scrap.set_meta("built", "yes")
		scrap.transform = _flat_xform(row.pos, float(row.rot), 1.0)
	index = 0
	for gate in sim.gates:
		var row: Dictionary = gate
		var hoop := _prop("gate%d" % index)
		index += 1
		var radius := float(row.get("radius", 80.0))
		if str(hoop.get_meta("built", "")) != "yes":
			var torus := TorusMesh.new()
			torus.inner_radius = maxf(radius - 7.0, 6.0)
			torus.outer_radius = radius + 7.0
			torus.rings = 28
			torus.ring_segments = 10
			hoop.mesh = torus
			var tone := Color("7d9a86")
			if str(row.get("color", "")) == "amber":
				tone = Color("c4a15a")
			elif str(row.get("color", "")) == "red":
				tone = Color("a85a4a")
			var mat := _metal(tone)
			mat.emission_enabled = true
			mat.emission = tone
			mat.emission_energy_multiplier = 0.35
			hoop.material_override = mat
			hoop.set_meta("built", "yes")
		hoop.position = chart(row.pos, 0.0)
		_tag(str(row.get("name", "")), chart(row.pos, radius * 0.15 + 20.0), Color("e6d7a8"), 13)
	var mast := _prop("beacon")
	if str(mast.get_meta("built", "")) != "yes":
		var pole := CylinderMesh.new()
		pole.top_radius = 2.2
		pole.bottom_radius = 3.4
		pole.height = 36.0
		mast.mesh = pole
		mast.material_override = _metal(Color("8a7a62"))
		mast.set_meta("built", "yes")
	mast.position = chart(sim.beacon_pos, 18.0)
	var lamp := _prop("beacon_lamp")
	if str(lamp.get_meta("built", "")) != "yes":
		var bulb := SphereMesh.new()
		bulb.radius = 5.5
		bulb.height = 11.0
		lamp.mesh = bulb
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color = Color("e7f2ea")
		glow.emission_enabled = true
		glow.emission = Color("d7e6c8")
		glow.emission_energy_multiplier = 1.6
		lamp.material_override = glow
		lamp.set_meta("built", "yes")
	lamp.position = chart(sim.beacon_pos, 40.0)
	_tag("Dock beacon", chart(sim.beacon_pos, 52.0), Color("8aa896"), 13)
	_sync_pocket(sim)
	_sync_nebula()
	_sync_shots(sim)
	_sync_wrecks(sim)
	_sync_meteors(sim)
	_sync_claim(sim)


func _sync_pocket(sim) -> void:
	var hoop := _prop("pocket")
	var radius := float(sim.defs.system.pocket.radius)
	if str(hoop.get_meta("built", "")) != str(radius):
		var torus := TorusMesh.new()
		torus.inner_radius = maxf(radius - 4.0, 8.0)
		torus.outer_radius = radius + 4.0
		torus.rings = 36
		torus.ring_segments = 8
		hoop.mesh = torus
		var mat := _metal(Color("9aaf8c"))
		mat.emission_enabled = true
		mat.emission = Color("9aaf8c")
		mat.emission_energy_multiplier = 0.2
		hoop.material_override = mat
		hoop.set_meta("built", str(radius))
	hoop.position = chart(sim.pocket_pos, 2.0)
	_tag(str(sim.defs.system.pocket.name), chart(sim.pocket_pos, 18.0), Color("c5d2b4"), 14)


func _sync_nebula() -> void:
	var banks: Array[Vector3] = [
		Vector3(-4600.0, 360.0, 2400.0),
		Vector3(5600.0, 280.0, -2200.0),
		Vector3(-2200.0, 420.0, -5200.0),
		Vector3(3800.0, 240.0, 4800.0),
	]
	var radii: Array[float] = [520.0, 460.0, 400.0, 340.0]
	var tints: Array[Color] = [Color(0.35, 0.48, 0.62, 0.08), Color(0.55, 0.32, 0.18, 0.07), Color(0.22, 0.4, 0.38, 0.06), Color(0.5, 0.4, 0.22, 0.05)]
	for i in banks.size():
		var cloud := _prop("nebula%d" % i)
		if str(cloud.get_meta("built", "")) != "yes":
			var ball := SphereMesh.new()
			ball.radius = radii[i]
			ball.height = radii[i] * 2.0
			ball.radial_segments = 24
			ball.rings = 12
			cloud.mesh = ball
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat.albedo_color = tints[i]
			cloud.material_override = mat
			cloud.set_meta("built", "yes")
		cloud.position = banks[i]


func _sync_shots(sim) -> void:
	var index := 0
	for shot in sim.projectiles:
		var row: Dictionary = shot
		var bolt := _prop("shot%d" % index)
		index += 1
		if bolt.mesh == null:
			var ball := SphereMesh.new()
			ball.radius = 2.4
			ball.height = 4.8
			ball.radial_segments = 10
			ball.rings = 6
			bolt.mesh = ball
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = Color("fff1d2")
			mat.emission_enabled = true
			mat.emission = Color("e7b15a")
			mat.emission_energy_multiplier = 2.0
			bolt.material_override = mat
		bolt.position = chart(row.pos, 8.0)


func _sync_wrecks(sim) -> void:
	var index := 0
	for wreck in sim.wrecks:
		var row: Dictionary = wreck
		var hulk := _prop("wreck%d" % index)
		index += 1
		if str(hulk.get_meta("built", "")) != "yes":
			var poly := PackedVector2Array([Vector2(12, 2), Vector2(-6, 9), Vector2(-14, -2), Vector2(3, -8)])
			hulk.mesh = _prism(poly, 7.0)
			var mat := _metal(Color("5a4038"))
			mat.roughness = 0.8
			hulk.material_override = mat
			hulk.set_meta("built", "yes")
		hulk.transform = _flat_xform(row.pos, 0.4, 1.0)
		_tag(str(row.get("name", "wreck")), chart(row.pos, 16.0), Color("a08070"), 12)


func _sync_meteors(sim) -> void:
	var index := 0
	for rock in sim.meteors:
		var row: Dictionary = rock
		var node := _prop("meteor%d" % index)
		index += 1
		if node.mesh == null:
			var ball := SphereMesh.new()
			ball.radius = float(row.get("size", 4.0)) * 2.2
			ball.height = ball.radius * 2.0
			node.mesh = ball
			var mat := _metal(Color("8a3c22"))
			mat.emission_enabled = true
			mat.emission = Color("e7b15a")
			mat.emission_energy_multiplier = 0.45
			node.material_override = mat
		node.position = chart(row.pos, float(row.get("size", 4.0)))


func _sync_claim(sim) -> void:
	var show := bool(sim.claim.get("owned", false)) and str(sim.claim.get("system_id", "")) == str(sim.defs.system.id)
	var dome := _prop("claim")
	if not show:
		dome.visible = false
		_used.erase("prop:claim")
		return
	var origin := Vector2(float(sim.claim.get("x", 0.0)), float(sim.claim.get("y", 0.0)))
	if dome.mesh == null:
		var ball := SphereMesh.new()
		ball.radius = 22.0
		ball.height = 28.0
		dome.mesh = ball
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.72, 0.84, 0.7, 0.72)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 0.12
		mat.emission_enabled = true
		mat.emission = Color("d7e6c8")
		mat.emission_energy_multiplier = 0.2
		dome.material_override = mat
	dome.position = chart(origin, 10.0)
	dome.visible = true


func _prop(key: String) -> MeshInstance3D:
	_used["prop:" + key] = true
	if _props.has(key):
		var existing: MeshInstance3D = _props[key]
		existing.visible = true
		return existing
	var node := MeshInstance3D.new()
	node.name = key
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	_props[key] = node
	return node


func _trash_poly(kind: int, scale: float) -> PackedVector2Array:
	var src := PackedVector2Array([Vector2(18, 0), Vector2(-10, 4), Vector2(-14, 0), Vector2(-10, -4)])
	if kind == 1:
		src = PackedVector2Array([Vector2(12, 0), Vector2(8, 9), Vector2(-12, 8), Vector2(-14, -7), Vector2(6, -9)])
	elif kind >= 2:
		src = PackedVector2Array([Vector2(8, 6), Vector2(-16, 3), Vector2(-6, -2), Vector2(10, -7)])
	var out := PackedVector2Array()
	for point in src:
		out.append(point * scale)
	return out


func _aim_sun(sim) -> void:
	var at: Vector2 = sim.player.pos
	var dir := Vector3(at.x, 40.0, -at.y)
	if dir.length_squared() < 1.0:
		dir = Vector3(1.0, 0.2, 0.0)
	dir = dir.normalized()
	var z_axis := -dir
	var x_axis := Vector3.UP.cross(z_axis)
	if x_axis.length_squared() < 0.001:
		x_axis = Vector3(1.0, 0.0, 0.0)
	x_axis = x_axis.normalized()
	var y_axis := z_axis.cross(x_axis).normalized()
	_sun.basis = Basis(x_axis, y_axis, z_axis)


func _build_grid() -> void:
	_grid = MeshInstance3D.new()
	_grid.name = "Grid"
	var plane := PlaneMesh.new()
	plane.size = Vector2(48000.0, 48000.0)
	_grid.mesh = plane
	_grid.position = Vector3(0.0, -18.0, 0.0)
	var mat := ShaderMaterial.new()
	var grid_shader := Shader.new()
	grid_shader.code = "shader_type spatial;\nrender_mode unshaded, cull_disabled;\nvoid fragment() {\n\tvec2 cell = fract(UV * 96.0);\n\tfloat line = max(step(0.985, cell.x), step(0.985, cell.y));\n\tif (line < 0.5) { discard; }\n\tALBEDO = vec3(0.42, 0.48, 0.52);\n\tALPHA = 0.28;\n}\n"
	mat.shader = grid_shader
	_grid.material_override = mat
	_grid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_grid)


func _sync_star(sim) -> void:
	var radius := float(sim.star_radius)
	if _star_mesh == null:
		_star_mesh = MeshInstance3D.new()
		_star_mesh.name = "Star"
		var ball := SphereMesh.new()
		ball.radial_segments = 48
		ball.rings = 24
		_star_mesh.mesh = ball
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_star_mesh.material_override = mat
		_star_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_star_mesh)
		_star_glow = MeshInstance3D.new()
		_star_glow.name = "Corona"
		var haze := SphereMesh.new()
		haze.radial_segments = 32
		haze.rings = 16
		_star_glow.mesh = haze
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glow.cull_mode = BaseMaterial3D.CULL_DISABLED
		_star_glow.material_override = glow
		_star_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_star_glow)
	var core := Color(str(sim.defs.system.star.color))
	(_star_mesh.mesh as SphereMesh).radius = radius
	(_star_mesh.mesh as SphereMesh).height = radius * 2.0
	var star_mat := _star_mesh.material_override as StandardMaterial3D
	star_mat.albedo_color = core.lightened(0.15)
	(_star_glow.mesh as SphereMesh).radius = radius * 1.35
	(_star_glow.mesh as SphereMesh).height = radius * 2.7
	var glow_mat := _star_glow.material_override as StandardMaterial3D
	glow_mat.albedo_color = Color(core.r, core.g, core.b, 0.08)


func _sync_planets(sim) -> void:
	for body in sim.planets:
		var row: Dictionary = body
		var bid := str(row.get("id", "planet"))
		var node := _body_node(bid)
		var radius := float(row.radius)
		node.position = chart(row.pos, 0.0)
		node.rotation.y = float(row.get("angle", 0.0)) + float(sim.time) * float(row.get("spin", 0.05))
		var ball := node.get_node("Ball") as MeshInstance3D
		(ball.mesh as SphereMesh).radius = radius
		(ball.mesh as SphereMesh).height = radius * 2.0
		var air := node.get_node("Air") as MeshInstance3D
		(air.mesh as SphereMesh).radius = radius * 1.045
		(air.mesh as SphereMesh).height = radius * 2.09
		var colors: Array = row.get("colors", ["#889088"])
		var mat := ball.material_override as ShaderMaterial
		mat.set_shader_parameter("albedo", Color(str(colors[0])))
		var world := chart(row.pos, 0.0)
		var to_star := -world
		if to_star.length_squared() < 1.0:
			to_star = Vector3(1.0, 0.2, 0.0)
		mat.set_shader_parameter("to_star", to_star.normalized())
		var legal := str(row.get("legal", ""))
		var city := 1.0 if (legal.contains("capital") or legal.contains("pdo")) else 0.0
		mat.set_shader_parameter("city", city)
		_sync_ring(node, row, radius)
		_sync_moon(node, sim, row, radius)
		_tag(str(row.get("name", "")), chart(row.pos, radius + 28.0), Color("e6d7bf"), 16)
	var star_name := str(sim.defs.system.star.name)
	_tag(star_name, Vector3(0.0, float(sim.star_radius) + 40.0, 0.0), Color("f0c27a"), 16)


func _body_node(bid: String) -> Node3D:
	_used["body:" + bid] = true
	if _bodies.has(bid):
		(_bodies[bid] as Node3D).visible = true
		return _bodies[bid]
	var node := Node3D.new()
	node.name = bid
	var ball := MeshInstance3D.new()
	ball.name = "Ball"
	var sphere := SphereMesh.new()
	sphere.radial_segments = 48
	sphere.rings = 24
	ball.mesh = sphere
	var mat := ShaderMaterial.new()
	mat.shader = _planet_shader
	ball.material_override = mat
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(ball)
	var air := MeshInstance3D.new()
	air.name = "Air"
	var shell := SphereMesh.new()
	shell.radial_segments = 32
	shell.rings = 16
	air.mesh = shell
	var haze := ShaderMaterial.new()
	var air_shader := Shader.new()
	air_shader.code = "shader_type spatial;\nrender_mode blend_mix, unshaded, cull_disabled;\nvoid fragment() {\n\tfloat fres = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 1.8);\n\tALBEDO = vec3(0.62, 0.8, 0.88);\n\tALPHA = fres * 0.42;\n}\n"
	haze.shader = air_shader
	air.material_override = haze
	air.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(air)
	add_child(node)
	_bodies[bid] = node
	return node


func _sync_ring(node: Node3D, row: Dictionary, radius: float) -> void:
	var ring := node.get_node_or_null("Ring") as MeshInstance3D
	if not bool(row.get("ring", false)):
		if ring != null:
			ring.visible = false
		var hidden := node.get_node_or_null("RingOuter") as MeshInstance3D
		if hidden != null:
			hidden.visible = false
		return
	if ring == null:
		ring = MeshInstance3D.new()
		ring.name = "Ring"
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("d5e4ee")
		mat.roughness = 0.45
		mat.metallic = 0.15
		ring.material_override = mat
		node.add_child(ring)
	var band := maxf(36.0, radius * 0.085)
	ring.mesh = _annulus(radius + band * 0.72, radius + band * 1.15, maxf(3.2, radius * 0.018), 80)
	ring.visible = true
	var outer := node.get_node_or_null("RingOuter") as MeshInstance3D
	if outer == null:
		outer = MeshInstance3D.new()
		outer.name = "RingOuter"
		outer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var faint := StandardMaterial3D.new()
		faint.albedo_color = Color(0.75, 0.84, 0.9, 0.55)
		faint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		faint.roughness = 0.6
		outer.material_override = faint
		node.add_child(outer)
	outer.mesh = _annulus(radius + band * 1.35, radius + band * 1.62, maxf(1.6, radius * 0.008), 72)
	outer.visible = true
	if str(row.get("ring_kind", "")) != "ice":
		var colors: Array = row.get("colors", ["#889088", "#667066", "#d7e6c8"])
		(ring.material_override as StandardMaterial3D).albedo_color = Color(str(colors[2]))


func _sync_moon(node: Node3D, sim, row: Dictionary, radius: float) -> void:
	var moon := node.get_node_or_null("Moon") as MeshInstance3D
	if not bool(row.get("moon", false)):
		if moon != null:
			moon.visible = false
		return
	if moon == null:
		moon = MeshInstance3D.new()
		moon.name = "Moon"
		var sphere := SphereMesh.new()
		sphere.radial_segments = 24
		sphere.rings = 12
		moon.mesh = sphere
		var mat := StandardMaterial3D.new()
		mat.roughness = 0.9
		moon.material_override = mat
		moon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(moon)
	var moon_r := maxf(22.0, radius * 0.1)
	(moon.mesh as SphereMesh).radius = moon_r
	(moon.mesh as SphereMesh).height = moon_r * 2.0
	var orbit := radius + moon_r * 3.1
	var ang := float(sim.time) * 0.35 + 0.6
	moon.position = Vector3(cos(ang) * orbit, moon_r * 0.3, sin(ang) * orbit)
	var colors: Array = row.get("colors", ["#889088", "#9aa090"])
	(moon.material_override as StandardMaterial3D).albedo_color = Color(str(colors[1]))
	moon.visible = true


func _sync_ships(sim) -> void:
	_place_ship(sim, sim.player, "player")
	for actor in sim.actors:
		if bool(actor.get("alive", false)):
			_place_ship(sim, actor, "actor:" + str(actor.get("name", actor.get("agent_id", "a"))))
	for mate in sim.captains:
		if bool(mate.get("alive", false)):
			_place_ship(sim, mate, "mate:" + str(mate.get("name", "mate")))


func _place_ship(sim, ship: Dictionary, key: String) -> void:
	var holder := _ship_holder(key)
	var class_id := str(ship.get("class_id", "vesper"))
	var shapes: Array = Silhouette.shapes_of(sim.defs, ship.modules)
	var layers: Array = Silhouette.layers_of(sim.defs, ship.modules)
	var mesh_key := class_id + "|" + str(shapes) + "|" + str(layers.size())
	if str(holder.get_meta("mesh_key", "")) != mesh_key:
		_fill_ship(holder, class_id, shapes, layers)
		holder.set_meta("mesh_key", mesh_key)
	var hull: Dictionary = sim.defs.ships[class_id]
	var hp := clampf(float(ship.hp) / maxf(float(ship.max_hp), 1.0), 0.0, 1.0)
	var body := Color(str(hull.color)).lerp(Color("3a1818"), (1.0 - hp) * 0.65)
	var accent := Color(str(hull.accent))
	for child in holder.get_children():
		if child is MeshInstance3D and str(child.name).begins_with("Plate"):
			(child.material_override as StandardMaterial3D).albedo_color = body
		elif child is MeshInstance3D and str(child.name).begins_with("Trim"):
			(child.material_override as StandardMaterial3D).albedo_color = accent
	holder.transform = _flat_xform(ship.pos, float(ship.rot), 2.0)
	var exhaust := holder.get_node_or_null("Exhaust") as MeshInstance3D
	if exhaust != null:
		exhaust.visible = bool(ship.get("thrusting", false))
	var call := str(ship.get("name", hull.get("callsign", class_id)))
	if key == "player":
		call = str(hull.get("callsign", call))
	_tag(call, chart(ship.pos + Vector2(22.0, 18.0), float(holder.get_meta("crown", 16.0))), Color("e6d7bf"), 14)


func _add_bridge(holder: Node3D, class_id: String, height: float, tail: float) -> void:
	var deck := Vector3(18.0, height, 0.0)
	var deck_size := Vector3(14.0, 5.5, 6.0)
	if class_id == "anvil":
		deck = Vector3(10.0, height, 0.0)
		deck_size = Vector3(12.0, 7.0, 14.0)
	elif class_id == "kestrel":
		deck = Vector3(12.0, height, 0.0)
		deck_size = Vector3(12.0, 5.0, 8.0)
	elif class_id == "cutter" or class_id == "skiff":
		deck = Vector3(6.0, height, 0.0)
		deck_size = Vector3(8.0, 4.0, 5.0)
	var bridge := MeshInstance3D.new()
	bridge.name = "TrimBridge"
	var box := BoxMesh.new()
	box.size = deck_size
	bridge.mesh = box
	bridge.position = deck + Vector3(0.0, deck_size.y * 0.5, 0.0)
	bridge.material_override = _metal(Color("1c2428"))
	holder.add_child(bridge)
	var glass := MeshInstance3D.new()
	glass.name = "Glass"
	var canopy := BoxMesh.new()
	canopy.size = Vector3(deck_size.x * 0.55, 2.4, deck_size.z * 0.45)
	glass.mesh = canopy
	glass.position = bridge.position + Vector3(deck_size.x * 0.1, deck_size.y * 0.5 + 0.8, 0.0)
	var pane := StandardMaterial3D.new()
	pane.albedo_color = Color(0.45, 0.75, 0.78, 0.55)
	pane.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pane.roughness = 0.08
	pane.metallic = 0.15
	pane.emission_enabled = true
	pane.emission = Color(0.6, 0.85, 0.9)
	pane.emission_energy_multiplier = 0.25
	glass.material_override = pane
	holder.add_child(glass)
	var bell := MeshInstance3D.new()
	bell.name = "TrimBell"
	var nozzle := BoxMesh.new()
	nozzle.size = Vector3(5.5, 3.2, 3.2)
	bell.mesh = nozzle
	bell.position = Vector3(tail - 2.4, height * 0.42, 0.0)
	var hot := _metal(Color("2a2420"))
	hot.emission_enabled = true
	hot.emission = Color("e7b15a")
	hot.emission_energy_multiplier = 0.15
	bell.material_override = hot
	holder.add_child(bell)
	var flame := MeshInstance3D.new()
	flame.name = "Exhaust"
	var plume := CylinderMesh.new()
	plume.top_radius = 0.4
	plume.bottom_radius = 2.6
	plume.height = maxf(18.0, height * 1.3)
	flame.mesh = plume
	flame.basis = Basis(Vector3(0.0, 0.0, 1.0), Vector3(-1.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0))
	flame.position = Vector3(tail - plume.height * 0.55, height * 0.42, 0.0)
	var burn := StandardMaterial3D.new()
	burn.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	burn.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	burn.albedo_color = Color(1.0, 0.72, 0.32, 0.85)
	burn.emission_enabled = true
	burn.emission = Color("ffd7a0")
	burn.emission_energy_multiplier = 1.4
	flame.material_override = burn
	flame.visible = false
	holder.add_child(flame)


func _ship_holder(key: String) -> Node3D:
	_used["ship:" + key] = true
	if _ships.has(key):
		(_ships[key] as Node3D).visible = true
		return _ships[key]
	var node := Node3D.new()
	node.name = key
	add_child(node)
	_ships[key] = node
	return node


func _fill_ship(holder: Node3D, class_id: String, shapes: Array, layers: Array) -> void:
	for child in holder.get_children():
		holder.remove_child(child)
		child.free()
	var geom := Silhouette.parts(class_id, shapes, layers)
	var ext: Vector2 = Silhouette.extent(geom)
	var height := clampf(maxf(ext.x, ext.y * 2.0) * 0.48, 14.0, 40.0)
	holder.set_meta("crown", height)
	holder.set_meta("tail", float(geom.tail))
	var hull_mesh := _prism(geom.hull, height)
	if hull_mesh != null:
		var plate := MeshInstance3D.new()
		plate.name = "Plate"
		plate.mesh = hull_mesh
		plate.material_override = _metal(Color("888888"))
		holder.add_child(plate)
	var extra_i := 0
	for extra in geom.extras:
		var extra_mesh := _prism(extra, height * 0.72)
		if extra_mesh == null:
			continue
		var trim := MeshInstance3D.new()
		trim.name = "Trim%d" % extra_i
		trim.mesh = extra_mesh
		trim.position.y = height * 0.2
		trim.material_override = _metal(Color("cccccc"))
		holder.add_child(trim)
		extra_i += 1
	var circle_i := 0
	for circle in geom.circles:
		var ball := MeshInstance3D.new()
		ball.name = "TrimC%d" % circle_i
		var sphere := SphereMesh.new()
		var rad := float(circle.r)
		sphere.radius = rad
		sphere.height = rad * 2.0
		ball.mesh = sphere
		ball.position = Vector3(float(circle.x), height * 0.55, float(circle.y))
		ball.material_override = _metal(Color("cccccc"))
		holder.add_child(ball)
		circle_i += 1
	_add_bridge(holder, class_id, height, float(geom.tail))


func _sync_craft(sim) -> void:
	var parked := 0
	var index := 0
	for item in sim.craft:
		var row: Dictionary = item
		var pos: Vector2 = row.pos
		var rot := float(row.rot)
		if str(row.get("state", "")) == "docked" and bool(sim.player.get("alive", false)):
			var side := Vector2.from_angle(float(sim.player.rot) + PI * 0.5)
			var back := Vector2.from_angle(float(sim.player.rot) + PI)
			pos = sim.player.pos + back * (34.0 + float(parked) * 16.0) + side * (18.0 if parked % 2 == 0 else -18.0)
			rot = float(sim.player.rot)
			parked += 1
		var key := "c%d" % index
		index += 1
		var kind := str(row.get("def_id", "fighter"))
		var holder := _craft_holder(key, kind)
		holder.transform = _flat_xform(pos, rot, 1.5)
		if Game.zoom > 0.9 and str(row.get("state", "")) != "docked":
			_tag(str(row.get("name", kind)), chart(pos + Vector2(14.0, 10.0), 8.0), Color("d7e6c8"), 12)


func _craft_holder(key: String, kind: String) -> Node3D:
	_used["craft:" + key] = true
	if _craft.has(key) and str((_craft[key] as Node).get_meta("kind", "")) == kind:
		(_craft[key] as Node3D).visible = true
		return _craft[key]
	if _craft.has(key):
		(_craft[key] as Node).queue_free()
	var node := Node3D.new()
	node.name = key
	node.set_meta("kind", kind)
	var poly := _craft_poly(kind)
	var mesh := _prism(poly, 6.0)
	if mesh != null:
		var body := MeshInstance3D.new()
		body.name = "Plate"
		body.mesh = mesh
		body.material_override = _metal(_craft_color(kind))
		node.add_child(body)
	add_child(node)
	_craft[key] = node
	return node


func _craft_poly(kind: String) -> PackedVector2Array:
	match kind:
		"survey_probe":
			return PackedVector2Array([Vector2(12, 0), Vector2(2, 1.7), Vector2(-8, 1.2), Vector2(-8, -1.2), Vector2(2, -1.7)])
		"harvest_drone":
			return PackedVector2Array([Vector2(5.5, 4.6), Vector2(5.5, -4.6), Vector2(-5, -4), Vector2(-5, 4)])
		"salvage_tender":
			return PackedVector2Array([Vector2(8, 3), Vector2(3, 5.2), Vector2(-7.5, 4.4), Vector2(-7.5, -4.4), Vector2(3, -5.2), Vector2(8, -3)])
		"away_shuttle":
			return PackedVector2Array([Vector2(9, 0), Vector2(1.5, 4), Vector2(-6.5, 3.2), Vector2(-6.5, -3.2), Vector2(1.5, -4)])
		_:
			return PackedVector2Array([Vector2(11, 0), Vector2(1, 2), Vector2(-3.5, 6), Vector2(-1.2, 0), Vector2(-3.5, -6), Vector2(1, -2)])


func _craft_color(kind: String) -> Color:
	match kind:
		"survey_probe":
			return Color("9fd0c8")
		"harvest_drone":
			return Color("d2a15a")
		"salvage_tender":
			return Color("c47a4a")
		"away_shuttle":
			return Color("d7d2c4")
		_:
			return Color("c4512c")


func _sync_sky(sim) -> void:
	if _sky == null:
		_sky = MultiMeshInstance3D.new()
		_sky.name = "Sky"
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		var dot := SphereMesh.new()
		dot.radius = 1.0
		dot.height = 2.0
		dot.radial_segments = 6
		dot.rings = 4
		mm.mesh = dot
		_sky.multimesh = mm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		_sky.material_override = mat
		_sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_sky)
	var mm := _sky.multimesh
	var count: int = sim.stars.size()
	if mm.instance_count != count:
		mm.instance_count = count
	for i in count:
		var star: Dictionary = sim.stars[i]
		var p: Vector2 = star.pos
		var lift := float(absi(hash(str(i))) % 500) - 250.0
		var scale := 2.4 + float(star.a) * 3.2
		var basis := Basis.IDENTITY.scaled(Vector3(scale, scale, scale))
		mm.set_instance_transform(i, Transform3D(basis, Vector3(p.x, lift, -p.y)))
		var temp := float(star.a)
		var tint := Color(0.72, 0.8, 0.95) if temp < 0.4 else Color(0.95, 0.9, 0.78)
		if temp > 0.7:
			tint = Color(1.0, 0.82, 0.62)
		mm.set_instance_color(i, tint)


func _tag(text: String, at: Vector3, color: Color, size: int) -> void:
	tags.append({"t": text, "p": at, "c": color, "s": size})


func _hide_stale(pool: Dictionary) -> void:
	for key in pool.keys():
		var kind := "body"
		if pool == _ships:
			kind = "ship"
		elif pool == _craft:
			kind = "craft"
		elif pool == _props:
			kind = "prop"
		if _used.has(kind + ":" + str(key)) == false:
			(pool[key] as Node3D).visible = false


func _flat_xform(pos: Vector2, rot: float, height: float) -> Transform3D:
	var fwd := Vector2.from_angle(rot)
	var x_axis := Vector3(fwd.x, 0.0, -fwd.y)
	var z_axis := Vector3(-fwd.y, 0.0, -fwd.x)
	return Transform3D(Basis(x_axis, Vector3.UP, z_axis), chart(pos, height))


func _metal(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.62
	mat.roughness = 0.38
	return mat


func _prism(poly: PackedVector2Array, height: float) -> ArrayMesh:
	if poly.size() < 3:
		return null
	var indices := Geometry2D.triangulate_polygon(poly)
	if indices.size() < 3:
		return null
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := poly.size()
	var centroid := Vector2.ZERO
	for point in poly:
		centroid += point
	centroid /= float(count)
	for t in range(0, indices.size(), 3):
		_tri(st, poly[indices[t]], poly[indices[t + 1]], poly[indices[t + 2]], height, Vector3.UP)
		_tri(st, poly[indices[t]], poly[indices[t + 2]], poly[indices[t + 1]], 0.0, Vector3.DOWN)
	for i in count:
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % count]
		var edge := b - a
		var outward := Vector2(edge.y, -edge.x)
		if outward.dot(a - centroid) < 0.0:
			outward = -outward
		if outward.length_squared() < 0.0001:
			continue
		outward = outward.normalized()
		var normal := Vector3(outward.x, 0.0, outward.y)
		_wall(st, a, b, height, normal)
	return st.commit()


func _tri(st: SurfaceTool, a: Vector2, b: Vector2, c: Vector2, y: float, normal: Vector3) -> void:
	st.set_normal(normal)
	st.add_vertex(Vector3(a.x, y, a.y))
	st.set_normal(normal)
	st.add_vertex(Vector3(b.x, y, b.y))
	st.set_normal(normal)
	st.add_vertex(Vector3(c.x, y, c.y))


func _wall(st: SurfaceTool, a: Vector2, b: Vector2, height: float, normal: Vector3) -> void:
	st.set_normal(normal)
	st.add_vertex(Vector3(a.x, 0.0, a.y))
	st.set_normal(normal)
	st.add_vertex(Vector3(b.x, 0.0, b.y))
	st.set_normal(normal)
	st.add_vertex(Vector3(b.x, height, b.y))
	st.set_normal(normal)
	st.add_vertex(Vector3(a.x, 0.0, a.y))
	st.set_normal(normal)
	st.add_vertex(Vector3(b.x, height, b.y))
	st.set_normal(normal)
	st.add_vertex(Vector3(a.x, height, a.y))


func _annulus(inner_r: float, outer_r: float, height: float, segs: int) -> ArrayMesh:
	var cached := "%0.1f|%0.1f|%0.2f" % [inner_r, outer_r, height]
	if _mesh_cache.has(cached):
		return _mesh_cache[cached]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := height * 0.5
	for i in segs:
		var a0 := float(i) * TAU / float(segs)
		var a1 := float(i + 1) * TAU / float(segs)
		var i0 := Vector3(cos(a0) * inner_r, 0.0, sin(a0) * inner_r)
		var o0 := Vector3(cos(a0) * outer_r, 0.0, sin(a0) * outer_r)
		var i1 := Vector3(cos(a1) * inner_r, 0.0, sin(a1) * inner_r)
		var o1 := Vector3(cos(a1) * outer_r, 0.0, sin(a1) * outer_r)
		_quad(st, i0 + Vector3.UP * half, o0 + Vector3.UP * half, o1 + Vector3.UP * half, i1 + Vector3.UP * half, Vector3.UP)
		_quad(st, i1 - Vector3.UP * half, o1 - Vector3.UP * half, o0 - Vector3.UP * half, i0 - Vector3.UP * half, Vector3.DOWN)
	var mesh := st.commit()
	_mesh_cache[cached] = mesh
	return mesh


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
	st.set_normal(normal)
	st.add_vertex(a)
	st.set_normal(normal)
	st.add_vertex(b)
	st.set_normal(normal)
	st.add_vertex(c)
	st.set_normal(normal)
	st.add_vertex(a)
	st.set_normal(normal)
	st.add_vertex(c)
	st.set_normal(normal)
	st.add_vertex(d)
