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
		sim.player.cargo["glasswheat"] = 2
		sim.player.cargo["dock_crate"] = 1
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
	check(seen.get("claim_core", false), "the claim core has a 3D card")
	check(seen.get("glasswheat", false), "glasswheat has a 3D card")
	check(seen.get("dock_crate", false), "the dock crate has a 3D card")
	var words := _box_text(box)
	check(words.contains("Claim Core"), "the hold still names the claim core")
	check(words.contains("Nickel cinder") or words.contains("nickel"), "nickel is named in the hold")
	var grid := _first_grid(box)
	check(grid != null and int(grid.columns) >= 3, "the hold is a grid")
	check(grid.get_child_count() >= 9, "the hold pads empty squares")
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
	var core := MeshInstance3D.new()
	stage.call("dress_stock", core, "claim_core", Color("4ec8d8"), Color("3cf0ff"), 5)
	check(core.mesh != null, "a claim core dresses a crystal")
	var crate := MeshInstance3D.new()
	stage.call("dress_stock", crate, "dock_crate", Color("8a6a3c"), Color("d4b078"), 9)
	check(crate.mesh != null, "a dock crate dresses a box")
	var wheat := MeshInstance3D.new()
	stage.call("dress_stock", wheat, "glasswheat", Color("c4a24a"), Color("f0e08a"), 13)
	check(wheat.mesh != null, "glasswheat dresses a sheaf")
	var wing: Node3D = stage.call("pose_craft", "fighter")
	check(wing != null and wing.get_child_count() > 0, "a fighter poses as a 3D hull")
	var probe: Node3D = stage.call("pose_craft", "survey_probe")
	check(probe != null and probe.get_child_count() > 0, "a probe poses as a 3D hull")
	chunk.free()
	rock.free()
	core.free()
	crate.free()
	wheat.free()
	if wing != null:
		wing.free()
	if probe != null:
		probe.free()
	hud.call("_toggle", "fleet")
	check(str(hud.get("panel_kind")) == "fleet", "Fleet opens the wing")
	var fleet: Node = hud.get("fleet_box")
	check(fleet != null and fleet.visible, "the fleet box is open")
	var ships: Dictionary = {}
	_collect_craft(fleet, ships)
	check(ships.get("fighter", false), "the fighter has a 3D card")
	check(ships.get("survey_probe", false), "the probe has a 3D card")
	var fleet_grid := _first_grid(fleet)
	check(fleet_grid != null and int(fleet_grid.columns) >= 3, "the rack is a grid")
	hud.call("_toggle", "market")
	check(str(hud.get("panel_kind")) == "market", "Market opens the exchange")
	var market: Node = hud.get("market_box")
	check(market != null and market.visible, "the exchange box is open")
	var words2 := _box_text(market)
	check(words2.contains("COLLECT") or words2.contains("waiting"), "the desk has a Collect box")
	check(words2.contains("SLOT") or words2.contains("Slot") or words2.contains("Empty"), "the desk still has slots")
	hud.call("_open_buy")
	var catalog: Dictionary = {}
	_collect_stock(market, catalog)
	check(catalog.get("nickel_cinder", false), "buy shows a 3D nickel")
	check(catalog.get("ice_spall", false), "buy shows a 3D ice")
	check(catalog.get("glasswheat", false), "buy shows a 3D glasswheat")
	hud.call("_set_market_page", "tape")
	check(str(hud.get("market_page")) == "tape", "Last opens the tape")
	hud.call("_set_market_page", "yard")
	var yard: Dictionary = {}
	_collect_stock(market, yard)
	check(yard.get("glasswheat", false), "the yard shows 3D glasswheat")
	check(yard.get("nickel_cinder", false), "the yard shows 3D nickel")


func _collect_stock(node: Node, seen: Dictionary) -> void:
	if node.get_script() != null and node.has_method("show_stock"):
		var id := str(node.get("stock_id"))
		if id != "":
			seen[id] = true
	for child in node.get_children():
		_collect_stock(child, seen)


func _collect_craft(node: Node, seen: Dictionary) -> void:
	if node.get_script() != null and node.has_method("show_craft"):
		var kind := str(node.get("craft_kind"))
		if kind != "":
			seen[kind] = true
	for child in node.get_children():
		_collect_craft(child, seen)


func _first_grid(node: Node) -> GridContainer:
	if node is GridContainer:
		return node
	for child in node.get_children():
		var found := _first_grid(child)
		if found != null:
			return found
	return null


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
