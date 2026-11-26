extends SceneTree

## Focused probe: PR #10 null-safe load vs combat BGM priority/shuffle/_switching.
## godot4 --headless --path . -s res://scripts/core/validate_audio_nullsafe_bgm.gd


func _init() -> void:
	call_deferred("_run")


func _pass(msg: String) -> void:
	print("PASS: ", msg)


func _wait_switch(audio: Node, ms: int = 4500) -> bool:
	var deadline: int = Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
		if not bool(audio.call("is_bgm_switching")):
			await create_timer(0.05).timeout
			return true
	return false


func _run() -> void:
	await process_frame
	var failed := 0
	var audio: Node = root.get_node_or_null("/root/AudioManager")
	if audio == null:
		print("FAIL: AudioManager missing")
		quit(1)
		return

	# --- File load matrix (same paths AudioManager uses) ---
	var paths: Dictionary = audio.get("BGM_PATHS")
	for key in paths.keys():
		var p: String = str(paths[key])
		var exists := ResourceLoader.exists(p)
		var loaded: Resource = load(p) if exists else null
		var ok := exists and loaded != null and (loaded is AudioStream)
		print("LOAD[%s] exists=%s load_ok=%s type=%s path=%s" % [
			key, exists, ok,
			loaded.get_class() if loaded else "null",
			p,
		])
		if not ok:
			print("FAIL: BGM path not loadable: ", key)
			failed += 1
	var amb_path: String = str(audio.get("SFX_PATHS")["ambience"])
	var amb: Resource = load(amb_path)
	print("LOAD[ambience] exists=%s load_ok=%s" % [
		ResourceLoader.exists(amb_path), amb != null and amb is AudioStream
	])
	if amb == null or not (amb is AudioStream):
		print("FAIL: ambience not loadable")
		failed += 1
	else:
		_pass("All BGM_PATHS + ambience load as AudioStream")

	audio.call("unlock_audio")

	# --- Call graph: playlist → _switch_to_track → _apply_stream ---
	audio.call("start_combat_playlist", true)
	await _wait_switch(audio)
	var bgm: AudioStreamPlayer = audio.get("_bgm")
	var ambience: AudioStreamPlayer = audio.get("_ambience")
	if bool(audio.call("is_bgm_switching")):
		print("FAIL: _switching stuck true after playlist start")
		failed += 1
	else:
		_pass("_switching cleared after playlist start")
	if bgm == null or bgm.stream == null or not bgm.playing:
		print("FAIL: BGM not playing after playlist (stream=%s playing=%s)" % [
			bgm.stream != null if bgm else false,
			bgm.playing if bgm else false,
		])
		failed += 1
	else:
		_pass("Playlist BGM playing after _apply_stream")

	audio.call("start_combat_ambience")
	await process_frame
	if ambience == null or not ambience.playing:
		print("FAIL: ambience not playing alongside BGM")
		failed += 1
	else:
		_pass("BGM + ambience simultaneous (both players playing)")
	if str(audio.call("get_combat_mode")) != "playlist":
		print("FAIL: ambience start altered combat mode")
		failed += 1
	else:
		_pass("Ambience does not leave playlist mode")

	# Shuffle advance must clear _switching each time
	var prev: String = str(audio.call("get_current_bgm"))
	var shuffle_ok := true
	for i in 4:
		audio.call("_on_bgm_finished")
		var cleared := await _wait_switch(audio)
		var cur: String = str(audio.call("get_current_bgm"))
		if not cleared or bool(audio.call("is_bgm_switching")):
			print("FAIL: _switching stuck after shuffle step %d" % i)
			failed += 1
			shuffle_ok = false
			break
		if cur == "" or cur == prev:
			print("FAIL: shuffle did not advance (prev=%s cur=%s)" % [prev, cur])
			failed += 1
			shuffle_ok = false
			break
		if bgm.stream == null or not bgm.playing:
			print("FAIL: silent after shuffle step %d" % i)
			failed += 1
			shuffle_ok = false
			break
		prev = cur
	if shuffle_ok:
		_pass("Shuffle advances + clears _switching each step")

	# Boss priority (implemented policy: mid+final → combat_boss)
	root.set_meta("dungeon_id", "shadow_crypt")
	root.set_meta("dungeon_floor", 5)
	var gs: Node = root.get_node_or_null("/root/GameState")
	if gs:
		gs.call("new_game")
	audio.call("on_enter_combat")
	await _wait_switch(audio)
	if str(audio.call("get_current_bgm")) != "combat_boss" or str(audio.call("get_combat_mode")) != "boss":
		print("FAIL: F5 mid not combat_boss (got %s/%s)" % [
			audio.call("get_combat_mode"), audio.call("get_current_bgm")
		])
		failed += 1
	elif bool(audio.call("is_bgm_switching")):
		print("FAIL: _switching stuck after boss enter")
		failed += 1
	else:
		_pass("F5 → combat_boss; _switching clear")
	if ambience and not ambience.playing:
		# on_enter_combat restarts ambience
		print("NOTE: ambience not playing right after boss enter — checking restart")
	audio.call("start_combat_ambience")
	await process_frame
	if ambience and ambience.playing and bgm.playing:
		_pass("Boss BGM + ambience simultaneous")
	else:
		print("FAIL: boss BGM/ambience not both playing")
		failed += 1

	# Boss → normal restore
	root.set_meta("dungeon_floor", 1)
	audio.call("on_enter_combat")
	await _wait_switch(audio)
	if str(audio.call("get_combat_mode")) != "playlist":
		print("FAIL: boss→normal did not restore playlist (got %s)" % audio.call("get_combat_mode"))
		failed += 1
	elif str(audio.call("get_current_bgm")) == "combat_boss":
		print("FAIL: still on combat_boss after F1")
		failed += 1
	elif bool(audio.call("is_bgm_switching")):
		print("FAIL: _switching stuck after boss→normal")
		failed += 1
	else:
		_pass("Boss→normal restores playlist; _switching clear")

	# Final boss
	root.set_meta("dungeon_floor", 10)
	audio.call("on_enter_combat")
	await _wait_switch(audio)
	if str(audio.call("get_current_bgm")) != "combat_boss":
		print("FAIL: F10 not combat_boss")
		failed += 1
	else:
		_pass("F10 → combat_boss")

	# Simulated null-load path must not leave _switching true
	audio.call("start_combat_playlist", true)
	await _wait_switch(audio)
	audio.set("_switching", true)
	audio.call("_apply_stream", "combat_epic", "res://assets/audio/bgm/__missing_nullsafe_probe__.ogg", false)
	await process_frame
	if bool(audio.call("is_bgm_switching")):
		print("FAIL: null-safe path left _switching=true")
		failed += 1
	else:
		_pass("Null/missing load path clears _switching")

	# Successful _apply_stream must not clear switching itself when fade owns it —
	# but playlist natural advance uses with_fade=true from finished with prev playing.
	# Direct apply after forced switching=true then fade_in path:
	audio.set("_switching", true)
	var epic_path: String = str(paths["combat_epic"])
	audio.call("_apply_stream", "combat_epic", epic_path, false)
	# Success path leaves _switching as caller left it (true) — intentional for fade_in ownership.
	if not bool(audio.call("is_bgm_switching")):
		print("NOTE: success _apply_stream cleared switching (unexpected but not sticky-false)")
	audio.set("_switching", false)
	if bgm.stream != null and bgm.playing:
		_pass("Successful _apply_stream still assigns+plays stream")
	else:
		print("FAIL: successful _apply_stream did not play")
		failed += 1

	# Diff vs stated product table (mid=heroic, elite=metal) — report only, not fail suite
	print("POLICY_NOTE: implemented v3 treats mid+final as combat_boss; no elite→combat_metal selector in AudioManager.on_enter_combat")
	print("POLICY_NOTE: stated mid→combat_heroic / elite→combat_metal is NOT implemented on main (pre-dates null-safe)")

	if failed == 0:
		print("=== NULLSAFE BGM PROBE: PASS ===")
		quit(0)
	else:
		print("=== NULLSAFE BGM PROBE: FAIL (%d) ===" % failed)
		quit(1)
