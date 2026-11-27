extends SceneTree

## Measure UI click SFX cost vs BGM continuity.
## DISPLAY=:1 godot4 --path . --display-driver x11 -s res://scripts/core/diagnose_sfx_bgm_hitch.gd

var _failed := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== diagnose_sfx_bgm_hitch ===")
	var am: Node = root.get_node_or_null("/root/AudioManager")
	if am == null:
		print("FAIL: AudioManager missing")
		quit(1)
		return

	am.call("unlock_audio")
	am.call("on_enter_town")
	await process_frame
	await process_frame
	await create_timer(0.55).timeout

	var bgm: AudioStreamPlayer = am.get("_bgm")
	var players := _count_am_players(am)
	print("SETUP track=%s playing=%s pos=%.3f players=%d switching=%s" % [
		str(am.call("get_current_bgm")),
		str(bgm.playing if bgm else false),
		float(am.call("get_bgm_playback_position")),
		players,
		str(am.call("is_bgm_switching")),
	])

	# Inspect what play_sfx does to stream identity.
	var cache: Dictionary = am.get("_sfx_stream_cache")
	var base_click = cache.get("ui_click", null)
	print("CACHE ui_click=%s type=%s" % [str(base_click != null), str(base_click.get_class() if base_click else "?")])

	var pos0: float = float(am.call("get_bgm_playback_position"))
	var stream0 = bgm.stream if bgm else null
	var track0 := str(am.call("get_current_bgm"))

	# Time a burst of UI clicks (same path as UIStyle button pressed).
	var max_call_us := 0
	var sum_call_us := 0
	var n := 24
	var max_gap_ms := 0.0
	for i in n:
		var t0 := Time.get_ticks_usec()
		am.call("play_ui_click")
		var dt := int(Time.get_ticks_usec() - t0)
		sum_call_us += dt
		if dt > max_call_us:
			max_call_us = dt
		var a := Time.get_ticks_usec()
		await process_frame
		var gap := float(Time.get_ticks_usec() - a) / 1000.0
		if gap > max_gap_ms:
			max_gap_ms = gap

	var pos1: float = float(am.call("get_bgm_playback_position"))
	var stream1 = bgm.stream if bgm else null
	var track1 := str(am.call("get_current_bgm"))
	var paused := bool(bgm.stream_paused) if bgm else false

	# Check if SFX / UI click voices hold duplicated stream instances.
	var sfx_arr = am.get("_sfx_players")
	var dup_count := 0
	var same_as_cache := 0
	var assigned := 0
	if sfx_arr is Array:
		for p in sfx_arr:
			if p is AudioStreamPlayer and p.stream != null:
				assigned += 1
				if base_click != null and p.stream == base_click:
					same_as_cache += 1
				elif base_click != null and p.stream != base_click:
					dup_count += 1
	var ui_click: AudioStreamPlayer = am.get("_ui_click")
	var ui_same := false
	var ui_dup := false
	if ui_click and ui_click.stream != null and base_click != null:
		ui_same = ui_click.stream == base_click
		ui_dup = ui_click.stream != base_click

	print("CLICK_BURST n=%d avg_us=%.1f max_us=%d max_frame_gap_ms=%.2f" % [
		n, float(sum_call_us) / float(n), max_call_us, max_gap_ms
	])
	print("SFX_STREAM_ASSIGN pool_assigned=%d same_as_cache=%d duplicated_vs_cache=%d ui_click_same=%s ui_click_dup=%s" % [
		assigned, same_as_cache, dup_count, str(ui_same), str(ui_dup)
	])
	print("BGM_AFTER track=%s pos=%.3f→%.3f stream_same=%s paused=%s" % [
		track1, pos0, pos1, str(stream1 == stream0), str(paused)
	])

	if track1 != track0:
		print("FAIL: BGM track changed"); _failed += 1
	elif stream1 != stream0:
		print("FAIL: BGM stream replaced"); _failed += 1
	elif paused:
		print("FAIL: BGM paused by clicks"); _failed += 1
	elif pos0 > 0.2 and pos1 < 0.05:
		print("FAIL: BGM seeked to start"); _failed += 1
	elif pos1 + 0.02 < pos0:
		print("FAIL: BGM pos went backwards"); _failed += 1
	else:
		print("PASS: BGM continuity across click burst")

	if dup_count > 0 or ui_dup:
		print("FINDING: play path assigns duplicated SFX streams (per-click alloc risk)")
	elif ui_same:
		print("FINDING: UiClickPlayer reuses cached stream (no per-click duplicate)")
	elif same_as_cache > 0:
		print("FINDING: SFX voices reuse cached stream (no per-click duplicate)")
	else:
		print("FINDING: no SFX/UI streams assigned after burst")

	# Registered sample?
	if base_click != null and AudioServer.has_method("is_stream_registered_as_sample"):
		print("SAMPLE_REGISTERED ui_click=%s" % str(AudioServer.is_stream_registered_as_sample(base_click)))

	print("=== diagnose done fails=%d ===" % _failed)
	quit(0 if _failed == 0 else 1)


func _count_am_players(n: Node) -> int:
	var c := 0
	if n is AudioStreamPlayer:
		c += 1
	for ch in n.get_children():
		c += _count_am_players(ch)
	return c
