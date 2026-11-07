extends RefCounted
## Keel and NPC hulls. The top-down silhouette stays the contract for every
## mount and gear socket; this builder gives it a real vertical profile: a
## lofted fuselage down the spine, the full planform as a bevelled wing
## plate, a faired command blister under a glass canopy, and a lit engine
## cluster at the tail.

const ForgeKit := preload("res://world/ship_forge.gd")

const STYLE := {
	"vesper": {"cap": 5.5, "wing": 0.0, "e": 2.4, "tile": 5.0},
	"anvil": {"cap": 15.0, "wing": 0.34, "e": 3.6, "tile": 6.0},
	"kestrel": {"cap": 6.5, "wing": 0.18, "e": 2.6, "tile": 5.0},
	"lumen": {"cap": 4.8, "wing": 0.14, "e": 2.6, "tile": 5.0},
	"casque": {"cap": 12.0, "wing": 0.3, "e": 3.2, "tile": 5.5},
	"alidade": {"cap": 4.6, "wing": 0.12, "e": 2.6, "tile": 5.0},
	"skiff": {"cap": 5.0, "wing": 0.22, "e": 2.6, "tile": 4.0},
	"brig": {"cap": 8.0, "wing": 0.26, "e": 3.0, "tile": 4.5},
	"yawl": {"cap": 3.2, "wing": 0.14, "e": 2.4, "tile": 4.0},
	"lugger": {"cap": 8.0, "wing": 0.3, "e": 3.2, "tile": 4.5},
	"pinnace": {"cap": 4.5, "wing": 0.0, "e": 2.4, "tile": 4.0},
	"ketch": {"cap": 7.0, "wing": 0.26, "e": 3.0, "tile": 4.5},
	"cutter": {"cap": 8.0, "wing": 0.28, "e": 3.0, "tile": 4.5},
}

var f: ForgeKit
var _poly := PackedVector2Array()
var _class := ""
var _h := 10.0
var _nose := 20.0
var _tail := -20.0
var _span := 40.0
var _cap := 5.0
var _e := 2.6


func _init(kit: ForgeKit) -> void:
	f = kit


func width_at(poly: PackedVector2Array, x: float) -> float:
	var best := 0.0
	var count := poly.size()
	for i in count:
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % count]
		if x < minf(a.x, b.x) - 0.001 or x > maxf(a.x, b.x) + 0.001:
			continue
		if absf(b.x - a.x) < 0.0001:
			best = maxf(best, maxf(absf(a.y), absf(b.y)))
			continue
		var t := clampf((x - a.x) / (b.x - a.x), 0.0, 1.0)
		best = maxf(best, absf(lerpf(a.y, b.y, t)))
	return best


func style_of(class_id: String) -> Dictionary:
	return STYLE.get(class_id, STYLE["skiff"])


func hull_material(color: Color, class_id: String, trim: Color, h: float, nose: float, tail: float, deck: bool = false) -> ShaderMaterial:
	var opts := {
		"tile": float(style_of(class_id).tile),
		"band_x": lerpf(tail, nose, 0.64),
		"band_w": 1.6,
		"aft_x": -28.0,
		"windows": 0.0 if deck else 1.0,
		"win_y": h * 0.44,
		"win_gap": maxf(h * 0.2, 2.4),
		"win_pitch": 2.8,
		"win_rows": 1.0,
	}
	if trim.a > 0.0:
		opts["accent"] = trim
		opts["stripe_z"] = maxf(h * 0.3, 3.0)
		opts["stripe_w"] = 0.9
	return f.hull_fresh(color, opts)


func _frame(poly: PackedVector2Array, class_id: String, h: float) -> void:
	_poly = poly
	_class = class_id
	_h = h
	_nose = -1000.0
	_tail = 1000.0
	for p in poly:
		_nose = maxf(_nose, p.x)
		_tail = minf(_tail, p.x)
	_span = _nose - _tail
	_cap = float(style_of(class_id).cap)
	_e = float(style_of(class_id).e)


func _prof(u: float) -> Vector2:
	var fore := smoothstep(0.55, 1.0, u)
	var aft := 1.0 - smoothstep(0.0, 0.2, u)
	return Vector2(0.06 + 0.2 * fore, 1.0 - 0.52 * pow(fore, 1.3) - 0.16 * aft)


func _u(x: float) -> float:
	return clampf((x - _tail) / _span, 0.0, 1.0)


func _hw(x: float) -> float:
	return maxf(minf(width_at(_poly, clampf(x, _tail + 0.01, _nose - 0.01)), _cap), 0.9)


func _top(x: float) -> float:
	return _prof(_u(x)).y * _h


func _bot(x: float) -> float:
	return _prof(_u(x)).x * _h


func _mid_y(x: float) -> float:
	return (_top(x) + _bot(x)) * 0.5


func _surf(x: float, z: float) -> float:
	var hw := _hw(x)
	var ratio := clampf(absf(z) / hw, 0.0, 0.995)
	var v := pow(1.0 - pow(ratio, _e), 1.0 / _e)
	return _mid_y(x) + (_top(x) - _bot(x)) * 0.5 * v


func build(holder: Node3D, class_id: String, poly: PackedVector2Array, h: float, paint: Color, deck_paint: Color, trim: Color) -> void:
	_frame(poly, class_id, h)
	var style := style_of(class_id)
	var stations: Array = []
	var ridge: Array = []
	var ridge_hw := clampf(minf(_cap, h * 0.28), 1.4, 6.0)
	for u in [0.0, 0.025, 0.08, 0.17, 0.28, 0.4, 0.52, 0.63, 0.73, 0.82, 0.9, 0.96, 1.0]:
		var uu := float(u)
		var x := _tail + _span * uu
		var hw := _hw(x)
		if uu >= 0.999:
			hw = 0.35
		var prof := _prof(uu)
		stations.append([x, hw, prof.x * h, prof.y * h, _e])
	for u in [0.1, 0.3, 0.5, 0.7, 0.82]:
		var uu := float(u)
		var prof := _prof(uu)
		var taper := 1.0 - 0.55 * smoothstep(0.6, 0.85, uu)
		ridge.append([_tail + _span * uu, minf(ridge_hw, _hw(_tail + _span * uu) * 0.8) * taper, prof.y * h - h * 0.1, prof.y * h + h * 0.05, 3.0])
	f.add(holder, "Plate", f.loft(stations, 22), hull_material(paint, class_id, trim, h, _nose, _tail))
	var wing_thick := float(style.wing)
	if wing_thick > 0.0:
		var wing_poly: Array = []
		for p in poly:
			wing_poly.append(Vector2(p.x, p.y))
		var wing := f.add(holder, "Wings", f.plate(wing_poly, h * wing_thick, 0.78, 0.94), hull_material(paint.darkened(0.06), class_id, trim, h, _nose, _tail), Vector3(0.0, h * 0.34, 0.0))
		wing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	f.add(holder, "Deck", f.loft(ridge, 14), hull_material(deck_paint, class_id, trim, h, _nose, _tail, true))


func engines(holder: Node3D, class_id: String, poly: PackedVector2Array, h: float, tail: float) -> void:
	var tail_hw := width_at(poly, tail + 0.4)
	var style := style_of(class_id)
	var er := clampf(maxf(minf(tail_hw, float(style.cap)), h * 0.1) * 0.8, 1.7, 6.5)
	var main := f.engine(holder, "Bell", Vector3(tail + 0.4, h * 0.44, 0.0), er, er * 2.0, Color("ffb86a"))
	main.name = "Bell"
	var side_z := minf(maxf(er * 2.2, h * 0.2), maxf(width_at(poly, tail + 2.0) * 0.82, er * 1.4))
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color("241c18")
	iron.metallic = 0.8
	iron.roughness = 0.35
	iron.emission_enabled = true
	iron.emission = Color("c47a3a")
	iron.emission_energy_multiplier = 0.14
	for side: float in [1.0, -1.0]:
		var nozzle := MeshInstance3D.new()
		nozzle.name = "NozzleP" if side > 0.0 else "NozzleS"
		nozzle.mesh = f.bell(er * 1.4, er * 0.34, er * 0.62)
		nozzle.position = Vector3(tail + 0.6, h * 0.34, side_z * side)
		nozzle.material_override = iron.duplicate()
		holder.add_child(nozzle)
		var barrel := f.add(holder, "NozzleHousing" + ("P" if side > 0.0 else "S"), f.tube(er * 0.5, er * 0.46, er * 1.8, 12), f.hull_fresh(Color("4a525a"), {"tile": 2.0}), Vector3(tail + er * 0.9, h * 0.34, side_z * side))
		barrel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var throat := MeshInstance3D.new()
	throat.name = "Throat"
	throat.mesh = f.tube(er * 0.48, er * 0.48, 0.3, 14)
	throat.position = Vector3(tail + er * 0.3, h * 0.44, 0.0)
	var coke := StandardMaterial3D.new()
	coke.albedo_color = Color("1a120e")
	coke.emission_enabled = true
	coke.emission = Color("ffb15a")
	coke.emission_energy_multiplier = 0.35
	throat.material_override = coke
	holder.add_child(throat)
	holder.set_meta("engine_r", er)


func superstructure(holder: Node3D, class_id: String, poly: PackedVector2Array, h: float, tail: float) -> void:
	var nose := float(holder.get_meta("nose", 20.0))
	var span := maxf(nose - tail, 12.0)
	var style := style_of(class_id)
	var deck := Vector3(18.0, h, 0.0)
	var size := Vector3(16.0, 9.2, 7.2)
	if class_id == "anvil":
		deck = Vector3(10.0, h, 0.0)
		size = Vector3(14.0, 9.0, 14.0)
	elif class_id == "kestrel":
		deck = Vector3(14.0, h, 0.0)
		size = Vector3(14.0, 7.0, 9.0)
	elif class_id == "lumen":
		deck = Vector3(22.0, h, 0.0)
		size = Vector3(12.0, 5.6, 5.2)
	elif class_id == "casque":
		deck = Vector3(-2.0, h, 0.0)
		size = Vector3(12.0, 7.4, 14.0)
	elif class_id == "alidade":
		deck = Vector3(2.0, h * 0.82, 0.0)
		size = Vector3(15.0, 5.0, 8.4)
	elif class_id == "vesper":
		deck = Vector3(18.0, h, 0.0)
		size = Vector3(16.0, 7.0, 6.4)
	else:
		deck = Vector3(6.0, h, 0.0)
		size = Vector3(9.0, 5.2, 5.4)
	var dx := size.x
	var dy := size.y
	var dz := minf(size.z, float(style.cap) * 1.9)
	var housing := [
		[-dx * 0.5, dz * 0.46, 0.0, dy * 0.6, 3.0],
		[-dx * 0.18, dz * 0.5, 0.0, dy * 0.92, 3.0],
		[dx * 0.2, dz * 0.4, 0.0, dy * 0.74, 3.0],
		[dx * 0.5, dz * 0.12, 0.0, dy * 0.3, 2.4],
	]
	var bridge_mat := f.hull_fresh(Color("5a6870"), {"tile": 2.6})
	var bridge := f.add(holder, "Bridge", f.loft(housing, 16), bridge_mat, deck + Vector3(0.0, dy * 0.0, 0.0))
	var glass := f.canopy(holder, "Glass", dx * 0.62, dz * 0.52, dy * 0.34, bridge.position + Vector3(dx * 0.06, dy * 0.86, 0.0), Color("1a5a72"))
	glass.name = "Glass"
	f.add(holder, "Frame", f.slab(Vector3(dx * 0.34, 0.3, dz * 0.5), 0.9), f.metal(Color("1a2024"), 0.5), bridge.position + Vector3(-dx * 0.2, dy * 0.92, 0.0))
	var mast_h := maxf(h * 0.42, 6.0)
	f.add(holder, "Mast", f.tube(0.22, 0.34, mast_h, 8), f.metal(Color("242a30"), 0.4), bridge.position + Vector3(-dx * 0.34, dy * 0.8 + mast_h * 0.5, 0.0), Vector3(0.0, 0.0, PI * 0.5))
	f.add(holder, "MastArray", f.slab(Vector3(0.4, 0.5, 2.8), 0.9), f.metal(Color("2a2f36"), 0.4), bridge.position + Vector3(-dx * 0.34, dy * 0.8 + mast_h * 0.86, 0.0))
	for i in 3:
		f.strip(holder, "BridgePane%d" % i, Vector3(0.9, 0.5, 0.14), bridge.position + Vector3(-dx * 0.22 + float(i) * dx * 0.2, dy * 0.42, dz * 0.47), Color("9ad8ff"), 1.4)
		f.strip(holder, "BridgePaneS%d" % i, Vector3(0.9, 0.5, 0.14), bridge.position + Vector3(-dx * 0.22 + float(i) * dx * 0.2, dy * 0.42, -dz * 0.47), Color("9ad8ff"), 1.4)
	var fin_h := maxf(h * 0.5, 6.0)
	var fin_mesh := f.plate([Vector2(fin_h * 0.7, 0.0), Vector2(-fin_h * 0.5, 0.0), Vector2(-fin_h * 0.75, fin_h * 0.9), Vector2(-fin_h * 0.1, fin_h * 0.9)], 0.7, 0.6, 1.0)
	var fin_span := minf(width_at(poly, tail + span * 0.1) * 0.7, float(style.cap) * 0.9)
	for side: float in [1.0, -1.0]:
		f.add(holder, "FinPort" if side > 0.0 else "FinStbd", fin_mesh, f.hull_fresh(Color("22282e"), {"tile": 2.4}), Vector3(tail + fin_h * 0.7, h * 0.9, maxf(fin_span, 1.6) * side), Vector3(-PI * 0.5, 0.0, 0.0))
	f.lamp(holder, "LampNose", Vector3(nose * 0.86, h * 0.5, 0.0), Color("d8fff6"), 1.05)
	f.lamp(holder, "LampPort", Vector3(tail * 0.55, h * 0.3, minf(width_at(poly, tail * 0.55), 5.0)), Color("d4553a"), 0.75)
	f.lamp(holder, "LampStbd", Vector3(tail * 0.55, h * 0.3, -minf(width_at(poly, tail * 0.55), 5.0)), Color("7dcea0"), 0.75)


# ------------------------------------------------------------------ dressing

func _blk(holder: Node3D, part_name: String, size: Vector3, at: Vector3, color: Color, rot: Vector3 = Vector3.ZERO, inset: float = 0.9, tile: float = 2.0) -> MeshInstance3D:
	return f.add(holder, part_name, f.slab(size, inset), f.hull_fresh(color, {"tile": tile, "aft_x": -28.0}), at, rot)


func _cylx(holder: Node3D, part_name: String, r: float, length: float, at: Vector3, color: Color, axis: String = "x", taper: float = 1.0) -> MeshInstance3D:
	var rot := Vector3.ZERO
	if axis == "y":
		rot = Vector3(0.0, 0.0, PI * 0.5)
	elif axis == "z":
		rot = Vector3(0.0, PI * 0.5, 0.0)
	return f.add(holder, part_name, f.tube(r, r * taper, length, 14), f.hull_fresh(color, {"tile": maxf(r * 1.6, 0.8), "aft_x": -28.0}), at, rot)


func _glow_lamp(holder: Node3D, part_name: String, at: Vector3, color: Color, r: float) -> void:
	f.lamp(holder, part_name, at, color, r)


func _side(i: int) -> float:
	return 1.0 if i % 2 == 0 else -1.0


func _tag(side: float) -> String:
	return "P" if side > 0.0 else "S"


func dress(holder: Node3D, class_id: String, poly: PackedVector2Array, h: float, paint: Color, trim: Color) -> void:
	_frame(poly, class_id, h)
	var dark := Color("1c2126")
	var steel := paint.lightened(0.12)
	steel.s *= 0.6
	var panel := paint.darkened(0.12)
	var mid_x := _tail + _span * 0.46
	var combat := class_id == "kestrel" or class_id == "casque" or class_id == "cutter"
	var courier := class_id == "vesper" or class_id == "lumen" or class_id == "pinnace" or class_id == "yawl"
	_blk(holder, "Keel", Vector3(_span * 0.55, h * 0.2, maxf(_hw(mid_x) * 0.6, 1.4)), Vector3(_tail + _span * 0.42, h * 0.05, 0.0), dark.lightened(0.1))
	for i in 5:
		var x := _tail + _span * (0.16 + float(i) * 0.14)
		var z := _side(i) * _hw(x) * 0.34
		_blk(holder, "Panel%d" % i, Vector3(_span * 0.11, 0.6, maxf(_hw(x) * 0.7, 1.6)), Vector3(x, _surf(x, z) + 0.15, z), steel, Vector3.ZERO, 0.86, 2.4)
	for i in 8:
		var x := _tail + _span * (0.12 + float(i) * 0.09)
		var side := _side(i)
		var tall := (_top(x) - _bot(x)) * 0.5
		_blk(holder, "Armor%d" % i, Vector3(_span * 0.085, tall, 0.8), Vector3(x, _mid_y(x), side * _hw(x) * 0.98), panel.lightened(0.04 * float(i % 3)), Vector3(0.0, -0.06 * side, 0.0), 0.82, 2.0)
	for i in 6:
		var x := _tail + _span * (0.2 + float(i) * 0.1)
		var side := _side(i)
		var z := side * _hw(x) * 0.52
		var gh := 0.8 + float(i % 3) * 0.35
		_blk(holder, "Greeble%d" % i, Vector3(_span * 0.04, gh, 1.2), Vector3(x, _surf(x, z) + gh * 0.4, z), dark.lightened(0.14), Vector3.ZERO, 0.9, 1.2)
		_cylx(holder, "GreeblePipe%d" % i, 0.11, 2.4, Vector3(x + 1.6, _surf(x, z) + 0.2, z + side * 0.5), dark)
		_blk(holder, "VentBox%d" % i, Vector3(_span * 0.026, 0.22, 1.2), Vector3(x - 1.4, _surf(x, z * 0.4) + 0.12, z * 0.4), Color("101214"), Vector3.ZERO, 1.0, 1.0)
	for i in 4:
		var x := _tail + _span * (0.28 + float(i) * 0.14)
		var z := (1.0 if i < 2 else -1.0) * _hw(x) * 0.22
		_blk(holder, "Access%d" % i, Vector3(_span * 0.07, 0.18, 2.2), Vector3(x, _surf(x, z) + 0.06, z), Color("14181c"), Vector3.ZERO, 0.95, 1.2)
		_blk(holder, "AccessLip%d" % i, Vector3(_span * 0.085, 0.12, 2.7), Vector3(x, _surf(x, z) + 0.02, z), steel, Vector3.ZERO, 1.0, 1.2)
	var sx := _nose - _span * 0.14
	_blk(holder, "SensorArray", Vector3(3.6, 1.2, 2.3), Vector3(sx, _top(sx) + 0.5, 0.0), Color("161e24"), Vector3.ZERO, 0.8, 1.2)
	_cylx(holder, "SensorMast", 0.13, 3.4, Vector3(sx, _top(sx) + 2.4, 0.0), Color("101418"), "y")
	_blk(holder, "SensorDish", Vector3(1.8, 0.24, 1.8), Vector3(sx, _top(sx) + 3.6, 0.0), steel, Vector3.ZERO, 0.8, 1.0)
	_glow_lamp(holder, "ArrayEye", Vector3(sx + 1.2, _top(sx) + 0.9, 0.0), Color("8ec8ff"), 0.26)
	for i in 6:
		var x := _tail + _span * (0.5 + float(i) * 0.07)
		var z := _side(i) * _hw(x) * 0.34
		_blk(holder, "HeatTile%d" % i, Vector3(_span * 0.05, 0.22, maxf(_hw(x) * 0.5, 1.4)), Vector3(x, _bot(x) + 0.05, z), Color("2a2220"), Vector3.ZERO, 0.95, 1.4)
	var dx := _nose - _span * 0.045
	var ring_r := clampf(h * 0.1, 1.1, 2.0)
	var ring := TorusMesh.new()
	ring.inner_radius = ring_r * 0.7
	ring.outer_radius = ring_r
	ring.rings = 20
	ring.ring_segments = 10
	f.add(holder, "DockRing", ring, f.metal(Color("8a8274"), 0.35), Vector3(dx, _mid_y(dx), 0.0), Vector3(0.0, 0.0, PI * 0.5))
	_blk(holder, "DockLip", Vector3(1.2, ring_r * 1.2, ring_r * 1.2), Vector3(dx - 0.2, _mid_y(dx), 0.0), Color("1a2024"), Vector3.ZERO, 0.8, 1.0)
	for i in 4:
		var ang := TAU * 0.25 * float(i) + 0.2
		_blk(holder, "DockClamp%d" % i, Vector3(0.7, 0.55, 0.45), Vector3(dx + 0.3, _mid_y(dx) + sin(ang) * ring_r * 0.82, cos(ang) * ring_r * 0.82), Color("c6b48a"), Vector3.ZERO, 0.9, 0.8)
	for side: float in [1.0, -1.0]:
		var tag := _tag(side)
		var ax := _tail + _span * 0.2
		var fx := _nose - _span * 0.16
		_blk(holder, "Rcs" + tag, Vector3(1.6, 1.0, 1.3), Vector3(ax, _mid_y(ax), side * _hw(ax) * 1.0), dark, Vector3.ZERO, 0.8, 0.8)
		f.add(holder, "RcsBell" + tag, f.tube(0.34, 0.2, 0.8, 8), f.metal(Color("15171a"), 0.45), Vector3(ax, _mid_y(ax), side * (_hw(ax) + 0.8)), Vector3(0.0, PI * 0.5, 0.0))
		_blk(holder, "RcsFwd" + tag, Vector3(1.2, 0.8, 1.0), Vector3(fx, _mid_y(fx), side * _hw(fx) * 1.0), dark, Vector3.ZERO, 0.8, 0.8)
		var scoop_x := mid_x
		var scoop := _blk(holder, "Scoop" + tag, Vector3(_span * 0.12, maxf(h * 0.16, 2.2), 1.6), Vector3(scoop_x, _mid_y(scoop_x), side * (_hw(scoop_x) + 0.2)), Color("1a1e22"), Vector3(0.0, 0.0, 0.0), 0.8, 1.2)
		scoop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		f.strip(holder, "ScoopLip" + tag, Vector3(_span * 0.1, 0.1, 0.12), Vector3(scoop_x, _mid_y(scoop_x) + maxf(h * 0.08, 1.1), side * (_hw(scoop_x) + 0.9)), Color("8ae8ff"), 1.2)
		var vane_x := _tail + _span * 0.2
		var vane_z := side * _hw(vane_x) * 0.7
		_blk(holder, "Vane" + tag, Vector3(_span * 0.09, h * 0.16, 0.3), Vector3(vane_x, _surf(vane_x, vane_z) + h * 0.07, vane_z), steel.darkened(0.25), Vector3(side * 0.35, 0.0, 0.0), 0.85, 1.6)
		_blk(holder, "Run" + tag + "Pod", Vector3(1.0, 0.7, 0.9), Vector3(mid_x + _span * 0.12, _mid_y(mid_x) - h * 0.1, side * (_hw(mid_x) + 0.3)), dark, Vector3.ZERO, 0.8, 0.8)
		_glow_lamp(holder, "Run" + tag, Vector3(mid_x + _span * 0.12, _mid_y(mid_x) - h * 0.1, side * (_hw(mid_x) + 1.0)), Color("d4553a") if side > 0.0 else Color("7dcea0"), 0.6)
	for i in 3:
		var x := _tail + _span * (0.34 + float(i) * 0.1)
		_cylx(holder, "Antenna%d" % i, 0.12, 3.4 + float(i) * 1.4, Vector3(x, _top(x) + 1.7 + float(i) * 0.7, _side(i) * _hw(x) * 0.3), Color("14181c"), "y")
	for i in 3:
		var x := _tail + _span * (0.2 + float(i) * 0.1)
		_blk(holder, "Rad%d" % i, Vector3(_span * 0.06, h * 0.12, 0.2), Vector3(x, _surf(x, _side(i) * _hw(x) * 0.5) + h * 0.05, _side(i) * _hw(x) * 0.5), Color("3a4044"), Vector3.ZERO, 1.0, 1.0)
	for i in 4:
		var x := _tail + _span * (0.16 + float(i) * 0.07)
		_blk(holder, "Vent%d" % i, Vector3(_span * 0.04, 0.16, maxf(_hw(x) * 0.5, 1.4)), Vector3(x, _surf(x, 0.0) + 0.06, 0.0), Color("101214"), Vector3.ZERO, 1.0, 1.0)
	if courier:
		for i in 2:
			var side := _side(i)
			var tx := _tail + _span * (0.3 + float(i) * 0.14)
			var tr := h * 0.17
			var tl := _span * 0.24
			var tz := _hw(tx) + tr * 1.05
			var at := Vector3(tx, _mid_y(tx), side * tz)
			f.add(holder, "Tank%d" % i, f.tube(tr, tr, tl, 16), f.hull_fresh(Color("8a949a"), {"tile": 3.0}), at)
			for bi in 3:
				_cylx(holder, "TankBand%d_%d" % [i, bi], tr + 0.15, 0.5, at + Vector3((float(bi) - 1.0) * tl * 0.3, 0.0, 0.0), dark)
			_cylx(holder, "TankCapF%d" % i, tr * 0.9, 0.6, at + Vector3(tl * 0.5, 0.0, 0.0), Color("6a3228"))
			_cylx(holder, "TankCapA%d" % i, tr * 0.9, 0.6, at + Vector3(-tl * 0.5, 0.0, 0.0), dark)
			_blk(holder, "TankPylon%d" % i, Vector3(tl * 0.5, 0.7, tr * 1.4), Vector3(tx, _mid_y(tx), side * (_hw(tx) + tr * 0.4)), steel, Vector3.ZERO, 0.85, 1.5)
			_cylx(holder, "TankValve%d" % i, 0.28, 0.8, at + Vector3(0.0, tr + 0.3, 0.0), Color("8a3a32"), "y")
	_dress_class(holder, class_id, h, paint, trim, combat)


func _dress_class(holder: Node3D, class_id: String, h: float, paint: Color, trim: Color, combat: bool) -> void:
	var dark := Color("1c2126")
	var steel := paint.lightened(0.14)
	var mid_x := _tail + _span * 0.46
	var _cx := _nose - _span * 0.18
	var hoop := TorusMesh.new()
	hoop.inner_radius = maxf(h * 0.16, 1.6)
	hoop.outer_radius = maxf(h * 0.22, 2.2)
	hoop.rings = 20
	hoop.ring_segments = 10
	f.add(holder, "SensorRing", hoop, f.metal(Color("2a3238"), 0.4), Vector3(_cx, _mid_y(_cx), 0.0), Vector3(0.0, 0.0, PI * 0.5))
	for i in 6:
		var x := _tail + _span * (0.16 + float(i) * 0.12)
		var side := _side(i)
		_blk(holder, "BayPlate%d" % i, Vector3(_span * (0.13 if class_id == "anvil" else 0.09), (_top(x) - _bot(x)) * 0.5, 0.9), Vector3(x, _mid_y(x) - h * 0.04, side * (_hw(x) * 1.0 + 0.1)), Color("3e464c").lerp(paint, 0.3) if i % 2 == 0 else Color("4a5258").lerp(paint, 0.3), Vector3.ZERO, 0.85, 2.0)
	for i in (6 if combat else 3):
		var x := _tail + _span * (0.18 + float(i) * 0.12)
		var side := _side(i)
		_blk(holder, "Beam%d" % i, Vector3(_span * 0.03, h * 0.46, 0.34), Vector3(x, _mid_y(x), side * (_hw(x) + 0.3)), Color("1c2226"), Vector3.ZERO, 0.9, 1.2)
		_blk(holder, "Gap%d" % i, Vector3(_span * 0.016, h * 0.3, 0.2), Vector3(x + _span * 0.045, _mid_y(x), side * (_hw(x) + 0.05)), Color("0c1012"), Vector3.ZERO, 0.9, 1.0)
	_blk(holder, "BeamCross", Vector3(0.5, 0.5, maxf(_hw(mid_x) * 2.2, 3.0)), Vector3(mid_x, _top(mid_x) + 0.6, 0.0), Color("1a2024"), Vector3.ZERO, 0.9, 1.0)
	var dome_x := _nose - _span * 0.22
	var bowl := SphereMesh.new()
	bowl.radius = 1.45
	bowl.height = 1.9
	bowl.radial_segments = 14
	bowl.rings = 8
	f.add(holder, "SensorDome", bowl, f.glass(Color(0.1, 0.3, 0.4, 0.92), 0.5), Vector3(dome_x, _top(dome_x) + 0.2, 0.0), Vector3.ZERO, Vector3(1.0, 0.62, 1.0))
	_blk(holder, "DomeRing", Vector3(3.2, 0.3, 3.2), Vector3(dome_x, _top(dome_x) - 0.1, 0.0), Color("12181c"), Vector3.ZERO, 0.95, 1.0)
	_glow_lamp(holder, "DomeEye", Vector3(dome_x + 0.8, _top(dome_x) + 0.55, 0.0), Color("7ec8ff"), 0.22)
	for i in (4 if combat else 2):
		var side := 1.0 if i % 2 == 0 else -1.0
		var x := _tail + _span * (0.34 + float(i / 2) * 0.22)
		var hz := _hw(x) + 0.7
		_blk(holder, "Hardpoint%d" % i, Vector3(2.6, 1.3, 1.7), Vector3(x, _mid_y(x) + h * 0.1, side * hz), Color("242c30"), Vector3.ZERO, 0.8, 1.2)
		f.barrel(holder, "HardBarrel%d" % i, Vector3(x + 2.0, _mid_y(x) + h * 0.1, side * hz), 3.4, 0.2)
	if combat:
		for i in 3:
			var x := _tail + _span * (0.28 + float(i) * 0.15)
			_blk(holder, "CombatPlate%d" % i, Vector3(_span * 0.15, 0.8, maxf(_hw(x) * 1.1, 2.6)), Vector3(x, _top(x) + 0.35, 0.0), Color("2e363c").lerp(paint, 0.2), Vector3(0.0, 0.0, 0.06 if i == 1 else -0.05), 0.82, 2.0)
		for side: float in [1.0, -1.0]:
			var cx := _tail + _span * 0.58
			_blk(holder, "CheekArmor" + _tag(side), Vector3(_span * 0.2, h * 0.34, 1.2), Vector3(cx, _mid_y(cx), side * (_hw(cx) + 0.3)), Color("343c42").lerp(paint, 0.2), Vector3(0.0, -0.32 * side, 0.0), 0.8, 2.0)
		for i in 4:
			var x := _tail + _span * (0.2 + float(i) * 0.16)
			_blk(holder, "ArmorBrick%d" % i, Vector3(_span * 0.09, h * 0.22, 1.1), Vector3(x, _bot(x) + h * 0.2, _side(i) * (_hw(x) + 0.2)), Color("2a3238").lerp(paint, 0.2), Vector3.ZERO, 0.8, 1.6)
		var er := float(holder.get_meta("engine_r", 2.0))
		f.add(holder, "ThrusterShroud", f.tube(er * 1.25, er * 1.45, 2.8, 20), f.hull_fresh(Color("2a2420"), {"tile": 1.6}), Vector3(_tail + 1.0, h * 0.44, 0.0))
		for i in 4:
			var ang := TAU * 0.25 * float(i) + 0.8
			var spread := er * 2.3
			var bell_at := Vector3(_tail - 0.1, h * 0.44 + cos(ang) * spread * 0.6, sin(ang) * spread)
			var cluster := f.add(holder, "ClusterBell%d" % i, f.bell(er * 1.5, er * 0.3, er * 0.5), f.metal(Color("181410"), 0.4), bell_at)
			cluster.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			f.add(holder, "ClusterThroat%d" % i, f.disc(er * 0.28), f.glow(Color("ff9a48"), 2.0), bell_at + Vector3(-er * 1.1, 0.0, 0.0))
		for side: float in [1.0, -1.0]:
			_blk(holder, "ThrusterVane" + _tag(side), Vector3(3.4, 0.22, 1.1), Vector3(_tail + 1.8, h * 0.2, side * _hw(_tail + 2.0) * 0.8), Color("121618"), Vector3.ZERO, 0.9, 1.0)
	match class_id:
		"kestrel":
			for side: float in [1.0, -1.0]:
				var cx := _tail + _span * 0.55
				_blk(holder, "Cheek" + _tag(side), Vector3(_span * 0.2, 1.2, 2.4), Vector3(cx, _mid_y(cx) - h * 0.1, side * (_hw(cx) + 1.4)), paint.darkened(0.1), Vector3(0.0, -0.45 * side, 0.0), 0.82, 1.6)
		"anvil":
			_dress_hauler(holder, h, paint)
		"lumen":
			_dress_lumen(holder, h)
		"casque":
			_dress_casque(holder, h)
		"alidade":
			_dress_alidade(holder, h)


func _dress_hauler(holder: Node3D, h: float, paint: Color) -> void:
	for side: float in [1.0, -1.0]:
		var rx := _tail + _span * 0.4
		_blk(holder, "Rib" + _tag(side), Vector3(_span * 0.16, h * 0.28, 1.6), Vector3(rx, _mid_y(rx), side * (_hw(rx) + 0.6)), paint.darkened(0.15), Vector3.ZERO, 0.8, 2.0)
		var hx := _tail + _span * 0.46
		_blk(holder, "SideHatch" + _tag(side), Vector3(_span * 0.2, h * 0.34, 0.3), Vector3(hx, _mid_y(hx), side * (_hw(hx) + 0.1)), Color("181c20"), Vector3.ZERO, 0.9, 1.2)
		_blk(holder, "HatchLip" + _tag(side), Vector3(_span * 0.22, 0.3, 0.6), Vector3(hx, _bot(hx) + h * 0.14, side * (_hw(hx) + 0.3)), Color("8a8276"), Vector3.ZERO, 1.0, 1.0)
		_cylx(holder, "CargoTank" + _tag(side), h * 0.12, _span * 0.3, Vector3(hx, _bot(hx) + h * 0.12, side * (_hw(hx) + 1.2)), Color("4a5258"))
	for i in 4:
		var x := _tail + _span * (0.22 + float(i) * 0.15)
		var hw := _hw(x)
		var bh := h * 0.34
		var bw := _span * 0.125
		var bd := minf(hw * 1.5, 16.0)
		var y := _top(x) + bh * 0.5
		_blk(holder, "CargoMod%d" % i, Vector3(bw, bh, bd), Vector3(x, y, 0.0), Color("8a7a62"), Vector3.ZERO, 0.94, 2.0)
		_blk(holder, "CargoLid%d" % i, Vector3(bw * 0.96, 0.18, bd * 0.96), Vector3(x, y + bh * 0.5, 0.0), Color("c4a574"), Vector3.ZERO, 0.98, 1.6)
		_blk(holder, "CargoDoor%d" % i, Vector3(0.2, bh * 0.7, bd * 0.6), Vector3(x + bw * 0.5, y, 0.0), Color("2a2420"), Vector3.ZERO, 0.95, 1.0)
		_blk(holder, "CargoBand%d" % i, Vector3(bw * 0.98, 0.3, bd * 0.08), Vector3(x, y, bd * 0.46), Color("6a3a28"), Vector3.ZERO, 1.0, 1.0)
		_blk(holder, "RibFrame%d" % i, Vector3(0.5, h * 0.5, minf(hw * 2.0, 30.0)), Vector3(x - bw * 0.58, _mid_y(x), 0.0), Color("262c30"), Vector3.ZERO, 0.9, 2.0)
	var mx := _tail + _span * 0.46
	_blk(holder, "LoadHatch", Vector3(_span * 0.2, 0.3, minf(_hw(mx) * 1.2, 14.0)), Vector3(mx, _top(mx) + 0.1, 0.0), Color("181c20"), Vector3.ZERO, 0.96, 1.2)
	_blk(holder, "HatchFrame", Vector3(_span * 0.23, 0.4, minf(_hw(mx) * 1.35, 16.0)), Vector3(mx, _top(mx) + 0.02, 0.0), Color("8a8276"), Vector3.ZERO, 1.0, 1.5)
	_blk(holder, "HatchRam", Vector3(_span * 0.08, 1.1, 1.4), Vector3(mx + _span * 0.08, _top(mx) + 0.6, 0.0), Color("2a2420"), Vector3.ZERO, 0.85, 1.0)
	var gx := _tail + _span * 0.62
	for side: float in [1.0, -1.0]:
		_blk(holder, "GantryPost" + _tag(side), Vector3(0.8, h * 0.9, 0.8), Vector3(gx, _top(gx) + h * 0.45, side * minf(_hw(gx) * 0.8, 12.0)), Color("6a6e72"), Vector3.ZERO, 0.9, 1.2)
	_blk(holder, "Gantry", Vector3(1.2, 0.9, minf(_hw(gx) * 1.7, 26.0)), Vector3(gx, _top(gx) + h * 0.9, 0.0), Color("6a6e72"), Vector3.ZERO, 0.9, 1.2)
	for i in 4:
		var side := 1.0 if i < 2 else -1.0
		var er := 0.9 + float(i % 2) * 0.1
		var at := Vector3(_tail + 0.2, _bot(_tail) + h * 0.2 + float(i % 2) * h * 0.18, side * minf(_hw(_tail + 1.0) * 0.9, 12.0))
		f.add(holder, "HaulBell%d" % i, f.bell(er * 3.0, er * 0.45, er * 1.0), f.metal(Color("161210"), 0.4), at)


func _dress_lumen(holder: Node3D, h: float) -> void:
	var nose := _nose
	var heart_at := Vector3(nose - 7.0, _top(nose - 7.0) + 2.2, 0.0)
	var orb := SphereMesh.new()
	orb.radius = 1.7
	orb.height = 3.4
	orb.radial_segments = 14
	orb.rings = 8
	var heart := f.add(holder, "LampHeart", orb, f.glow(Color("ffd27a"), 2.2), heart_at)
	heart.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cage := TorusMesh.new()
	cage.inner_radius = 2.0
	cage.outer_radius = 2.35
	cage.rings = 20
	cage.ring_segments = 6
	f.add(holder, "LampCage", cage, f.metal(Color("c8b48a"), 0.35), heart_at, Vector3(0.0, 0.0, PI * 0.5))
	_cylx(holder, "LampStem", 0.4, 2.2, heart_at - Vector3(0.0, 1.8, 0.0), Color("3a3458"), "y")
	for side: float in [1.0, -1.0]:
		var tag := _tag(side)
		var fx := nose * 0.38
		f.add(holder, "Fork" + tag, f.tube(0.7, 0.45, 18.0, 12), f.hull_fresh(Color("3a3458"), {"tile": 2.0}), Vector3(fx, h * 0.34, side * 15.0))
		_glow_lamp(holder, "ForkLamp" + tag, Vector3(nose * 0.52, h * 0.46, side * 17.5), Color("f0c14a"), 0.7)


func _dress_casque(holder: Node3D, h: float) -> void:
	var nose := _nose
	var plow := f.add(holder, "RamPlow", f.plate([Vector2(3.0, 6.5), Vector2(-4.5, 6.5), Vector2(-4.5, -6.5), Vector2(3.0, -6.5)], h * 0.52, 0.55, 1.0), f.hull_fresh(Color("241c16"), {"tile": 2.2}), Vector3(nose - 1.0, h * 0.42, 0.0))
	plow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_blk(holder, "RamShoe", Vector3(5.4, 1.6, 9.5), Vector3(nose + 0.4, h * 0.12, 0.0), Color("6a5438"), Vector3.ZERO, 0.8, 1.6)
	for side: float in [1.0, -1.0]:
		_blk(holder, "RamCheek" + _tag(side), Vector3(11.0, h * 0.3, 4.2), Vector3(1.0, h * 0.34, side * (_hw(1.0) + 1.8)), Color("3a2c24"), Vector3(0.0, -0.3 * side, 0.0), 0.8, 2.0)
	_glow_lamp(holder, "RamLamp", Vector3(nose * 0.55, _top(nose * 0.55) + 0.6, 0.0), Color("e6b15a"), 0.85)


func _dress_alidade(holder: Node3D, h: float) -> void:
	var dome_at := Vector3(4.0, _top(4.0) + 0.3, 0.0)
	var bowl := SphereMesh.new()
	bowl.radius = 4.6
	bowl.height = 6.0
	bowl.radial_segments = 18
	bowl.rings = 10
	f.add(holder, "SkyDome", bowl, f.glass(Color(0.1, 0.34, 0.44, 0.9), 0.6), dome_at, Vector3.ZERO, Vector3(1.0, 0.55, 1.0))
	f.add(holder, "DomeLip", f.tube(4.9, 4.9, 0.6, 20), f.hull_fresh(Color("1a2428"), {"tile": 2.0}), dome_at + Vector3(0.0, -0.4, 0.0), Vector3(0.0, 0.0, PI * 0.5))
	var eye := SphereMesh.new()
	eye.radius = 1.0
	eye.height = 2.0
	f.add(holder, "SkyEye", eye, f.glow(Color("8ae8ff"), 2.2), dome_at + Vector3(0.0, 0.8, 0.0))
	for side: float in [1.0, -1.0]:
		var tag := _tag(side)
		f.add(holder, "WingPod" + tag, f.tube(1.4, 1.1, 9.0, 14), f.hull_fresh(Color("1e3238"), {"tile": 2.0}), Vector3(-20.0, h * 0.4, side * 24.0))
		_glow_lamp(holder, "Tip" + tag, Vector3(-30.0, h * 0.38, side * 27.0), Color("9fd0c8"), 0.55)
