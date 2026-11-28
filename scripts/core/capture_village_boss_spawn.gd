extends SceneTree

## Evidence: world map Elderwood expedition + Gorgon boss fight.
## DISPLAY=:1 godot4 --path . --display-driver x11 -s res://scripts/core/capture_village_boss_spawn.gd

const OUT_RES := "docs/reviews/village-boss-spawn/captures"
const DEFAULT_STORE := "/cursor/stores/bc-e37588d2-6890-4fb7-945a-c6a1997eb0b9/media/village-boss-spawn/evidence"

const SIZES := [
	{"tag": "844x390", "w": 844, "h": 390},
	{"tag": "1280x720", "w": 1280, "h": 720},
	{"tag": "1366x768", "w": 1366, "h": 768},
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if str(DisplayServer.get_name()) == "headless":
		printerr("ABORT: headless")
		quit(2)
		return
	var store := OS.get_environment("STORE_DIR")
	if store == "":
		store = DEFAULT_STORE
	var out_abs := ProjectSettings.globalize_path("res://" + OUT_RES)
	DirAccess.make_dir_recursive_absolute(out_abs)
	DirAccess.make_dir_recursive_absolute(store)

	var gs: Node = root.get_node_or_null("/root/GameState")
	var sr: Node = root.get_node_or_null("/root/SceneRouter")
	if gs == null or sr == null:
		printerr("ABORT: autoloads missing")
		quit(2)
		return

	var win := root.get_window()
	for sz in SIZES:
		var target := Vector2i(int(sz["w"]), int(sz["h"]))
		if win:
			win.size = target
			win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
			win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
		DisplayServer.window_set_size(target)
		var ui: Node = root.get_node_or_null("/root/UIStyle")
		if ui and ui.has_method("_apply_display_adapt"):
			ui.call("_apply_display_adapt")
		await process_frame
		await process_frame
		gs.new_game()
		await _capture_size(gs, sr, str(sz["tag"]), out_abs, store)

	print("=== VILLAGE BOSS CAPTURE DONE ===")
	quit(0)


func _capture_size(gs: Node, sr: Node, tag: String, out_abs: String, store: String) -> void:
	# Town → world map → Elderwood selected
	sr.go_town()
	await process_frame
	await process_frame
	await _shot("town_%s.png" % tag, out_abs, store)

	sr.go_world_map()
	await process_frame
	await process_frame
	await process_frame
	var wm := _find_world_map()
	if wm and wm.has_method("_select_marker"):
		wm.call("_select_marker", "elderwood")
	await process_frame
	await _shot("world_map_elderwood_%s.png" % tag, out_abs, store)

	# Jump to Gorgon boss room combat (same path as expedition hunt)
	var hunt_id := "cursed_marsh"
	root.set_meta("village_id", "elderwood")
	root.set_meta("village_boss_id", "gorgon")
	root.set_meta("hunt_id", hunt_id)
	root.set_meta("combat_hunt_id", hunt_id)
	root.set_meta("hunt_force_new", true)
	root.set_meta("hunt_spawn_at_start", true)
	var map: Dictionary = gs.start_hunt_run(hunt_id, true, true)
	var boss_rid := ""
	for rid in map.get("rooms", {}).keys():
		if str(map["rooms"][rid].get("room_type", "")) == "boss":
			boss_rid = str(rid)
			break
	if boss_rid != "":
		map["current_room_id"] = boss_rid
		map["rooms"][boss_rid]["discovered"] = true
		map["rooms"][boss_rid]["cleared"] = false
		var prog: Dictionary = gs.hunt_progress.get(hunt_id, {})
		prog["map"] = map
		prog["pending_spawn_at_start"] = false
		gs.hunt_progress[hunt_id] = prog
		gs.active_hunt_id = hunt_id
	root.set_meta("hunt_force_new", false)
	root.set_meta("hunt_spawn_at_start", false)

	var combat: Node = load("res://scenes/combat/combat.tscn").instantiate()
	# Replace current scene content carefully: add combat as root child after freeing map.
	var current := root.get_child(root.get_child_count() - 1)
	# SceneRouter changed scene — find current scene
	var scene := get_current_scene_safe()
	if scene:
		scene.queue_free()
		await process_frame
	root.add_child(combat)
	await process_frame
	await process_frame
	var t := 0.0
	while t < 1.0:
		await process_frame
		t += 1.0 / 60.0
	await _shot("gorgon_boss_%s.png" % tag, out_abs, store)
	var boss = combat.get_active_boss() if combat.has_method("get_active_boss") else null
	print("SHOT gorgon_", tag, " boss=", boss.display_name if boss else "null")
	combat.queue_free()
	await process_frame
	gs.leave_hunt_session()
	sr.go_town()
	await process_frame


func get_current_scene_safe() -> Node:
	var cs := get_current_scene()
	return cs


func _find_world_map() -> Node:
	var cs := get_current_scene()
	if cs and cs.has_method("_select_marker"):
		return cs
	return root.find_child("WorldMap*", true, false)


func _shot(filename: String, out_abs: String, store: String) -> void:
	RenderingServer.force_draw(true)
	await process_frame
	await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	if img == null or img.get_width() < 2:
		printerr("FAIL null ", filename)
		return
	img.save_png("%s/%s" % [out_abs, filename])
	img.save_png("%s/%s" % [store, filename])
	print("WROTE ", store, "/", filename, " ", img.get_width(), "x", img.get_height())
