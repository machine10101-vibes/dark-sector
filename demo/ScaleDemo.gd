extends Node2D

## Parking orbit 420 km above Aegis Prime. Origin starts on the ship
## so render is near 0. Buoys every 5 km make a rebase visible.


func _ready() -> void:
	var gate: Variant = WorldCoord.gate()
	var center := Vector2(12000000.0, 0.0)
	var park := center + Vector2(6371000.0 + 420000.0, 0.0)
	if gate != null:
		gate.origin_m = park
		gate.system_id = "HC-V1-R1-S1"
		gate.body_id = "aegis_prime"
		gate.layer = WorldCoord.BAND
		gate.origin_id = "aegis_orbital_band"
		gate.rebase_count = 0
		gate.settle_left = 0.0
		gate.armed = true

	var limb := PlanetLimb2D.new()
	limb.name = "AegisLimb"
	limb.world_center_m = center
	limb.radius_m = 6371000.0
	limb.atmo_m = 80000.0
	add_child(limb)

	var ship := HelmShip2D.new()
	ship.name = "Vesper"
	ship.world_m = park
	add_child(ship)
	ship.snap_to_world()
	if gate != null:
		gate.set_focus(ship)

	# Outbound buoys. 5 km spacing, far enough that an 8 km rebase jumps them.
	for step in 9:
		var buoy := _Buoy.new()
		buoy.name = "Buoy%d" % step
		buoy.world_m = park + Vector2(float(step + 1) * 5000.0, 0.0)
		add_child(buoy)
		buoy.snap_to_world()
	for step in 4:
		var cross := _Buoy.new()
		cross.name = "Cross%d" % step
		cross.world_m = park + Vector2(0.0, float(step + 1) * 5000.0)
		add_child(cross)
		cross.snap_to_world()

	var cam := RebasingCamera2D.new()
	cam.name = "Eye"
	cam.follow = ship
	# 5 km buoys sit on the glass. Aegis, 420 km down, stays a limb.
	cam.zoom = Vector2(0.09, 0.09)
	add_child(cam)

	var hud := preload("res://ui/OriginDebugHUD.gd").new()
	hud.name = "OriginDebug"
	add_child(hud)


class _Buoy extends RebasingBody2D:
	func _draw() -> void:
		draw_circle(Vector2.ZERO, 90.0, Color(0.95, 0.78, 0.32, 0.95))
		draw_arc(Vector2.ZERO, 220.0, 0.0, TAU, 20, Color(0.95, 0.78, 0.32, 0.8), 18.0, true)
