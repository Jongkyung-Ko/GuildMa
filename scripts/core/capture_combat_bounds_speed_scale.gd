extends SceneTree

## Evidence: arena clamp + speed button + 80% scale across 844/1280/1366.
## DISPLAY=:1 godot4 --path . --display-driver x11 -s res://scripts/core/capture_combat_bounds_speed_scale.gd

const OUT_RES := "docs/reviews/combat-bounds-speed-scale/captures"
const DEFAULT_STORE := "/cursor/stores/bc-e37588d2-6890-4fb7-945a-c6a1997eb0b9/media/combat-bounds-speed-scale/evidence"

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
	var win := root.get_window()
	for sz in SIZES:
		var target := Vector2i(int(sz["w"]), int(sz["h"]))
		if win:
			win.size = target
			win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		DisplayServer.window_set_size(target)
		CombatFieldBounds.debug_force_vp_size = Vector2(target)
		var ui: Node = root.get_node_or_null("/root/UIStyle")
		if ui and ui.has_method("_apply_display_adapt"):
			ui.call("_apply_display_adapt")
		await process_frame
		if gs:
			gs.new_game()
		await _capture_size(str(sz["tag"]), out_abs, store)

	CombatFieldBounds.debug_force_vp_size = Vector2.ZERO
	print("=== COMBAT BOUNDS/SPEED/SCALE CAPTURE DONE ===")
	quit(0)


func _capture_size(tag: String, out_abs: String, store: String) -> void:
	root.set_meta("hunt_id", "cursed_marsh")
	root.set_meta("combat_hunt_id", "cursed_marsh")
	root.set_meta("hunt_force_new", true)
	root.set_meta("hunt_spawn_at_start", true)
	root.set_meta("dungeon_id", "")
	root.set_meta("special_encounter_id", "")
	var gs: Node = root.get_node_or_null("/root/GameState")
	if gs:
		var map: Dictionary = gs.start_hunt_run("cursed_marsh", true, true)
		var boss_rid := ""
		for rid in map.get("rooms", {}).keys():
			if str(map["rooms"][rid].get("room_type", "")) == "boss":
				boss_rid = str(rid)
				break
		if boss_rid != "":
			map["current_room_id"] = boss_rid
			map["rooms"][boss_rid]["discovered"] = true
			map["rooms"][boss_rid]["cleared"] = false
			var prog: Dictionary = gs.hunt_progress.get("cursed_marsh", {})
			prog["map"] = map
			prog["pending_spawn_at_start"] = false
			gs.hunt_progress["cursed_marsh"] = prog
			gs.active_hunt_id = "cursed_marsh"
	root.set_meta("hunt_force_new", false)
	root.set_meta("hunt_spawn_at_start", false)

	var combat: Node = load("res://scenes/combat/combat.tscn").instantiate()
	# Clear previous scene children that look like combat
	for c in root.get_children():
		if c.name.begins_with("Combat") or (c.get_class() == "Node2D" and c.has_method("get_combat_speed")):
			c.queue_free()
	await process_frame
	root.add_child(combat)
	await process_frame
	await process_frame
	for _i in range(20):
		await process_frame

	await _shot("combat_1x_%s.png" % tag, out_abs, store)
	if combat.has_method("cycle_combat_speed"):
		combat.cycle_combat_speed()  # 2x
	await process_frame
	await _shot("combat_2x_%s.png" % tag, out_abs, store)
	if combat.has_method("cycle_combat_speed"):
		combat.cycle_combat_speed()  # 4x
	for _i in range(25):
		await process_frame
	await _shot("combat_4x_%s.png" % tag, out_abs, store)
	var boss = combat.get_active_boss() if combat.has_method("get_active_boss") else null
	print("SHOT ", tag, " boss=", boss.display_name if boss else "null", " speed=", combat.combat_speed)
	combat.queue_free()
	await process_frame
	if gs and gs.has_method("leave_hunt_session"):
		gs.leave_hunt_session()


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
