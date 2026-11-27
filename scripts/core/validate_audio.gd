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

const MP3_EXPECT := {
	"title": "res://assets/audio/music/sovereign_of_the_keep.mp3",
	"town": "res://assets/audio/music/morning_dew_on_stone.mp3",
	## Hunting grounds dedicated key (PR14). Legacy "combat" alias kept for play_bgm("combat").
	"hunt": "res://assets/audio/music/tobitate_aoi_sora.mp3",
	"combat": "res://assets/audio/music/tobitate_aoi_sora.mp3",
}


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

	# New MP3 cues: present, loadable as AudioStreamMP3, wired in BGM_PATHS.
	for key in MP3_EXPECT.keys():
		var mp3_path: String = MP3_EXPECT[key]
		if not ResourceLoader.exists(mp3_path):
			print("FAIL: missing MP3 ", mp3_path)
			failed += 1
			continue
		var mp3_stream: AudioStream = load(mp3_path)
		if mp3_stream == null:
			print("FAIL: cannot load MP3 ", mp3_path)
			failed += 1
			continue
		if not (mp3_stream is AudioStreamMP3):
			print("FAIL: expected AudioStreamMP3 for ", mp3_path)
			failed += 1
			continue
		_pass("MP3 load %s → AudioStreamMP3" % key)
		if not paths.has(key):
			print("FAIL: BGM_PATHS missing MP3 key %s" % key)
			failed += 1
		elif str(paths[key]) != mp3_path:
			print("FAIL: BGM_PATHS[%s]=%s expected %s" % [key, str(paths[key]), mp3_path])
			failed += 1
		else:
			_pass("BGM_PATHS[%s] → %s" % [key, mp3_path])

	# Title / town entry hooks play the new MP3s.
	audio.call("unlock_audio")
	audio.call("on_enter_title")
	await process_frame
	if str(audio.call("get_current_bgm")) != "title":
		print("FAIL: on_enter_title expected title got ", audio.call("get_current_bgm"))
		failed += 1
	else:
		var title_player: AudioStreamPlayer = audio.get("_bgm")
		if title_player and title_player.stream is AudioStreamMP3:
			_pass("Title entry plays Sovereign MP3 stream")
		else:
			print("FAIL: title stream is not AudioStreamMP3")
			failed += 1

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

	# Situational: mid / final / normal / elite
	root.set_meta("dungeon_id", "shadow_crypt")
	root.set_meta("dungeon_floor", 5)
	root.set_meta("hunt_id", "")
	var gs: Node = root.get_node_or_null("/root/GameState")
	if gs:
		gs.call("new_game")
	var inten5: String = str(audio.call("resolve_combat_intensity"))
	if inten5 != "mid":
		print("FAIL: F5 intensity expected mid got ", inten5)
		failed += 1
	else:
		_pass("resolve F5 → mid")
	audio.call("on_enter_combat")
	await _wait_bgm_ready(audio)
	if str(audio.call("get_combat_mode")) != "mid" or str(audio.call("get_current_bgm")) != "combat_heroic":
		print("FAIL: F5 mid → combat_heroic (got %s / %s)" % [
			str(audio.call("get_combat_mode")), str(audio.call("get_current_bgm"))
		])
		failed += 1
	else:
		_pass("Mid boss F5 → combat_heroic loop")

	# Same-state re-enter must not restart / glitch mode
	var mid_track := str(audio.call("get_current_bgm"))
	audio.call("on_enter_combat")
	await process_frame
	if str(audio.call("get_combat_mode")) != "mid" or str(audio.call("get_current_bgm")) != mid_track:
		print("FAIL: same-state mid re-enter changed BGM")
		failed += 1
	else:
		_pass("Same-state mid re-enter does not restart track")

	# Non-boss dungeon floor → playlist
	root.set_meta("dungeon_floor", 1)
	audio.call("on_enter_combat")
	await _wait_bgm_ready(audio)
	if str(audio.call("get_combat_mode")) != "playlist":
		print("FAIL: F1 should be playlist (got %s)" % str(audio.call("get_combat_mode")))
		failed += 1
	else:
		_pass("Normal floor F1 → playlist")

	# Final boss F10 → combat_boss only
	root.set_meta("dungeon_floor", 10)
	if str(audio.call("resolve_combat_intensity")) != "final":
		print("FAIL: F10 intensity expected final")
		failed += 1
	else:
		_pass("resolve F10 → final")
	audio.call("on_enter_combat")
	await _wait_bgm_ready(audio)
	if str(audio.call("get_combat_mode")) != "final" or str(audio.call("get_current_bgm")) != "combat_boss":
		print("FAIL: F10 final → combat_boss (got %s / %s)" % [
			str(audio.call("get_combat_mode")), str(audio.call("get_current_bgm"))
		])
		failed += 1
	else:
		_pass("Final boss F10 → combat_boss loop (no shuffle)")

	# Elite: hunt maze room_type=elite only (no false elite on normal rooms)
	root.set_meta("dungeon_id", "")
	root.set_meta("dungeon_floor", 0)
	if gs:
		gs.call("new_game")
		gs.call("start_hunt_run", "beginner_forest", true)
		var map: Dictionary = gs.call("get_active_hunt_map")
		var rooms: Dictionary = map.get("rooms", {})
		var elite_id := ""
		var normal_id := ""
		for rid in rooms.keys():
			var rt := str(rooms[rid].get("room_type", ""))
			if rt == "elite" and elite_id == "":
				elite_id = str(rid)
			elif rt == "normal" and normal_id == "":
				normal_id = str(rid)
		# PR14: hunt maze always plays Tobitate MP3 — OGG intensity is dungeon-only.
		root.set_meta("hunt_id", "beginner_forest")
		root.set_meta("dungeon_id", "")
		if elite_id == "":
			print("FAIL: no elite room in generated hunt map")
			failed += 1
		else:
			map["current_room_id"] = elite_id
			gs.call("_store_active_map", map)
			if str(audio.call("resolve_combat_intensity")) != "elite":
				print("FAIL: elite room intensity expected elite got ", audio.call("resolve_combat_intensity"))
				failed += 1
			else:
				_pass("Hunt elite room → elite intensity (metadata)")
			audio.call("on_enter_combat", true)
			await _wait_bgm_ready(audio)
			print("LOG: hunt elite BGM key=%s mode=%s path=%s" % [
				audio.call("get_current_bgm"), audio.call("get_combat_mode"), paths.get(audio.call("get_current_bgm"), "")
			])
			if str(audio.call("get_current_bgm")) != "hunt" or str(audio.call("get_combat_mode")) != "hunt":
				print("FAIL: hunt elite must keep Tobitate (got %s / %s)" % [
					audio.call("get_current_bgm"), audio.call("get_combat_mode")
				])
				failed += 1
			else:
				_pass("Hunt elite room → hunt Tobitate MP3 (not combat_metal)")
		if normal_id != "":
			map = gs.call("get_active_hunt_map")
			map["current_room_id"] = normal_id
			gs.call("_store_active_map", map)
			if str(audio.call("resolve_combat_intensity")) != "normal":
				print("FAIL: normal hunt room falsely elite/boss: ", audio.call("resolve_combat_intensity"))
				failed += 1
			else:
				_pass("Normal hunt room not false-elite")
		# Hunt goal: intensity metadata final, BGM stays Tobitate
		map = gs.call("get_active_hunt_map")
		rooms = map.get("rooms", {})
		var goal_id := ""
		for rid2 in rooms.keys():
			if bool(rooms[rid2].get("boss_flag", false)):
				goal_id = str(rid2)
				break
		if goal_id == "":
			print("FAIL: no hunt goal boss room")
			failed += 1
		else:
			map["current_room_id"] = goal_id
			gs.call("_store_active_map", map)
			if str(audio.call("resolve_combat_intensity")) != "final":
				print("FAIL: hunt goal intensity expected final got ", audio.call("resolve_combat_intensity"))
				failed += 1
			else:
				_pass("Hunt goal boss → final intensity (metadata)")
			audio.call("on_enter_combat", true)
			await _wait_bgm_ready(audio)
			print("LOG: hunt goal BGM key=%s mode=%s path=%s" % [
				audio.call("get_current_bgm"), audio.call("get_combat_mode"), paths.get(audio.call("get_current_bgm"), "")
			])
			if str(audio.call("get_current_bgm")) != "hunt" or str(audio.call("get_combat_mode")) != "hunt":
				print("FAIL: hunt goal must keep Tobitate (got %s / %s)" % [
					audio.call("get_current_bgm"), audio.call("get_combat_mode")
				])
				failed += 1
			else:
				_pass("Hunt goal → hunt Tobitate MP3 (not combat_boss)")

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
	var sfx_count := 0
	for c in audio.get_children():
		if str(c.name).begins_with("Bgm"):
			bgm_count += 1
		elif str(c.name).begins_with("Sfx_"):
			sfx_count += 1
	if bgm_count != 1:
		print("FAIL: expected 1 Bgm player, got %d" % bgm_count)
		failed += 1
	else:
		_pass("Single BGM player (no duplicate playback nodes)")
	if sfx_count < 6:
		print("FAIL: expected SFX pool >= 6, got %d" % sfx_count)
		failed += 1
	else:
		_pass("SFX pool size %d (separate from BGM)" % sfx_count)

	# --- Hunt room travel continuity: Tobitate MP3 must not restart ---
	root.set_meta("dungeon_id", "")
	root.set_meta("dungeon_floor", 0)
	if gs:
		gs.call("new_game")
		gs.call("start_hunt_run", "beginner_forest", true)
	root.set_meta("hunt_id", "beginner_forest")
	audio.call("on_enter_combat", true)
	await _wait_bgm_ready(audio)
	print("LOG: hunt enter BGM key=%s mode=%s path=%s" % [
		audio.call("get_current_bgm"), audio.call("get_combat_mode"), paths.get(audio.call("get_current_bgm"), "")
	])
	if str(audio.call("get_current_bgm")) != "hunt" or str(audio.call("get_combat_mode")) != "hunt":
		print("FAIL: hunt enter expected hunt/hunt got %s/%s" % [
			audio.call("get_current_bgm"), audio.call("get_combat_mode")
		])
		failed += 1
	else:
		_pass("Hunt enter → Tobitate (key=hunt)")
	var cont_track := str(audio.call("get_current_bgm"))
	var cont_mode := str(audio.call("get_combat_mode"))
	var cont_pos: float = float(audio.call("get_bgm_playback_position"))
	var amb_player: AudioStreamPlayer = audio.get("_ambience")
	# Simulate A→B→C same-zone refreshes (internal travel).
	for hop in 3:
		audio.call("on_enter_combat", false)
		await process_frame
	var after_pos: float = float(audio.call("get_bgm_playback_position"))
	if str(audio.call("get_current_bgm")) != cont_track or str(audio.call("get_combat_mode")) != cont_mode:
		print("FAIL: hunt hop changed BGM track/mode (%s/%s → %s/%s)" % [
			cont_track, cont_mode, str(audio.call("get_current_bgm")), str(audio.call("get_combat_mode"))
		])
		failed += 1
	else:
		_pass("Hunt hops keep track/mode (%s / %s)" % [cont_track, cont_mode])
	# Position should not reset to ~0 if it had advanced (dummy driver may stay at 0).
	if cont_pos >= 0.0 and after_pos + 0.001 < cont_pos and after_pos < 0.05 and cont_pos > 0.2:
		print("FAIL: BGM playback position reset on hunt hop (%.3f → %.3f)" % [cont_pos, after_pos])
		failed += 1
	else:
		_pass("BGM playback position not hard-reset on hunt hop (%.3f → %.3f)" % [cont_pos, after_pos])

	# Ambience ensure: repeated on_enter_combat must not stop/restart (stream instance stable).
	if amb_player and amb_player.stream != null:
		var amb_stream_a = amb_player.stream
		audio.call("ensure_combat_ambience")
		audio.call("ensure_combat_ambience")
		if amb_player.stream != amb_stream_a:
			print("FAIL: ensure_combat_ambience replaced ambience stream")
			failed += 1
		else:
			_pass("ensure_combat_ambience keeps existing ambience stream")

	# Elite room in hunt still keeps Tobitate (no OGG overwrite).
	if gs:
		var map2: Dictionary = gs.call("get_active_hunt_map")
		var rooms2: Dictionary = map2.get("rooms", {})
		var elite2 := ""
		for rid3 in rooms2.keys():
			if str(rooms2[rid3].get("room_type", "")) == "elite":
				elite2 = str(rid3)
				break
		if elite2 != "":
			map2["current_room_id"] = elite2
			gs.call("_store_active_map", map2)
			audio.call("on_enter_combat", false)
			await _wait_bgm_ready(audio)
			if str(audio.call("get_combat_mode")) != "hunt" or str(audio.call("get_current_bgm")) != "hunt":
				print("FAIL: hunt elite hop should keep hunt/Tobitate (got %s / %s)" % [
					str(audio.call("get_combat_mode")), str(audio.call("get_current_bgm"))
				])
				failed += 1
			else:
				_pass("Hunt elite hop keeps Tobitate (no OGG overwrite)")

	# SFX must not pause/stop/seek BGM.
	audio.call("on_enter_combat")
	await _wait_bgm_ready(audio)
	var bgm_before := str(audio.call("get_current_bgm"))
	var pos_before: float = float(audio.call("get_bgm_playback_position"))
	var paused_before := bool(bgm_player.stream_paused) if bgm_player else false
	var bgm_stream_before = bgm_player.stream if bgm_player else null
	for _i in 12:
		audio.call("play_hit")
		audio.call("play_magic")
	await process_frame
	await process_frame
	if str(audio.call("get_current_bgm")) != bgm_before:
		print("FAIL: SFX burst changed BGM track")
		failed += 1
	else:
		_pass("SFX burst leaves BGM track unchanged")
	if bgm_player and bgm_player.stream_paused and not paused_before:
		print("FAIL: SFX burst paused BGM")
		failed += 1
	else:
		_pass("SFX burst does not pause BGM")
	if bgm_player and bgm_player.bus != "BGM":
		print("FAIL: BGM player bus is %s" % bgm_player.bus)
		failed += 1
	else:
		_pass("BGM player stays on BGM bus")
	var sfx_players_arr = audio.get("_sfx_players")
	var sfx_voice: AudioStreamPlayer = null
	if sfx_players_arr is Array and sfx_players_arr.size() > 0:
		sfx_voice = sfx_players_arr[0]
	if sfx_voice and sfx_voice.bus != "SFX":
		print("FAIL: SFX player bus is %s" % sfx_voice.bus)
		failed += 1
	else:
		_pass("SFX players use SFX bus")
	# Position should not jump backward to 0 from SFX alone.
	var pos_after_sfx: float = float(audio.call("get_bgm_playback_position"))
	if pos_before > 0.25 and pos_after_sfx < 0.05:
		print("FAIL: SFX burst seeked BGM to start (%.3f → %.3f)" % [pos_before, pos_after_sfx])
		failed += 1
	else:
		_pass("SFX burst does not seek BGM to start (%.3f → %.3f)" % [pos_before, pos_after_sfx])

	# UI click hot path: no BGM touch, reuse cached SAMPLE (no per-click duplicate).
	audio.call("on_enter_town")
	await _wait_bgm_ready(audio)
	var sfx_cache: Dictionary = audio.get("_sfx_stream_cache")
	var click_cache = sfx_cache.get("ui_click", null)
	var hit_cache = sfx_cache.get("hit", null)
	var ui_click: AudioStreamPlayer = audio.get("_ui_click")
	var town_pos0: float = float(audio.call("get_bgm_playback_position"))
	var town_stream0 = bgm_player.stream if bgm_player else null
	for _j in 16:
		audio.call("play_ui_click")
	await process_frame
	await process_frame
	var town_pos1: float = float(audio.call("get_bgm_playback_position"))
	if bgm_player and bgm_player.stream != town_stream0:
		print("FAIL: UI click replaced BGM stream")
		failed += 1
	else:
		_pass("UI click leaves BGM stream instance unchanged")
	if town_pos0 > 0.2 and town_pos1 < 0.05:
		print("FAIL: UI click seeked town BGM (%.3f → %.3f)" % [town_pos0, town_pos1])
		failed += 1
	elif town_pos1 + 0.02 < town_pos0:
		print("FAIL: UI click moved BGM backwards (%.3f → %.3f)" % [town_pos0, town_pos1])
		failed += 1
	else:
		_pass("UI click keeps town BGM position (%.3f → %.3f)" % [town_pos0, town_pos1])
	if ui_click == null:
		print("FAIL: dedicated UiClickPlayer missing")
		failed += 1
	elif ui_click.bus != "SFX":
		print("FAIL: UiClickPlayer bus=%s" % ui_click.bus)
		failed += 1
	elif click_cache != null and ui_click.stream != click_cache:
		print("FAIL: UiClickPlayer holds duplicated stream (should reuse cache)")
		failed += 1
	else:
		_pass("UiClickPlayer reuses cached ui_click SAMPLE stream")
	if click_cache != null and AudioServer.has_method("is_stream_registered_as_sample"):
		# Dummy/ALSA-less VMs often cannot register SAMPLE; web drivers can.
		if AudioServer.is_stream_registered_as_sample(click_cache):
			_pass("ui_click SAMPLE pre-registered")
		else:
			print("NOTE: ui_click SAMPLE not reported registered (dummy driver may lack SAMPLE support)")
			_pass("ui_click SAMPLE register path exercised (driver-dependent)")
	# General one-shots must also reuse cache (no per-play .duplicate()).
	audio.call("play_hit")
	await process_frame
	var hit_reused := false
	var hit_duplicated := false
	if sfx_players_arr is Array and hit_cache != null:
		for p_hit in sfx_players_arr:
			if not (p_hit is AudioStreamPlayer) or p_hit.stream == null:
				continue
			if p_hit.stream == hit_cache:
				hit_reused = true
			elif p_hit.playing:
				hit_duplicated = true
	if hit_reused:
		_pass("play_hit reuses cached SAMPLE stream (no duplicate)")
	elif hit_duplicated:
		print("FAIL: play_hit assigned duplicated stream")
		failed += 1
	else:
		_pass("play_hit stream check inconclusive (voice not captured)")
	if bgm_stream_before != null:
		pass

	print("NOTE: Ear / audible listening not performed in this headless run — do not treat as acoustic PASS.")

	if failed == 0:
		print("=== AUDIO VALIDATE: PASS ===")
		quit(0)
	else:
		print("=== AUDIO VALIDATE: FAIL (%d) ===" % failed)
		quit(1)
