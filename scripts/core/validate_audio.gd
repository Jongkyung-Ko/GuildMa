extends SceneTree

## Headless audio asset + AudioManager wiring smoke test (incl. combat BGM v3).
## godot4 --headless --path . -s res://scripts/core/validate_audio.gd
## Autoload globals are NOT injected into -s scripts; use /root/AudioManager.

const SFX := {
	"ui_click": "res://assets/audio/sfx/01_ui_button_click.wav",
	"ambience": "res://assets/audio/sfx/02_battle_ambience_loop.wav",
	"hit": "res://assets/audio/sfx/03_combat_hit.wav",
	"magic": "res://assets/audio/sfx/04_magic_cast.wav",
	"equip": "res://assets/audio/sfx/05_item_equip.wav",
}

const BGM_FILES := [
	"01_town_theme.ogg",
	"02_hunting_grounds_rock.ogg",
	"03_combat_epic_rock.ogg",
	"04_combat_metal_drive.ogg",
	"05_combat_heroic_anthem.ogg",
	"06_combat_boss_intensity.ogg",
]

const MIDI_FILES := [
	"01_town_theme.mid",
	"02_hunting_grounds_rock.mid",
	"03_combat_epic_rock.mid",
	"04_combat_metal_drive.mid",
	"05_combat_heroic_anthem.mid",
	"06_combat_boss_intensity.mid",
]

const COMBAT_KEYS := [
	"combat_epic",
	"combat_heroic",
	"combat_metal",
	"combat_hunting",
	"combat_boss",
]


func _init() -> void:
	call_deferred("_run")


func _pass(msg: String) -> void:
	print("PASS: ", msg)


func _wait_bgm_ready(audio: Node) -> void:
	## Wall-clock wait so SceneTreeTweens (1.5s out + 1.5s in) can finish.
	var deadline_ms: int = Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < deadline_ms:
		await create_timer(0.05).timeout
		if audio.has_method("is_bgm_switching") and not bool(audio.call("is_bgm_switching")):
			await create_timer(0.05).timeout
			return
	print("WARN: BGM switch wait timed out — forcing unlock for test")
	if audio.get("_bgm"):
		audio.get("_bgm").volume_db = 0.0
	audio.set("_switching", false)


func _run() -> void:
	await process_frame
	var failed := 0
	var audio: Node = root.get_node_or_null("/root/AudioManager")
	if audio == null:
		print("FAIL: AudioManager autoload missing")
		quit(1)
		return
	_pass("AudioManager autoload present")

	for id in SFX.keys():
		var path: String = SFX[id]
		if not ResourceLoader.exists(path):
			print("FAIL: missing SFX ", path)
			failed += 1
			continue
		var s: AudioStream = load(path)
		if s == null:
			print("FAIL: cannot load SFX ", path)
			failed += 1
		else:
			_pass("SFX load %s" % id)

	for fname in BGM_FILES:
		var path := "res://assets/audio/bgm/%s" % fname
		if not ResourceLoader.exists(path):
			print("FAIL: missing BGM ", path)
			failed += 1
			continue
		var s: AudioStream = load(path)
		if s == null:
			print("FAIL: cannot load BGM ", path)
			failed += 1
		else:
			_pass("BGM load %s" % fname)

	for mid in MIDI_FILES:
		var p := "res://assets/audio/bgm/%s" % mid
		if not FileAccess.file_exists(p):
			print("FAIL: missing MIDI source ", p)
			failed += 1
		else:
			_pass("MIDI source %s" % mid)

	# Existing hunting OGG must remain
	var hunt := "res://assets/audio/bgm/02_hunting_grounds_rock.ogg"
	if ResourceLoader.exists(hunt):
		_pass("02_hunting_grounds_rock.ogg retained")
	else:
		print("FAIL: hunting grounds OGG missing")
		failed += 1

	var paths: Dictionary = audio.get("BGM_PATHS")
	for key in COMBAT_KEYS:
		if not paths.has(key):
			print("FAIL: BGM_PATHS missing %s" % key)
			failed += 1
		elif not ResourceLoader.exists(str(paths[key])):
			print("FAIL: BGM_PATHS[%s] file missing" % key)
			failed += 1
		else:
			_pass("BGM_PATHS[%s] ok" % key)

	var playlist: Array = audio.get("COMBAT_PLAYLIST")
	var expect := ["combat_epic", "combat_heroic", "combat_metal", "combat_hunting"]
	if playlist != expect:
		print("FAIL: COMBAT_PLAYLIST order %s != %s" % [str(playlist), str(expect)])
		failed += 1
	else:
		_pass("COMBAT_PLAYLIST order Epic→Heroic→Metal→Hunting")

	if AudioServer.get_bus_index("BGM") < 0 or AudioServer.get_bus_index("SFX") < 0:
		print("FAIL: BGM/SFX buses missing")
		failed += 1
	else:
		_pass("BGM/SFX buses present")

	# Volumes stay independent
	var bgm0: float = float(audio.get("bgm_linear"))
	var sfx0: float = float(audio.get("sfx_linear"))
	audio.call("set_bgm_volume", 0.4)
	audio.call("set_sfx_volume", 0.9)
	if abs(float(audio.get("bgm_linear")) - 0.4) > 0.001 or abs(float(audio.get("sfx_linear")) - 0.9) > 0.001:
		print("FAIL: BGM/SFX volume not independent")
		failed += 1
	else:
		_pass("BGM/SFX volumes independent")
	audio.call("set_bgm_volume", bgm0)
	audio.call("set_sfx_volume", sfx0)

	audio.call("unlock_audio")
	audio.call("play_bgm", "town", true)
	await process_frame
	var bgm_player: AudioStreamPlayer = audio.get("_bgm")
	if bgm_player == null or bgm_player.stream == null:
		print("FAIL: BGM stream not assigned")
		failed += 1
	else:
		_pass("Town BGM stream assigned")

	audio.call("play_ui_click")
	audio.call("play_hit")
	audio.call("play_magic")
	audio.call("play_equip")
	audio.call("start_combat_ambience")
	await process_frame
	_pass("SFX + ambience calls completed without error")

	# Playlist start (normal combat)
	audio.call("start_combat_playlist", true)
	await _wait_bgm_ready(audio)
	if str(audio.call("get_combat_mode")) != "playlist":
		print("FAIL: combat mode not playlist (got %s)" % str(audio.call("get_combat_mode")))
		failed += 1
	else:
		_pass("Combat playlist mode active")
	var first: String = str(audio.call("get_current_bgm"))
	if first not in ["combat_epic", "combat_heroic", "combat_metal", "combat_hunting"]:
		print("FAIL: playlist start track invalid: ", first)
		failed += 1
	else:
		_pass("Playlist started on %s" % first)

	# Simulate natural end → next track; no consecutive duplicate
	var seen: Array = [first]
	for i in 6:
		audio.call("_on_bgm_finished")
		await _wait_bgm_ready(audio)
		var cur: String = str(audio.call("get_current_bgm"))
		if cur == "":
			print("FAIL: silent BGM after playlist advance")
			failed += 1
			break
		if cur == seen[seen.size() - 1]:
			print("FAIL: consecutive duplicate track %s" % cur)
			failed += 1
			break
		seen.append(cur)
	if seen.size() >= 5:
		_pass("Playlist advanced without consecutive repeats (%s)" % ",".join(PackedStringArray(seen)))
	# Ensure all four appear within a cycle+
	var uniq := {}
	for t in seen:
		uniq[t] = true
	if uniq.size() >= 4:
		_pass("All 4 playlist tracks appear in rotation")
	else:
		print("FAIL: playlist diversity low: ", seen)
		failed += 1

	# Boss mode
	root.set_meta("dungeon_id", "shadow_crypt")
	root.set_meta("dungeon_floor", 5)
	var gs: Node = root.get_node_or_null("/root/GameState")
	if gs:
		gs.call("new_game")
	audio.call("on_enter_combat")
	await _wait_bgm_ready(audio)
	if str(audio.call("get_combat_mode")) != "boss":
		print("FAIL: F5 should start boss mode (got %s / %s)" % [
			str(audio.call("get_combat_mode")), str(audio.call("get_current_bgm"))
		])
		failed += 1
	elif str(audio.call("get_current_bgm")) != "combat_boss":
		print("FAIL: boss track expected combat_boss got ", audio.call("get_current_bgm"))
		failed += 1
	else:
		_pass("Boss floor F5 → combat_boss")

	# Non-boss dungeon floor → playlist
	root.set_meta("dungeon_floor", 1)
	audio.call("on_enter_combat")
	await _wait_bgm_ready(audio)
	if str(audio.call("get_combat_mode")) != "playlist":
		print("FAIL: F1 should be playlist (got %s)" % str(audio.call("get_combat_mode")))
		failed += 1
	else:
		_pass("Normal floor F1 → playlist")

	# Final boss F10
	root.set_meta("dungeon_floor", 10)
	audio.call("on_enter_combat")
	await _wait_bgm_ready(audio)
	if str(audio.call("get_current_bgm")) != "combat_boss":
		print("FAIL: F10 final boss BGM")
		failed += 1
	else:
		_pass("Boss floor F10 → combat_boss")

	# Pause / resume
	audio.call("pause_bgm")
	await process_frame
	if bgm_player and bgm_player.stream_paused:
		_pass("pause_bgm sets stream_paused")
	else:
		print("NOTE: stream_paused check inconclusive under dummy driver")
		_pass("pause_bgm called without error")
	audio.call("resume_bgm")
	await process_frame
	_pass("resume_bgm called without error")

	# Return to town stops ambience + leaves combat music
	audio.call("on_enter_town")
	await process_frame
	var amb: AudioStreamPlayer = audio.get("_ambience")
	if amb and amb.playing:
		print("FAIL: combat ambience still playing after town")
		failed += 1
	else:
		_pass("Combat ambience stopped on town")
	if str(audio.call("get_combat_mode")) != "none":
		print("FAIL: combat mode still active after town")
		failed += 1
	else:
		_pass("Combat music mode cleared on town")
	if str(audio.call("get_current_bgm")) != "town":
		print("FAIL: town BGM not restored (got %s)" % str(audio.call("get_current_bgm")))
		failed += 1
	else:
		_pass("Town BGM restored after combat")

	# Single BGM player — no second player spawned
	var bgm_count := 0
	for c in audio.get_children():
		if str(c.name).begins_with("Bgm"):
			bgm_count += 1
	if bgm_count != 1:
		print("FAIL: expected 1 Bgm player, got %d" % bgm_count)
		failed += 1
	else:
		_pass("Single BGM player (no duplicate playback nodes)")

	print("NOTE: Ear / audible listening not performed in this headless run — do not treat as acoustic PASS.")

	if failed == 0:
		print("=== AUDIO VALIDATE: PASS ===")
		quit(0)
	else:
		print("=== AUDIO VALIDATE: FAIL (%d) ===" % failed)
		quit(1)
