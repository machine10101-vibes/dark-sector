extends SceneTree

## Renders the realtime Needle materials to top-down crops. Not a second art style.


func _init() -> void:
	call_deferred("_go")


func _go() -> void:
	var dir := ProjectSettings.globalize_path("res://art/crops")
	DirAccess.make_dir_recursive_absolute(dir)
	await _save("needle_bare.png", [], false)
	await _save("needle_mast.png", ["mast"], false)
	await _save("needle_thrust.png", [], true)
	quit()


func _save(file_name: String, shapes: Array, thrusting: bool) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(512, 512)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var card := NeedleCrop.new()
	card.shapes = shapes
	card.thrusting = thrusting
	vp.add_child(card)
	for _i in 4:
		await process_frame
	var image := vp.get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://art/crops/%s" % file_name)
	var err := image.save_png(path)
	print("crop %s err=%s %dx%d" % [path, err, image.get_width(), image.get_height()])
	vp.queue_free()


class NeedleCrop extends Node2D:
	var shapes: Array = []
	var thrusting := false

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(512, 512)), Color("07080c"), true)
		Silhouette.draw(
			self,
			Vector2(256, 286),
			-PI * 0.5,
			"vesper",
			shapes,
			3.15,
			Color("1f6f73"),
			Color("d7e6c8"),
			1.0,
			thrusting
		)
