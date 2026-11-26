extends Node

## Central SFX / BGM. MIDI sources are kept under assets/audio/bgm/*.mid but
## playback uses FluidSynth-rendered OGG (Godot 4.3 + web have no GM synth).
## Situational combat intensity (final > mid > elite > normal) picks among existing OGGs.
## Normal fights shuffle a playlist with end-of-track fade; higher tiers use dedicated loops.

const SFX_PATHS := {
	"ui_click": "res://assets/audio/sfx/01_ui_button_click.wav",
	"ambience": "res://assets/audio/sfx/02_battle_ambience_loop.wav",
	"hit": "res://assets/audio/sfx/03_combat_hit.wav",
	"magic": "res://assets/audio/sfx/04_magic_cast.wav",
	"equip": "res://assets/audio/sfx/05_item_equip.wav",
}

const BGM_PATHS := {
	## New MP3 cues (title / town). Combat intensity tracks keep OGG pack.
	"title": "res://assets/audio/music/sovereign_of_the_keep.mp3",
	"town": "res://assets/audio/music/morning_dew_on_stone.mp3",
	## Explicit combat cue (MP3). Normal fights still use COMBAT_PLAYLIST shuffle.
	"combat": "res://assets/audio/music/tobitate_aoi_sora.mp3",
	"combat_epic": "res://assets/audio/bgm/03_combat_epic_rock.ogg",
	"combat_metal": "res://assets/audio/bgm/04_combat_metal_drive.ogg",
	"combat_heroic": "res://assets/audio/bgm/05_combat_heroic_anthem.ogg",
	"combat_hunting": "res://assets/audio/bgm/02_hunting_grounds_rock.ogg",
	"combat_boss": "res://assets/audio/bgm/06_combat_boss_intensity.ogg",
}

## Normal combat rotation order (diversity): Epic → Heroic → Metal → Hunting.
const COMBAT_PLAYLIST := [
	"combat_epic",
	"combat_heroic",
	"combat_metal",
	"combat_hunting",
]

const SFX_POOL_SIZE := 6
const FADE_SEC := 1.5

var _bgm: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_idx: int = 0

var _unlocked: bool = false
var _pending_bgm: String = ""
## Pending combat intensity when audio locked: "" | "normal" | "elite" | "mid" | "final"
var _pending_combat_intensity: String = ""
var _pending_ambience: bool = false
var _current_bgm: String = ""

## "none" | "playlist" | "elite" | "mid" | "final"
var _combat_mode: String = "none"
var _playlist_queue: Array[String] = []
var _last_playlist_track: String = ""
var _fade_tween: Tween
var _switching: bool = false
var _finished_connected: bool = false
var _enemy_catalog: Array = []

var bgm_linear: float = 0.72
var sfx_linear: float = 0.85


func _ready() -> void:
	_ensure_buses()
	_load_enemy_catalog()
	_bgm = AudioStreamPlayer.new()
	_bgm.name = "BgmPlayer"
	_bgm.bus = "BGM"
	# Stream mode: full Godot audio path (needed for reliable loop on web Sample limits).
	_bgm.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(_bgm)
	_bgm.finished.connect(_on_bgm_finished)
	_finished_connected = true

	_ambience = AudioStreamPlayer.new()
	_ambience.name = "AmbiencePlayer"
	_ambience.bus = "SFX"
	_ambience.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(_ambience)

	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.name = "Sfx_%d" % i
		p.bus = "SFX"
		p.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		add_child(p)
		_sfx_players.append(p)

	_apply_volumes()
	# Browser autoplay: wait for first user gesture.
	set_process_input(true)


func _ensure_buses() -> void:
	if AudioServer.get_bus_index("BGM") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "BGM")
		AudioServer.set_bus_send(AudioServer.get_bus_index("BGM"), "Master")
	if AudioServer.get_bus_index("SFX") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "SFX")
		AudioServer.set_bus_send(AudioServer.get_bus_index("SFX"), "Master")


func _input(event: InputEvent) -> void:
	if _unlocked:
		return
	if event is InputEventMouseButton and event.pressed:
		unlock_audio()
	elif event is InputEventKey and event.pressed:
		unlock_audio()
	elif event is InputEventScreenTouch and event.pressed:
		unlock_audio()


func unlock_audio() -> void:
	if _unlocked:
		return
	_unlocked = true
	set_process_input(false)
	if _pending_combat_intensity != "":
		var intensity := _pending_combat_intensity
		_pending_combat_intensity = ""
		_apply_combat_intensity(intensity, true)
	elif _pending_bgm != "":
		play_bgm(_pending_bgm, true)
	if _pending_ambience:
		_pending_ambience = false
		start_combat_ambience()


func is_unlocked() -> bool:
	return _unlocked


func set_bgm_volume(linear: float) -> void:
	bgm_linear = clampf(linear, 0.0, 1.0)
	_apply_volumes()


func set_sfx_volume(linear: float) -> void:
	sfx_linear = clampf(linear, 0.0, 1.0)
	_apply_volumes()


func _apply_volumes() -> void:
	var bi := AudioServer.get_bus_index("BGM")
	var si := AudioServer.get_bus_index("SFX")
	if bi >= 0:
		AudioServer.set_bus_volume_db(bi, _linear_to_db(bgm_linear))
	if si >= 0:
		AudioServer.set_bus_volume_db(si, _linear_to_db(sfx_linear))
	# Keep player volume at unity unless mid-fade; bus owns user volume.
	if _bgm and not _switching:
		_bgm.volume_db = 0.0


func _linear_to_db(v: float) -> float:
	if v <= 0.0001:
		return -80.0
	return linear_to_db(v)


func play_bgm(track: String, force: bool = false) -> void:
	if not BGM_PATHS.has(track):
		push_warning("AudioManager: unknown BGM '%s'" % track)
		return
	# Explicit single-track play leaves situational combat rotation (town, legacy "combat", etc.).
	_leave_combat_music_mode()
	if not _unlocked:
		_pending_bgm = track
		_pending_combat_intensity = ""
		return
	if not force and _current_bgm == track and _bgm.playing and not _bgm.stream_paused:
		return
	_switch_to_track(track, true, force)


func stop_bgm() -> void:
	_kill_fade()
	_leave_combat_music_mode()
	_pending_bgm = ""
	_pending_combat_intensity = ""
	_current_bgm = ""
	_switching = false
	if _bgm:
		_bgm.stream_paused = false
		_bgm.volume_db = 0.0
		_bgm.stop()


func pause_bgm() -> void:
	if _bgm and _bgm.playing:
		_bgm.stream_paused = true


func resume_bgm() -> void:
	if _bgm and _bgm.stream:
		_bgm.stream_paused = false
		if not _bgm.playing:
			_bgm.play()


func play_sfx(id: String, volume_scale: float = 1.0) -> void:
	if not SFX_PATHS.has(id):
		return
	# Soft unlock on first SFX from a button (user already interacted).
	if not _unlocked:
		unlock_audio()
	var path: String = SFX_PATHS[id]
	if not ResourceLoader.exists(path):
		push_warning("AudioManager: missing SFX %s" % path)
		return
	var stream: AudioStream = load(path)
	if stream == null:
		return
	var p: AudioStreamPlayer = _sfx_players[_sfx_idx]
	_sfx_idx = (_sfx_idx + 1) % _sfx_players.size()
	p.stop()
	p.stream = stream
	p.volume_db = _linear_to_db(clampf(volume_scale, 0.0, 1.5))
	p.play()


func play_ui_click() -> void:
	play_sfx("ui_click", 0.7)


func play_hit() -> void:
	play_sfx("hit", 0.9)


func play_magic() -> void:
	play_sfx("magic", 1.0)


func play_equip() -> void:
	play_sfx("equip", 0.85)


func start_combat_ambience() -> void:
	var path: String = SFX_PATHS["ambience"]
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStream = (load(path) as AudioStream).duplicate()
	if stream == null:
		return
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	_ambience.stop()
	_ambience.stream = stream
	_ambience.volume_db = _linear_to_db(0.55)
	if not _unlocked:
		_pending_ambience = true
		return
	_pending_ambience = false
	_ambience.play()


func stop_combat_ambience() -> void:
	_pending_ambience = false
	if _ambience:
		_ambience.stop()


func on_enter_title() -> void:
	stop_combat_ambience()
	_leave_combat_music_mode()
	play_bgm("title")


func on_enter_town() -> void:
	stop_combat_ambience()
	_leave_combat_music_mode()
	play_bgm("town")


func on_enter_facility() -> void:
	# Still in town hub flow — keep town theme, no stack.
	stop_combat_ambience()
	_leave_combat_music_mode()
	play_bgm("town")


func on_enter_combat() -> void:
	var intensity := resolve_combat_intensity()
	_apply_combat_intensity(intensity, false)
	start_combat_ambience()


## final > mid > elite > normal — uses only existing BGM_PATHS tracks.
func resolve_combat_intensity() -> String:
	var tree := get_tree()
	if tree == null:
		return "normal"
	var dungeon_id := str(tree.root.get_meta("dungeon_id", ""))
	var floor := int(tree.root.get_meta("dungeon_floor", 0))
	# --- Dungeon vertical floors ---
	if dungeon_id != "" and floor > 0 and GameState != null:
		var fdef: Dictionary = GameState.get_dungeon_floor_def(dungeon_id, floor)
		if not fdef.is_empty():
			var boss := str(fdef.get("boss", ""))
			if boss == "final":
				return "final"
			if boss == "mid":
				return "mid"
			var tier := _highest_enemy_tier(fdef.get("enemies", []))
			if tier == "boss_final":
				return "final"
			if tier == "boss_mid":
				return "mid"
			if tier == "elite":
				return "elite"
			return "normal"
	# --- Hunting maze current room (real room_type / boss_flag only) ---
	if GameState != null:
		var room: Dictionary = GameState.get_current_hunt_room()
		if not room.is_empty():
			var rtype := str(room.get("room_type", ""))
			var kind := str(room.get("boss_kind", ""))
			if bool(room.get("boss_flag", false)) or rtype == "boss" or kind == "hunt_goal":
				# Hunt goal boss = expedition finale → final intensity track.
				return "final"
			if rtype == "elite":
				return "elite"
			var hunt_tier := _highest_enemy_tier(room.get("monsters", []))
			if hunt_tier == "boss_final":
				return "final"
			if hunt_tier == "boss_mid":
				return "mid"
			if hunt_tier == "elite":
				return "elite"
	return "normal"


func _apply_combat_intensity(intensity: String, force: bool) -> void:
	match intensity:
		"final":
			start_final_boss_bgm(force)
		"mid":
			start_mid_boss_bgm(force)
		"elite":
			start_elite_combat_bgm(force)
		_:
			start_combat_playlist(force)


## Normal combat: rotate playlist; each track plays to natural end, then fades to next.
func start_combat_playlist(force: bool = false) -> void:
	if not _unlocked:
		_pending_combat_intensity = "normal"
		_pending_bgm = ""
		return
	if not force and _combat_mode == "playlist" and _bgm.playing:
		return
	_kill_fade()
	_combat_mode = "playlist"
	_rebuild_playlist_queue(true)
	var next := _pop_next_playlist_track()
	if next == "":
		next = "combat_hunting"
	_switch_to_track(next, false, true)


## Elite encounter: prefer Metal Drive (loop for the fight).
func start_elite_combat_bgm(force: bool = false) -> void:
	if not _unlocked:
		_pending_combat_intensity = "elite"
		_pending_bgm = ""
		return
	if not force and _combat_mode == "elite" and _current_bgm == "combat_metal" and _bgm.playing:
		return
	_kill_fade()
	_combat_mode = "elite"
	_playlist_queue.clear()
	_switch_to_track("combat_metal", true, true)


## Mid boss: Heroic Anthem loop (distinct from final boss intensity).
func start_mid_boss_bgm(force: bool = false) -> void:
	if not _unlocked:
		_pending_combat_intensity = "mid"
		_pending_bgm = ""
		return
	if not force and _combat_mode == "mid" and _current_bgm == "combat_heroic" and _bgm.playing:
		return
	_kill_fade()
	_combat_mode = "mid"
	_playlist_queue.clear()
	_switch_to_track("combat_heroic", true, true)


## Final boss: Boss Intensity only — no normal shuffle during the fight.
func start_final_boss_bgm(force: bool = false) -> void:
	if not _unlocked:
		_pending_combat_intensity = "final"
		_pending_bgm = ""
		return
	if not force and _combat_mode == "final" and _current_bgm == "combat_boss" and _bgm.playing:
		return
	_kill_fade()
	_combat_mode = "final"
	_playlist_queue.clear()
	_switch_to_track("combat_boss", true, true)


## Backward-compatible alias → final boss track.
func start_boss_combat_bgm(force: bool = false) -> void:
	start_final_boss_bgm(force)


func get_combat_mode() -> String:
	return _combat_mode


func get_current_bgm() -> String:
	return _current_bgm


func get_playlist_queue() -> Array:
	return _playlist_queue.duplicate()


# --- Internals ---------------------------------------------------------------

func _leave_combat_music_mode() -> void:
	_combat_mode = "none"
	_playlist_queue.clear()
	_last_playlist_track = ""


## Highest explicit catalog tier among enemy ids. Never invents elite without tier=="elite".
func _highest_enemy_tier(enemy_ids: Array) -> String:
	var best := "normal"
	var rank := {"normal": 0, "elite": 1, "boss_mid": 2, "boss_final": 3}
	for eid in enemy_ids:
		var def := _enemy_def_by_id(str(eid))
		if def.is_empty():
			continue
		var t := str(def.get("tier", "normal"))
		if int(rank.get(t, 0)) > int(rank.get(best, 0)):
			best = t
	return best


func _load_enemy_catalog() -> void:
	var f := FileAccess.open("res://data/combat/enemies.json", FileAccess.READ)
	if f == null:
		_enemy_catalog = []
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		_enemy_catalog = []
		return
	_enemy_catalog = data.get("enemies", [])


func _enemy_def_by_id(enemy_id: String) -> Dictionary:
	if _enemy_catalog.is_empty():
		_load_enemy_catalog()
	for e in _enemy_catalog:
		if str(e.get("id", "")) == enemy_id:
			return e
	return {}


func _rebuild_playlist_queue(fresh_start: bool) -> void:
	var pool: Array[String] = []
	for t in COMBAT_PLAYLIST:
		pool.append(t)
	pool.shuffle()
	if fresh_start and _last_playlist_track != "" and pool.size() > 1 and pool[0] == _last_playlist_track:
		# Avoid starting on the same track that just finished a previous fight.
		var swap_i := 1
		var tmp := pool[0]
		pool[0] = pool[swap_i]
		pool[swap_i] = tmp
	_playlist_queue = pool


func _pop_next_playlist_track() -> String:
	if _playlist_queue.is_empty():
		_rebuild_playlist_queue(false)
		# After full cycle, ensure first != last played.
		if _playlist_queue.size() > 1 and _playlist_queue[0] == _last_playlist_track:
			var tmp := _playlist_queue[0]
			_playlist_queue[0] = _playlist_queue[1]
			_playlist_queue[1] = tmp
	if _playlist_queue.is_empty():
		return ""
	var track: String = _playlist_queue.pop_front()
	# Hard guard: never consecutive identical (shouldn't happen with unique pool).
	if track == _last_playlist_track and not _playlist_queue.is_empty():
		_playlist_queue.append(track)
		track = _playlist_queue.pop_front()
	return track


func _on_bgm_finished() -> void:
	if _combat_mode != "playlist":
		return
	# Natural end: previous stream is already done — clear any stale fade lock,
	# then soft-enter the next track (no mid-track cut).
	_kill_fade()
	_switching = false
	if _bgm:
		_bgm.volume_db = 0.0
	var next := _pop_next_playlist_track()
	if next == "":
		return
	_switch_to_track(next, false, true)


func _kill_fade() -> void:
	if _fade_tween and is_instance_valid(_fade_tween):
		_fade_tween.kill()
	_fade_tween = null


func _switch_to_track(track: String, loop: bool, with_fade: bool) -> void:
	if not BGM_PATHS.has(track):
		push_warning("AudioManager: unknown BGM '%s'" % track)
		return
	var path: String = BGM_PATHS[track]
	if not ResourceLoader.exists(path):
		push_warning("AudioManager: missing BGM %s" % path)
		return
	_kill_fade()
	_switching = true
	_bgm.stream_paused = false
	# Commit target immediately so callers / playlist bookkeeping see the new track
	# while fade-out of the previous stream is still running.
	var prev := _current_bgm
	_current_bgm = track
	if _combat_mode == "playlist":
		_last_playlist_track = track

	var do_fade_out := with_fade and _bgm.playing and prev != "" and prev != track
	if do_fade_out:
		_fade_tween = create_tween()
		_fade_tween.tween_property(_bgm, "volume_db", -40.0, FADE_SEC)
		_fade_tween.tween_callback(func():
			_apply_stream(track, path, loop)
			_fade_in()
		)
	else:
		_apply_stream(track, path, loop)
		if with_fade and prev != "":
			_bgm.volume_db = -40.0
			_fade_in()
		else:
			_bgm.volume_db = 0.0
			_switching = false


func _apply_stream(track: String, path: String, loop: bool) -> void:
	_bgm.stop()
	var stream: AudioStream = (load(path) as AudioStream).duplicate()
	if stream == null:
		_switching = false
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = loop
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = loop
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = (
			AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
		)
	_bgm.stream = stream
	_bgm.play()
	_current_bgm = track
	_pending_bgm = ""
	if _combat_mode == "playlist":
		_last_playlist_track = track


func is_bgm_switching() -> bool:
	return _switching


func _fade_in() -> void:
	_kill_fade()
	_bgm.volume_db = -40.0
	_fade_tween = create_tween()
	_fade_tween.tween_property(_bgm, "volume_db", 0.0, FADE_SEC)
	_fade_tween.tween_callback(func():
		_switching = false
		_bgm.volume_db = 0.0
	)
