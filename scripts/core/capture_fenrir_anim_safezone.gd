extends SceneTree

## Evidence: Fenrir attack/hit/death + top safe-zone at 844×390 and 1366×768.
## Real display required (x11). Not a visual PASS claim.
##
##   DISPLAY=:1 godot4 --path . --display-driver x11 -s res://scripts/core/capture_fenrir_anim_safezone.gd

const OUT_RES := "docs/reviews/boss-assets/fenrir-anim-safezone"
const DEFAULT_STORE := "/cursor/stores/bc-e37588d2-6890-4fb7-945a-c6a1997eb0b9/media/boss-assets/evidence/fenrir-anim-safezone"

const SIZES := [
	{"tag": "844x390", "w": 844, "h": 390},
	{"tag": "1366x768", "w": 1366, "h": 768},
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var ds := str(DisplayServer.get_name())
	print("=== FENRIR ANIM + SAFEZONE CAPTURE ===")
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
		print("SIZE ", sz["tag"], " win=", win.size if win else Vector2i.ZERO)
		gs.new_game()
		await _capture_size(gs, str(sz["tag"]), out_abs, store)

	print("=== FENRIR ANIM + SAFEZONE CAPTURE DONE === store=", store)
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

	# Pause AI; stage Fenrir mid-field under dynamic top.
	combat.phase = combat.Phase.PAUSED
	for a in combat.get_allies():
		a.set_physics_process(false)
	for e in combat.get_enemies():
		e.set_physics_process(false)

	var top := CombatFieldBounds.top_y(boss)
	var safe_y := top + 40.0
	boss.global_position = CombatFieldBounds.clamp_point(Vector2(640, safe_y + 80.0), boss)
	boss._face_right = false
	boss._apply_facing()
	CombatFieldBounds.debug_draw_enabled = true
	boss.queue_redraw()

	# Idle baseline
	boss._set_anim_state(boss.AnimState.IDLE)
	boss._play_anim("idle", true)
	await _settle(0.25)
	await _shot(combat, "fenrir_idle_%s.png" % size_tag, out_abs, store)

	# Attack mid-hitframe
	boss._set_anim_state(boss.AnimState.ATTACK_WINDUP)
	boss._play_anim("attack", true)
	await _settle(0.05)
	if boss._sprite:
		boss._sprite.frame = int(boss._attack_active_idx)
		boss._sprite.pause()
	await _settle(0.1)
	await _shot(combat, "fenrir_attack_hitframe_%s.png" % size_tag, out_abs, store)

	# Hit reaction
	boss._set_anim_state(boss.AnimState.HIT)
	boss._play_anim("hit", true)
	await _settle(0.05)
	if boss._sprite:
		boss._sprite.frame = 1
		boss._sprite.pause()
	await _settle(0.1)
	await _shot(combat, "fenrir_hit_%s.png" % size_tag, out_abs, store)

	# Death mid / last frame
	boss._set_anim_state(boss.AnimState.DEATH)
	boss._play_anim("death", true)
	await _settle(0.05)
	if boss._sprite:
		boss._sprite.frame = 2
		boss._sprite.pause()
	await _settle(0.1)
	await _shot(combat, "fenrir_death_%s.png" % size_tag, out_abs, store)

	# Safe-zone stress: place near top bound
	boss.global_position = CombatFieldBounds.clamp_point(Vector2(640, top - 80.0), boss)
	boss._set_anim_state(boss.AnimState.IDLE)
	boss._play_anim("idle", true)
	if boss._sprite:
		boss._sprite.play("idle")
	await _settle(0.15)
	await _shot(combat, "fenrir_safezone_top_%s.png" % size_tag, out_abs, store)

	CombatFieldBounds.debug_draw_enabled = false
	print(
		"SHOTS ",
		size_tag,
		" boss=",
		boss.display_name,
		" top_y=",
		top,
		" pos=",
		boss.global_position
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
	var p1 := "%s/%s" % [out_abs, filename]
	var p2 := "%s/%s" % [store, filename]
	var err1 := img.save_png(p1)
	var err2 := img.save_png(p2)
	print("WROTE ", p2, " ", img.get_width(), "x", img.get_height(), " err=", err1, "/", err2)
