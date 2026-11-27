extends SceneTree

## Diagnose town→shop BGM continuity vs shop UI hitch.
## DISPLAY=:1 godot4 --path . --display-driver x11 -s res://scripts/core/diagnose_shop_bgm_stutter.gd

var _failed := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== diagnose_shop_bgm_stutter ===")
	var am: Node = root.get_node_or_null("/root/AudioManager")
	if am == null:
		print("FAIL: AudioManager missing")
		quit(1)
		return

	am.call("unlock_audio")
	am.call("on_enter_town")
	await process_frame
	await process_frame
	await create_timer(0.6).timeout

	var bgm: AudioStreamPlayer = am.get("_bgm")
	_dump("TOWN_READY", am, bgm)
	var pos0: float = float(am.call("get_bgm_playback_position"))
	var track0 := str(am.call("get_current_bgm"))
	var stream0 = bgm.stream if bgm else null
	var playing0 := bgm.playing if bgm else false

	root.set_meta("facility_id", "shop")
	var t_audio0 := Time.get_ticks_usec()
	am.call("on_enter_facility")
	var audio_ms := float(Time.get_ticks_usec() - t_audio0) / 1000.0
	var pos_after_audio: float = float(am.call("get_bgm_playback_position"))
	print("AFTER_on_enter_facility track=%s pos=%.3f (was %.3f) stream_same=%s audio_call_ms=%.2f" % [
		str(am.call("get_current_bgm")), pos_after_audio, pos0,
		str((bgm.stream if bgm else null) == stream0), audio_ms
	])

	var t_scene0 := Time.get_ticks_usec()
	var err := change_scene_to_file("res://scenes/facilities/facility.tscn")
	if err != OK:
		print("FAIL: change_scene shop err=%s" % err)
		quit(1)
		return
	# First frames include shop mount + icon loads.
	var max_gap_ms := 0.0
	var sum_gap_ms := 0.0
	var gaps := 0
	for _i in 45:
		var a := Time.get_ticks_usec()
		await process_frame
		var gap := float(Time.get_ticks_usec() - a) / 1000.0
		gaps += 1
		sum_gap_ms += gap
		if gap > max_gap_ms:
			max_gap_ms = gap
	var scene_ms := float(Time.get_ticks_usec() - t_scene0) / 1000.0
	print("HITCH scene_open_wall_ms=%.1f max_frame_gap_ms=%.1f avg_frame_gap_ms=%.1f frames=%d approx_min_fps=%.1f" % [
		scene_ms, max_gap_ms, (sum_gap_ms / float(gaps)) if gaps > 0 else 0.0, gaps,
		(1000.0 / max_gap_ms) if max_gap_ms > 0.0 else -1.0
	])

	_dump("SHOP_OPEN", am, bgm)
	var pos1: float = float(am.call("get_bgm_playback_position"))
	var track1 := str(am.call("get_current_bgm"))
	var stream1 = bgm.stream if bgm else null
	var playing1 := bgm.playing if bgm else false

	var shop := _find_shop(root)
	if shop:
		var grid_children := -1
		var g = shop.get("_grid")
		if g:
			grid_children = g.get_child_count()
		print("SHOP_UI buttons=%d texture_rects=%d grid_children=%d" % [
			_count_by_class(shop, "Button"),
			_count_by_class(shop, "TextureRect"),
			grid_children,
		])
	else:
		print("WARN: shop panel not found")

	# Cold-ish icon load cost for default weapon category (48 icons).
	var gs: Node = root.get_node_or_null("/root/GameState")
	var t_load0 := Time.get_ticks_usec()
	var loaded := 0
	if gs:
		for item in gs.call("items_by_category", "weapon"):
			var path := str(item.get("icon", ""))
			if path != "" and ResourceLoader.exists(path):
				var tex: Texture2D = load(path) as Texture2D
				if tex:
					loaded += 1
	var load_ms := float(Time.get_ticks_usec() - t_load0) / 1000.0
	print("ICON_LOAD_BENCH weapon_icons=%d elapsed_ms=%.1f" % [loaded, load_ms])

	if shop and shop.has_method("_populate_grid"):
		var t_grid0 := Time.get_ticks_usec()
		shop.call("_populate_grid")
		var grid_ms := float(Time.get_ticks_usec() - t_grid0) / 1000.0
		var grid_n := -1
		var grid_node = shop.get("_grid")
		if grid_node:
			grid_n = grid_node.get_child_count()
		print("GRID_POPULATE_BENCH elapsed_ms=%.1f children=%d" % [grid_ms, grid_n])

	if track1 != track0:
		print("FAIL: BGM track changed on shop open %s → %s" % [track0, track1])
		_failed += 1
	elif stream1 != stream0 and stream0 != null:
		print("FAIL: BGM stream instance replaced on shop open")
		_failed += 1
	elif playing0 and playing1 and pos0 > 0.15 and pos1 < 0.05:
		print("FAIL: BGM position hard-reset on shop open (%.3f → %.3f)" % [pos0, pos1])
		_failed += 1
	elif playing0 and playing1 and pos1 + 0.02 < pos0:
		print("FAIL: BGM position went backwards on shop open (%.3f → %.3f)" % [pos0, pos1])
		_failed += 1
	else:
		print("PASS: shop open kept track=%s pos %.3f→%.3f stream_same=%s" % [
			track1, pos0, pos1, str(stream1 == stream0)
		])

	if max_gap_ms >= 100.0:
		print("FINDING: residual frame hitch on shop open (max_gap=%.1fms) — FPS/audio risk if sustained" % max_gap_ms)
	else:
		print("FINDING: shop open max_gap=%.1fms load=%.1fms scene_wall=%.1fms" % [max_gap_ms, load_ms, scene_ms])

	await create_timer(0.25).timeout
	var pos_before_town: float = float(am.call("get_bgm_playback_position"))
	am.call("on_enter_town")
	var err2 := change_scene_to_file("res://scenes/town/town.tscn")
	if err2 != OK:
		print("FAIL: change_scene town err=%s" % err2)
		quit(1)
		return
	for _j in 20:
		await process_frame
	_dump("TOWN_RETURN", am, bgm)
	var pos2: float = float(am.call("get_bgm_playback_position"))
	if pos_before_town > 0.25 and pos2 + 0.05 < pos_before_town and pos2 < 0.35:
		print("FINDING: on_enter_town RESTARTS town BGM (%.3f → %.3f)" % [pos_before_town, pos2])
	else:
		print("FINDING: town return keeps/continues pos %.3f → %.3f" % [pos_before_town, pos2])

	await create_timer(0.35).timeout
	var pos3: float = float(am.call("get_bgm_playback_position"))
	am.call("on_enter_facility")
	root.set_meta("facility_id", "shop")
	change_scene_to_file("res://scenes/facilities/facility.tscn")
	for _k in 30:
		await process_frame
	var pos4: float = float(am.call("get_bgm_playback_position"))
	_dump("SHOP_REOPEN", am, bgm)
	print("REOPEN pos %.3f → %.3f" % [pos3, pos4])

	# Blacksmith open compare
	var t_bs0 := Time.get_ticks_usec()
	var max_bs := 0.0
	root.set_meta("facility_id", "blacksmith")
	am.call("on_enter_facility")
	change_scene_to_file("res://scenes/facilities/facility.tscn")
	for _m in 40:
		var a2 := Time.get_ticks_usec()
		await process_frame
		var g2 := float(Time.get_ticks_usec() - a2) / 1000.0
		if g2 > max_bs:
			max_bs = g2
	print("BLACKSMITH_HITCH wall_ms=%.1f max_frame_gap_ms=%.1f" % [
		float(Time.get_ticks_usec() - t_bs0) / 1000.0, max_bs
	])
	_dump("BLACKSMITH", am, bgm)

	print("=== diagnose done fails=%d ===" % _failed)
	quit(0 if _failed == 0 else 1)


func _dump(tag: String, am: Node, bgm: AudioStreamPlayer) -> void:
	var players := _count_audio_players(am)
	var path := ""
	if bgm and bgm.stream:
		path = str(bgm.stream.resource_path)
		if path == "":
			path = str(am.get("BGM_PATHS").get(str(am.call("get_current_bgm")), "?"))
	print("%s track=%s mode=%s playing=%s paused=%s pos=%.3f path=%s am_audio_players=%d switching=%s" % [
		tag,
		str(am.call("get_current_bgm")),
		str(am.call("get_combat_mode")),
		str(bgm.playing if bgm else false),
		str(bgm.stream_paused if bgm else false),
		float(am.call("get_bgm_playback_position")),
		path,
		players,
		str(am.call("is_bgm_switching")),
	])


func _count_audio_players(n: Node) -> int:
	var c := 0
	if n is AudioStreamPlayer or n is AudioStreamPlayer2D or n is AudioStreamPlayer3D:
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


func _count_by_class(n: Node, cls: String) -> int:
	var c := 0
	if n.get_class() == cls:
		c += 1
	for ch in n.get_children():
		c += _count_by_class(ch, cls)
	return c
