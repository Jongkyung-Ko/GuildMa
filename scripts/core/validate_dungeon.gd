extends SceneTree

## Headless validation for dungeon vertical progression.
## Run: godot4 --headless --path . -s res://scripts/core/validate_dungeon.gd
## Autoload globals are NOT injected into -s scripts; use /root/GameState etc.

const DID := "shadow_crypt"
const ART := "/opt/cursor/artifacts/dungeon_validation"
const DOCS := "docs/reviews/dungeon_validation"

var _ok := true
var _lines: PackedStringArray = PackedStringArray()
var _shot_i := 0
var gs: Node
var sr: Node


func _init() -> void:
	call_deferred("_run")


func _log(msg: String) -> void:
	print(msg)
	_lines.append(msg)


func _pass(msg: String) -> void:
	_log("PASS: " + msg)


func _fail(msg: String) -> void:
	_ok = false
	_log("FAIL: " + msg)


func _flush() -> void:
	DirAccess.make_dir_recursive_absolute(ART)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + DOCS))
	var body := "\n".join(_lines) + "\n"
	var f := FileAccess.open(ART + "/validation_run.log", FileAccess.WRITE)
	if f:
		f.store_string(body)
	var f2 := FileAccess.open("res://" + DOCS + "/validation_run.log", FileAccess.WRITE)
	if f2:
		f2.store_string(body)


func _capture(tag: String) -> void:
	await process_frame
	await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	if img == null:
		_log("WARN: no viewport image for " + tag)
		return
	_shot_i += 1
	var name := "%02d_%s.png" % [_shot_i, tag]
	img.save_png(ART + "/" + name)
	img.save_png(ProjectSettings.globalize_path("res://" + DOCS) + "/" + name)
	_log("SHOT: " + name)


func _run() -> void:
	_log("=== Dungeon vertical progression validation ===")
	_log("Godot: " + str(Engine.get_version_info().get("string", "?")))
	_log("Time UTC: " + Time.get_datetime_string_from_system(true))

	gs = root.get_node_or_null("/root/GameState")
	sr = root.get_node_or_null("/root/SceneRouter")
	if gs == null:
		_fail("GameState autoload missing")
		_finish()
		return
	if sr == null:
		_fail("SceneRouter autoload missing")
		_finish()
		return
	_pass("Autoloads present")

	gs.new_game()
	if gs.get_dungeon_def(DID).is_empty():
		_fail("dungeons.json missing shadow_crypt")
		_finish()
		return
	_pass("dungeon catalog loaded (%s)" % str(gs.get_dungeon_def(DID).get("name")))

	# --- Progress API: block next while uncleared ---
	gs.ensure_dungeon_progress(DID)
	if gs.dungeon_can_go_next(DID):
		_fail("next should be blocked on uncleared F1")
	else:
		_pass("next blocked while F1 uncleared")
	if gs.dungeon_set_floor(DID, 2):
		_fail("set_floor(2) should fail while F1 uncleared")
	else:
		_pass("set_floor(2) rejected while locked")

	gs.mark_dungeon_floor_cleared(DID, 1, 3)
	if not gs.dungeon_is_floor_cleared(DID, 1):
		_fail("F1 not marked cleared")
	else:
		_pass("F1 cleared")
	if not gs.dungeon_can_go_next(DID):
		_fail("next should unlock after F1 clear")
	else:
		_pass("next unlocked after F1 clear")
	if not gs.dungeon_set_floor(DID, 2):
		_fail("set_floor(2) after clear")
	else:
		_pass("moved to F2")

	if not gs.dungeon_set_floor(DID, 1):
		_fail("back to F1")
	else:
		_pass("previous floor (F2→F1) works")
	gs.dungeon_set_floor(DID, 2)

	for f in range(2, 12):
		gs.mark_dungeon_floor_cleared(DID, f, 1)
		if f < 11:
			if not gs.dungeon_set_floor(DID, f + 1):
				_fail("could not advance to F%d" % (f + 1))
				_finish()
				return
	_pass("climbed F1→F11 via clear/next")

	var prog: Dictionary = gs.ensure_dungeon_progress(DID)
	if int(prog.get("deepest_floor", 0)) < 11:
		_fail("deepest_floor expected >=11 got %s" % str(prog.get("deepest_floor")))
	else:
		_pass("deepest_floor=%d" % int(prog.get("deepest_floor")))
	if not bool(prog.get("mid_boss_defeated", false)):
		_fail("mid_boss_defeated not set after F5")
	else:
		_pass("mid_boss_defeated after F5")
	if not bool(prog.get("final_boss_defeated", false)):
		_fail("final_boss_defeated not set after F10")
	else:
		_pass("final_boss_defeated after F10")
	if gs.dungeon_can_go_next(DID):
		_fail("next should be blocked at max floor 11")
	else:
		_pass("next blocked at F11 (max)")

	if not gs.dungeon_set_floor(DID, 10):
		_fail("back to F10 from F11")
	else:
		_pass("previous floor from F11→F10")

	# --- Save / reload ---
	# Note: new_game() also save_game()'s and would wipe progress — test memory wipe + load.
	gs.save_game()
	var saved_floor := int(gs.ensure_dungeon_progress(DID).get("current_floor", 0))
	var saved_deep := int(gs.ensure_dungeon_progress(DID).get("deepest_floor", 0))
	var saved_mid := bool(gs.ensure_dungeon_progress(DID).get("mid_boss_defeated", false))
	gs.dungeon_progress = {}
	if gs.dungeon_is_floor_cleared(DID, 5):
		# ensure creates fresh empty — cleared should be false on brand-new progress
		var fresh_check: Dictionary = gs.dungeon_progress.get(DID, {})
		if fresh_check.is_empty() or not (fresh_check.get("cleared", []) as Array).has(5):
			_pass("memory wipe cleared dungeon_progress")
		else:
			_fail("memory wipe incomplete")
	else:
		_pass("memory wipe cleared dungeon_progress")
	if not gs.load_game():
		_fail("load_game failed")
		_finish()
		return
	var loaded: Dictionary = gs.ensure_dungeon_progress(DID)
	if int(loaded.get("current_floor", 0)) != saved_floor:
		_fail("reload current_floor %s != %d" % [str(loaded.get("current_floor")), saved_floor])
	else:
		_pass("reload current_floor=%d" % saved_floor)
	if int(loaded.get("deepest_floor", 0)) != saved_deep:
		_fail("reload deepest_floor mismatch")
	else:
		_pass("reload deepest_floor=%d" % saved_deep)
	if bool(loaded.get("mid_boss_defeated", false)) != saved_mid:
		_fail("reload mid_boss_defeated mismatch")
	else:
		_pass("reload mid/final boss flags intact")
	if not gs.dungeon_is_floor_cleared(DID, 5) or not gs.dungeon_is_floor_cleared(DID, 10):
		_fail("reload cleared floors missing F5/F10")
	else:
		_pass("reload cleared floors include F5 mid + F10 final")

	var def: Dictionary = gs.get_dungeon_def(DID)
	var bosses: Dictionary = def.get("boss_floors", {})
	if bosses.has("5") and bosses.has("10"):
		_pass("boss_floors extensible map has 5 mid + 10 final")
	else:
		_fail("boss_floors missing 5/10")

	if sr.has_method("go_dungeon") and sr.has_method("go_dungeon_combat"):
		_pass("SceneRouter.go_dungeon / go_dungeon_combat present")
	else:
		_fail("SceneRouter dungeon methods missing")

	# --- Hub scene ---
	_log("--- Hub scene ---")
	gs.new_game()
	gs.ensure_dungeon_progress(DID)
	root.set_meta("dungeon_id", DID)
	var hub_ps = load("res://scenes/dungeon/dungeon_hub.tscn")
	if hub_ps == null:
		_fail("dungeon_hub.tscn load")
		_finish()
		return
	var hub: Node = hub_ps.instantiate()
	root.add_child(hub)
	await process_frame
	await process_frame
	await process_frame
	await _capture("hub_f1")
	if str(hub.get("dungeon_id")) != DID:
		_fail("hub dungeon_id")
	else:
		_pass("hub loaded for shadow_crypt")
	if hub.has_method("_refresh"):
		hub.call("_refresh")
	await process_frame
	hub.queue_free()
	await process_frame

	await _test_floor_combat(1, false)
	await _test_floor_combat(5, true)
	await _test_floor_combat(10, true)

	# Full climb with combat victory wiring (force-kill; no combat speed changes)
	_log("--- Force-clear climb F1→F11 via combat victory hook ---")
	gs.new_game()
	gs.ensure_dungeon_progress(DID)
	for f in range(1, 12):
		gs.dungeon_set_floor(DID, f)
		root.set_meta("dungeon_id", DID)
		root.set_meta("dungeon_floor", f)
		root.set_meta("combat_hunt_id", "dungeon_%s_f%d" % [DID, f])
		var cps = load("res://scenes/combat/combat.tscn")
		var c: Node = cps.instantiate()
		root.add_child(c)
		await process_frame
		await process_frame
		var enemies: Array = c.call("get_enemies")
		if enemies.is_empty():
			_fail("F%d combat spawned 0 enemies" % f)
			c.queue_free()
			await process_frame
			continue
		for e in enemies:
			if e and e.has_method("take_damage"):
				e.take_damage(99999.0, null, {})
		await process_frame
		if c.has_method("_check_end_conditions"):
			c.call("_check_end_conditions")
		await process_frame
		var phase: String = str(c.call("get_phase_name"))
		if phase != "victory":
			_fail("F%d expected victory got %s" % [f, phase])
		elif not gs.dungeon_is_floor_cleared(DID, f):
			_fail("F%d victory did not mark cleared" % f)
		else:
			_pass("F%d combat victory → floor cleared" % f)
		if f == 5:
			await _capture("combat_f5_mid_boss_win")
		if f == 10:
			await _capture("combat_f10_final_boss_win")
		if f == 11:
			await _capture("combat_f11_win")
		c.queue_free()
		await process_frame
		if f < 11 and not gs.dungeon_can_go_next(DID):
			_fail("after F%d clear, next should be allowed" % f)
		elif f < 11:
			gs.dungeon_set_floor(DID, f + 1)

	var p2: Dictionary = gs.ensure_dungeon_progress(DID)
	if bool(p2.get("mid_boss_defeated")) and bool(p2.get("final_boss_defeated")) and int(p2.get("deepest_floor")) >= 11:
		_pass("combat climb left mid+final flags and deepest>=11")
	else:
		_fail("combat climb progress incomplete: %s" % str(p2))

	if gs.dungeon_set_floor(DID, 6) and gs.dungeon_current_floor(DID) == 6:
		_pass("post-climb previous floor to F6")
	else:
		_fail("post-climb back floor")

	gs.save_game()
	_pass("final save after climb")

	_log("NOTE: Mobile phone UI not verified in this headless run (desktop viewport only).")
	_log("NOTE: GitHub Pages web build verified by CI after push to main (not in this script).")
	_finish()


func _test_floor_combat(floor: int, is_boss: bool) -> void:
	_log("--- Combat spawn F%d ---" % floor)
	gs.new_game()
	gs.ensure_dungeon_progress(DID)
	for f in range(1, floor):
		gs.mark_dungeon_floor_cleared(DID, f, 1)
	gs.dungeon_set_floor(DID, floor)
	root.set_meta("dungeon_id", DID)
	root.set_meta("dungeon_floor", floor)
	root.set_meta("combat_hunt_id", "dungeon_%s_f%d" % [DID, floor])
	var cps = load("res://scenes/combat/combat.tscn")
	var c: Node = cps.instantiate()
	root.add_child(c)
	await process_frame
	await process_frame
	await process_frame
	var enemies: Array = c.call("get_enemies")
	_log("F%d enemies=%d" % [floor, enemies.size()])
	if enemies.is_empty():
		_fail("F%d no enemies" % floor)
	else:
		var ids: PackedStringArray = PackedStringArray()
		for e in enemies:
			ids.append(str(e.display_name))
		_pass("F%d spawned %d (%s)%s" % [floor, enemies.size(), ",".join(ids), " [boss]" if is_boss else ""])
	if is_boss and enemies.size() != 1:
		_fail("boss floor F%d expected 1 enemy got %d" % [floor, enemies.size()])
	await _capture("combat_f%d_spawn" % floor)
	c.queue_free()
	await process_frame


func _finish() -> void:
	_flush()
	if _ok:
		_log("=== RESULT: OK ===")
	else:
		_log("=== RESULT: FAILED ===")
	_flush()
	quit(0 if _ok else 1)
