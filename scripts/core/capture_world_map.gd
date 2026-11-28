extends SceneTree

## Full-screen world map evidence captures (X11 display required).
## DISPLAY=:1 godot4 --path . --display-driver x11 -s res://scripts/core/capture_world_map.gd
##
## Writes to OUT_DIR (repo) and optionally STORE_DIR (project store evidence).

const OUT_DIR := "docs/reviews/worldmap-bgm/captures"
const ART := "/opt/cursor/artifacts/worldmap-bgm"
const SIZES := [
	{"tag": "844x390", "size": Vector2i(844, 390)},
	{"tag": "1366x768", "size": Vector2i(1366, 768)},
	{"tag": "1280x720", "size": Vector2i(1280, 720)},
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var ds := str(DisplayServer.get_name())
	print("=== WORLD MAP CAPTURE === DisplayServer=", ds)
	if ds == "headless":
		printerr("ABORT: headless — need real display for evidence PNGs")
		quit(2)
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + OUT_DIR))
	DirAccess.make_dir_recursive_absolute(ART)
	var store := OS.get_environment("STORE_DIR")
	if store != "":
		DirAccess.make_dir_recursive_absolute(store)

	var gs: Node = root.get_node("/root/GameState")
	var sr: Node = root.get_node("/root/SceneRouter")
	gs.new_game()

	# Town with WORLD MAP button visible
	for spec in SIZES:
		await _resize(spec["size"])
		sr.go_town()
		await _settle()
		await _shot("town_with_map_btn_%s.png" % spec["tag"], store)

	# World map main + selected castle
	for spec in SIZES:
		await _resize(spec["size"])
		sr.go_world_map()
		await _settle()
		await _shot("world_map_main_%s.png" % spec["tag"], store)
		var scene := root.get_child(root.get_child_count() - 1)
		# Current scene is under root after change_scene; find WorldMap control.
		var wm := _find_world_map()
		if wm and wm.has_method("_select_marker"):
			wm.call("_select_marker", "icecrown")
			await _settle()
			await _shot("world_map_icecrown_%s.png" % spec["tag"], store)
			wm.call("_select_marker", "abysscal")
			await _settle()
			await _shot("world_map_abysscal_%s.png" % spec["tag"], store)

	# Return to town (start town preserved)
	await _resize(Vector2i(1280, 720))
	sr.go_town()
	await _settle()
	await _shot("town_after_world_map_1280x720.png", store)

	print("=== WORLD MAP CAPTURE DONE ===")
	quit(0)


func _find_world_map() -> Node:
	var current := root.get_tree().current_scene
	if current and str(current.name).begins_with("WorldMap"):
		return current
	# Fallback walk
	for c in root.get_children():
		if c is Control and c.has_method("_select_marker"):
			return c
	return null


func _resize(sz: Vector2i) -> void:
	var win := root.get_window()
	if win:
		win.size = sz
	await process_frame
	await process_frame


func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame
	await create_timer(0.15).timeout


func _shot(name: String, store: String) -> void:
	await process_frame
	await process_frame
	var tex: ViewportTexture = root.get_viewport().get_texture()
	if tex == null:
		printerr("FAIL no tex ", name)
		return
	var img: Image = tex.get_image()
	if img == null or img.get_width() < 8:
		printerr("FAIL empty image ", name)
		return
	var repo_path := ProjectSettings.globalize_path("res://" + OUT_DIR + "/" + name)
	img.save_png(repo_path)
	img.save_png(ART.path_join(name))
	if store != "":
		img.save_png(store.path_join(name))
	print("SHOT ", name, " ", img.get_width(), "x", img.get_height())
