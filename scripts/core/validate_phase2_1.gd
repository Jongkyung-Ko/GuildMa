extends SceneTree

## Phase 2-1 validation runner: loads scenes, drives combat, writes log + PNG captures.
## Run: godot4 --path . -s res://scripts/core/validate_phase2_1.gd
## Prefer a real display (DISPLAY=:1) so Viewport captures are meaningful.

const OUT_DIR := "res://docs/reviews/phase2_1_artifacts"
const USER_OUT := "user://phase2_1_validation"
const ABS_DOCS := "docs/reviews/phase2_1_artifacts"

var _log_path: String = ""
var _lines: PackedStringArray = PackedStringArray()
var _ok := true
var _shot_i := 0


func _init() -> void:
	call_deferred("_run")


func _log(msg: String) -> void:
	print(msg)
	_lines.append(msg)


func _fail(msg: String) -> void:
	_ok = false
	_log("FAIL: " + msg)


func _pass(msg: String) -> void:
	_log("PASS: " + msg)


func _ensure_dirs() -> void:
	DirAccess.make_dir_recursive_absolute("res://docs/reviews/phase2_1_artifacts")
	# Also write under project absolute path via OS
	var abs := ProjectSettings.globalize_path("res://docs/reviews/phase2_1_artifacts")
	DirAccess.make_dir_recursive_absolute(abs)
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts/phase2_1_validation")
	_log_path = abs + "/validation_run.log"


func _flush_log() -> void:
	var f := FileAccess.open(_log_path, FileAccess.WRITE)
	if f:
		f.store_string("\n".join(_lines) + "\n")
	var f2 := FileAccess.open("/opt/cursor/artifacts/phase2_1_validation/validation_run.log", FileAccess.WRITE)
	if f2:
		f2.store_string("\n".join(_lines) + "\n")


func _capture(tag: String) -> String:
	await process_frame
	await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	if img == null:
		_log("WARN: viewport image null for " + tag)
		return ""
	_shot_i += 1
	var name := "%02d_%s.png" % [_shot_i, tag]
	var abs := ProjectSettings.globalize_path("res://docs/reviews/phase2_1_artifacts") + "/" + name
	var art := "/opt/cursor/artifacts/phase2_1_validation/" + name
	var err := img.save_png(abs)
	img.save_png(art)
	if err != OK:
		_log("WARN: save_png failed %s err=%s" % [abs, str(err)])
	else:
		_log("SHOT: " + abs)
	return abs


func _run() -> void:
	_ensure_dirs()
	_log("=== Phase 2-1 validation start ===")
	_log("Godot: " + Engine.get_version_info().get("string", "?"))
	_log("Display driver note: running as -s SceneTree script")
	_log("Time UTC: " + Time.get_datetime_string_from_system(true))

	# Autoloads should exist when --path project is used
	var gs: Node = root.get_node_or_null("/root/GameState")
	var sr: Node = root.get_node_or_null("/root/SceneRouter")
	var ui: Node = root.get_node_or_null("/root/UIStyle")
	if gs == null:
		_fail("GameState autoload missing")
		_finish()
		return
	if sr == null:
		_fail("SceneRouter autoload missing")
		_finish()
		return
	if ui == null:
		_fail("UIStyle autoload missing")
		_finish()
		return
	_pass("Autoloads GameState/SceneRouter/UIStyle present")

	gs.new_game()
	_log("Party members after new_game: %d" % gs.members.size())
	var in_party := 0
	for m in gs.members:
		if bool(m.get("in_party", false)):
			in_party += 1
			_log("  - %s job=%s lv=%s" % [m.get("name"), m.get("job"), m.get("level")])
	if in_party != 5:
		_fail("Expected 5 in_party, got %d" % in_party)
	else:
		_pass("Starting party in_party count = 5")

	# --- Title scene ---
	_log("--- Load title ---")
	var title = load("res://scenes/title/title.tscn")
	if title == null:
		_fail("title.tscn load")
	else:
		var tnode: Node = title.instantiate()
		root.add_child(tnode)
		await process_frame
		await process_frame
		await _capture("title")
		_pass("title.tscn instantiated")
		tnode.queue_free()
		await process_frame

	# --- Town scene ---
	_log("--- Load town ---")
	var town = load("res://scenes/town/town.tscn")
	if town == null:
		_fail("town.tscn load")
	else:
		var tn: Node = town.instantiate()
		root.add_child(tn)
		await process_frame
		await process_frame
		await process_frame
		await _capture("town")
		_pass("town.tscn instantiated")
		tn.queue_free()
		await process_frame

	# --- Facility gate ---
	_log("--- Load facility (gate) ---")
	root.set_meta("facility_id", "gate")
	var fac = load("res://scenes/facilities/facility.tscn")
	if fac == null:
		_fail("facility.tscn load")
	else:
		var fn: Node = fac.instantiate()
		root.add_child(fn)
		await process_frame
		await process_frame
		await process_frame
		await _capture("facility_gate")
		_pass("facility.tscn (gate) instantiated")
		fn.queue_free()
		await process_frame

	# --- Combat ---
	_log("--- Load combat ---")
	var combat_ps = load("res://scenes/combat/combat.tscn")
	if combat_ps == null:
		_fail("combat.tscn load")
		_finish()
		return
	var combat: Node = combat_ps.instantiate()
	root.add_child(combat)
	await process_frame
	await process_frame
	await process_frame

	if not combat.has_method("get_allies"):
		_fail("combat missing get_allies")
		_finish()
		return

	var allies: Array = combat.get_allies()
	var enemies: Array = combat.get_enemies()
	_log("Spawned allies=%d enemies=%d" % [allies.size(), enemies.size()])
	if allies.size() != 5:
		_fail("Expected 5 allies spawned, got %d" % allies.size())
	else:
		_pass("5 allies spawned")
	if enemies.size() < 1:
		_fail("Expected >=1 enemy")
	else:
		_pass("Enemies spawned: %d (species from enemies.json)" % enemies.size())

	for a in allies:
		_log("  ally %s hp=%.1f/%.1f pos=%s" % [a.display_name, a.hp, a.hp_max, str(a.global_position)])
	for e in enemies:
		_log("  enemy %s hp=%.1f/%.1f pos=%s" % [e.display_name, e.hp, e.hp_max, str(e.global_position)])

	await _capture("combat_start")

	var enemy_hp0 := 0.0
	for e in enemies:
		enemy_hp0 += float(e.hp)
	var ally_hp0 := 0.0
	for a in allies:
		ally_hp0 += float(a.hp)

	var saw_move := false
	var saw_damage := false
	var start_pos: Dictionary = {}
	for a in allies:
		start_pos[a.get_instance_id()] = a.global_position

	var frames := 0
	var max_frames := 90 * 60
	while frames < max_frames:
		await process_frame
		frames += 1
		var dt := 1.0 / 60.0
		# Drive AI if physics server idle under -s
		for a in combat.get_allies():
			if a and not a.is_dead and a.has_method("_physics_process"):
				a._physics_process(dt)
		for e in combat.get_enemies():
			if e and not e.is_dead and e.has_method("_physics_process"):
				e._physics_process(dt)
		if combat.has_method("_check_end_conditions"):
			combat._check_end_conditions()

		if not saw_move:
			for a2 in combat.get_allies():
				if a2 == null or a2.is_dead:
					continue
				var p0: Vector2 = start_pos.get(a2.get_instance_id(), a2.global_position)
				if p0.distance_to(a2.global_position) > 8.0:
					saw_move = true
					_pass("Ally auto-move observed (%s moved)" % a2.display_name)
					break

		var ehp := 0.0
		for e2 in combat.get_enemies():
			if e2:
				ehp += float(e2.hp)
		if ehp < enemy_hp0 - 0.5:
			if not saw_damage:
				saw_damage = true
				_pass("Enemy HP decreased (%.1f -> %.1f)" % [enemy_hp0, ehp])

		if frames == 90:
			await _capture("combat_mid_90f")
		if frames == 240:
			await _capture("combat_mid_240f")

		var phase: String = combat.get_phase_name()
		if phase == "victory" or phase == "defeat":
			_log("Combat ended phase=%s frames=%d" % [phase, frames])
			break

		if frames % 120 == 0:
			_log("... tick %d ehp=%.1f phase=%s" % [frames, ehp, phase])

	if not saw_move:
		_fail("No ally movement detected")
	if not saw_damage:
		_fail("No enemy HP damage detected")

	# Death check
	var dead_enemies := 0
	for e3 in combat.get_enemies():
		if e3 and e3.is_dead:
			dead_enemies += 1
	_log("Dead enemies at end: %d / %d" % [dead_enemies, combat.get_enemies().size()])
	if dead_enemies > 0:
		_pass("Enemy death handled (is_dead)")
	else:
		if combat.get_phase_name() == "victory":
			_fail("Victory but no is_dead enemies?")
		else:
			_log("NOTE: no enemy deaths before timeout/end")

	var end_phase: String = combat.get_phase_name()
	if end_phase == "victory":
		_pass("Combat ended in victory")
	elif end_phase == "defeat":
		_pass("Combat ended in defeat (resolved)")
	else:
		_fail("Combat did not reach victory/defeat (phase=%s)" % end_phase)

	await _capture("combat_end")

	# Pause only if still fighting (may already be over)
	if combat.get_phase_name() == "fighting":
		combat.toggle_pause()
		if combat.get_phase_name() == "paused":
			_pass("Pause works")
			combat.toggle_pause()
		else:
			_fail("Pause did not enter paused")
	else:
		_log("NOTE: pause toggle skipped (combat already finished)")

	# SceneRouter.go_combat / go_town API presence
	if sr.has_method("go_combat") and sr.has_method("go_town"):
		_pass("SceneRouter.go_combat and go_town exist")
	else:
		_fail("SceneRouter missing go_combat/go_town")

	_log("Ally HP total start=%.1f end=%.1f" % [ally_hp0, _sum_hp(combat.get_allies())])
	_finish()


func _sum_hp(units: Array) -> float:
	var s := 0.0
	for u in units:
		if u:
			s += float(u.hp)
	return s


func _finish() -> void:
	_log("=== RESULT: %s ===" % ("PASS" if _ok else "FAIL"))
	_flush_log()
	quit(0 if _ok else 1)
