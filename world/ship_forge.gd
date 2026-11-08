extends RefCounted
## Procedural sci-fi hull kit. Fuselages are lofted from cross-sections,
## wings are bevelled plates that root inside the body, engines are real
## bells with a lit throat, and every surface carries the panel shader.
## Craft and ship builders compose these parts so each hull reads as one
## finished machine.

const HULL_SHADER := "shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
varying vec3 lp;
varying vec3 ln;
uniform vec4 albedo : source_color = vec4(0.5, 0.55, 0.58, 1.0);
uniform vec4 accent : source_color = vec4(0.0, 0.0, 0.0, 0.0);
uniform float tile = 4.0;
uniform float stripe_z = 0.0;
uniform float stripe_w = 0.0;
uniform float band_x = 9999.0;
uniform float band_w = 0.0;
uniform float windows = 0.0;
uniform float win_y = 0.0;
uniform float win_gap = 2.0;
uniform float win_pitch = 1.2;
uniform float win_rows = 2.0;
uniform float plate_heat = 0.0;
uniform float aft_x = -9999.0;
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}
vec2 face_uv(vec3 p, vec3 n) {
	vec3 a = abs(n);
	if (a.y >= a.x && a.y >= a.z) {
		return p.xz;
	}
	if (a.z >= a.x) {
		return p.xy;
	}
	return p.zy;
}
void vertex() {
	lp = VERTEX;
	ln = NORMAL;
}
void fragment() {
	vec3 n = normalize(ln);
	vec2 uv = face_uv(lp, n);
	vec2 g = uv / tile;
	float row = floor(g.y);
	g.x += hash(vec2(row, 3.0)) * 0.5;
	vec2 cell = floor(g);
	vec2 f = abs(fract(g) - 0.5);
	float line = smoothstep(0.455, 0.5, max(f.x, f.y));
	vec2 g2 = uv / (tile * 0.25);
	vec2 f2 = abs(fract(g2) - 0.5);
	float fine = smoothstep(0.47, 0.5, max(f2.x, f2.y)) * 0.35;
	float id = hash(cell);
	vec3 col = albedo.rgb * (0.9 + 0.2 * id);
	col = mix(col, col * 0.72, step(0.82, id) * 0.6);
	col = mix(col, col * vec3(0.3, 0.32, 0.34), max(line, fine * (1.0 - line)) * 0.8);
	float rivet = smoothstep(0.1, 0.0, length(fract(g * 4.0) - 0.5)) * smoothstep(0.34, 0.5, max(f.x, f.y)) * (1.0 - line);
	col = mix(col, col * 1.35, rivet * 0.6);
	float hatch = smoothstep(0.1, 0.06, length(f - vec2(0.3))) * step(0.82, hash(cell + 7.0));
	col = mix(col, col * 0.35, hatch * 0.7);
	float vent = step(0.88, hash(cell + 3.0)) * smoothstep(0.35, 0.3, f.x) * step(0.5, abs(sin(uv.y * 6.28 / tile * 3.0)));
	col = mix(col, col * 0.3, vent * (1.0 - line) * 0.8);
	float scuff = smoothstep(0.93, 0.995, hash(floor(uv * 5.0 / tile * 3.0) + cell));
	col = mix(col, col * 1.28, scuff * 0.25);
	float stripe = stripe_w > 0.0 ? smoothstep(stripe_w, stripe_w * 0.55, abs(abs(lp.z) - stripe_z)) : 0.0;
	stripe *= smoothstep(0.1, 0.6, n.y);
	float band = band_w > 0.0 ? smoothstep(band_w, band_w * 0.6, abs(lp.x - band_x)) : 0.0;
	col = mix(col, accent.rgb, clamp(stripe + band, 0.0, 1.0) * accent.a);
	float belly = smoothstep(0.1, -0.7, n.y);
	col *= mix(1.0, 0.7, belly);
	float sky = smoothstep(0.2, 1.0, n.y);
	col *= mix(0.94, 1.1, sky);
	float edge = pow(clamp(1.0 - abs(n.y), 0.0, 1.0), 2.2);
	float aft = aft_x > -9000.0 ? smoothstep(aft_x * 0.45, aft_x, lp.x) : 0.0;
	col = mix(col, col * vec3(1.12, 0.82, 0.62), aft * 0.4);
	float wy = 0.0;
	float wx = 0.0;
	float lit = 0.0;
	if (windows > 0.0) {
		float rows_in = step(win_y - win_gap * 0.5, lp.y) * step(lp.y, win_y + win_gap * (win_rows - 0.5));
		wy = smoothstep(0.16, 0.08, abs(fract((lp.y - win_y) / win_gap + 0.5) - 0.5)) * rows_in;
		wx = smoothstep(0.34, 0.26, abs(fract(lp.x / win_pitch) - 0.5));
		float side = smoothstep(0.55, 0.85, abs(n.z));
		float on = wy * wx * side * windows;
		lit = step(0.35, hash(vec2(floor(lp.x / win_pitch), floor((lp.y - win_y) / win_gap)))) * on;
		col = mix(col, vec3(0.03, 0.045, 0.06), on * 0.9);
	}
	ALBEDO = col;
	float bare = clamp(edge * (1.0 - line), 0.0, 1.0);
	METALLIC = mix(0.3, 0.62, bare + hatch * 0.3);
	ROUGHNESS = mix(0.46, 0.3, bare) + line * 0.3 + vent * 0.2;
	AO = mix(1.0, 0.55, line);
	EMISSION = vec3(1.0, 0.88, 0.52) * lit * 2.4 + vec3(0.46, 0.62, 0.8) * edge * 0.06;
	EMISSION += vec3(1.0, 0.32, 0.06) * clamp(plate_heat, 0.0, 1.0) * (0.22 + aft * 1.1);
	EMISSION += accent.rgb * accent.a * stripe * 0.05;
}
"

const GLASS_SHADER := "shader_type spatial;
render_mode blend_mix, depth_draw_opaque, specular_schlick_ggx;
varying vec3 wn;
varying vec3 wp;
varying vec3 lp;
uniform vec4 tint : source_color = vec4(0.1, 0.34, 0.44, 0.9);
uniform float glow = 0.6;
void vertex() {
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	lp = VERTEX;
}
void fragment() {
	vec3 n = normalize(wn);
	vec3 eye = normalize(CAMERA_POSITION_WORLD - wp);
	float fres = pow(clamp(1.0 - abs(dot(n, eye)), 0.0, 1.0), 2.0);
	float streak = smoothstep(0.55, 0.9, sin(lp.x * 1.3 + lp.z * 2.2) * 0.5 + 0.5) * 0.35;
	vec3 deep = tint.rgb * (0.5 + 0.5 * n.y);
	ALBEDO = mix(deep, vec3(0.7, 0.9, 1.0), fres * 0.6 + streak * 0.4);
	EMISSION = tint.rgb * glow * (0.6 + 0.4 * n.y) + vec3(0.6, 0.85, 1.0) * (fres * 0.5 + streak * 0.4);
	METALLIC = 0.85;
	ROUGHNESS = 0.08;
	ALPHA = clamp(tint.a - fres * 0.12, 0.0, 1.0);
}
"

const SOLAR_SHADER := "shader_type spatial;
varying vec3 lp;
uniform float cell = 1.2;
void vertex() {
	lp = VERTEX;
}
void fragment() {
	vec2 g = abs(fract(lp.xz / cell) - 0.5);
	float line = smoothstep(0.42, 0.5, max(g.x, g.y));
	float sheen = 0.5 + 0.5 * sin(lp.x * 0.35 + lp.z * 0.5);
	vec3 pane = mix(vec3(0.03, 0.1, 0.26), vec3(0.08, 0.3, 0.56), sheen);
	ALBEDO = mix(pane, vec3(0.5, 0.56, 0.62), line);
	METALLIC = 0.85;
	ROUGHNESS = mix(0.18, 0.55, line);
	EMISSION = pane * 0.28 * (1.0 - line);
}
"

class MB:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var idx := PackedInt32Array()

	func vert(p: Vector3, nn: Vector3) -> int:
		v.append(p)
		n.append(nn)
		return v.size() - 1

	func tri(a: int, b: int, c: int) -> void:
		var g := (v[b] - v[a]).cross(v[c] - v[a])
		var facing := n[a] + n[b] + n[c]
		if g.dot(facing) > 0.0:
			idx.append_array([a, c, b])
		else:
			idx.append_array([a, b, c])

	func quad(a: int, b: int, c: int, d: int) -> void:
		tri(a, b, c)
		tri(a, c, d)

	func flat_tri(p0: Vector3, p1: Vector3, p2: Vector3, hint: Vector3) -> void:
		var nn := (p1 - p0).cross(p2 - p0)
		if nn.length() < 0.000001:
			return
		nn = nn.normalized()
		if nn.dot(hint) < 0.0:
			nn = -nn
		tri(vert(p0, nn), vert(p1, nn), vert(p2, nn))

	func flat_quad(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, hint: Vector3) -> void:
		flat_tri(p0, p1, p2, hint)
		flat_tri(p0, p2, p3, hint)

	func build() -> ArrayMesh:
		var mesh := ArrayMesh.new()
		if v.is_empty():
			return mesh
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = v
		arrays[Mesh.ARRAY_NORMAL] = n
		arrays[Mesh.ARRAY_INDEX] = idx
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return mesh


var host: Node
var hull_shader: Shader
var glass_shader: Shader
var solar_shader: Shader
var plume_shader: Shader
var _mats: Dictionary = {}
var _meshes: Dictionary = {}


func _init(owner_node: Node = null, plume: Shader = null) -> void:
	host = owner_node
	plume_shader = plume
	hull_shader = Shader.new()
	hull_shader.code = HULL_SHADER
	glass_shader = Shader.new()
	glass_shader.code = GLASS_SHADER
	solar_shader = Shader.new()
	solar_shader.code = SOLAR_SHADER


# ---------------------------------------------------------------- materials

func hull(color: Color, opts: Dictionary = {}) -> ShaderMaterial:
	var key := "hull|%s|%s" % [color.to_html(), str(opts)]
	if _mats.has(key):
		return _mats[key]
	var mat := ShaderMaterial.new()
	mat.shader = hull_shader
	mat.set_shader_parameter("albedo", color)
	for name in opts:
		mat.set_shader_parameter(str(name), opts[name])
	_mats[key] = mat
	return mat


func hull_fresh(color: Color, opts: Dictionary = {}) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = hull_shader
	mat.set_shader_parameter("albedo", color)
	for key in opts:
		mat.set_shader_parameter(str(key), opts[key])
	return mat


func metal(color: Color, rough: float = 0.3, metallic: float = 0.8) -> StandardMaterial3D:
	var key := "metal|%s|%0.2f|%0.2f" % [color.to_html(), rough, metallic]
	if _mats.has(key):
		return _mats[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = rough
	_mats[key] = mat
	return mat


func glow(color: Color, energy: float = 2.0) -> StandardMaterial3D:
	var key := "glow|%s|%0.2f" % [color.to_html(), energy]
	if _mats.has(key):
		return _mats[key]
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	_mats[key] = mat
	return mat


func glass(color: Color = Color(0.1, 0.34, 0.44, 0.9), energy: float = 0.6) -> ShaderMaterial:
	var key := "glass|%s|%0.2f" % [color.to_html(), energy]
	if _mats.has(key):
		return _mats[key]
	var mat := ShaderMaterial.new()
	mat.shader = glass_shader
	mat.set_shader_parameter("tint", color)
	mat.set_shader_parameter("glow", energy)
	_mats[key] = mat
	return mat


func solar(cell: float = 1.2) -> ShaderMaterial:
	var key := "solar|%0.2f" % cell
	if _mats.has(key):
		return _mats[key]
	var mat := ShaderMaterial.new()
	mat.shader = solar_shader
	mat.set_shader_parameter("cell", cell)
	_mats[key] = mat
	return mat


# ------------------------------------------------------------------ meshes

func loft(stations: Array, sides: int = 18) -> ArrayMesh:
	var key := "loft|%s|%d" % [str(stations), sides]
	if _meshes.has(key):
		return _meshes[key]
	var mb := MB.new()
	var rows: Array = []
	var centers: Array = []
	for st in stations:
		var x := float(st[0])
		var hw := maxf(float(st[1]), 0.02)
		var yb := float(st[2])
		var yt := float(st[3])
		var e := float(st[4]) if st.size() > 4 else 2.5
		var yc := (yb + yt) * 0.5
		var hh := maxf((yt - yb) * 0.5, 0.02)
		var ring: Array = []
		for j in sides:
			var a := TAU * float(j) / float(sides)
			var c := cos(a)
			var s := sin(a)
			var pz := hw * signf(c) * pow(absf(c), 2.0 / e)
			var py := yc + hh * signf(s) * pow(absf(s), 2.0 / e)
			ring.append(Vector3(x, py, pz))
		rows.append(ring)
		centers.append(Vector3(x, yc, 0.0))
	var count := rows.size()
	var ids: Array = []
	for i in count:
		var row_ids: Array = []
		for j in sides:
			var p: Vector3 = rows[i][j]
			var ti: Vector3 = rows[mini(i + 1, count - 1)][j] - rows[maxi(i - 1, 0)][j]
			var tj: Vector3 = rows[i][(j + 1) % sides] - rows[i][(j - 1 + sides) % sides]
			var out: Vector3 = p - centers[i]
			out.x = 0.0
			var nn := ti.cross(tj)
			if nn.length() < 0.00001:
				nn = out
			nn = nn.normalized()
			if nn.dot(out) < 0.0:
				nn = -nn
			row_ids.append(mb.vert(p, nn))
		ids.append(row_ids)
	for i in count - 1:
		for j in sides:
			var j2 := (j + 1) % sides
			mb.quad(ids[i][j], ids[i][j2], ids[i + 1][j2], ids[i + 1][j])
	for end in [0, count - 1]:
		var st: Array = stations[end]
		if float(st[1]) < 0.25:
			continue
		var dir := Vector3(-1.0, 0.0, 0.0) if end == 0 else Vector3(1.0, 0.0, 0.0)
		var hub := mb.vert(centers[end], dir)
		var ring_ids: Array = []
		for j in sides:
			ring_ids.append(mb.vert(rows[end][j], dir))
		for j in sides:
			mb.tri(hub, ring_ids[j], ring_ids[(j + 1) % sides])
	var mesh := mb.build()
	_meshes[key] = mesh
	return mesh


func plate(poly: Array, thick: float, top_inset: float = 0.86, bot_inset: float = 0.96) -> ArrayMesh:
	var key := "plate|%s|%0.2f|%0.2f|%0.2f" % [str(poly), thick, top_inset, bot_inset]
	if _meshes.has(key):
		return _meshes[key]
	var mb := MB.new()
	var c := Vector2.ZERO
	for p in poly:
		c += p
	c /= float(poly.size())
	var top: Array = []
	var bot: Array = []
	for p in poly:
		var tp: Vector2 = c + (p - c) * top_inset
		var bp: Vector2 = c + (p - c) * bot_inset
		top.append(Vector3(tp.x, thick * 0.5, tp.y))
		bot.append(Vector3(bp.x, -thick * 0.5, bp.y))
	var count := poly.size()
	for i in count:
		var j := (i + 1) % count
		var mid: Vector2 = (poly[i] + poly[j]) * 0.5 - c
		mb.flat_quad(bot[i], bot[j], top[j], top[i], Vector3(mid.x, 0.2, mid.y))
	var top_c := Vector3(c.x, thick * 0.5, c.y)
	var bot_c := Vector3(c.x, -thick * 0.5, c.y)
	for i in count:
		var j := (i + 1) % count
		mb.flat_tri(top_c, top[i], top[j], Vector3.UP)
		mb.flat_tri(bot_c, bot[i], bot[j], Vector3.DOWN)
	var mesh := mb.build()
	_meshes[key] = mesh
	return mesh


func slab(size: Vector3, inset: float = 0.9) -> ArrayMesh:
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	return plate([Vector2(hx, hz), Vector2(-hx, hz), Vector2(-hx, -hz), Vector2(hx, -hz)], size.y, inset, 1.0)


func tube(r_aft: float, r_fore: float, length: float, sides: int = 16, caps: bool = true) -> ArrayMesh:
	var key := "tube|%0.2f|%0.2f|%0.2f|%d|%s" % [r_aft, r_fore, length, sides, caps]
	if _meshes.has(key):
		return _meshes[key]
	var mb := MB.new()
	var slope := (r_aft - r_fore) / maxf(length, 0.01)
	var a_ids: Array = []
	var f_ids: Array = []
	for j in sides:
		var a := TAU * float(j) / float(sides)
		var c := cos(a)
		var s := sin(a)
		var nn := Vector3(slope, c, s).normalized()
		a_ids.append(mb.vert(Vector3(-length * 0.5, c * r_aft, s * r_aft), nn))
		f_ids.append(mb.vert(Vector3(length * 0.5, c * r_fore, s * r_fore), nn))
	for j in sides:
		var j2 := (j + 1) % sides
		mb.quad(a_ids[j], a_ids[j2], f_ids[j2], f_ids[j])
	if caps:
		for end in [0, 1]:
			var r := r_aft if end == 0 else r_fore
			if r < 0.02:
				continue
			var x := -length * 0.5 if end == 0 else length * 0.5
			var dir := Vector3(-1.0, 0.0, 0.0) if end == 0 else Vector3(1.0, 0.0, 0.0)
			var hub := mb.vert(Vector3(x, 0.0, 0.0), dir)
			var ring: Array = []
			for j in sides:
				var a := TAU * float(j) / float(sides)
				ring.append(mb.vert(Vector3(x, cos(a) * r, sin(a) * r), dir))
			for j in sides:
				mb.tri(hub, ring[j], ring[(j + 1) % sides])
	var mesh := mb.build()
	_meshes[key] = mesh
	return mesh


func bell(length: float, r_throat: float, r_mouth: float, sides: int = 20) -> ArrayMesh:
	var key := "bell|%0.2f|%0.2f|%0.2f" % [length, r_throat, r_mouth]
	if _meshes.has(key):
		return _meshes[key]
	var mb := MB.new()
	var wall := maxf(r_mouth * 0.09, 0.06)
	var slope := (r_throat - r_mouth) / maxf(length, 0.01)
	var o_t: Array = []
	var o_m: Array = []
	var i_t: Array = []
	var i_m: Array = []
	for j in sides:
		var a := TAU * float(j) / float(sides)
		var c := cos(a)
		var s := sin(a)
		var nn := Vector3(-slope * 0.0 - 0.3, c, s).normalized()
		var ni := Vector3(0.3, -c, -s).normalized()
		o_t.append(mb.vert(Vector3(0.0, c * (r_throat + wall), s * (r_throat + wall)), nn))
		o_m.append(mb.vert(Vector3(-length, c * (r_mouth + wall), s * (r_mouth + wall)), nn))
		i_t.append(mb.vert(Vector3(0.0, c * r_throat, s * r_throat), ni))
		i_m.append(mb.vert(Vector3(-length, c * r_mouth, s * r_mouth), ni))
	for j in sides:
		var j2 := (j + 1) % sides
		mb.quad(o_t[j], o_t[j2], o_m[j2], o_m[j])
		mb.quad(i_t[j], i_t[j2], i_m[j2], i_m[j])
		var lip_n := Vector3(-1.0, 0.0, 0.0)
		var a0 := mb.vert(mb.v[o_m[j]], lip_n)
		var a1 := mb.vert(mb.v[o_m[j2]], lip_n)
		var b0 := mb.vert(mb.v[i_m[j]], lip_n)
		var b1 := mb.vert(mb.v[i_m[j2]], lip_n)
		mb.quad(a0, a1, b1, b0)
	var mesh := mb.build()
	_meshes[key] = mesh
	return mesh


func disc(radius: float, sides: int = 16) -> ArrayMesh:
	return tube(radius, radius, 0.06, sides)


# --------------------------------------------------------------- placement

func add(parent: Node3D, part_name: String, mesh: Mesh, mat: Material, at: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = part_name
	node.mesh = mesh
	node.material_override = mat
	node.position = at
	node.rotation = rot
	node.scale = scl
	parent.add_child(node)
	return node


func fuselage(parent: Node3D, part_name: String, stations: Array, color: Color, opts: Dictionary = {}, sides: int = 18) -> MeshInstance3D:
	return add(parent, part_name, loft(stations, sides), hull(color, opts))


func wing(parent: Node3D, part_name: String, poly: Array, at: Vector3, thick: float, color: Color, opts: Dictionary = {}, dihedral: float = 0.0, top_inset: float = 0.8) -> void:
	var mesh := plate(poly, thick, top_inset, 0.97)
	var mat := hull(color, opts)
	add(parent, part_name + "P", mesh, mat, at, Vector3(-dihedral, 0.0, 0.0))
	var mirrored: Array = []
	for i in range(poly.size() - 1, -1, -1):
		var p: Vector2 = poly[i]
		mirrored.append(Vector2(p.x, -p.y))
	add(parent, part_name + "S", plate(mirrored, thick, top_inset, 0.97), mat, Vector3(at.x, at.y, -at.z), Vector3(dihedral, 0.0, 0.0))


func block(parent: Node3D, part_name: String, size: Vector3, at: Vector3, color: Color, opts: Dictionary = {}, inset: float = 0.9) -> MeshInstance3D:
	return add(parent, part_name, slab(size, inset), hull(color, opts), at)


func pipe(parent: Node3D, part_name: String, radius: float, length: float, at: Vector3, color: Color, rot: Vector3 = Vector3.ZERO, taper: float = 1.0) -> MeshInstance3D:
	return add(parent, part_name, tube(radius, radius * taper, length), hull(color, {"tile": maxf(length * 0.5, 1.0)}), at, rot)


func canopy(parent: Node3D, part_name: String, length: float, width: float, height: float, at: Vector3, tint: Color = Color(0.1, 0.34, 0.44, 0.9)) -> MeshInstance3D:
	var half := length * 0.5
	var stations := [
		[-half, width * 0.18, -height * 0.05, height * 0.2, 2.2],
		[-half * 0.5, width * 0.5, -height * 0.1, height * 0.85, 2.2],
		[half * 0.1, width * 0.5, -height * 0.1, height, 2.2],
		[half * 0.7, width * 0.34, -height * 0.1, height * 0.55, 2.2],
		[half, width * 0.08, -height * 0.05, height * 0.12, 2.2],
	]
	return add(parent, part_name, loft(stations, 12), glass(tint), at)


func engine(parent: Node3D, part_name: String, at: Vector3, r: float, length: float, tint: Color = Color(1.0, 0.62, 0.26)) -> MeshInstance3D:
	var node := add(parent, part_name, bell(length, r * 0.62, r), hull(Color("2a2d33"), {"tile": maxf(r, 0.6)}), at)
	add(node, "Housing", tube(r * 0.72, r * 0.66, length * 0.7, 16), hull(Color("59626a"), {"tile": maxf(r * 1.5, 0.8)}), Vector3(length * 0.34, 0.0, 0.0))
	add(node, "Ring", tube(r * 0.78, r * 0.78, maxf(r * 0.18, 0.1), 16), metal(Color("c9ccd0"), 0.25), Vector3(-length * 0.08, 0.0, 0.0))
	var hot := add(node, "Core", disc(r * 0.6), glow(tint, 3.2), Vector3(-length * 0.35, 0.0, 0.0))
	hot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


func plume(parent: Node3D, part_name: String, at: Vector3, length: float, radius: float, color: Color = Color(0.95, 0.62, 0.28, 0.45), core: float = 0.35) -> void:
	if plume_shader == null or host == null:
		return
	var node := MeshInstance3D.new()
	node.name = part_name
	node.mesh = host.call("_plume_mesh", length, radius)
	node.position = at
	var burn := ShaderMaterial.new()
	burn.shader = plume_shader
	burn.set_shader_parameter("albedo", color)
	burn.set_shader_parameter("core", core)
	node.material_override = burn
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)


func lamp(parent: Node3D, part_name: String, at: Vector3, color: Color, radius: float) -> void:
	host.call("_nav_lamp", parent, part_name, at, color, radius)


func strip(parent: Node3D, part_name: String, size: Vector3, at: Vector3, color: Color, energy: float = 1.8) -> MeshInstance3D:
	var node := add(parent, part_name, slab(size, 0.9), glow(color, energy), at)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


func dish(parent: Node3D, part_name: String, radius: float, at: Vector3, rot: Vector3 = Vector3.ZERO) -> Node3D:
	host.call("_lens", parent, part_name, radius, at, Color("d7e6ee"))
	var node := parent.get_node(part_name) as Node3D
	node.rotation = rot
	return node


func barrel(parent: Node3D, part_name: String, at: Vector3, length: float, r: float, color: Color = Color("2b2f35"), rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var gun := add(parent, part_name, tube(r, r * 0.8, length, 14), metal(color, 0.28, 0.85), at, rot)
	add(gun, "Sleeve", tube(r * 1.55, r * 1.45, length * 0.34, 14), hull(Color("5c646c"), {"tile": maxf(r * 2.0, 0.8)}), Vector3(-length * 0.26, 0.0, 0.0))
	add(gun, "Brake", tube(r * 1.3, r * 1.3, maxf(length * 0.1, 0.2), 14), metal(Color("15171a"), 0.4, 0.6), Vector3(length * 0.46, 0.0, 0.0))
	return gun


func turret(parent: Node3D, part_name: String, at: Vector3, r: float, guns: int = 1, gun_len: float = 0.0) -> MeshInstance3D:
	var base := add(parent, part_name + "Ring", tube(r * 1.15, r * 1.15, r * 0.35, 16), hull(Color("4a525a"), {"tile": maxf(r, 0.8)}), at, Vector3(0.0, 0.0, PI * 0.5))
	var head := add(parent, part_name, slab(Vector3(r * 1.9, r * 0.9, r * 1.7), 0.8), hull(Color("8a929a"), {"tile": maxf(r * 0.8, 0.6)}), at + Vector3(0.0, r * 0.55, 0.0))
	var length := gun_len if gun_len > 0.0 else r * 2.6
	for i in guns:
		var z := 0.0
		if guns > 1:
			z = (float(i) - float(guns - 1) * 0.5) * r * 0.75
		barrel(parent, "Barrel%d" % i if guns > 1 else "Barrel", at + Vector3(r * 0.95 + length * 0.5, r * 0.55, z), length, r * 0.2)
	base.name = part_name + "Ring"
	return head


func panel_array(parent: Node3D, part_name: String, size: Vector2, at: Vector3, rot: Vector3 = Vector3.ZERO, cell: float = 1.0) -> MeshInstance3D:
	var half := Vector2(size.x * 0.5, size.y * 0.5)
	var mesh := plate([Vector2(half.x, half.y), Vector2(-half.x, half.y), Vector2(-half.x, -half.y), Vector2(half.x, -half.y)], 0.12, 0.98, 1.0)
	var node := add(parent, part_name, mesh, solar(cell), at, rot)
	add(node, "Frame", slab(Vector3(size.x + 0.2, 0.08, 0.16), 1.0), metal(Color("9aa3aa"), 0.3), Vector3(0.0, 0.0, half.y))
	add(node, "FrameB", slab(Vector3(size.x + 0.2, 0.08, 0.16), 1.0), metal(Color("9aa3aa"), 0.3), Vector3(0.0, 0.0, -half.y))
	return node
