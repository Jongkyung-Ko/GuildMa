extends SceneTree

## Town↔shop BGM continuity + single BGM player (code-level).
## DISPLAY=:1 godot4 --path . --display-driver x11 -s res://scripts/core/validate_shop_bgm.gd
## Not a browser ear PASS.

var failed := 0


func _init() -> void:
	call_deferred("_run")


func _pass(msg: String) -> void:
	print("PASS: %s" % msg)


func _fail(msg: String) -> void:
	print("FAIL: %s" % msg)
	failed += 1


func _run() -> void:
	print("=== validate_shop_bgm ===")
	var am: Node = root.get_node_or_null("/root/AudioManager")
	if am == null:
		_fail("AudioManager missing")
		quit(1)
		return

	am.call("unlock_audio")
	am.call("on_enter_town")
	await process_frame
	await process_frame
	await create_timer(0.55).timeout

	var bgm: AudioStreamPlayer = am.get("_bgm")
	var players0 := _count_audio_players(am)
	if players0 < 1:
		_fail("no AudioManager players")
	else:
		_pass("AudioManager players=%d" % players0)

	var pos0: float = float(am.call("get_bgm_playback_position"))
	var track0 := str(am.call("get_current_bgm"))
	var stream0 = bgm.stream if bgm else null
	if track0 != "town" or not (bgm and bgm.playing):
		_fail("town BGM not playing at start (track=%s)" % track0)
	else:
		_pass("Town BGM playing pos=%.3f" % pos0)

	# Facility enter must not restart
	am.call("on_enter_facility")
	root.set_meta("facility_id", "shop")
	var err := change_scene_to_file("res://scenes/facilities/facility.tscn")
	if err != OK:
		_fail("shop scene err=%s" % err)
		quit(1)
		return
	for _i in 50:
		await process_frame

	var pos1: float = float(am.call("get_bgm_playback_position"))
	var track1 := str(am.call("get_current_bgm"))
	var stream1 = bgm.stream if bgm else null
	if track1 != "town":
		_fail("shop open changed track %s→%s" % [track0, track1])
	elif stream1 != stream0:
		_fail("shop open replaced BGM stream instance")
	elif pos0 > 0.2 and pos1 < 0.05:
		_fail("shop open hard-reset BGM (%.3f→%.3f)" % [pos0, pos1])
	elif pos1 + 0.02 < pos0:
		_fail("shop open seeked BGM backwards (%.3f→%.3f)" % [pos0, pos1])
	else:
		_pass("Shop open kept town BGM (%.3f→%.3f)" % [pos0, pos1])

	var shop := _find_shop(root)
	if shop == null:
		_fail("shop panel missing")
	else:
		# Wait for staged cards to finish.
		for _j in 40:
			await process_frame
			var g = shop.get("_grid")
			var q: Array = shop.get("_grid_queue")
			if g and g.get_child_count() >= 40 and q.is_empty():
				break
		var grid = shop.get("_grid")
		var n: int = int(grid.get_child_count()) if grid else 0
		if n < 40:
			_fail("shop grid under-populated after staging (children=%d)" % n)
		else:
			_pass("Shop staged grid populated (children=%d)" % n)

	# Return to town — must keep position (facility↔town continuity)
	var pos_before: float = float(am.call("get_bgm_playback_position"))
	am.call("on_enter_town")
	change_scene_to_file("res://scenes/town/town.tscn")
	for _k in 20:
		await process_frame
	var pos2: float = float(am.call("get_bgm_playback_position"))
	var track2 := str(am.call("get_current_bgm"))
	if track2 != "town":
		_fail("town return track=%s" % track2)
	elif pos_before > 0.4 and pos2 < 0.08:
		_fail("town return force-restarted BGM (%.3f→%.3f)" % [pos_before, pos2])
	elif pos2 + 0.05 < pos_before:
		_fail("town return seeked backwards (%.3f→%.3f)" % [pos_before, pos2])
	else:
		_pass("Town return kept BGM position (%.3f→%.3f)" % [pos_before, pos2])

	# Single BGM player still
	var bgm_nodes := 0
	for ch in am.get_children():
		if ch is AudioStreamPlayer and str(ch.name).begins_with("Bgm"):
			bgm_nodes += 1
	if bgm_nodes != 1:
		_fail("expected 1 BgmPlayer, got %d" % bgm_nodes)
	else:
		_pass("Single BgmPlayer")

	# Hunt → town still switches / starts town (track change)
	root.set_meta("hunt_id", "beginner_forest")
	root.set_meta("dungeon_id", "")
	am.call("on_enter_combat", true)
	await process_frame
	await create_timer(0.35).timeout
	var hunt_track := str(am.call("get_current_bgm"))
	am.call("on_enter_town")
	await process_frame
	await process_frame
	var after_hunt := str(am.call("get_current_bgm"))
	var after_pos: float = float(am.call("get_bgm_playback_position"))
	if after_hunt != "town":
		_fail("hunt→town track=%s" % after_hunt)
	elif after_pos > 3.0:
		_fail("hunt→town should start near 0 (pos=%.3f)" % after_pos)
	else:
		_pass("Hunt→town switches to town near start (from %s, pos=%.3f)" % [hunt_track, after_pos])

	if failed == 0:
		print("=== validate_shop_bgm: PASS ===")
	else:
		print("=== validate_shop_bgm: FAIL (%d) ===" % failed)
	quit(0 if failed == 0 else 1)


func _count_audio_players(n: Node) -> int:
	var c := 0
	if n is AudioStreamPlayer:
		c += 1
	for ch in n.get_children():
		c += _count_audio_players(ch)
	return c


func _find_shop(n: Node) -> Node:
	if n == null:
		return null
	if n.has_method("_populate_grid") and n.get("_grid") != null:
		return n
	for ch in n.get_children():
		var f := _find_shop(ch)
		if f:
			return f
	return null
