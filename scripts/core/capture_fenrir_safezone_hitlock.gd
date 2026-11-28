extends SceneTree

## Evidence for safe-zone (no top relax) + hit-lock polish.
## Real display required.
##
##   DISPLAY=:1 godot4 --path . --display-driver x11 -s res://scripts/core/capture_fenrir_safezone_hitlock.gd

const OUT_RES := "docs/reviews/boss-assets/fenrir-safezone-hitlock"
const DEFAULT_STORE := "/cursor/stores/bc-e37588d2-6890-4fb7-945a-c6a1997eb0b9/media/boss-assets/evidence/fenrir-safezone-hitlock"

const SIZES := [
	{"tag": "844x390", "w": 844, "h": 390},
	{"tag": "1366x768", "w": 1366, "h": 768},
	{"tag": "1280x720", "w": 1280, "h": 720},
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var ds := str(DisplayServer.get_name())
	print("=== FENRIR SAFEZONE + HITLOCK CAPTURE ===")
	print("DisplayServer: ", ds)
	if ds == "headless":
		printerr("ABORT: headless — refuse visual capture")
		quit(2)
		return

	var store := OS.get_environment("STORE_DIR")
	if store == "":
		store = DEFAULT_STORE
	var out_abs := ProjectSettings.globalize_path("res://" + OUT_RES)
	DirAccess.make_dir_recursive_absolute(out_abs)
	DirAccess.make_dir_recursive_absolute(store)

	var gs: Node = root.get_node_or_null("/root/GameState")
	if gs == null:
		printerr("ABORT: GameState missing")
		quit(2)
		return

	var win := root.get_window()
	for sz in SIZES:
		var target := Vector2i(int(sz["w"]), int(sz["h"]))
		if win:
			win.size = target
			win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
			win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
			win.content_scale_factor = 1.0
		DisplayServer.window_set_size(target)
		var ui: Node = root.get_node_or_null("/root/UIStyle")
		if ui and ui.has_method("_apply_display_adapt"):
			ui.call("_apply_display_adapt")
		await process_frame
		await process_frame
		await process_frame
		gs.new_game()
		await _capture_size(gs, str(sz["tag"]), out_abs, store)

	print("=== CAPTURE DONE === store=", store)
	quit(0)


func _capture_size(gs: Node, size_tag: String, out_abs: String, store: String) -> void:
	root.set_meta("hunt_id", "beginner_forest")
	root.set_meta("combat_hunt_id", "beginner_forest")
	root.set_meta("dungeon_id", "")
	root.set_meta("special_encounter_id", "")
	root.set_meta("hunt_force_new", true)
	root.set_meta("hunt_spawn_at_start", true)

	var map: Dictionary = gs.start_hunt_run("beginner_forest", true, true)
	var boss_rid := ""
	for rid in map.get("rooms", {}).keys():
		var room: Dictionary = map["rooms"][rid]
		if str(room.get("room_type", "")) == "boss":
			boss_rid = str(rid)
			break
	if boss_rid != "":
		map["current_room_id"] = boss_rid
		map["rooms"][boss_rid]["discovered"] = true
		map["rooms"][boss_rid]["cleared"] = false
		var prog: Dictionary = gs.hunt_progress.get("beginner_forest", {})
		prog["map"] = map
		prog["pending_spawn_at_start"] = false
		gs.hunt_progress["beginner_forest"] = prog
		gs.active_hunt_id = "beginner_forest"
	root.set_meta("hunt_force_new", false)
	root.set_meta("hunt_spawn_at_start", false)

	var combat: Node = load("res://scenes/combat/combat.tscn").instantiate()
	root.add_child(combat)
	await process_frame
	await process_frame
	await process_frame

	var boss = combat.get_active_boss() if combat.has_method("get_active_boss") else null
	if boss == null:
		printerr("WARN: no Fenrir for ", size_tag)
		combat.queue_free()
		await process_frame
		return

	combat.phase = combat.Phase.PAUSED
	for a in combat.get_allies():
		a.set_physics_process(false)
	for e in combat.get_enemies():
		e.set_physics_process(false)

	CombatFieldBounds.debug_draw_enabled = true
	# Force logical viewport to the capture target (project stretch can keep 1280×720 visible_rect).
	var bits := size_tag.split("x")
	if bits.size() == 2:
		CombatFieldBounds.debug_force_vp_size = Vector2(float(bits[0]), float(bits[1]))
	var top := CombatFieldBounds.top_y(boss)
	var head_w := CombatFieldBounds.estimate_headroom_world(boss)
	# Stress the top bound: request above top, clamp must keep feet on/below top.
	boss.global_position = CombatFieldBounds.clamp_point(Vector2(640, top - 80.0), boss)
	boss._face_right = false
	boss._apply_facing()
	boss._set_anim_state(boss.AnimState.IDLE)
	boss._play_anim("idle", true)
	boss.queue_redraw()
	await _settle(0.2)
	await _shot(combat, "fenrir_safezone_top_%s.png" % size_tag, out_abs, store)

	# Mid-field hit reaction (HIT lock evidence)
	boss.global_position = CombatFieldBounds.clamp_point(Vector2(640, top + 60.0), boss)
	boss._begin_hit_reaction()
	await _settle(0.05)
	if boss._sprite:
		boss._sprite.frame = mini(1, boss._sprite.sprite_frames.get_frame_count("hit") - 1)
		boss._sprite.pause()
	boss.queue_redraw()
	await _settle(0.1)
	await _shot(combat, "fenrir_hitlock_%s.png" % size_tag, out_abs, store)

	CombatFieldBounds.debug_draw_enabled = false
	CombatFieldBounds.debug_force_vp_size = Vector2.ZERO
	print(
		"SHOTS ",
		size_tag,
		" top=",
		top,
		" headroom_world=",
		head_w,
		" pos=",
		boss.global_position,
		" force_vp=",
		size_tag
	)
	combat.queue_free()
	await process_frame
	await process_frame


func _settle(sec: float) -> void:
	var t := 0.0
	while t < sec:
		await process_frame
		t += 1.0 / 60.0


func _shot(combat: Node, filename: String, out_abs: String, store: String) -> void:
	RenderingServer.force_draw(true)
	await process_frame
	await process_frame
	var img: Image = combat.get_viewport().get_texture().get_image()
	if img == null or img.get_width() < 2:
		printerr("FAIL null image ", filename)
		return
	var err1 := img.save_png("%s/%s" % [out_abs, filename])
	var err2 := img.save_png("%s/%s" % [store, filename])
	print("WROTE ", store, "/", filename, " ", img.get_width(), "x", img.get_height(), " err=", err1, "/", err2)
