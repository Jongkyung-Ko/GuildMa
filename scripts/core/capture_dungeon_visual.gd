extends SceneTree

## Graphic-mode dungeon visual evidence for PR #9.
## MUST run under a real DisplayServer (xvfb X11 / OpenGL), NOT --headless.
##
##   xvfb-run -a /tmp/godot --path . -s res://scripts/core/capture_dungeon_visual.gd
##
## Saves screenshots only — does not change gameplay code.
## Autoloads: use /root/GameState (not bare GameState in -s scripts).

const DID := "shadow_crypt"
const OUT := "Guild Hub Layout/internal/pr9-visual-verification"
const ART := "/opt/cursor/artifacts/pr9-visual-verification"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var ds := str(DisplayServer.get_name())
	print("=== DUNGEON VISUAL CAPTURE ===")
	print("Godot: ", Engine.get_version_info().get("string", "?"))
	print("DisplayServer: ", ds)
	print("Video adapter: ", OS.get_video_adapter_driver_info())
	if ds == "headless":
		printerr("ABORT: headless/dummy renderer — refuse visual capture")
		quit(2)
		return

	var out_abs := ProjectSettings.globalize_path("res://" + OUT)
	DirAccess.make_dir_recursive_absolute(out_abs)
	DirAccess.make_dir_recursive_absolute(ART)

	var gs: Node = root.get_node_or_null("/root/GameState")
	if gs == null:
		printerr("ABORT: GameState missing")
		quit(2)
		return

	gs.new_game()
	gs.ensure_dungeon_progress(DID)
	gs.dungeon_set_floor(DID, 1)

	# --- A. Hub ---
	root.set_meta("dungeon_id", DID)
	root.set_meta("dungeon_floor", 1)
	var hub: Node = load("res://scenes/dungeon/dungeon_hub.tscn").instantiate()
	root.add_child(hub)
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	await _shot("01_dungeon_hub.png")
	hub.queue_free()
	await process_frame

	# --- B. F1 combat spawn ---
	await _combat_shot(gs, 1, "02_dungeon_f1_combat.png", false)

	# --- C. F5 mid boss ---
	for f in range(1, 5):
		gs.mark_dungeon_floor_cleared(DID, f)
	gs.dungeon_set_floor(DID, 5)
	await _combat_shot(gs, 5, "03_dungeon_f5_miniboss.png", false)

	# --- D. F10 final boss ---
	for f2 in range(5, 10):
		gs.mark_dungeon_floor_cleared(DID, f2)
	gs.dungeon_set_floor(DID, 10)
	await _combat_shot(gs, 10, "04_dungeon_f10_final_boss.png", false)

	# --- E. Victory UI (combat) + hub after clear (next-floor control) ---
	gs.new_game()
	gs.ensure_dungeon_progress(DID)
	gs.dungeon_set_floor(DID, 1)
	await _combat_shot(gs, 1, "05_dungeon_victory.png", true)
	# Supplemental evidence for "다음 층" on hub after clear (not a substitute for 05).
	gs.mark_dungeon_floor_cleared(DID, 1)
	gs.dungeon_set_floor(DID, 1)
	root.set_meta("dungeon_id", DID)
	var hub2: Node = load("res://scenes/dungeon/dungeon_hub.tscn").instantiate()
	root.add_child(hub2)
	await process_frame
	await process_frame
	await process_frame
	await _shot("05b_dungeon_hub_after_clear_next.png")
	hub2.queue_free()

	print("=== DUNGEON VISUAL CAPTURE DONE === ", out_abs)
	quit(0)


func _combat_shot(gs: Node, floor: int, filename: String, force_victory: bool) -> void:
	root.set_meta("dungeon_id", DID)
	root.set_meta("dungeon_floor", floor)
	root.set_meta("combat_hunt_id", "dungeon_%s_f%d" % [DID, floor])
	root.set_meta("hunt_id", "")
	var combat: Node = load("res://scenes/combat/combat.tscn").instantiate()
	root.add_child(combat)
	await process_frame
	await process_frame
	await process_frame
	# Let combat AI move/swing so still frames can show mid-fight activity.
	var settle := 0.4 if force_victory else 3.5
	var t := 0.0
	while t < settle:
		await process_frame
		t += 1.0 / 60.0
	if force_victory:
		for e in combat.get_enemies():
			if e and e.has_method("take_damage"):
				e.take_damage(99999.0, null, {})
		await process_frame
		if combat.has_method("_check_end_conditions"):
			combat.call("_check_end_conditions")
		await process_frame
		await process_frame
		if combat.has_method("get") and combat.get("_ui") and combat.get("_ui").has_method("refresh"):
			combat.get("_ui").refresh()
		await process_frame
		await process_frame
	await _shot(filename)
	combat.queue_free()
	await process_frame


func _shot(filename: String) -> void:
	await process_frame
	await process_frame
	var tex: ViewportTexture = root.get_viewport().get_texture()
	if tex == null:
		printerr("FAIL capture (no texture): ", filename)
		return
	var img: Image = tex.get_image()
	if img == null:
		printerr("FAIL capture (no image): ", filename)
		return
	var p1 := ProjectSettings.globalize_path("res://" + OUT) + "/" + filename
	var p2 := ART + "/" + filename
	img.save_png(p1)
	img.save_png(p2)
	print("SHOT OK DisplayServer=", DisplayServer.get_name(), " -> ", p1, " size=", img.get_width(), "x", img.get_height())
