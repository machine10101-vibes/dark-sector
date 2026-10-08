extends SceneTree

var fails := 0
var phase := 0
var hud: Node


func _process(_dt: float) -> bool:
	phase += 1
	if phase < 3:
		return false
	if hud == null:
		var game: Node = root.get_node("Game")
		if game.get("sim") == null:
			game.call("begin_new", "kestrel")
		game.set("mode", "sector")
		var sim: Variant = game.get("sim")
		sim.player.cargo["claim_core"] = 1
		sim.player.cargo["nickel_cinder"] = 3
		sim.player.cargo["ice_spall"] = 2
		sim.player.cargo["copper_slag"] = 1
		sim.player.cargo["hull_plate"] = 1
		sim.player.cargo["raw_mass"] = 2
		sim.player.cargo["salvage_parts"] = 1
		hud = load("res://ui/hud.gd").new()
		root.add_child(hud)
		return false
	if phase < 6:
		return false
	_run()
	if fails == 0:
		print("STOCK PASS")
	else:
		print("STOCK FAIL %d" % fails)
	quit(fails)
	return true


func check(cond: bool, message: String) -> void:
	if cond:
		print("ok: %s" % message)
	else:
		fails += 1
		print("FAIL: %s" % message)


func _run() -> void:
	var stock := _find_button(hud, "Stock")
	check(stock != null, "the SHIP row has a Stock button")
	hud.call("_toggle", "stock")
	check(str(hud.get("panel_kind")) == "stock", "Stock opens the inventory")
	var title: Label = hud.get("panel_title")
	check(title != null and title.text == "Inventory", "the panel is named Inventory")
	var box: Node = hud.get("stock_box")
	check(box != null and box.visible, "the inventory box is open")
	var seen: Dictionary = {}
	_collect_stock(box, seen)
	check(seen.get("nickel_cinder", false), "nickel cinder has a 3D card")
	check(seen.get("ice_spall", false), "ice spall has a 3D card")
	check(seen.get("copper_slag", false), "copper slag has a 3D card")
	check(seen.get("hull_plate", false), "hull plate has a 3D card")
	check(seen.get("raw_mass", false), "raw mass has a 3D card")
	check(seen.get("salvage_parts", false), "keel salvage has a 3D card")
	check(not seen.get("claim_core", false), "the claim core stays on the text list")
	var words := _box_text(box)
	check(words.contains("Claim Core"), "the hold still lists the claim core")
	check(words.contains("Nickel cinder") or words.contains("nickel"), "nickel is named in the hold")
	var stage: Node3D = load("res://world/stage3d.gd").new()
	stage.set("portrait_mode", true)
	hud.add_child(stage)
	stage.set_process(false)
	stage.call("ensure_stock_shaders")
	var chunk := MeshInstance3D.new()
	stage.call("dress_stock", chunk, "ice_spall", Color("d5e6f0"), Color("f4fbff"), 11)
	check(chunk.mesh != null, "ice dresses a crystal mesh")
	var rock := MeshInstance3D.new()
	stage.call("dress_stock", rock, "nickel_cinder", Color("c4a06a"), Color("f6c36a"), 7)
	check(rock.mesh != null, "nickel dresses a rock mesh")
	chunk.free()
	rock.free()


func _collect_stock(node: Node, seen: Dictionary) -> void:
	if node.get_script() != null and node.has_method("show_stock"):
		var id := str(node.get("stock_id"))
		if id != "":
			seen[id] = true
	for child in node.get_children():
		_collect_stock(child, seen)


func _box_text(node: Node) -> String:
	var bits: PackedStringArray = PackedStringArray()
	if node is Label:
		bits.append((node as Label).text)
	for child in node.get_children():
		bits.append(_box_text(child))
	return " ".join(bits)


func _find_button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node
	for child in node.get_children():
		var found := _find_button(child, text)
		if found != null:
			return found
	return null
