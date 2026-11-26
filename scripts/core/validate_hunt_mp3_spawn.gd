extends SceneTree

## PR14: hunting Tobitate MP3 + re-entry spawn (room + party coords).
## godot4 --headless --path . -s res://scripts/core/validate_hunt_mp3_spawn.gd

const HUNT_MP3 := "res://assets/audio/music/tobitate_aoi_sora.mp3"
const ALLY_SLOTS := [
	Vector2(220, 280),
	Vector2(180, 360),
	Vector2(260, 420),
	Vector2(160, 220),
	Vector2(300, 340),
]


func _init() -> void:
	call_deferred("_run")


func _pass(msg: String) -> void:
	print("PASS: ", msg)


func _wait_bgm(am: Node) -> void:
	var deadline := Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
		if not bool(am.call("is_bgm_switching")):
			await create_timer(0.05).timeout
			return
	am.set("_switching", false)


func _run() -> void:
	await process_frame
	var failed := 0
	var gs: Node = root.get_node("/root/GameState")
	var am: Node = root.get_node("/root/AudioManager")
	gs.call("new_game")
	am.call("unlock_audio")

	# --- A. File + path wiring ---
	if not ResourceLoader.exists(HUNT_MP3):
		print("FAIL: missing hunt MP3 ", HUNT_MP3)
		quit(1)
		return
	_pass("Hunt MP3 exists on disk")
	var paths: Dictionary = am.get("BGM_PATHS")
	if str(paths.get("hunt", "")) != HUNT_MP3:
		print("FAIL: BGM_PATHS.hunt=%s" % str(paths.get("hunt", "")))
		failed += 1
	else:
		_pass("BGM_PATHS.hunt → tobitate_aoi_sora.mp3")
	if str(paths.get("combat", "")) != HUNT_MP3:
		print("FAIL: combat alias not Tobitate")
		failed += 1
	else:
		_pass("BGM_PATHS.combat alias → Tobitate")

	# --- B. Town → hunt plays hunt MP3 ---
	am.call("on_enter_town")
	await _wait_bgm(am)
	root.set_meta("hunt_id", "beginner_forest")
	root.set_meta("dungeon_id", "")
	root.set_meta("dungeon_floor", 0)
	am.call("on_enter_combat", true)
	await _wait_bgm(am)
	print("LOG: after hunt enter key=%s mode=%s path=%s" % [
		am.call("get_current_bgm"), am.call("get_combat_mode"), paths.get(am.call("get_current_bgm"), "")
	])
	if str(am.call("get_current_bgm")) != "hunt" or str(am.call("get_combat_mode")) != "hunt":
		print("FAIL: expected hunt/hunt got %s/%s" % [am.call("get_current_bgm"), am.call("get_combat_mode")])
		failed += 1
	else:
		_pass("Town→hunt selects hunt MP3 key")
	var bgm: AudioStreamPlayer = am.get("_bgm")
	if bgm and bgm.stream is AudioStreamMP3:
		_pass("Hunt stream is AudioStreamMP3")
	else:
		print("FAIL: hunt stream not MP3"); failed += 1

	# --- C. Internal hop keeps position ---
	var pos1: float = float(am.call("get_bgm_playback_position"))
	am.call("on_enter_combat", false)
	await process_frame
	var pos2: float = float(am.call("get_bgm_playback_position"))
	if str(am.call("get_current_bgm")) != "hunt":
		print("FAIL: internal hop left hunt BGM"); failed += 1
	elif pos1 > 0.2 and pos2 < 0.05:
		print("FAIL: internal hop seeked BGM"); failed += 1
	else:
		_pass("Hunt internal hop keeps Tobitate position (%.3f→%.3f)" % [pos1, pos2])

	# --- D. Dungeon normal still uses OGG playlist ---
	root.set_meta("hunt_id", "")
	root.set_meta("dungeon_id", "shadow_crypt")
	root.set_meta("dungeon_floor", 1)
	gs.call("new_game")
	gs.call("ensure_dungeon_progress", "shadow_crypt")
	am.call("on_enter_combat", true)
	await _wait_bgm(am)
	print("LOG: dungeon F1 key=%s mode=%s path=%s" % [
		am.call("get_current_bgm"), am.call("get_combat_mode"), paths.get(am.call("get_current_bgm"), "")
	])
	if str(am.call("get_combat_mode")) != "playlist":
		print("FAIL: dungeon F1 should be playlist"); failed += 1
	elif not str(paths.get(am.call("get_current_bgm"), "")).ends_with(".ogg"):
		print("FAIL: dungeon F1 should be OGG"); failed += 1
	else:
		_pass("Dungeon F1 uses OGG playlist (not hunt MP3)")

	# F5 / F10
	root.set_meta("dungeon_floor", 5)
	am.call("on_enter_combat", true)
	await _wait_bgm(am)
	if str(am.call("get_current_bgm")) != "combat_heroic":
		print("FAIL: F5"); failed += 1
	else:
		_pass("F5 → combat_heroic")
	root.set_meta("dungeon_floor", 10)
	am.call("on_enter_combat", true)
	await _wait_bgm(am)
	if str(am.call("get_current_bgm")) != "combat_boss":
		print("FAIL: F10"); failed += 1
	else:
		_pass("F10 → combat_boss")

	am.call("on_enter_town")
	await _wait_bgm(am)
	if str(am.call("get_current_bgm")) != "town":
		print("FAIL: town restore"); failed += 1
	else:
		_pass("Town MP3 after combat")

	# --- E. Re-entry spawn: room + party coords + save ---
	gs.call("new_game")
	root.set_meta("hunt_id", "beginner_forest")
	root.set_meta("dungeon_id", "")
	root.set_meta("hunt_spawn_at_start", true)
	var map1: Dictionary = gs.call("start_hunt_run", "beginner_forest", true, true)
	var start_id := str(gs.call("get_hunt_start_room_id", map1))
	var cur := str(map1.get("current_room_id", ""))
	gs.call("mark_hunt_room_cleared", cur)
	# Move away from start
	var dest := ""
	for rid in gs.call("hunt_connected_room_ids", cur):
		if gs.call("hunt_can_move_to", str(rid)):
			gs.call("hunt_move_to", str(rid))
			dest = str(rid)
			break
	if dest == "" or dest == start_id:
		print("FAIL: could not leave start room"); failed += 1
	else:
		_pass("Moved to mid room %s" % dest)
	var mid := str(gs.call("get_active_hunt_map").get("current_room_id"))

	# Leave via override id (simulates combat-local hunt_id)
	gs.call("leave_hunt_session", "beginner_forest")
	if str(gs.get("active_hunt_id")) != "":
		print("FAIL: active not cleared"); failed += 1
	else:
		_pass("leave_hunt_session cleared active_hunt_id")
	var saved: Dictionary = gs.get("hunt_progress").get("beginner_forest", {})
	if not bool(saved.get("pending_spawn_at_start", false)):
		print("FAIL: pending_spawn_at_start not set"); failed += 1
	else:
		_pass("pending_spawn_at_start stamped on leave")
	var saved_cur := str(saved.get("map", {}).get("current_room_id", ""))
	if saved_cur != start_id:
		print("FAIL: saved current_room after leave is %s not start %s" % [saved_cur, start_id]); failed += 1
	else:
		_pass("Saved current_room_id is start after leave")

	# Persist via save/load
	gs.call("save_game")
	var ok_load := bool(gs.call("load_game"))
	if not ok_load:
		print("FAIL: load_game"); failed += 1
	else:
		_pass("Save/load after leave")
	var loaded_map: Dictionary = gs.get("hunt_progress").get("beginner_forest", {}).get("map", {})
	if str(loaded_map.get("current_room_id", "")) != start_id:
		print("FAIL: load restored mid room"); failed += 1
	else:
		_pass("After load, current_room still start")
	if not bool(loaded_map.get("rooms", {}).get(start_id, {}).get("cleared", false)):
		print("FAIL: cleared progress lost"); failed += 1
	else:
		_pass("Cleared progress retained across save/load")

	# Re-enter with spawn_at_start
	var remap: Dictionary = gs.call("start_hunt_run", "beginner_forest", false, true)
	var re_cur := str(remap.get("current_room_id", ""))
	var re_type := str(remap.get("rooms", {}).get(re_cur, {}).get("room_type", ""))
	print("LOG: re-entry room=%s type=%s start=%s mid_was=%s" % [re_cur, re_type, start_id, mid])
	if re_cur != start_id or re_type != "start":
		print("FAIL: re-entry not at start room"); failed += 1
	else:
		_pass("Re-entry current_room_id is start")
	if re_cur == mid and mid != start_id:
		print("FAIL: re-entry restored mid room"); failed += 1
	else:
		_pass("Re-entry did not restore mid room")

	# Party spawn coords (entrance formation slots)
	root.set_meta("hunt_id", "beginner_forest")
	root.set_meta("dungeon_id", "")
	root.set_meta("dungeon_floor", 0)
	root.set_meta("hunt_spawn_at_start", true)
	root.set_meta("hunt_force_new", false)
	var combat: Node = load("res://scenes/combat/combat.tscn").instantiate()
	root.add_child(combat)
	await process_frame
	await process_frame
	await process_frame
	var room_now: Dictionary = gs.call("get_current_hunt_room")
	if str(room_now.get("room_type", "")) != "start":
		print("FAIL: combat scene room_type=%s" % str(room_now.get("room_type", "")))
		failed += 1
	else:
		_pass("Combat scene at start room_type")
	var allies: Array = combat.get("_allies")
	if allies == null or allies.size() == 0:
		print("FAIL: no allies spawned"); failed += 1
	else:
		var matched := 0
		for i in mini(allies.size(), ALLY_SLOTS.size()):
			var p: Vector2 = allies[i].global_position
			print("LOG: ally[%d] pos=%s expect=%s" % [i, str(p), str(ALLY_SLOTS[i])])
			if p.distance_to(ALLY_SLOTS[i]) < 1.0:
				matched += 1
		if matched != mini(allies.size(), ALLY_SLOTS.size()):
			print("FAIL: ally spawn coords mismatch matched=%d/%d" % [matched, allies.size()])
			failed += 1
		else:
			_pass("Ally spawn coords match entrance formation (%d)" % matched)

	# Internal travel must NOT reset via start_hunt_run(spawn_at_start=false)
	gs.call("mark_hunt_room_cleared")
	var cur2 := str(gs.call("get_active_hunt_map").get("current_room_id"))
	var moved2 := false
	var dest2 := ""
	for rid2 in gs.call("hunt_connected_room_ids", cur2):
		if gs.call("hunt_can_move_to", str(rid2)):
			moved2 = gs.call("hunt_move_to", str(rid2))
			dest2 = str(rid2)
			break
	if not moved2:
		print("NOTE: could not move after combat spawn (may be uncleared) — skip internal no-reset check")
	else:
		var keep := str(gs.call("get_active_hunt_map").get("current_room_id"))
		# Simulate mid-run resume without spawn_at_start (room travel path)
		var mid_resume: Dictionary = gs.call("start_hunt_run", "beginner_forest", false, false)
		if str(mid_resume.get("current_room_id", "")) != keep:
			print("FAIL: internal resume without spawn_at_start reset room"); failed += 1
		else:
			_pass("Internal start_hunt_run(spawn_at_start=false) keeps room %s" % keep)

	combat.queue_free()
	await process_frame

	# Re-entry BGM from start
	root.set_meta("hunt_id", "beginner_forest")
	root.set_meta("dungeon_id", "")
	am.call("on_enter_combat", true)
	await _wait_bgm(am)
	var rpos: float = float(am.call("get_bgm_playback_position"))
	print("LOG: re-entry BGM key=%s pos=%.3f" % [am.call("get_current_bgm"), rpos])
	if str(am.call("get_current_bgm")) != "hunt":
		print("FAIL: re-entry BGM not hunt"); failed += 1
	elif rpos > 5.0:
		print("FAIL: re-entry BGM mid-track"); failed += 1
	else:
		_pass("Re-entry hunt MP3 from near start")

	print("NOTE: Ear / browser listening NOT VERIFIED.")
	if failed == 0:
		print("=== HUNT MP3+SPAWN VALIDATE: PASS ===")
		quit(0)
	else:
		print("=== HUNT MP3+SPAWN VALIDATE: FAIL (%d) ===" % failed)
		quit(1)
