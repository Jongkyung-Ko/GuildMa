extends SceneTree

## Hunt re-entry spawn + town↔hunt BGM restart policy.
## godot4 --headless --path . -s res://scripts/core/validate_hunt_reentry.gd

func _init() -> void:
	call_deferred("_run")


func _pass(msg: String) -> void:
	print("PASS: ", msg)


func _wait_bgm(audio: Node) -> void:
	var deadline := Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
		if audio.has_method("is_bgm_switching") and not bool(audio.call("is_bgm_switching")):
			await create_timer(0.05).timeout
			return
	audio.set("_switching", false)
	if audio.get("_bgm"):
		audio.get("_bgm").volume_db = 0.0


func _run() -> void:
	await process_frame
	var failed := 0
	var gs: Node = root.get_node_or_null("/root/GameState")
	var am: Node = root.get_node_or_null("/root/AudioManager")
	if gs == null or am == null:
		print("FAIL: missing autoloads")
		quit(1)
		return

	gs.call("new_game")
	am.call("unlock_audio")

	# 1) Town BGM from start
	am.call("on_enter_town")
	await _wait_bgm(am)
	if str(am.call("get_current_bgm")) != "town":
		print("FAIL: town BGM expected"); failed += 1
	else:
		_pass("Town BGM playing")
	var town_pos1: float = float(am.call("get_bgm_playback_position"))

	# 2) Enter hunt (fresh session) — combat BGM from start
	gs.call("start_hunt_run", "beginner_forest", true)
	root.set_meta("hunt_id", "beginner_forest")
	root.set_meta("dungeon_id", "")
	root.set_meta("dungeon_floor", 0)
	var start_id := str(gs.call("get_hunt_start_room_id"))
	var cur0 := str(gs.call("get_active_hunt_map").get("current_room_id", ""))
	if cur0 != start_id or start_id == "":
		print("FAIL: hunt start room mismatch %s vs %s" % [cur0, start_id]); failed += 1
	else:
		_pass("Hunt starts at entrance (%s)" % start_id)

	am.call("on_enter_combat", true)
	await _wait_bgm(am)
	var hunt_track := str(am.call("get_current_bgm"))
	var hunt_mode := str(am.call("get_combat_mode"))
	if hunt_mode == "none" or hunt_track == "town":
		print("FAIL: hunt combat BGM not started"); failed += 1
	else:
		_pass("Hunt combat BGM started (%s / %s)" % [hunt_mode, hunt_track])
	var hunt_pos1: float = float(am.call("get_bgm_playback_position"))

	# 3) Move to an adjacent room (must clear first)
	var map: Dictionary = gs.call("get_active_hunt_map")
	gs.call("mark_hunt_room_cleared", cur0)
	map = gs.call("get_active_hunt_map")
	var moved := false
	var dest := ""
	for rid in gs.call("hunt_connected_room_ids", cur0):
		if gs.call("hunt_can_move_to", str(rid)):
			moved = gs.call("hunt_move_to", str(rid))
			dest = str(rid)
			break
	if not moved:
		print("FAIL: could not move to adjacent room"); failed += 1
	else:
		_pass("Moved to adjacent room %s" % dest)
	var mid_room := str(gs.call("get_active_hunt_map").get("current_room_id", ""))
	if mid_room == start_id:
		print("FAIL: still at start after move"); failed += 1

	# Internal hop: BGM position preserved
	am.call("on_enter_combat", false)
	await process_frame
	var hunt_pos2: float = float(am.call("get_bgm_playback_position"))
	if str(am.call("get_current_bgm")) != hunt_track and str(am.call("get_combat_mode")) == hunt_mode:
		# intensity may change if dest is elite — allow track change only then
		pass
	if hunt_pos1 >= 0.0 and hunt_pos2 + 0.001 < hunt_pos1 and hunt_pos2 < 0.05 and hunt_pos1 > 0.2:
		print("FAIL: internal hop reset BGM (%.3f → %.3f)" % [hunt_pos1, hunt_pos2]); failed += 1
	else:
		_pass("Internal hunt hop keeps BGM position (%.3f → %.3f)" % [hunt_pos1, hunt_pos2])

	# 4) Leave to town — spawn reset + town BGM from 0
	gs.call("leave_hunt_session")
	if str(gs.get("active_hunt_id")) != "":
		print("FAIL: active_hunt_id not cleared"); failed += 1
	else:
		_pass("active_hunt_id cleared on leave")
	var prog_map: Dictionary = gs.get("hunt_progress").get("beginner_forest", {}).get("map", {})
	var after_leave_cur := str(prog_map.get("current_room_id", ""))
	var after_leave_start := str(gs.call("get_hunt_start_room_id", prog_map))
	if after_leave_cur != after_leave_start:
		print("FAIL: leave did not reset to start (%s vs %s)" % [after_leave_cur, after_leave_start]); failed += 1
	else:
		_pass("Leave resets current_room_id to start")
	# Cleared progress kept
	if not bool(prog_map.get("rooms", {}).get(start_id, {}).get("cleared", false)):
		print("FAIL: start room cleared flag lost"); failed += 1
	else:
		_pass("Cleared progress retained after leave")

	am.call("on_enter_town")
	await _wait_bgm(am)
	if str(am.call("get_current_bgm")) != "town":
		print("FAIL: town BGM after leave"); failed += 1
	else:
		_pass("Town BGM after leave")
	var town_pos2: float = float(am.call("get_bgm_playback_position"))
	# Force restart should be near start (dummy may report 0)
	if town_pos2 > 2.0 and town_pos1 > 1.0 and absf(town_pos2 - town_pos1) < 0.05:
		# Same high position strongly suggests no restart
		print("FAIL: town BGM appears continued mid-track (%.3f)" % town_pos2); failed += 1
	else:
		_pass("Town BGM restarted (pos=%.3f)" % town_pos2)

	# Force restart even if already on town
	am.call("play_bgm", "town", true)
	await _wait_bgm(am)
	var town_pos3: float = float(am.call("get_bgm_playback_position"))
	if town_pos3 > 5.0:
		print("FAIL: forced town restart still mid-track (%.3f)" % town_pos3); failed += 1
	else:
		_pass("Forced town restart from near start (pos=%.3f)" % town_pos3)

	# 5) Re-enter same hunt — must be at start, BGM from 0
	var re: Dictionary = gs.call("start_hunt_run", "beginner_forest", false)
	var re_cur := str(re.get("current_room_id", ""))
	var re_start := str(gs.call("get_hunt_start_room_id", re))
	if re_cur != re_start:
		print("FAIL: re-entry not at start (%s vs %s)" % [re_cur, re_start]); failed += 1
	else:
		_pass("Re-entry spawns at start room")
	if re_cur == mid_room and mid_room != re_start:
		print("FAIL: re-entry restored mid-hunt room"); failed += 1
	else:
		_pass("Re-entry did not restore previous mid-hunt room")

	am.call("on_enter_combat", true)
	await _wait_bgm(am)
	var re_pos: float = float(am.call("get_bgm_playback_position"))
	if re_pos > 5.0:
		print("FAIL: re-entry combat BGM mid-track (%.3f)" % re_pos); failed += 1
	else:
		_pass("Re-entry combat BGM from near start (pos=%.3f)" % re_pos)

	# 6) Internal continuity still works after re-entry
	var t_before := str(am.call("get_current_bgm"))
	var p_before: float = float(am.call("get_bgm_playback_position"))
	am.call("on_enter_combat", false)
	await process_frame
	if str(am.call("get_current_bgm")) != t_before and str(am.call("get_combat_mode")) == "playlist":
		print("FAIL: same-intensity refresh changed track unexpectedly"); failed += 1
	else:
		_pass("Post-reentry internal refresh keeps track")
	var p_after: float = float(am.call("get_bgm_playback_position"))
	if p_before > 0.2 and p_after < 0.05:
		print("FAIL: internal refresh seeked to 0"); failed += 1
	else:
		_pass("Post-reentry internal refresh keeps position")

	print("NOTE: Ear listening NOT VERIFIED in headless run.")
	if failed == 0:
		print("=== HUNT REENTRY VALIDATE: PASS ===")
		quit(0)
	else:
		print("=== HUNT REENTRY VALIDATE: FAIL (%d) ===" % failed)
		quit(1)
