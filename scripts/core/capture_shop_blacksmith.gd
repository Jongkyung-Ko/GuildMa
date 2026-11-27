extends SceneTree

## Capture shop + blacksmith at 844×390 and 1366×768.
## DISPLAY=:1 godot4 --path . --display-driver x11 -s res://scripts/core/capture_shop_blacksmith.gd
## Optional: STORE_DIR=/cursor/stores/.../media/shop-blacksmith OUT_DIR=...

const SIZES := [
	{"tag": "landscape_844x390", "size": Vector2i(844, 390)},
	{"tag": "pc_1366x768", "size": Vector2i(1366, 768)},
]

var _out_dir: String = "res://docs/reviews/shop-blacksmith/captures"
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
	DirAccess.make_dir_recursive_absolute(_resolve_user_path(_out_dir))
	if _store_dir != "":
		DirAccess.make_dir_recursive_absolute(_store_dir)

	var gs: Node = root.get_node("/root/GameState")
	gs.new_game()
	# Seed inventory for richer screenshots.
	gs.buy_item("sword_basic", 1)
	gs.buy_item("armor_leather", 1)
	gs.buy_item("potion_hp_s", 2)
	gs.add_item("enhance_stone", 5)
	# Force a +1 sword for blacksmith selection chrome.
	if gs.inventory_qty("sword_basic", 0) > 0:
		gs.remove_item("sword_basic", 1, 0)
		gs.add_item("sword_basic", 1, 1)

	var win := root.get_window()
	for spec in SIZES:
		var tag: String = spec["tag"]
		var sz: Vector2i = spec["size"]
		win.size = sz
		await process_frame
		await process_frame

		await _capture_facility("shop", "%s_shop_main" % tag)
		# Select first grid item by simulating state — UI selection is visual;
		# buy a second item then reopen for "detail" feel is optional.
		await _capture_facility("blacksmith", "%s_blacksmith_main" % tag)
		await _capture_facility("warehouse", "%s_warehouse" % tag)

	print("=== capture_shop_blacksmith done fails=%d ===" % _failed)
	quit(0 if _failed == 0 else 1)


func _capture_facility(fid: String, name: String) -> void:
	root.set_meta("facility_id", fid)
	var err := change_scene_to_file("res://scenes/facilities/facility.tscn")
	if err != OK:
		_fail("scene %s" % fid)
		return
	await process_frame
	await process_frame
	await process_frame
	await _capture(name)


func _capture(name: String) -> void:
	await process_frame
	var img: Image = root.get_texture().get_image()
	if img == null or img.get_width() < 2:
		_fail("null image %s" % name)
		return
	var path := _resolve_user_path(_out_dir).path_join("%s.png" % name)
	var err := img.save_png(path)
	if err != OK:
		_fail("save %s err=%s" % [path, err])
		return
	print("WROTE ", path)
	if _store_dir != "":
		var store_path := _store_dir.path_join("%s.png" % name)
		img.save_png(store_path)
		print("WROTE ", store_path)


func _resolve_user_path(p: String) -> String:
	if p.begins_with("res://"):
		return ProjectSettings.globalize_path(p)
	return p
