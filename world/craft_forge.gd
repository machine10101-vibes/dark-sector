extends RefCounted
## Sci-fi craft designs built from the ship forge kit: the Mothership, the
## combat wing, and the small work boats. Every design keeps the node names
## the sim, the HUD cards, and the tests look up.

const ForgeKit := preload("res://world/ship_forge.gd")

const PADS: Array = [
	Vector3(18.0, 0.0, 1.0),
	Vector3(-6.0, 0.0, 1.0),
	Vector3(-30.0, 0.0, 1.0),
	Vector3(18.0, 0.0, -1.0),
	Vector3(-6.0, 0.0, -1.0),
	Vector3(-30.0, 0.0, -1.0),
]
const PAD_BEAM := 33.0
const PAD_HEIGHT := 14.2

var f: ForgeKit


func _init(kit: ForgeKit) -> void:
	f = kit


func build(node: Node3D, kind: String, color: Color) -> void:
	match kind:
		"survey_probe":
			_probe(node, color)
		"harvest_drone":
			_miner(node, color)
		"salvage_tender":
			_tender(node, color)
		"away_shuttle":
			_shuttle(node, color)
		"dart_drone":
			_dart(node, color)
		"sting_drone":
			_sting(node, color)
		"wasp_drone":
			_wasp(node, color)
		"fang_drone":
			_fang(node, color)
		"lance_drone":
			_lance(node, color)
		"picket_drone":
			_picket(node, color)
		"manifest_drone":
			_manifest(node, color)
		"hawser_drone":
			_hawser(node, color)
		"sentry_drone":
			_sentry(node, color)
		"repair_drone":
			_welder(node, color)
		"livestock_lighter":
			_lighter(node, color)
		"mothership":
			_mothership(node, color)
		_:
			_fighter(node, color)


func _ring_mesh(inner: float, outer: float) -> TorusMesh:
	var ring := TorusMesh.new()
	ring.inner_radius = inner
	ring.outer_radius = outer
	ring.rings = 36
	ring.ring_segments = 4
	return ring


func pad_pose(index: int) -> Dictionary:
	var pad: Vector3 = PADS[index % PADS.size()]
	return {"fore": pad.x, "side": pad.z * PAD_BEAM}


# ------------------------------------------------------------------ shared

func _engines(node: Node3D, spots: Array, r: float, length: float, plume_len: float, tint: Color = Color(1.0, 0.62, 0.26)) -> void:
	for i in spots.size():
		var at: Vector3 = spots[i]
		var label := "BellMain"
		if spots.size() > 1:
			label = "BellP" if at.z > 0.01 else ("BellS" if at.z < -0.01 else "BellMain")
			if i > 1 and label != "BellMain":
				label += str(i)
		f.engine(node, label, at, r, length, tint)
		f.plume(node, "Exhaust" if i == 0 else "Exhaust%d" % i, at + Vector3(-length * 0.35, 0.0, 0.0), plume_len, r * 0.82)


func _run_lights(node: Node3D, port: Vector3, nose: Vector3, lamp_r: float = 0.22) -> void:
	f.lamp(node, "RunP", port, Color("d4553a"), lamp_r)
	f.lamp(node, "RunS", Vector3(port.x, port.y, -port.z), Color("7dcea0"), lamp_r)
	f.lamp(node, "LampNose", nose, Color("f2e2c4"), lamp_r * 1.3)


func _skids(node: Node3D, z: float, x0: float, x1: float, y_top: float) -> void:
	for side in [1.0, -1.0]:
		var tag := "P" if side > 0.0 else "S"
		f.add(node, "Skid" + tag, f.tube(0.16, 0.16, x1 - x0, 8), f.metal(Color("3a3f45"), 0.5), Vector3((x0 + x1) * 0.5, 0.2, z * side))
		for x in [x0 + 0.6, x1 - 0.6]:
			f.add(node, "Strut%s%d" % [tag, int(x)], f.tube(0.12, 0.12, y_top, 6), f.metal(Color("5c636a"), 0.4), Vector3(x, y_top * 0.5, z * side), Vector3(0.0, 0.0, PI * 0.5))
		f.add(node, "Pad" + tag, f.slab(Vector3(1.1, 0.12, 0.7), 0.9), f.metal(Color("1c1a16"), 0.7, 0.2), Vector3(x0 + 0.4, 0.07, z * side))


func _rcs(node: Node3D, spots: Array, r: float = 0.17) -> void:
	var i := 0
	for s in spots:
		var spot: Array = s
		var at: Vector3 = spot[0]
		var dir: Vector3 = spot[1]
		var quad := f.add(node, "Rcs%d" % i, f.tube(r * 1.5, r, r * 3.0, 8), f.metal(Color("15171a"), 0.45), at)
		quad.rotation = dir
		i += 1


func _sensor_ball(node: Node3D, part_name: String, at: Vector3, r: float) -> void:
	var ball := SphereMesh.new()
	ball.radius = r
	ball.height = r * 2.0
	ball.radial_segments = 14
	ball.rings = 8
	f.add(node, part_name, ball, f.metal(Color("2a2f36"), 0.25, 0.85), at)
	var eye := SphereMesh.new()
	eye.radius = r * 0.45
	eye.height = r * 0.9
	eye.radial_segments = 10
	eye.rings = 6
	f.add(node, part_name + "Eye", eye, f.glow(Color("8ae8ff"), 2.4), at + Vector3(r * 0.62, r * 0.12, 0.0))


func _intake(node: Node3D, part_name: String, at: Vector3, size: Vector3, rot: float = 0.0) -> void:
	f.block(node, part_name, size, at, Color("23272c"), {"tile": 1.2}, 0.8).rotation.y = rot
	f.strip(node, part_name + "Lip", Vector3(size.x * 0.9, 0.08, 0.1), at + Vector3(0.0, size.y * 0.5, 0.0), Color("8ae8ff"), 1.2).rotation.y = rot


func _trim(color: Color, strength: float = 0.9) -> Color:
	var c := color.lightened(0.45)
	c.a = strength
	return c


# ------------------------------------------------------------------- probe

func _probe(node: Node3D, color: Color) -> void:
	var accent := Color("e8a040")
	accent.a = 0.9
	f.fuselage(node, "Plate", [
		[-8.0, 1.0, 0.8, 2.6, 2.8], [-6.5, 1.55, 0.5, 3.0, 2.8], [1.5, 1.6, 0.5, 3.0, 2.8],
		[5.5, 1.2, 0.8, 2.7, 2.6], [9.0, 0.6, 1.3, 2.3, 2.4], [11.2, 0.12, 1.6, 2.0, 2.2],
	], color, {"tile": 2.2, "accent": accent, "band_x": -2.0, "band_w": 0.7})
	f.block(node, "Deck", Vector3(6.0, 0.35, 1.8), Vector3(-1.0, 3.05, 0.0), color.lightened(0.1), {"tile": 1.4})
	f.block(node, "Bus", Vector3(3.0, 1.0, 2.0), Vector3(-5.2, 3.3, 0.0), Color("2a3438"), {"tile": 1.2})
	f.block(node, "Radiator", Vector3(3.6, 0.1, 2.8), Vector3(-4.6, 3.8, 0.0), Color("a8a094"), {"tile": 0.8}, 1.0)
	f.pipe(node, "Boom", 0.22, 5.0, Vector3(2.6, 3.0, 0.0), Color("9aa2a8"))
	f.dish(node, "Dish", 3.3, Vector3(2.6, 5.8, 0.0), Vector3(0.0, 0.0, -PI * 0.5 + 0.35))
	f.add(node, "DishMast", f.tube(0.2, 0.28, 2.8, 8), f.metal(Color("c8d0d4"), 0.3), Vector3(2.6, 4.4, 0.0), Vector3(0.0, 0.0, PI * 0.5))
	_sensor_ball(node, "Eye", Vector3(7.4, 1.65, 0.0), 0.8)
	for side in [1.0, -1.0]:
		var tag := "P" if side > 0.0 else "S"
		f.add(node, "Arm" + tag, f.tube(0.18, 0.18, 4.2, 8), f.metal(Color("9aa2a8"), 0.3), Vector3(-1.2, 2.2, 3.5 * side), Vector3(0.0, PI * 0.5, 0.0))
		f.panel_array(node, "Wing" + tag, Vector2(7.4, 5.6), Vector3(-1.2, 2.2, 7.1 * side), Vector3(0.0, 0.0, 0.0), 0.9)
		f.add(node, "Cell" + tag, f.slab(Vector3(0.5, 0.4, 0.5), 0.9), f.metal(Color("c8d0d4"), 0.3), Vector3(-1.2, 2.2, 10.2 * side))
		f.lamp(node, "Tip" + tag, Vector3(-1.2, 2.3, 10.4 * side), Color("d4553a") if side > 0.0 else Color("7dcea0"), 0.18)
	f.pipe(node, "Antenna", 0.05, 3.8, Vector3(-6.6, 5.0, 0.6), Color("c8d0d4"), Vector3(0.0, 0.0, PI * 0.5))
	f.pipe(node, "Whip", 0.04, 2.4, Vector3(-3.8, 4.7, -0.7), Color("c8d0d4"), Vector3(0.0, 0.0, PI * 0.5))
	_engines(node, [Vector3(-8.3, 1.7, 0.0)], 0.85, 2.0, 5.0)
	_rcs(node, [
		[Vector3(5.0, 1.0, 1.3), Vector3(0.0, PI * 0.5, 0.0)], [Vector3(5.0, 1.0, -1.3), Vector3(0.0, -PI * 0.5, 0.0)],
		[Vector3(-6.0, 3.0, 1.6), Vector3(0.0, PI * 0.5, 0.0)], [Vector3(-6.0, 3.0, -1.6), Vector3(0.0, -PI * 0.5, 0.0)],
	])
	_run_lights(node, Vector3(-6.5, 3.0, 1.7), Vector3(10.4, 1.8, 0.0))


# ------------------------------------------------------------------- miner

func _miner(node: Node3D, color: Color) -> void:
	var hazard := Color("1c1a16")
	hazard.a = 0.95
	f.fuselage(node, "Plate", [
		[-8.2, 3.2, 0.8, 4.8, 3.4], [-4.0, 4.6, 0.4, 5.6, 3.4], [3.0, 4.2, 0.5, 5.0, 3.2],
		[6.8, 3.3, 0.7, 4.2, 3.0], [8.8, 2.4, 1.1, 3.6, 2.8],
	], color, {"tile": 2.4, "accent": hazard, "stripe_z": 2.2, "stripe_w": 0.55, "band_x": -7.0, "band_w": 0.9})
	f.block(node, "Deck", Vector3(8.0, 0.4, 5.0), Vector3(-2.0, 5.6, 0.0), color.lightened(0.08), {"tile": 1.6})
	f.canopy(node, "Cab", 4.6, 3.0, 1.7, Vector3(4.2, 4.5, 0.0), Color("2a5c6c"))
	f.block(node, "Hopper", Vector3(7.0, 2.6, 4.6), Vector3(-4.4, 6.5, 0.0), color.darkened(0.2), {"tile": 1.8}, 0.78)
	f.block(node, "HopperLid", Vector3(5.0, 0.3, 3.4), Vector3(-4.4, 7.9, 0.0), Color("2a2d33"), {"tile": 1.0}, 0.9)
	f.block(node, "Bucket", Vector3(5.0, 1.6, 4.4), Vector3(-2.6, 0.9, 0.0), Color("3a3a3e"), {"tile": 1.4}, 0.8)
	f.add(node, "Cutter", f.tube(2.7, 2.2, 2.4, 20), f.metal(Color("5a6068"), 0.35), Vector3(9.6, 2.35, 0.0))
	f.add(node, "CutterRim", f.tube(2.95, 2.95, 0.4, 20), f.metal(Color("e8a040"), 0.4, 0.5), Vector3(10.9, 2.35, 0.0))
	f.add(node, "Guard", f.tube(2.5, 2.5, 0.3, 20), f.metal(Color("2a2d33"), 0.5), Vector3(8.4, 2.35, 0.0))
	var bit := f.add(node, "Bit", f.tube(2.0, 0.25, 6.0, 14), f.metal(Color("e8e0d4"), 0.22, 0.9), Vector3(13.2, 2.35, 0.0))
	for k in 3:
		f.add(bit, "Flute%d" % k, f.tube(2.15 - float(k) * 0.55, 2.15 - float(k) * 0.55, 0.35, 14), f.metal(Color("c8c0b4"), 0.3, 0.9), Vector3(-2.0 + float(k) * 1.8, 0.0, 0.0))
	for k in 8:
		var ang := TAU * float(k) / 8.0
		f.add(bit, "Tooth%d" % k, f.slab(Vector3(0.9, 0.3, 0.38), 0.8), f.metal(Color("f0e8d8"), 0.25, 0.9), Vector3(-1.7 + float(k) * 0.42, sin(ang) * (1.9 - float(k) * 0.2), cos(ang) * (1.9 - float(k) * 0.2)), Vector3(ang, 0.0, 0.0))
	for side in [1.0, -1.0]:
		var tag := "P" if side > 0.0 else "S"
		f.add(node, "Shoulder" + tag, f.tube(0.9, 0.9, 1.4, 12), f.metal(Color("5a6068"), 0.4), Vector3(3.5, 4.6, 4.6 * side), Vector3(0.0, PI * 0.5, 0.0))
		f.add(node, "Arm" + tag, f.tube(0.45, 0.4, 5.4, 10), f.hull(Color("8a6a38"), {"tile": 1.2}), Vector3(6.0, 4.9, 5.4 * side), Vector3(0.0, 0.22 * side, 0.0))
		f.add(node, "Elbow" + tag, f.tube(0.7, 0.7, 0.9, 12), f.metal(Color("5a6068"), 0.4), Vector3(8.6, 4.9, 5.9 * side), Vector3(0.0, PI * 0.5, 0.0))
		f.add(node, "Fore" + tag, f.tube(0.38, 0.32, 3.6, 10), f.hull(Color("8a6a38"), {"tile": 1.0}), Vector3(10.2, 4.1, 5.1 * side), Vector3(0.0, -0.5 * side, -0.35))
		f.add(node, "Jaw" + tag, f.slab(Vector3(2.1, 0.9, 0.5), 0.8), f.metal(Color("e2d6c0"), 0.3), Vector3(12.4, 3.1, 4.6 * side), Vector3(0.0, -0.3 * side, 0.0))
		f.block(node, "Palm" + tag, Vector3(1.2, 1.0, 1.0), Vector3(11.5, 3.6, 4.7 * side), Color("5a6068"), {"tile": 0.8}, 0.85)
		f.add(node, "JawIn" + tag, f.slab(Vector3(1.7, 0.8, 0.4), 0.8), f.metal(Color("e2d6c0"), 0.3), Vector3(12.2, 3.1, 3.6 * side), Vector3(0.0, 0.25 * side, 0.0))
		f.add(node, "Pod" + tag, f.tube(1.1, 1.0, 6.0, 12), f.hull(color.darkened(0.15), {"tile": 1.4}), Vector3(-1.0, 2.4, 5.8 * side), Vector3(0.0, 0.0, 0.0))
		f.lamp(node, "Work" + tag, Vector3(5.6, 5.4, 2.6 * side), Color("fff0c0"), 0.34)
	_engines(node, [Vector3(-9.2, 3.2, 2.3), Vector3(-9.2, 3.2, -2.3)], 1.5, 2.8, 6.0)
	_skids(node, 3.1, -4.0, 3.0, 1.4)
	_run_lights(node, Vector3(-7.4, 5.0, 3.6), Vector3(6.6, 4.4, 0.0), 0.26)


# ------------------------------------------------------------------ tender

func _tender(node: Node3D, color: Color) -> void:
	var stripe := Color("1c1a16")
	stripe.a = 0.9
	f.fuselage(node, "Plate", [
		[-8.2, 3.2, 0.7, 4.4, 3.4], [-3.0, 4.2, 0.4, 5.0, 3.4], [3.0, 3.6, 0.6, 4.6, 3.2],
		[7.0, 2.4, 1.0, 3.8, 3.0], [9.0, 1.4, 1.4, 3.2, 2.8],
	], color, {"tile": 2.4, "accent": stripe, "stripe_z": 1.8, "stripe_w": 0.5, "band_x": -5.5, "band_w": 0.8})
	f.block(node, "Deck", Vector3(9.0, 0.35, 5.0), Vector3(-2.0, 5.0, 0.0), color.lightened(0.08), {"tile": 1.6})
	f.canopy(node, "Cab", 4.4, 3.0, 1.6, Vector3(4.4, 4.0, 0.0), Color("2a5c6c"))
	for side in [1.0, -1.0]:
		var tag := "P" if side > 0.0 else "S"
		f.add(node, "Tank" + tag, f.tube(1.4, 1.4, 8.0, 14), f.hull(color.darkened(0.12), {"tile": 1.6}), Vector3(-2.4, 2.0, 5.2 * side), Vector3(0.0, 0.0, 0.0))
		for k in 3:
			f.add(node, "Band%s%d" % [tag, k], f.tube(1.5, 1.5, 0.3, 14), f.metal(Color("c4b8a4"), 0.4), Vector3(-5.0 + float(k) * 2.6, 2.0, 5.2 * side))
		f.add(node, "AFrame" + tag, f.tube(0.22, 0.22, 4.4, 8), f.metal(Color("c47a4a"), 0.4), Vector3(-4.5, 6.8, 1.6 * side), Vector3(0.0, 0.0, PI * 0.5))
		f.add(node, "ClawArm" + tag, f.tube(0.18, 0.14, 2.6, 8), f.metal(Color("e4d8c4"), 0.3), Vector3(8.2, 3.2, 1.2 * side))
	f.add(node, "Boom", f.tube(0.34, 0.28, 12.0, 10), f.hull(Color("c47a4a"), {"tile": 1.4}), Vector3(1.1, 7.5, 0.0), Vector3(0.0, 0.0, 0.35))
	f.add(node, "Winch", f.tube(0.9, 0.9, 2.6, 14), f.metal(Color("2a2d33"), 0.5), Vector3(-4.6, 5.9, 0.0), Vector3(0.0, PI * 0.5, 0.0))
	f.add(node, "Cable", f.tube(0.05, 0.05, 6.0, 6), f.metal(Color("d8d0b8"), 0.5), Vector3(6.7, 6.5, 0.0), Vector3(0.0, 0.0, PI * 0.5))
	f.block(node, "Hook", Vector3(0.7, 1.1, 0.7), Vector3(6.7, 3.3, 0.0), Color("c4b8a4"), {"tile": 0.6})
	f.add(node, "ClawP", f.slab(Vector3(1.0, 0.8, 0.14), 0.9), f.metal(Color("e4d8c4"), 0.3), Vector3(6.7, 2.7, 0.55))
	f.add(node, "ClawS", f.slab(Vector3(1.0, 0.8, 0.14), 0.9), f.metal(Color("e4d8c4"), 0.3), Vector3(6.7, 2.7, -0.55))
	f.lamp(node, "WorkP", Vector3(7.4, 4.6, 1.8), Color("fff0c0"), 0.3)
	f.lamp(node, "WorkS", Vector3(7.4, 4.6, -1.8), Color("fff0c0"), 0.3)
	_engines(node, [Vector3(-9.2, 2.8, 2.2), Vector3(-9.2, 2.8, -2.2)], 1.45, 2.6, 6.0)
	_skids(node, 3.0, -5.0, 2.0, 1.2)
	_run_lights(node, Vector3(-7.0, 4.4, 3.4), Vector3(8.4, 3.2, 0.0), 0.26)


# ----------------------------------------------------------------- shuttle

func _shuttle(node: Node3D, color: Color) -> void:
	var trim := Color("c4512c")
	trim.a = 0.85
	f.fuselage(node, "Plate", [
		[-6.8, 2.2, 0.7, 3.4, 2.6], [-2.5, 3.0, 0.4, 4.0, 2.6], [2.0, 2.5, 0.6, 3.8, 2.4],
		[6.0, 1.3, 1.0, 3.0, 2.4], [9.0, 0.2, 1.5, 2.4, 2.2],
	], color, {"tile": 1.8, "accent": trim, "stripe_z": 1.2, "stripe_w": 0.35, "windows": 1.0, "win_y": 2.1, "win_gap": 1.2, "win_pitch": 1.1, "win_rows": 1.0, "band_x": 3.0, "band_w": 0.3})
	f.canopy(node, "Glass", 5.0, 2.6, 1.3, Vector3(5.0, 3.0, 0.0))
	f.wing(node, "Wing", [Vector2(1.5, 2.4), Vector2(-5.0, 7.4), Vector2(-6.8, 7.4), Vector2(-6.8, 2.4)], Vector3(0.0, 1.6, 0.0), 0.34, color.lightened(0.04), {"tile": 1.6}, 0.06)
	for side in [1.0, -1.0]:
		var tag := "P" if side > 0.0 else "S"
		f.add(node, "Nacelle" + tag, f.tube(1.0, 0.9, 5.0, 14), f.hull(color.darkened(0.12), {"tile": 1.2}), Vector3(-4.2, 1.8, 4.2 * side))
		f.block(node, "Winglet" + tag, Vector3(2.0, 2.0, 0.2), Vector3(-6.3, 2.8, 7.2 * side), color.darkened(0.2), {"tile": 1.0}, 0.8)
		f.block(node, "DoorFrame" + tag, Vector3(2.2, 1.7, 0.1), Vector3(0.6, 2.4, 2.45 * side), Color("2a3034"), {"tile": 0.8}, 0.85)
		f.add(node, "Gear" + tag, f.tube(0.12, 0.12, 1.5, 8), f.metal(Color("5c636a"), 0.4), Vector3(-1.4, 0.8, 2.4 * side))
		f.add(node, "GearPad" + tag, f.slab(Vector3(1.0, 0.12, 0.7), 0.9), f.metal(Color("1c1a16"), 0.7, 0.2), Vector3(-1.4, 0.07, 2.4 * side))
		f.lamp(node, "Tip" + tag, Vector3(-6.0, 1.7, 7.5 * side), Color("d4553a") if side > 0.0 else Color("7dcea0"), 0.2)
	f.block(node, "Door", Vector3(2.3, 1.8, 0.08), Vector3(0.6, 2.4, 2.48), Color("3a4248"), {"tile": 0.7}, 0.9)
	f.add(node, "Ramp", f.slab(Vector3(2.6, 0.14, 2.2), 0.95), f.hull(Color("4a453c"), {"tile": 0.8}), Vector3(-7.9, 1.0, 0.0), Vector3(0.0, 0.0, -0.32))
	f.add(node, "Gear", f.tube(0.12, 0.12, 1.4, 8), f.metal(Color("5c636a"), 0.4), Vector3(6.0, 0.8, 0.0))
	f.add(node, "GearPad", f.slab(Vector3(0.9, 0.12, 0.6), 0.9), f.metal(Color("1c1a16"), 0.7, 0.2), Vector3(6.0, 0.07, 0.0))
	_engines(node, [Vector3(-6.8, 1.8, 4.2), Vector3(-6.8, 1.8, -4.2)], 0.8, 1.8, 4.6)
	f.lamp(node, "LampNose", Vector3(8.0, 1.9, 0.0), Color("f2e2c4"), 0.28)
	f.lamp(node, "RunP", Vector3(-2.0, 1.0, 3.0), Color("d4553a"), 0.2)
	f.lamp(node, "RunS", Vector3(-2.0, 1.0, -3.0), Color("7dcea0"), 0.2)


# ------------------------------------------------------------------ fighters

func _dart(node: Node3D, color: Color) -> void:
	var trim := Color("e8fbff")
	trim.a = 0.85
	f.fuselage(node, "Plate", [
		[-7.0, 0.95, 1.0, 2.7, 2.5], [-3.0, 1.35, 0.7, 3.3, 2.5], [3.0, 1.1, 0.9, 3.0, 2.5],
		[9.0, 0.55, 1.4, 2.5, 2.4], [14.0, 0.1, 1.8, 2.1, 2.2],
	], color, {"tile": 1.8, "accent": trim, "stripe_z": 0.55, "stripe_w": 0.2, "band_x": -4.0, "band_w": 0.3}, 16)
	f.canopy(node, "Canopy", 4.8, 1.3, 1.1, Vector3(3.6, 2.95, 0.0), Color("1a6a86"))
	f.wing(node, "Fin", [Vector2(5.5, 0.9), Vector2(-5.5, 6.8), Vector2(-7.0, 6.8), Vector2(-7.0, 0.9)], Vector3(0.0, 1.7, 0.0), 0.3, color.darkened(0.12), {"tile": 1.6, "accent": trim, "band_x": -5.5, "band_w": 0.45}, 0.0, 0.72)
	for side in [1.0, -1.0]:
		var tag := "P" if side > 0.0 else "S"
		f.block(node, "Vane" + tag, Vector3(3.6, 2.2, 0.12), Vector3(-5.2, 3.5, 1.1 * side), color.darkened(0.3), {"tile": 1.0}, 0.7).rotation.x = 0.3 * side
		f.add(node, "Rail" + tag, f.tube(0.2, 0.17, 3.0, 8), f.metal(Color("2b2f35"), 0.3), Vector3(-1.6, 1.55, 6.4 * side))
		f.add(node, "Missile" + tag, f.tube(0.17, 0.05, 1.8, 8), f.metal(Color("e8eef2"), 0.3, 0.3), Vector3(0.3, 1.55, 6.4 * side))
		f.lamp(node, "Tip" + tag, Vector3(-6.4, 1.8, 6.9 * side), Color("d4553a") if side > 0.0 else Color("7dcea0"), 0.17)
		_intake(node, "Intake" + tag, Vector3(1.0, 1.9, 1.35 * side), Vector3(2.4, 0.9, 0.5))
		f.add(node, "Vernier" + tag, f.bell(0.9, 0.22, 0.4), f.metal(Color("1c1f24"), 0.4), Vector3(-5.8, 1.35, 3.0 * side))
	f.add(node, "Spike", f.tube(0.14, 0.05, 4.0, 8), f.metal(Color("9fe8f4"), 0.25), Vector3(15.0, 1.95, 0.0), Vector3(0.0, 0.0, 0.0))
	f.barrel(node, "GunN", Vector3(9.5, 1.4, 0.0), 4.4, 0.2)
	_engines(node, [Vector3(-7.2, 1.85, 0.0)], 1.0, 2.2, 5.6, Color("7ad8ff"))
	f.lamp(node, "LampNose", Vector3(11.0, 2.2, 0.0), Color("f2e2c4"), 0.2)


func _sting(node: Node3D, color: Color) -> void:
	var trim := Color("1c1a16")
	trim.a = 0.9
	f.fuselage(node, "Plate", [
		[-5.8, 2.4, 0.8, 3.6, 3.2], [-1.0, 3.0, 0.5, 4.2, 3.2], [3.0, 2.3, 0.8, 3.8, 3.0],
		[7.8, 0.5, 1.4, 2.8, 2.6],
	], color, {"tile": 1.9, "accent": trim, "stripe_z": 1.3, "stripe_w": 0.35, "band_x": -3.0, "band_w": 0.5})
	f.canopy(node, "Canopy", 4.4, 2.2, 1.3, Vector3(1.8, 3.9, 0.0), Color("4a3a24"))
	f.add(node, "Drum", f.tube(1.5, 1.5, 3.0, 16), f.hull(Color("6a4a22"), {"tile": 1.4}), Vector3(-1.6, 4.5, 0.0), Vector3(0.0, PI * 0.5, 0.0))
	f.block(node, "Belt", Vector3(2.8, 0.4, 0.9), Vector3(0.6, 4.0, 1.4), Color("2a2014"), {"tile": 0.6}, 0.9)
	for side in [1.0, -1.0]:
		var tag := "P" if side > 0.0 else "S"
		f.add(node, "Pod" + tag, f.tube(0.95, 0.85, 6.0, 14), f.hull(color.darkened(0.15), {"tile": 1.2}), Vector3(2.4, 2.1, 3.4 * side))
		f.add(node, "Armor" + tag, f.slab(Vector3(5.0, 0.8, 1.6), 0.8), f.hull(color.lightened(0.05), {"tile": 1.2}), Vector3(0.0, 3.0, 2.6 * side))
	f.barrel(node, "GunA", Vector3(7.0, 2.1, 3.4), 6.0, 0.34)
	f.barrel(node, "GunB", Vector3(7.0, 2.1, -3.4), 6.0, 0.34)
	f.barrel(node, "GunC", Vector3(6.4, 1.5, 1.3), 5.2, 0.28)
	f.barrel(node, "GunD", Vector3(6.4, 1.5, -1.3), 5.2, 0.28)
	_engines(node, [Vector3(-6.0, 2.0, 1.7), Vector3(-6.0, 2.0, -1.7)], 1.0, 2.0, 5.0)
	_run_lights(node, Vector3(-4.0, 3.0, 3.4), Vector3(7.4, 2.0, 0.0))


func _wasp(node: Node3D, color: Color) -> void:
	var trim := Color("f0b44a")
	trim.a = 0.95
	f.fuselage(node, "Plate", [
		[-5.8, 1.6, 0.9, 3.4, 2.6], [-1.0, 2.1, 0.6, 4.0, 2.6], [3.0, 1.6, 0.9, 3.6, 2.5],
		[8.5, 0.15, 1.5, 2.8, 2.3],
	], color, {"tile": 1.8, "accent": trim, "stripe_z": 0.9, "stripe_w": 0.3, "band_x": -2.5, "band_w": 0.5})
	f.canopy(node, "Canopy", 4.6, 1.9, 1.3, Vector3(2.8, 3.7, 0.0), Color("6a3820"))
	f.wing(node, "Wing", [Vector2(3.5, 1.5), Vector2(4.2, 8.6), Vector2(0.8, 8.6), Vector2(-5.8, 1.7)], Vector3(0.0, 2.0, 0.0), 0.4, color.darkened(0.1), {"tile": 1.6, "accent": trim, "stripe_z": 5.0, "stripe_w": 0.35}, -0.05, 0.75)
	f.block(node, "Stripe", Vector3(6.4, 0.12, 0.7), Vector3(0.6, 4.1, 0.0), trim, {"tile": 0.8}, 1.0)
	for side in [1.0, -1.0]:
		var tag := "P" if side > 0.0 else "S"
		f.add(node, "Pod" + tag, f.tube(0.85, 0.75, 6.2, 14), f.hull(color.darkened(0.25), {"tile": 1.2}), Vector3(1.8, 2.2, 8.2 * side))
		f.add(node, "PodCap" + tag, f.tube(0.9, 0.9, 0.5, 14), f.metal(Color("f0b44a"), 0.4, 0.5), Vector3(4.9, 2.2, 8.2 * side))
		f.lamp(node, "Tip" + tag, Vector3(-1.2, 2.3, 8.8 * side), Color("d4553a") if side > 0.0 else Color("7dcea0"), 0.18)
		_intake(node, "Intake" + tag, Vector3(0.8, 2.6, 1.7 * side), Vector3(2.4, 0.9, 0.5))
	f.barrel(node, "GunP", Vector3(7.6, 2.2, 8.2), 5.2, 0.34)
	f.barrel(node, "GunS", Vector3(7.6, 2.2, -8.2), 5.2, 0.34)
	_engines(node, [Vector3(-6.0, 2.1, 2.1), Vector3(-6.0, 2.1, -2.1)], 1.05, 2.1, 5.2)
	f.lamp(node, "LampNose", Vector3(7.4, 2.3, 0.0), Color("f2e2c4"), 0.22)


func _fang(node: Node3D, color: Color) -> void:
	var trim := Color("e8c8c4")
	trim.a = 0.85
	f.fuselage(node, "Plate", [
		[-6.2, 1.5, 0.8, 3.1, 2.5], [-1.0, 2.0, 0.55, 3.6, 2.5], [4.0, 1.25, 0.9, 3.0, 2.4],
		[9.5, 0.6, 1.2, 2.5, 2.3], [13.6, 0.1, 1.5, 2.0, 2.1],
	], color, {"tile": 1.8, "accent": trim, "stripe_z": 0.7, "stripe_w": 0.2, "band_x": -3.5, "band_w": 0.35})
	f.canopy(node, "Canopy", 4.8, 1.7, 1.2, Vector3(1.8, 3.3, 0.0), Color("3a1018"))
	f.block(node, "Snout", Vector3(8.0, 0.5, 0.9), Vector3(7.4, 2.7, 0.0), color.lightened(0.05), {"tile": 1.2}, 0.7)
	f.wing(node, "Fin", [Vector2(1.5, 1.7), Vector2(-6.4, 6.6), Vector2(-7.0, 6.6), Vector2(-7.0, 2.0)], Vector3(0.0, 1.9, 0.0), 0.28, color.darkened(0.25), {"tile": 1.6}, 0.12, 0.7)
	for side in [1.0, -1.0]:
		var tag := "P" if side > 0.0 else "S"
		var fang := f.add(node, "Fang" if side > 0.0 else "FangS", f.tube(0.5, 0.06, 8.6, 10), f.metal(Color("e8c8c4"), 0.28, 0.5), Vector3(11.0, 1.9, 1.5 * side), Vector3(0.0, -0.1 * side, 0.0))
		fang.rotation.z = 0.0
		f.block(node, "Gill" + tag, Vector3(3.4, 0.5, 0.2), Vector3(1.0, 2.1, 1.72 * side), Color("1c1014"), {"tile": 0.7}, 0.8)
		f.lamp(node, "Tip" + tag, Vector3(-6.4, 2.0, 6.4 * side), Color("d4553a") if side > 0.0 else Color("7dcea0"), 0.17)
		f.add(node, "Vent" + tag, f.tube(0.45, 0.45, 2.0, 8), f.metal(Color("1c1014"), 0.4), Vector3(-3.6, 1.2, 2.2 * side), Vector3(0.0, 0.0, PI * 0.5))
	f.barrel(node, "GunV", Vector3(5.6, 1.1, 0.0), 4.4, 0.26)
	_engines(node, [Vector3(-6.4, 1.9, 0.0)], 1.1, 2.3, 5.6, Color("ff6a5a"))
	f.lamp(node, "LampNose", Vector3(10.0, 2.2, 0.0), Color("f2e2c4"), 0.2)


func _lance(node: Node3D, color: Color) -> void:
	var trim := Color("c8b48a")
	trim.a = 0.9
	f.fuselage(node, "Plate", [
		[-6.8, 3.6, 0.8, 4.8, 3.6], [-2.0, 4.2, 0.5, 5.4, 3.6], [3.5, 3.4, 0.9, 4.8, 3.4],
		[7.0, 2.0, 1.4, 3.8, 3.0],
	], color, {"tile": 2.4, "accent": trim, "stripe_z": 2.2, "stripe_w": 0.45, "band_x": -4.5, "band_w": 0.8})
	f.canopy(node, "Canopy", 4.2, 2.2, 1.3, Vector3(-1.2, 5.2, 0.0), Color("1c2a34"))
	f.block(node, "Block", Vector3(7.0, 1.2, 3.4), Vector3(2.0, 5.0, 0.0), color.lightened(0.04), {"tile": 1.4}, 0.8)
	f.block(node, "Collar", Vector3(3.0, 2.4, 3.0), Vector3(5.2, 3.6, 0.0), Color("a89a78"), {"tile": 1.0}, 0.82)
	f.add(node, "Lance", f.tube(0.8, 0.55, 14.0, 16), f.metal(Color("d8dde4"), 0.18, 0.95), Vector3(11.0, 3.6, 0.0))
	for side in [1.0, -1.0]:
		var tag := "P" if side > 0.0 else "S"
		f.add(node, "Rail" + tag, f.tube(0.28, 0.24, 11.0, 10), f.metal(Color("3a4048"), 0.3, 0.9), Vector3(10.0, 3.6, 0.95 * side))
		f.add(node, "Skirt" + tag, f.slab(Vector3(8.0, 1.3, 1.0), 0.8), f.hull(Color("8a8e96"), {"tile": 1.4}), Vector3(-0.5, 2.0, 4.0 * side))
		f.add(node, "Plate" + tag, f.slab(Vector3(5.6, 0.5, 3.2), 0.8), f.hull(Color("8a8e96"), {"tile": 1.4}), Vector3(-1.4, 2.7, 4.3 * side))
		f.lamp(node, "Tip" + tag, Vector3(-4.0, 3.5, 4.4 * side), Color("d4553a") if side > 0.0 else Color("7dcea0"), 0.2)
	for k in 5:
		f.add(node, "Coil%d" % k, f.tube(1.05, 1.05, 0.42, 14), f.metal(Color("c8b48a"), 0.3, 0.9), Vector3(7.0 + float(k) * 2.2, 3.6, 0.0), Vector3(0.0, 0.0, 0.0))
	f.strip(node, "Charge", Vector3(11.0, 0.08, 0.18), Vector3(11.0, 4.45, 0.0), Color("9ad8ff"), 2.2)
	f.add(node, "Muzzle", f.tube(0.95, 0.95, 0.7, 14), f.metal(Color("15171a"), 0.35, 0.7), Vector3(17.8, 3.6, 0.0))
	_engines(node, [Vector3(-7.2, 2.6, 2.2), Vector3(-7.2, 2.6, -2.2)], 1.3, 2.6, 6.0)
	f.lamp(node, "LampNose", Vector3(6.8, 2.5, 0.0), Color("f2e2c4"), 0.24)


func _fighter(node: Node3D, color: Color) -> void:
	var trim := Color("f2e2c4")
	trim.a = 0.85
	f.fuselage(node, "Plate", [
		[-5.0, 1.25, 0.9, 3.3, 2.5], [0.0, 1.85, 0.6, 3.9, 2.5], [4.0, 1.25, 0.9, 3.3, 2.4],
		[8.5, 0.5, 1.3, 2.6, 2.2], [12.0, 0.08, 1.7, 2.1, 2.0],
	], color, {"tile": 1.8, "accent": trim, "stripe_z": 0.6, "stripe_w": 0.2, "band_x": -2.0, "band_w": 0.4})
	f.canopy(node, "Canopy", 4.4, 1.5, 1.1, Vector3(3.6, 3.15, 0.0), Color("2a5868"))
	f.wing(node, "Wing", [Vector2(3.0, 1.5), Vector2(-3.4, 7.0), Vector2(-5.2, 7.0), Vector2(-5.2, 1.5)], Vector3(0.0, 1.8, 0.0), 0.32, color.darkened(0.1), {"tile": 1.6}, 0.0, 0.74)
	for side in [1.0, -1.0]:
		var tag := "P" if side > 0.0 else "S"
		f.add(node, "Pod" + tag, f.tube(0.5, 0.4, 2.6, 12), f.hull(color.darkened(0.3), {"tile": 0.9}), Vector3(-2.2, 1.9, 7.0 * side))
		f.barrel(node, "Gun" + tag, Vector3(0.6, 1.9, 7.0 * side), 3.6, 0.15)
		f.block(node, "Vane" + tag, Vector3(3.0, 2.0, 0.12), Vector3(-4.0, 3.4, 1.2 * side), color.darkened(0.3), {"tile": 1.0}, 0.7).rotation.x = 0.3 * side
		_intake(node, "Intake" + tag, Vector3(0.6, 2.1, 1.5 * side), Vector3(2.4, 0.9, 0.5))
		f.lamp(node, "Tip" + tag, Vector3(-3.4, 1.9, 7.3 * side), Color("d4553a") if side > 0.0 else Color("7dcea0"), 0.18)
	_engines(node, [Vector3(-5.2, 1.9, 1.0), Vector3(-5.2, 1.9, -1.0)], 0.72, 1.7, 4.8)
	f.lamp(node, "LampNose", Vector3(9.4, 2.1, 0.0), Color("f2e2c4"), 0.2)


# -------------------------------------------------------- support / scouts

func _picket(node: Node3D, color: Color) -> void:
	var trim := Color("9fd0ff")
	trim.a = 0.85
	f.fuselage(node, "Plate", [
		[-6.0, 1.0, 0.9, 2.7, 2.5], [-1.0, 1.4, 0.6, 3.1, 2.5], [4.0, 1.0, 0.9, 2.7, 2.4],
		[8.5, 0.5, 1.2, 2.3, 2.2], [11.0, 0.1, 1.5, 1.9, 2.0],
	], color, {"tile": 1.8, "accent": trim, "stripe_z": 0.5, "stripe_w": 0.18, "band_x": 1.5, "band_w": 0.3})
	f.canopy(node, "Canopy", 3.6, 1.2, 0.9, Vector3(5.6, 2.6, 0.0), Color("1a5a78"))
	f.add(node, "Mast", f.tube(0.2, 0.26, 4.2, 8), f.metal(Color("d7e6ee"), 0.25), Vector3(0.4, 4.9, 0.0), Vector3(0.0, 0.0, PI * 0.5))
	f.dish(node, "Dish", 2.2, Vector3(0.4, 7.2, 0.0), Vector3(0.0, 0.0, -0.4))
	f.block(node, "Radar", Vector3(0.5, 0.5, 3.6), Vector3(0.4, 5.1, 0.0), Color("2a2d33"), {"tile": 0.7}, 0.9)
	f.wing(node, "Fin", [Vector2(1.5, 1.2), Vector2(-3.5, 4.4), Vector2(-5.8, 4.4), Vector2(-5.8, 1.2)], Vector3(0.0, 1.9, 0.0), 0.2, color.darkened(0.15), {"tile": 1.2}, 0.1, 0.78)
	for side in [1.0, -1.0]:
		var tag := "P" if side > 0.0 else "S"
		f.add(node, "Sensor" + tag, f.tube(0.22, 0.22, 1.6, 8), f.metal(Color("2a2f36"), 0.3), Vector3(-3.6, 1.9, 4.5 * side))
		f.lamp(node, "Tip" + tag, Vector3(-4.5, 2.0, 4.5 * side), Color("d4553a") if side > 0.0 else Color("7dcea0"), 0.15)
	f.lamp(node, "LampBow", Vector3(9.2, 1.9, 0.0), Color("9fd0ff"), 0.28)
	_engines(node, [Vector3(-6.3, 1.85, 0.0)], 0.75, 1.8, 4.6)


func _manifest(node: Node3D, color: Color) -> void:
	var trim := Color("7dffc2")
	trim.a = 0.85
	f.fuselage(node, "Plate", [
		[-6.0, 2.3, 0.8, 3.5, 3.0], [-1.0, 2.8, 0.5, 4.1, 3.0], [3.5, 2.2, 0.8, 3.7, 2.9],
		[7.6, 1.0, 1.3, 2.9, 2.7], [9.0, 0.3, 1.6, 2.5, 2.4],
	], color, {"tile": 1.9, "accent": trim, "stripe_z": 1.4, "stripe_w": 0.3, "band_x": -2.8, "band_w": 0.45})
	f.canopy(node, "Canopy", 3.6, 1.8, 1.0, Vector3(5.2, 3.4, 0.0), Color("2a5c5c"))
	for side in [1.0, -1.0]:
		var tag := "P" if side > 0.0 else "S"
		f.add(node, "Post" + tag, f.tube(0.16, 0.16, 2.8, 8), f.metal(Color("c8b48a"), 0.3), Vector3(0.6, 5.4, 1.5 * side), Vector3(0.0, 0.0, PI * 0.5))
	f.block(node, "Slate", Vector3(3.2, 2.4, 0.18), Vector3(0.6, 6.6, 0.0), Color("1c2428"), {"tile": 0.8}, 0.95)
	f.block(node, "SlateFrame", Vector3(3.5, 2.7, 0.1), Vector3(0.6, 6.6, 0.0), Color("8ea4a8"), {"tile": 0.8}, 0.95)
	f.strip(node, "Scan", Vector3(2.6, 0.12, 0.24), Vector3(0.6, 6.9, 0.12), Color("7dffc2"), 2.0)
	f.dish(node, "Reader", 1.4, Vector3(3.0, 4.3, 0.0), Vector3(0.0, 0.0, -PI * 0.5 + 0.5))
	f.block(node, "Clip", Vector3(0.4, 0.7, 1.4), Vector3(2.0, 4.6, 0.0), Color("c8b48a"), {"tile": 0.6})
	f.add(node, "Lens", f.tube(0.6, 0.6, 0.4, 14), f.glow(Color("7dffc2"), 1.6), Vector3(8.0, 1.9, 0.0), Vector3(0.0, 0.0, 0.0))
	f.lamp(node, "LampScan", Vector3(4.2, 4.0, 0.0), Color("7dffc2"), 0.26)
	_engines(node, [Vector3(-6.2, 2.0, 1.6), Vector3(-6.2, 2.0, -1.6)], 0.8, 1.8, 4.4)
	_run_lights(node, Vector3(-4.0, 3.0, 2.4), Vector3(7.2, 2.2, 0.0))


func _hawser(node: Node3D, color: Color) -> void:
	var trim := Color("f0c56a")
	trim.a = 0.9
	f.fuselage(node, "Plate", [
		[-7.0, 3.0, 0.7, 3.9, 3.2], [-2.0, 3.6, 0.5, 4.5, 3.2], [3.0, 3.0, 0.8, 3.9, 3.0],
		[8.0, 1.8, 1.2, 3.1, 2.8],
	], color, {"tile": 2.0, "accent": trim, "stripe_z": 1.8, "stripe_w": 0.4, "band_x": -4.0, "band_w": 0.7})
	f.canopy(node, "Canopy", 3.8, 2.2, 1.2, Vector3(4.2, 3.7, 0.0), Color("2a5c6c"))
	f.add(node, "Drum", f.tube(1.2, 1.2, 3.0, 16), f.hull(Color("3a4248"), {"tile": 1.0}), Vector3(-2.6, 5.0, 0.0), Vector3(0.0, PI * 0.5, 0.0))
	f.add(node, "Boom", f.tube(0.36, 0.3, 11.0, 12), f.hull(Color("8a5a32"), {"tile": 1.4}), Vector3(8.4, 3.3, 0.0))
	f.add(node, "BoomBase", f.tube(0.9, 0.9, 1.6, 12), f.metal(Color("3a4248"), 0.4), Vector3(3.2, 3.3, 0.0))
	f.add(node, "Cable", f.tube(0.07, 0.07, 9.0, 6), f.metal(Color("c8b48a"), 0.6, 0.3), Vector3(1.8, 4.05, 0.0))
	var collar := TorusMesh.new()
	collar.inner_radius = 0.75
	collar.outer_radius = 1.2
	collar.rings = 18
	collar.ring_segments = 8
	f.add(node, "Collar", collar, f.metal(Color("3a4248"), 0.35), Vector3(14.0, 3.3, 0.0), Vector3(0.0, 0.0, PI * 0.5))
	for side in [1.0, -1.0]:
		var tag := "P" if side > 0.0 else "S"
		f.add(node, "Jaw" + tag, f.slab(Vector3(1.4, 0.4, 0.3), 0.8), f.metal(Color("c8b48a"), 0.3), Vector3(14.0, 3.3, 1.0 * side))
		f.lamp(node, "Tip" + tag, Vector3(-6.0, 3.6, 3.6 * side), Color("d4553a") if side > 0.0 else Color("7dcea0"), 0.2)
	f.lamp(node, "LampTow", Vector3(13.2, 4.5, 0.0), Color("f0c56a"), 0.28)
	_engines(node, [Vector3(-7.2, 2.4, 2.0), Vector3(-7.2, 2.4, -2.0)], 1.15, 2.3, 5.4)
	_skids(node, 2.6, -4.0, 2.0, 1.2)
	f.lamp(node, "LampNose", Vector3(7.8, 2.4, 0.0), Color("f2e2c4"), 0.24)


func _sentry(node: Node3D, color: Color) -> void:
	var trim := Color("c8b46a")
	trim.a = 0.9
	f.fuselage(node, "Plate", [
		[-7.0, 4.8, 0.7, 2.8, 4.0], [-1.0, 6.2, 0.4, 3.2, 4.0], [4.0, 5.0, 0.6, 2.8, 3.8],
		[6.6, 3.4, 0.9, 2.5, 3.4],
	], color, {"tile": 2.0, "accent": trim, "stripe_z": 4.0, "stripe_w": 0.5, "band_x": -3.5, "band_w": 0.6}, 20)
	f.block(node, "Base", Vector3(8.0, 0.5, 6.0), Vector3(0.0, 3.4, 0.0), color.lightened(0.08), {"tile": 1.6}, 0.82)
	f.turret(node, "Turret", Vector3(0.6, 3.5, 0.0), 2.1, 1, 11.0)
	f.add(node, "Mantlet", f.tube(0.95, 0.85, 1.6, 12), f.metal(Color("6a6840"), 0.4), Vector3(3.2, 4.6, 0.0))
	_sensor_ball(node, "Eye", Vector3(-1.4, 5.7, 0.0), 0.65)
	f.add(node, "Radar", f.slab(Vector3(0.3, 1.2, 2.4), 0.9), f.metal(Color("2a2d33"), 0.4), Vector3(-3.2, 4.4, 0.0))
	for side in [1.0, -1.0]:
		var tag := "P" if side > 0.0 else "S"
		f.add(node, "Leg" + tag, f.tube(0.28, 0.2, 3.4, 8), f.metal(Color("5c636a"), 0.4), Vector3(0.0, 1.0, 6.4 * side), Vector3(0.0, 0.0, PI * 0.5))
		f.add(node, "Foot" + tag, f.slab(Vector3(2.2, 0.15, 1.2), 0.9), f.metal(Color("1c1a16"), 0.7, 0.2), Vector3(0.0, 0.1, 6.4 * side))
		f.block(node, "Pylon" + tag, Vector3(4.0, 1.4, 1.2), Vector3(-1.5, 1.5, 5.4 * side), color.darkened(0.15), {"tile": 1.2}, 0.8)
	_engines(node, [Vector3(-7.2, 1.8, 2.6), Vector3(-7.2, 1.8, -2.6)], 0.9, 1.8, 4.4)
	_run_lights(node, Vector3(-5.0, 2.8, 5.4), Vector3(6.2, 1.9, 0.0), 0.24)


func _welder(node: Node3D, color: Color) -> void:
	var trim := Color("e8a040")
	trim.a = 0.9
	f.fuselage(node, "Plate", [
		[-5.0, 1.2, 0.8, 2.5, 2.6], [-0.5, 1.6, 0.5, 3.0, 2.6], [3.0, 1.2, 0.8, 2.6, 2.5],
		[6.0, 0.2, 1.2, 2.0, 2.2],
	], color, {"tile": 1.4, "accent": trim, "stripe_z": 0.8, "stripe_w": 0.2, "band_x": -2.5, "band_w": 0.35})
	f.canopy(node, "Canopy", 3.0, 1.4, 0.9, Vector3(2.4, 2.9, 0.0), Color("2a5c6c"))
	f.add(node, "ArmBase", f.tube(0.5, 0.5, 0.8, 12), f.metal(Color("5a6068"), 0.4), Vector3(0.4, 3.3, 0.0), Vector3(0.0, 0.0, PI * 0.5))
	f.add(node, "WeldArm", f.tube(0.2, 0.17, 3.8, 8), f.hull(Color("d8d4c8"), {"tile": 0.8}), Vector3(2.0, 4.4, 0.0), Vector3(0.0, 0.0, 0.57))
	f.add(node, "Elbow", f.tube(0.3, 0.3, 0.5, 10), f.metal(Color("5a6068"), 0.4), Vector3(3.5, 5.3, 0.0), Vector3(0.0, PI * 0.5, 0.0))
	f.add(node, "Fore", f.tube(0.16, 0.14, 2.6, 8), f.hull(Color("d8d4c8"), {"tile": 0.8}), Vector3(4.4, 4.5, 0.0), Vector3(0.0, 0.0, -0.81))
	f.add(node, "Torch", f.tube(0.34, 0.2, 0.9, 10), f.metal(Color("e8a040"), 0.3, 0.6), Vector3(5.3, 3.4, 0.0), Vector3(0.0, 0.0, -0.81))
	f.lamp(node, "LampWeld", Vector3(5.7, 3.0, 0.0), Color("ffd27a"), 0.24)
	f.block(node, "Tools", Vector3(2.2, 0.9, 1.6), Vector3(-2.6, 3.4, 0.0), Color("3a3f45"), {"tile": 0.8}, 0.8)
	f.wing(node, "Fin", [Vector2(1.0, 1.1), Vector2(-3.0, 3.2), Vector2(-4.6, 3.2), Vector2(-4.6, 1.1)], Vector3(0.0, 1.7, 0.0), 0.16, color.darkened(0.15), {"tile": 1.0}, 0.0, 0.8)
	_engines(node, [Vector3(-5.2, 1.7, 0.0)], 0.7, 1.5, 4.0)
	_rcs(node, [
		[Vector3(3.6, 1.0, 1.2), Vector3(0.0, PI * 0.5, 0.0)], [Vector3(3.6, 1.0, -1.2), Vector3(0.0, -PI * 0.5, 0.0)],
	], 0.13)
	_run_lights(node, Vector3(-3.0, 1.9, 1.7), Vector3(5.2, 1.8, 0.0), 0.18)


func _lighter(node: Node3D, color: Color) -> void:
	var trim := Color("8a6a38")
	trim.a = 0.9
	f.fuselage(node, "Plate", [
		[-8.2, 4.4, 0.7, 3.2, 3.6], [-3.0, 5.2, 0.4, 3.8, 3.6], [3.0, 4.6, 0.5, 3.4, 3.4],
		[7.2, 2.6, 1.0, 2.9, 3.0],
	], color, {"tile": 2.4, "accent": trim, "stripe_z": 3.6, "stripe_w": 0.5, "band_x": 4.0, "band_w": 0.6})
	f.add(node, "Pen", f.loft([
		[-7.4, 3.2, 0.0, 2.0, 3.0], [-6.8, 3.8, 0.0, 2.8, 3.0], [1.0, 3.8, 0.0, 2.8, 3.0],
		[2.2, 3.4, 0.0, 2.5, 3.0], [2.6, 1.4, 0.0, 1.6, 3.0],
	], 16), f.glass(Color(0.42, 0.62, 0.52, 0.62), 0.5), Vector3(-0.8, 3.3, 0.0))
	for k in 5:
		f.add(node, "PenRib%d" % k, f.tube(3.9, 3.9, 0.22, 18), f.metal(Color("d8d0b8"), 0.4), Vector3(-6.4 + float(k) * 1.9, 4.7, 0.0), Vector3.ZERO, Vector3(1.0, 0.37, 1.0))
	f.block(node, "Stall", Vector3(2.4, 1.8, 2.4), Vector3(-3.0, 4.2, 1.6), Color("8a6a38"), {"tile": 1.0}, 0.85)
	f.block(node, "StallB", Vector3(2.4, 1.8, 2.4), Vector3(-3.0, 4.2, -1.6), Color("8a6a38"), {"tile": 1.0}, 0.85)
	f.add(node, "Ramp", f.slab(Vector3(3.4, 0.2, 3.6), 0.95), f.hull(Color("6a5438"), {"tile": 0.9}), Vector3(-9.6, 1.0, 0.0), Vector3(0.0, 0.0, -0.3))
	f.canopy(node, "Cab", 3.6, 3.0, 1.4, Vector3(5.0, 3.5, 0.0), Color("2a5c6c"))
	for side in [1.0, -1.0]:
		var tag := "P" if side > 0.0 else "S"
		f.add(node, "Rail" + tag, f.tube(0.12, 0.12, 6.6, 8), f.metal(Color("e8e0d0"), 0.35), Vector3(-2.0, 3.4, 4.6 * side))
		f.block(node, "Sponson" + tag, Vector3(5.0, 1.2, 1.4), Vector3(-1.0, 1.4, 5.3 * side), color.darkened(0.15), {"tile": 1.2}, 0.8)
	_engines(node, [Vector3(-8.8, 2.2, 2.2), Vector3(-8.8, 2.2, -2.2)], 1.25, 2.4, 5.6)
	_skids(node, 3.2, -4.0, 3.0, 1.2)
	_run_lights(node, Vector3(-6.8, 3.4, 5.0), Vector3(7.4, 2.2, 0.0), 0.26)


# -------------------------------------------------------------- mothership

func _mothership(node: Node3D, color: Color) -> void:
	var trim := Color("3aa0b8")
	trim.a = 0.9
	var hull_opts := {
		"tile": 12.0, "accent": trim, "stripe_z": 10.0, "stripe_w": 1.8, "band_x": 56.0, "band_w": 3.0,
		"windows": 1.0, "win_y": 11.0, "win_gap": 3.6, "win_pitch": 3.4, "win_rows": 2.0,
	}
	f.fuselage(node, "Plate", [
		[94.0, 2.5, 6.0, 14.0, 2.4], [86.0, 9.0, 4.0, 18.0, 3.0], [68.0, 15.0, 2.0, 21.0, 3.4],
		[30.0, 19.0, 0.0, 24.0, 3.8], [-20.0, 22.0, 0.0, 26.0, 4.0], [-60.0, 19.0, 2.0, 23.0, 4.0],
		[-80.0, 14.0, 4.0, 19.0, 4.0],
	], color, hull_opts, 22)
	f.block(node, "Spine", Vector3(112.0, 3.0, 9.0), Vector3(-8.0, 26.4, 0.0), color.lightened(0.08), {"tile": 6.0}, 0.9)
	f.block(node, "Prow", Vector3(26.0, 2.0, 12.0), Vector3(74.0, 20.4, 0.0), color.darkened(0.12), {"tile": 5.0}, 0.78)
	f.block(node, "TowerBase", Vector3(30.0, 5.0, 20.0), Vector3(36.0, 28.4, 0.0), color.lightened(0.04), {"tile": 6.0}, 0.86)
	f.block(node, "Tower", Vector3(14.0, 12.0, 10.0), Vector3(38.0, 36.0, 0.0), Color("3a4448"), {"tile": 3.0, "windows": 1.0, "win_y": 33.0, "win_gap": 3.0, "win_pitch": 2.4, "win_rows": 2.0}, 0.86)
	f.canopy(node, "Bridge", 14.0, 11.0, 4.2, Vector3(42.0, 43.0, 0.0), Color("1a4c64"))
	f.block(node, "Crown", Vector3(8.0, 1.2, 6.0), Vector3(38.0, 42.6, 0.0), Color("2a3236"), {"tile": 2.0}, 0.9)
	f.add(node, "Mast", f.tube(0.5, 0.7, 14.0, 10), f.metal(Color("c4ccd0"), 0.3), Vector3(34.0, 49.0, 0.0), Vector3(0.0, 0.0, PI * 0.5))
	f.dish(node, "Radar", 6.0, Vector3(31.0, 46.0, 0.0), Vector3(0.0, 0.0, -PI * 0.5 + 0.45))
	f.lamp(node, "LampKeep", Vector3(40.0, 49.0, 0.0), Color("f0c56a"), 1.3)
	f.add(node, "Vane", f.tube(0.18, 0.18, 18.0, 8), f.metal(Color("c4ccd0"), 0.3), Vector3(34.0, 54.0, 0.0), Vector3(0.0, 0.0, PI * 0.5))
	for side in [1.0, -1.0]:
		var tag := "P" if side > 0.0 else "S"
		f.add(node, "Hangar" + tag, f.plate([Vector2(30.0, 13.0), Vector2(30.0, -13.0), Vector2(-52.0, -13.0), Vector2(-52.0, 13.0)], 14.0, 0.9, 0.98), f.hull(color.darkened(0.06), {"tile": 8.0, "accent": trim, "windows": 1.0, "win_y": 4.0, "win_gap": 3.4, "win_pitch": 4.0, "win_rows": 2.0, "band_x": -40.0, "band_w": 2.0}), Vector3(-11.0, 7.0, 33.0 * side))
		f.block(node, "Bay" + tag, Vector3(1.4, 9.0, 18.0), Vector3(-52.6, 7.0, 33.0 * side), Color("1a2024"), {"tile": 3.0}, 0.9)
		f.strip(node, "BayGlow" + tag, Vector3(0.3, 0.6, 16.0), Vector3(-53.4, 11.0, 33.0 * side), Color("ffb85a"), 2.4)
		f.strip(node, "BayGlowB" + tag, Vector3(0.3, 0.6, 16.0), Vector3(-53.4, 3.4, 33.0 * side), Color("ffb85a"), 2.4)
		f.lamp(node, "Beacon" + tag, Vector3(-52.0, 14.5, 45.0 * side), Color("d4553a") if side > 0.0 else Color("7dcea0"), 1.1)
		f.lamp(node, "Beacon2" + tag, Vector3(28.0, 14.5, 44.0 * side), Color("d4553a") if side > 0.0 else Color("7dcea0"), 1.0)
		f.block(node, "Wall" + tag, Vector3(80.0, 3.0, 1.0), Vector3(-11.0, 15.5, 45.5 * side), color.darkened(0.2), {"tile": 4.0}, 0.9)
		f.block(node, "Neck" + tag, Vector3(60.0, 6.0, 8.0), Vector3(-6.0, 20.0, 21.0 * side), color.darkened(0.1), {"tile": 6.0}, 0.8)
		for k in 6:
			f.add(node, "Rib%s%d" % [tag, k], f.tube(0.5, 0.5, 20.0, 8), f.metal(Color("8a9298"), 0.4), Vector3(-44.0 + float(k) * 14.0, 14.6, 33.0 * side), Vector3(0.0, PI * 0.5, 0.0))
	for i in PADS.size():
		var pad: Vector3 = PADS[i]
		var pad_at := Vector3(pad.x, PAD_HEIGHT - 0.05, pad.z * PAD_BEAM)
		f.add(node, "Pad%d" % i, f.tube(9.0, 9.0, 0.16, 28), f.hull(Color("2c3338"), {"tile": 3.0}), pad_at, Vector3(0.0, 0.0, PI * 0.5))
		f.add(node, "PadRing%d" % i, _ring_mesh(8.1, 8.7), f.glow(Color("ffd27a"), 1.6), pad_at + Vector3(0.0, 0.05, 0.0))
		f.add(node, "PadHub%d" % i, f.tube(6.8, 6.8, 0.2, 28), f.hull(Color("2c3338"), {"tile": 3.0}), pad_at + Vector3(0.0, 0.06, 0.0), Vector3(0.0, 0.0, PI * 0.5))
	f.block(node, "EngineBlock", Vector3(18.0, 22.0, 40.0), Vector3(-82.0, 13.0, 0.0), Color("3a4248"), {"tile": 5.0}, 0.9)
	for side in [1.0, -1.0]:
		var tag := "P" if side > 0.0 else "S"
		f.block(node, "Cowl" + tag, Vector3(22.0, 12.0, 8.0), Vector3(-76.0, 12.0, 18.0 * side), Color("4a525a"), {"tile": 4.0}, 0.8)
		f.block(node, "Radiator" + tag, Vector3(24.0, 14.0, 0.8), Vector3(-44.0, 32.0, 7.0 * side), Color("a8a094"), {"tile": 2.0}, 1.0)
		f.block(node, "RadiatorB" + tag, Vector3(24.0, 14.0, 0.8), Vector3(-44.0, 32.0, 12.0 * side), Color("a8a094"), {"tile": 2.0}, 1.0)
	f.engine(node, "BellMain", Vector3(-90.0, 13.0, 0.0), 7.0, 12.0, Color("8ad8ff"))
	f.engine(node, "BellP", Vector3(-90.0, 13.0, 17.0), 5.6, 10.0, Color("8ad8ff"))
	f.engine(node, "BellS", Vector3(-90.0, 13.0, -17.0), 5.6, 10.0, Color("8ad8ff"))
	f.engine(node, "BellUp", Vector3(-88.0, 24.0, 8.0), 3.0, 6.0, Color("8ad8ff"))
	f.engine(node, "BellUpS", Vector3(-88.0, 24.0, -8.0), 3.0, 6.0, Color("8ad8ff"))
	f.plume(node, "Exhaust", Vector3(-95.0, 13.0, 0.0), 46.0, 6.5, Color(0.55, 0.82, 1.0, 0.5), 0.6)
	f.plume(node, "Exhaust1", Vector3(-93.0, 13.0, 17.0), 36.0, 5.0, Color(0.55, 0.82, 1.0, 0.5), 0.6)
	f.plume(node, "Exhaust2", Vector3(-93.0, 13.0, -17.0), 36.0, 5.0, Color(0.55, 0.82, 1.0, 0.5), 0.6)
	var guns := [
		Vector3(66.0, 21.4, 7.0), Vector3(66.0, 21.4, -7.0), Vector3(14.0, 26.6, 13.0), Vector3(14.0, 26.6, -13.0),
		Vector3(-34.0, 26.6, 12.0), Vector3(-34.0, 26.6, -12.0), Vector3(-66.0, 23.4, 8.0), Vector3(-66.0, 23.4, -8.0),
	]
	for i in guns.size():
		f.turret(node, "Flak%d" % i, guns[i], 2.2, 2, 6.0)
	f.add(node, "Collar", f.tube(7.0, 7.0, 3.0, 24), f.metal(Color("4a525a"), 0.35), Vector3(95.0, 10.0, 0.0))
	f.add(node, "CollarRing", f.tube(7.6, 7.6, 0.6, 24, false), f.glow(Color("8ad8ff"), 1.6), Vector3(96.6, 10.0, 0.0))
	f.lamp(node, "LampNose", Vector3(94.0, 10.0, 0.0), Color("f2e2c4"), 1.0)
	f.lamp(node, "LampStern", Vector3(-96.0, 24.0, 0.0), Color("d4553a"), 1.0)
