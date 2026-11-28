extends SceneTree

## UI quality polish evidence — shop / guild / backgrounds / non-combat chars.
## DISPLAY=:1 godot4 --path . --display-driver x11 -s res://scripts/core/capture_ui_quality_polish.gd
## STORE_DIR=/cursor/stores/.../media/ui-quality-polish/evidence

const SIZES := [
	{"tag": "844x390", "size": Vector2i(844, 390)},
	{"tag": "1280x720", "size": Vector2i(1280, 720)},
	{"tag": "1366x768", "size": Vector2i(1366, 768)},
]

var _out_dir: String = "res://docs/reviews/ui-quality-polish/evidence"
var _store_dir: String = ""
var _failed := 0


func _init() -> void:
	call_deferred("_run")


func _fail(msg: String) -> void:
	printerr("FAIL: ", msg)
	_failed += 1


func _run() -> void:
	var env_out := OS.get_environment("OUT_DIR")
	if env_out != "":
		_out_dir = env_out
	_store_dir = OS.get_environment("STORE_DIR")
	DirAccess.make_dir_recursive_absolute(_resolve(_out_dir))
	if _store_dir != "":
		DirAccess.make_dir_recursive_absolute(_store_dir)

	var gs: Node = root.get_node("/root/GameState")
	gs.call("new_game")
	gs.call("buy_item", "sword_basic", 1)
	gs.call("buy_item", "armor_leather", 1)
	gs.call("buy_item", "potion_hp_s", 2)

	var win := root.get_window()
	for spec in SIZES:
		var tag: String = spec["tag"]
		var sz: Vector2i = spec["size"]
		win.size = sz
		await process_frame
		await process_frame
		await process_frame

		await _goto_facility("shop")
		await _settle()
		await _capture("shop_main_%s" % tag)
		# Hover/select path — selection chrome must not rebuild the grid.
		await _select_first_shop_card()
		await _settle()
		await _capture("shop_selected_%s" % tag)

		await _goto_facility("guild")
		await _settle()
		await _capture("facility_guild_%s" % tag)

		await _goto_scene("res://scenes/facilities/guild_hall.tscn")
		await _settle()
		await _capture("guild_hall_%s" % tag)

		await _goto_scene("res://scenes/town/town.tscn")
		await _settle()
		await _capture("town_bg_%s" % tag)

		await _goto_scene("res://scenes/title/title.tscn")
		await _settle()
		await _capture("title_bg_%s" % tag)

	print("=== capture_ui_quality_polish done fails=%d ===" % _failed)
	quit(0 if _failed == 0 else 1)


func _goto_facility(fid: String) -> void:
	root.set_meta("facility_id", fid)
	var err := change_scene_to_file("res://scenes/facilities/facility.tscn")
	if err != OK:
		_fail("facility scene %s err=%s" % [fid, err])


func _goto_scene(path: String) -> void:
	var err := change_scene_to_file(path)
	if err != OK:
		_fail("scene %s err=%s" % [path, err])


func _settle() -> void:
	for _i in 5:
		await process_frame


func _select_first_shop_card() -> void:
	var shop := _find_shop_root(root)
	if shop == null:
		_fail("shop root missing for select")
		return
	if shop.has_method("_select_item"):
		var gs: Node = root.get_node_or_null("/root/GameState")
		var list: Array = []
		if gs and gs.has_method("items_by_category"):
			list = gs.call("items_by_category", "weapon")
		if list.size() > 0:
			shop.call("_select_item", str(list[0].get("id", "")), 0, true)
			return
	# Fallback: click first Button under grid.
	var grid := _find_named(shop, "GridContainer")
	if grid:
		for c in grid.get_children():
			if c is Button:
				(c as Button).emit_signal("pressed")
				return


func _find_shop_root(n: Node) -> Node:
	if n.get_script() != null and str(n.get_script().resource_path).ends_with("shop_panel.gd"):
		return n
	# ShopPanelRoot is an inner class — match by presence of catalog helpers.
	if n.has_method("_catalog_fingerprint") and n.has_method("_patch_selection_chrome"):
		return n
	for c in n.get_children():
		var found := _find_shop_root(c)
		if found:
			return found
	return null


func _find_named(n: Node, type_name: String) -> Node:
	if n.get_class() == type_name:
		return n
	for c in n.get_children():
		var found := _find_named(c, type_name)
		if found:
			return found
	return null


func _capture(name: String) -> void:
	await process_frame
	var img: Image = root.get_texture().get_image()
	if img == null or img.get_width() < 2:
		_fail("null image %s" % name)
		return
	var path := _resolve(_out_dir).path_join("%s.png" % name)
	var err := img.save_png(path)
	if err != OK:
		_fail("save %s err=%s" % [path, err])
		return
	print("WROTE ", path)
	if _store_dir != "":
		var store_path := _store_dir.path_join("%s.png" % name)
		img.save_png(store_path)
		print("WROTE ", store_path)


func _resolve(p: String) -> String:
	if p.begins_with("res://"):
		return ProjectSettings.globalize_path(p)
	return p
