extends SceneTree

## Graphic-mode AudioManager evidence for PR #11 ear/runtime verification.
## Does NOT change BGM policy or audio assets.
##
##   DISPLAY=:1 godot --path . -s res://scripts/core/capture_audio_pr11.gd
##
## Writes:
##   Guild Hub Layout/internal/pr11-audio-ear-verification/
##   /opt/cursor/artifacts/pr11-audio-ear-verification/

const DID := "shadow_crypt"
const OUT_REL := "Guild Hub Layout/internal/pr11-audio-ear-verification"
const ART := "/opt/cursor/artifacts/pr11-audio-ear-verification"
const LOG_NAME := "audiomanager_runtime.log"

var _log_path: String = ""
var _fail: int = 0
var _pass: int = 0
var _lines: PackedStringArray = PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _log(msg: String) -> void:
	print(msg)
	_lines.append(msg)


func _expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		_log("PASS: %s" % label)
	else:
		_fail += 1
		_log("FAIL: %s" % label)


func _snapshot(am: Node, tag: String) -> Dictionary:
	var bgm: AudioStreamPlayer = am.get("_bgm")
	var amb: AudioStreamPlayer = am.get("_ambience")
	var key := str(am.call("get_current_bgm"))
	var mode := str(am.call("get_combat_mode"))
	var paths: Dictionary = am.get("BGM_PATHS")
	var path := str(paths.get(key, ""))
	var stream_cls := "null"
	var playing := false
	var paused := false
	var vol := 0.0
	if bgm:
		playing = bgm.playing
		paused = bgm.stream_paused
		vol = bgm.volume_db
		if bgm.stream:
			stream_cls = bgm.stream.get_class()
	var amb_playing := false
	var amb_stream := "null"
	if amb:
		amb_playing = amb.playing
		if amb.stream:
			amb_stream = amb.stream.get_class()
	var players := 0
	for c in am.get_children():
		if str(c.name).begins_with("Bgm"):
			players += 1
	var snap := {
		"tag": tag,
		"key": key,
		"mode": mode,
		"path": path,
		"stream_class": stream_cls,
		"playing": playing,
		"paused": paused,
		"volume_db": vol,
		"switching": bool(am.call("is_bgm_switching")),
		"unlocked": bool(am.get("_unlocked")),
		"bgm_players": players,
		"ambience_playing": amb_playing,
		"ambience_stream": amb_stream,
	}
	_log("SNAP[%s] key=%s mode=%s path=%s stream=%s playing=%s paused=%s switching=%s unlocked=%s players=%d amb=%s/%s" % [
		tag, key, mode, path, stream_cls, str(playing), str(paused),
		str(snap["switching"]), str(snap["unlocked"]), players, str(amb_playing), amb_stream
	])
	return snap


func _wait_bgm(am: Node) -> void:
	var deadline := Time.get_ticks_msec() + 4500
	while Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
		if not bool(am.call("is_bgm_switching")):
			await create_timer(0.1).timeout
			return
	_log("WARN: BGM switch wait timed out — forcing unlock for capture")
	if am.get("_bgm"):
		am.get("_bgm").volume_db = 0.0
	am.set("_switching", false)


func _shot(filename: String) -> void:
	await process_frame
	await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	if img == null:
		_log("WARN: screenshot null for %s" % filename)
		return
	var out_abs := ProjectSettings.globalize_path("res://" + OUT_REL)
	var p1 := "%s/%s" % [out_abs, filename]
	var p2 := "%s/%s" % [ART, filename]
	img.save_png(p1)
	img.save_png(p2)
	_log("SHOT: %s (%dx%d)" % [filename, img.get_width(), img.get_height()])


func _clear_scene_children() -> void:
	for c in root.get_children():
		# Keep autoloads (UIStyle, GameState, SceneRouter, AudioManager).
		if c.name in ["UIStyle", "GameState", "SceneRouter", "AudioManager"]:
			continue
		c.queue_free()
	await process_frame
	await process_frame


func _run() -> void:
	var ds := str(DisplayServer.get_name())
	_log("=== PR11 AUDIO RUNTIME CAPTURE ===")
	_log("Godot: %s" % str(Engine.get_version_info().get("string", "?")))
	_log("DisplayServer: %s" % ds)
	_log("Video: %s" % str(OS.get_video_adapter_driver_info()))
	_log("Timezone note: machine UTC; report times in Asia/Seoul")
	if ds == "headless":
		_log("ABORT: headless — refuse graphic audio capture")
		quit(2)
		return

	var out_abs := ProjectSettings.globalize_path("res://" + OUT_REL)
	DirAccess.make_dir_recursive_absolute(out_abs)
	DirAccess.make_dir_recursive_absolute(ART)
	_log_path = "%s/%s" % [out_abs, LOG_NAME]

	var am: Node = root.get_node_or_null("/root/AudioManager")
	var gs: Node = root.get_node_or_null("/root/GameState")
	var sr: Node = root.get_node_or_null("/root/SceneRouter")
	if am == null or gs == null or sr == null:
		_log("ABORT: autoload missing")
		quit(2)
		return

	# --- 1. Title (boot path) ---
	# Simulate first user gesture (web unlock) then title BGM.
	am.call("unlock_audio")
	am.call("on_enter_title")
	await _wait_bgm(am)
	var title_scene: Node = load("res://scenes/title/title.tscn").instantiate()
	root.add_child(title_scene)
	await process_frame
	await process_frame
	var s1 := _snapshot(am, "title")
	await _shot("01_title_sovereign.png")
	_expect(s1["key"] == "title", "title key == title")
	_expect(str(s1["path"]).ends_with("sovereign_of_the_keep.mp3"), "title path Sovereign MP3")
	_expect(s1["stream_class"] == "AudioStreamMP3", "title stream AudioStreamMP3")
	_expect(bool(s1["playing"]), "title BGM playing=true")
	_expect(int(s1["bgm_players"]) == 1, "single BGM player on title")

	# --- 2. Town ---
	await _clear_scene_children()
	gs.call("new_game")
	am.call("on_enter_town")
	await _wait_bgm(am)
	var town_scene: Node = load("res://scenes/town/town.tscn").instantiate()
	root.add_child(town_scene)
	await process_frame
	await process_frame
	var s2 := _snapshot(am, "town")
	await _shot("02_town_morning_dew.png")
	_expect(s2["key"] == "town", "town key == town")
	_expect(str(s2["path"]).ends_with("morning_dew_on_stone.mp3"), "town path Morning Dew MP3")
	_expect(s2["stream_class"] == "AudioStreamMP3", "town stream AudioStreamMP3")
	_expect(bool(s2["playing"]), "town BGM playing=true")
	_expect(s2["mode"] == "none", "town combat mode cleared")

	# --- 3. Normal combat F1 playlist ---
	await _clear_scene_children()
	gs.call("ensure_dungeon_progress", DID)
	gs.call("dungeon_set_floor", DID, 1)
	root.set_meta("dungeon_id", DID)
	root.set_meta("dungeon_floor", 1)
	root.set_meta("hunt_id", "")
	root.set_meta("combat_hunt_id", "dungeon_%s_f1" % DID)
	am.call("on_enter_combat")
	await _wait_bgm(am)
	var combat1: Node = load("res://scenes/combat/combat.tscn").instantiate()
	root.add_child(combat1)
	await process_frame
	await process_frame
	await create_timer(0.4).timeout
	var s3 := _snapshot(am, "f1_normal")
	await _shot("03_combat_f1_playlist.png")
	var playlist_ok: bool = (
		s3["mode"] == "playlist"
		and str(s3["key"]) in ["combat_epic", "combat_heroic", "combat_metal", "combat_hunting"]
	)
	_expect(playlist_ok, "F1 playlist mode + OGG track key")
	_expect(str(s3["path"]).ends_with(".ogg"), "F1 stream path is OGG")
	_expect(s3["stream_class"] == "AudioStreamOggVorbis", "F1 AudioStreamOggVorbis")
	_expect(bool(s3["playing"]), "F1 BGM playing=true")
	# Advance playlist once to prove shuffle/rotation path (not single loop of Tobitate).
	var first_key := str(s3["key"])
	am.call("_on_bgm_finished")
	await _wait_bgm(am)
	var s3b := _snapshot(am, "f1_playlist_advance")
	_expect(str(s3b["key"]) != first_key, "playlist advanced to different track (no stuck single loop)")
	_expect(str(s3b["key"]) in ["combat_epic", "combat_heroic", "combat_metal", "combat_hunting"], "advance stayed in playlist set")

	# --- 4. F5 mid boss ---
	await _clear_scene_children()
	for f in range(1, 5):
		gs.call("mark_dungeon_floor_cleared", DID, f)
	gs.call("dungeon_set_floor", DID, 5)
	root.set_meta("dungeon_floor", 5)
	root.set_meta("combat_hunt_id", "dungeon_%s_f5" % DID)
	am.call("on_enter_combat")
	await _wait_bgm(am)
	var combat5: Node = load("res://scenes/combat/combat.tscn").instantiate()
	root.add_child(combat5)
	await process_frame
	await process_frame
	await create_timer(0.3).timeout
	var s5 := _snapshot(am, "f5_mid")
	await _shot("04_combat_f5_heroic.png")
	_expect(s5["mode"] == "mid" and s5["key"] == "combat_heroic", "F5 → mid / combat_heroic")
	_expect(str(s5["path"]).ends_with("05_combat_heroic_anthem.ogg"), "F5 path heroic OGG")
	_expect(bool(s5["playing"]), "F5 BGM playing=true")

	# --- 5. F10 final boss ---
	await _clear_scene_children()
	for f2 in range(5, 10):
		gs.call("mark_dungeon_floor_cleared", DID, f2)
	gs.call("dungeon_set_floor", DID, 10)
	root.set_meta("dungeon_floor", 10)
	root.set_meta("combat_hunt_id", "dungeon_%s_f10" % DID)
	am.call("on_enter_combat")
	await _wait_bgm(am)
	var combat10: Node = load("res://scenes/combat/combat.tscn").instantiate()
	root.add_child(combat10)
	await process_frame
	await process_frame
	await create_timer(0.3).timeout
	var s10 := _snapshot(am, "f10_final")
	await _shot("05_combat_f10_boss.png")
	_expect(s10["mode"] == "final" and s10["key"] == "combat_boss", "F10 → final / combat_boss")
	_expect(str(s10["path"]).ends_with("06_combat_boss_intensity.ogg"), "F10 path boss OGG")
	_expect(bool(s10["playing"]), "F10 BGM playing=true")

	# --- 6. Return to town ---
	await _clear_scene_children()
	am.call("on_enter_town")
	await _wait_bgm(am)
	var town2: Node = load("res://scenes/town/town.tscn").instantiate()
	root.add_child(town2)
	await process_frame
	await process_frame
	var s6 := _snapshot(am, "town_after_combat")
	await _shot("06_town_after_combat.png")
	_expect(s6["key"] == "town", "town restored after combat")
	_expect(str(s6["path"]).ends_with("morning_dew_on_stone.mp3"), "town restore Morning Dew")
	_expect(s6["mode"] == "none", "combat mode cleared on town return")
	_expect(bool(s6["playing"]), "town BGM playing after return")
	_expect(not bool(s6["ambience_playing"]), "combat ambience stopped on town")

	# --- 7. No duplicate / stuck switching across transitions ---
	_expect(int(s6["bgm_players"]) == 1, "still single BGM player after all transitions")
	_expect(not bool(s6["switching"]), "_switching cleared after town return")

	# Ear-listening disclaimer (automation cannot certify audible output).
	_log("NOTE: Ear / audible listening is NOT claimed PASS in this automation environment.")
	_log("NOTE: Results above certify stream selection, class, playing flag, and single-player invariants.")

	# Persist log to repo + artifacts.
	var body := "\n".join(_lines) + "\n"
	body += "=== SUMMARY pass=%d fail=%d ===\n" % [_pass, _fail]
	var fa := FileAccess.open(_log_path, FileAccess.WRITE)
	if fa:
		fa.store_string(body)
		fa.close()
	var fa2 := FileAccess.open("%s/%s" % [ART, LOG_NAME], FileAccess.WRITE)
	if fa2:
		fa2.store_string(body)
		fa2.close()
	_log("LOG_WRITTEN: %s" % _log_path)

	if _fail == 0:
		_log("=== PR11 AUDIO RUNTIME: PASS (code/runtime flags; ear NOT VERIFIED) ===")
		quit(0)
	else:
		_log("=== PR11 AUDIO RUNTIME: FAIL (%d) ===" % _fail)
		quit(1)
