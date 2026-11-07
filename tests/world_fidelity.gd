extends SceneTree

var fails := 0
var frames := 0


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 3:
		return false
	_run()
	if fails == 0:
		print("WORLD FIDELITY PASS")
	else:
		print("WORLD FIDELITY FAIL %d" % fails)
	quit(fails)
	return true


func _run() -> void:
	var scr: Script = load("res://world/stage3d.gd")
	if scr == null or scr.can_instantiate() == false:
		print("FAIL: stage3d did not parse")
		fails += 1
		return
	var stage: Node = scr.new()
	stage.call("_ready")
	var rock: ArrayMesh = stage.call("_rock_mesh", 4, 12.0)
	var box: AABB = rock.get_aabb()
	check(box.size.x > 6.0 and box.size.y > 6.0 and box.size.z > 6.0, "a rock volume has thickness on every axis")
	check(box.size.y > box.size.x * 0.35, "a rock is not a flat card")
	check(rock.get_faces().size() > 500, "rubble is a cluster of stones")
	var ring: Shader = stage.get("_ring_shader")
	var star: Shader = stage.get("_star_shader")
	var corona: Shader = stage.get("_corona_shader")
	var rays: Shader = stage.get("_ray_shader")
	var planet: Shader = stage.get("_planet_shader")
	check(ring != null and ring.code.find("TIME") >= 0 and ring.code.find("glitter") >= 0, "ice ring glitter moves")
	check(star != null and star.code.find("grain") >= 0, "the star keeps surface grain")
	check(corona != null and corona.code.find("fbm") < 0 and corona.code.find("spoke") < 0, "the corona glow is a smooth halo")
	check(rays != null and rays.code.find("spoke") >= 0 and rays.code.find("UV") >= 0, "corona spokes are a card past the halo")
	var pile: ArrayMesh = stage.call("_rubble_mesh", 3, 20.0)
	var pile_box: AABB = pile.get_aabb()
	var rubble: Shader = stage.get("_rubble_shader")
	check(pile_box.size.x > 28.0 and pile_box.size.y > 16.0 and pile_box.size.z > 16.0, "seized rubble is a lifted cluster")
	check(rubble != null and rubble.code.find("unshaded") >= 0, "rubble stays lit without the sun")
	check(planet != null and planet.code.find("VERTEX +=") >= 0 and planet.code.find("night_side") >= 0 and planet.code.find("blob") >= 0, "night-side city lamps are blobs on the limb")
	var hull: Shader = stage.get("_hull_shader")
	check(hull != null and hull.code.find("plate_gutter") >= 0 and hull.code.find("albedo.rgb") >= 0 and hull.code.find("plate_heat") >= 0, "plate gutters darken the seams, heat glows on top, and the paint stays the hull color")
	check(absf(float(stage.call("_plate_heat", {"therm": 0.0})) ) < 0.001, "a cold keel leaves the plate dark")
	check(absf(float(stage.call("_plate_heat", {"therm": 80.0})) - 0.8) < 0.001, "gun heat warms the plate")
	check(float(stage.call("_plate_heat", {"therm": 40.0, "overheat": true})) >= 0.85, "held guns keep the plate hot")
	var slide := {"rot": 0.0, "vel": Vector2(0.0, 160.0)}
	check(float(stage.call("_slip_cant", slide)) > 0.5, "a sideways slide cants the plume")
	check(absf(float(stage.call("_slip_cant", {"rot": 0.0, "vel": Vector2(160.0, 0.0)}))) < 0.001, "thrust along the nose leaves the plume centered")
	var yaw_hull := Node3D.new()
	stage.call("_fill_ship", yaw_hull, "vesper", [], [])
	stage.call("_set_plate_heat", yaw_hull, 0.8)
	var keel := yaw_hull.get_node_or_null("Keel") as MeshInstance3D
	var skin: ShaderMaterial = null
	if keel != null:
		skin = keel.material_override as ShaderMaterial
	check(skin != null and absf(float(skin.get_shader_parameter("plate_heat")) - 0.8) < 0.001, "the keel skin takes the plate heat")
	stage.call("_place_plumes", yaw_hull, {"yaw_hold": 1.0, "rot": 0.0, "vel": Vector2.ZERO, "thrusting": false, "boosting": false, "strafe_hold": 0.0, "retro_hold": false})
	var stbd := yaw_hull.get_node_or_null("JetStbd") as MeshInstance3D
	var port := yaw_hull.get_node_or_null("JetPort") as MeshInstance3D
	check(stbd != null and stbd.visible, "a positive yaw lights the starboard jet")
	check(port != null and not port.visible, "a positive yaw leaves the port jet dark")
	var vent := Node3D.new()
	stage.call("_fill_ship", vent, "vesper", ["vent"], [])
	check(vent.get_node_or_null("Gearvent0/VentFin") != null, "Ash Vent wears a flank fin")
	root.add_child(stage)
	var cold := {"layer": 0, "star_radius": 40.0, "local_origin": Vector2.ZERO, "defs": {"system": {"star": {"color": "#3a6cff", "name": "Cold"}}}}
	var warm := {"layer": 0, "star_radius": 40.0, "local_origin": Vector2.ZERO, "defs": {"system": {"star": {"color": "#ff8844", "name": "Warm"}}}}
	stage.call("_sync_star", cold)
	var cold_light: Color = stage.get("_sun").light_color
	stage.call("_sync_star", warm)
	var warm_light: Color = stage.get("_sun").light_color
	check(cold_light.b > warm_light.b + 0.05, "a blue star cools the key light on the plate")
	check(warm_light.r > cold_light.r + 0.05, "an amber star warms the key light on the plate")
	for class_id in ["vesper", "anvil", "kestrel"]:
		var holder := Node3D.new()
		stage.call("_fill_ship", holder, class_id, ["mast", "blister", "sponson", "probes"], [])
		check(holder.get_node_or_null("Keel") != null, "%s wears a rounded keel" % class_id)
		check(holder.get_node_or_null("Panel0") != null, "%s wears deck plates" % class_id)
		check(holder.get_node_or_null("MountMast") != null, "%s still wears the mast" % class_id)
		check(holder.get_node_or_null("MountBay") != null, "%s still wears the bay" % class_id)
		check(holder.get_node_or_null("MountGunP") != null, "%s still wears the gun" % class_id)
		check(holder.get_node_or_null("MountProbe") != null, "%s still wears the probe" % class_id)
	check(holder_part(stage, "vesper", "VaneP"), "Needle wears spine vanes")
	check(holder_part(stage, "anvil", "RibP"), "Barn wears flank ribs")
	check(holder_part(stage, "kestrel", "CheekP"), "Beak wears cheek fairings")
	check(holder_part(stage, "lumen", "LampHeart"), "Wick wears a lamp crown")
	check(holder_part(stage, "casque", "RamPlow"), "Ram wears a plow")
	check(holder_part(stage, "alidade", "SkyDome"), "Kite wears a survey eye")
	check(holder_part(stage, "vesper", "HeatTile0"), "Needle wears heat tiles")
	check(holder_part(stage, "vesper", "DockRing"), "Needle wears a dock ring")
	check(holder_part(stage, "anvil", "HeatTile0"), "Barn wears heat tiles")
	check(holder_part(stage, "kestrel", "DockRing"), "Beak wears a dock ring")
	check(holder_part(stage, "vesper", "Armor0"), "Needle wears layered armor")
	check(holder_part(stage, "vesper", "Greeble0"), "Needle wears hull greebles")
	check(holder_part(stage, "vesper", "Access0"), "Needle wears access hatches")
	check(holder_part(stage, "vesper", "SensorArray"), "Needle wears a sensor array")
	check(holder_part(stage, "vesper", "Tank0"), "Needle wears cylindrical tanks")
	check(holder_part(stage, "anvil", "Armor0"), "Barn wears layered armor")
	check(holder_part(stage, "anvil", "CargoMod0"), "Barn wears cargo modules")
	check(holder_part(stage, "anvil", "LoadHatch"), "Barn wears a loading hatch")
	check(holder_part(stage, "kestrel", "Armor0"), "Beak wears layered armor")
	check(holder_part(stage, "kestrel", "CombatPlate0"), "Beak wears combat plates")
	check(holder_part(stage, "casque", "CombatPlate0"), "Ram wears combat plates")
	check(holder_part(stage, "kestrel", "Beam0"), "Beak wears exposed beams")
	check(holder_part(stage, "kestrel", "SensorDome"), "Beak wears a sensor dome")
	check(holder_part(stage, "kestrel", "Hardpoint0"), "Beak wears hardpoints")
	check(holder_part(stage, "kestrel", "ThrusterShroud"), "Beak wears a thruster shroud")
	check(holder_part(stage, "kestrel", "CheekArmorP"), "Beak wears angular cheek armor")
	check(holder_part(stage, "vesper", "Beam0"), "Needle wears exposed beams")
	check(holder_part(stage, "vesper", "SensorDome"), "Needle wears a sensor dome")
	check(holder_part(stage, "anvil", "Hardpoint0"), "Barn wears hardpoints")
	check(holder_part(stage, "anvil", "SensorRing"), "Barn wears a sensor ring")
	check(holder_part(stage, "anvil", "BayPlate0"), "Barn wears modular bay plates")
	check(holder_part(stage, "anvil", "RibFrame0"), "Barn wears structural rib frames")
	check(holder_part(stage, "anvil", "SideHatchP"), "Barn wears a side loading hatch")
	check(holder_part(stage, "anvil", "HatchFrame"), "Barn wears a hatch frame")
	check(holder_part(stage, "anvil", "Gantry"), "Barn wears a cargo gantry")
	check(holder_part(stage, "anvil", "HaulBell0"), "Barn wears extra haul bells")
	check(holder_part(stage, "vesper", "SensorRing"), "Needle wears a sensor ring")
	check(holder_part(stage, "kestrel", "BayPlate0"), "Beak wears modular bay plates")


func holder_part(stage: Node, class_id: String, part_name: String) -> bool:
	var holder := Node3D.new()
	stage.call("_fill_ship", holder, class_id, [], [])
	return holder.get_node_or_null(part_name) != null


func check(cond: bool, message: String) -> void:
	if cond:
		print("ok: %s" % message)
	else:
		fails += 1
		print("FAIL: %s" % message)
