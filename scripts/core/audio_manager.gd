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
	## Title / town MP3s.
	"title": "res://assets/audio/music/sovereign_of_the_keep.mp3",
	"town": "res://assets/audio/music/morning_dew_on_stone.mp3",
	## Hunting-grounds theme (user-specified). Not used for dungeon OGG shuffle.
	"hunt": "res://assets/audio/music/tobitate_aoi_sora.mp3",
	## Legacy alias → same hunting MP3 (explicit play_bgm("combat")).
	"combat": "res://assets/audio/music/tobitate_aoi_sora.mp3",
	## Dungeon normal-combat OGG shuffle + situational intensity.
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

const SFX_POOL_SIZE := 10
const FADE_SEC := 1.5
## Leave headroom on SFX bus so overlapping hits do not clip Master against BGM.
const SFX_BUS_HEADROOM_DB := -3.0
const AMBIENCE_VOL_SCALE := 0.35

var _bgm: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_idx: int = 0
## Cached base streams for SAMPLE one-shots. Do NOT .duplicate() per play —
## fresh WAV copies force re-register_as_sample and hitch BGM STREAM on web.
var _sfx_stream_cache: Dictionary = {}
## Dedicated UI click voice (pre-bound stream) — hottest path, zero acquire churn.
var _ui_click: AudioStreamPlayer

var _unlocked: bool = false
var _pending_bgm: String = ""
## Pending combat intensity when audio locked: "" | "normal" | "elite" | "mid" | "final"
var _pending_combat_intensity: String = ""
var _pending_ambience: bool = false
var _current_bgm: String = ""

## "none" | "hunt" | "playlist" | "elite" | "mid" | "final"
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
	_preload_sfx_cache()
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
		# Short one-shots: Sample path avoids STREAM buffer churn that can glitch BGM on web.
		p.playback_type = AudioServer.PLAYBACK_TYPE_SAMPLE
		add_child(p)
		_sfx_players.append(p)

	_ui_click = AudioStreamPlayer.new()
	_ui_click.name = "UiClickPlayer"
	_ui_click.bus = "SFX"
	_ui_click.playback_type = AudioServer.PLAYBACK_TYPE_SAMPLE
	add_child(_ui_click)
	_bind_ui_click_stream()

	_apply_volumes()
	# Browser autoplay: wait for first user gesture.
	set_process_input(true)


func _preload_sfx_cache() -> void:
	_sfx_stream_cache.clear()
	for id in SFX_PATHS.keys():
		var path: String = SFX_PATHS[id]
		if not ResourceLoader.exists(path):
			continue
		var s: AudioStream = load(path)
		if s:
			_sfx_stream_cache[id] = s
			_ensure_sample_registered(s)


func _ensure_sample_registered(stream: AudioStream) -> void:
	## Register once so SAMPLE play() does not hitch the mix graph (BGM STREAM).
	if stream == null:
		return
	if not AudioServer.has_method("is_stream_registered_as_sample"):
		return
	if AudioServer.is_stream_registered_as_sample(stream):
		return
	if AudioServer.has_method("register_stream_as_sample"):
		AudioServer.register_stream_as_sample(stream)


func _bind_ui_click_stream() -> void:
	if _ui_click == null:
		return
	var click: AudioStream = _sfx_stream_for("ui_click")
	if click == null:
		return
	_ensure_sample_registered(click)
	if _ui_click.stream != click:
		_ui_click.stream = click


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
	## Browser autoplay: catch the first gesture early. Do NOT mark the event
	## handled — Buttons (title menu, etc.) must still receive the same click.
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
		var pending := _pending_bgm
		_pending_bgm = ""
		if pending == "hunt":
			_play_hunt_bgm(true)
		else:
			play_bgm(pending, true)
	if _pending_ambience:
		_pending_ambience = false
		ensure_combat_ambience()


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
		# User SFX level + fixed headroom so stacked hits do not clip into BGM.
		AudioServer.set_bus_volume_db(si, _linear_to_db(sfx_linear) + SFX_BUS_HEADROOM_DB)
	# Keep BGM player volume at unity unless mid-fade; bus owns user volume.
	# Never rewrite BGM volume from SFX volume changes while fading.
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
	# force=true → restart from 0 even if same track (town/hunt zone re-entry).
	_switch_to_track(track, true, true, force)


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
	# unlock_audio must never stop/seek BGM when already unlocked.
	if not _unlocked:
		unlock_audio()
	# Never touch the BGM player from SFX paths.
	var stream := _sfx_stream_for(id)
	if stream == null:
		return
	_ensure_sample_registered(stream)
	var p := _acquire_sfx_player()
	# Reuse cached SAMPLE stream — per-click .duplicate() re-registers samples and
	# briefly stalls the audio graph (audible BGM chop on web).
	if p.stream != stream:
		p.stream = stream
	p.volume_db = _linear_to_db(clampf(volume_scale, 0.0, 1.2))
	p.play()


func _sfx_stream_for(id: String) -> AudioStream:
	if _sfx_stream_cache.has(id):
		return _sfx_stream_cache[id] as AudioStream
	var path: String = SFX_PATHS.get(id, "")
	if path == "" or not ResourceLoader.exists(path):
		push_warning("AudioManager: missing SFX %s" % path)
		return null
	var s: AudioStream = load(path)
	if s:
		_sfx_stream_cache[id] = s
		_ensure_sample_registered(s)
	return s


func _acquire_sfx_player() -> AudioStreamPlayer:
	# Prefer an idle voice so we do not cut overlapping hits mid-play.
	for i in _sfx_players.size():
		var idx := (_sfx_idx + i) % _sfx_players.size()
		var cand: AudioStreamPlayer = _sfx_players[idx]
		if not cand.playing:
			_sfx_idx = (idx + 1) % _sfx_players.size()
			return cand
	# All busy: steal the next round-robin voice only.
	var p: AudioStreamPlayer = _sfx_players[_sfx_idx]
	_sfx_idx = (_sfx_idx + 1) % _sfx_players.size()
	p.stop()
	return p


func play_ui_click() -> void:
	## Hot path for every UIStyle button — dedicated SAMPLE voice, no pool steal,
	## no stream.duplicate(), no BGM touch.
	if not _unlocked:
		unlock_audio()
	if _ui_click == null:
		play_sfx("ui_click", 0.7)
		return
	if _ui_click.stream == null:
		_bind_ui_click_stream()
	if _ui_click.stream == null:
		return
	_ensure_sample_registered(_ui_click.stream)
	_ui_click.volume_db = _linear_to_db(0.7)
	# Restart from 0 if already playing (rapid clicks) without reallocating stream.
	_ui_click.play(0.0)


func play_hit() -> void:
	play_sfx("hit", 0.75)


func play_magic() -> void:
	play_sfx("magic", 0.85)


func play_equip() -> void:
	play_sfx("equip", 0.8)


func start_combat_ambience() -> void:
	## Public alias — ensures loop without restarting if already running.
	ensure_combat_ambience()


func ensure_combat_ambience(force_restart: bool = false) -> void:
	if not force_restart and _ambience and _ambience.playing and _ambience.stream != null:
		_pending_ambience = false
		return
	var path: String = SFX_PATHS["ambience"]
	if not ResourceLoader.exists(path):
		return
	var base: AudioStream = _sfx_stream_for("ambience")
	if base == null:
		base = load(path) as AudioStream
	if base == null:
		return
	# Ambience uses PLAYBACK_TYPE_STREAM — duplicate so loop flag edits stay local.
	var stream: AudioStream = base.duplicate()
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	if _ambience.playing:
		_ambience.stop()
	_ambience.stream = stream
	_ambience.volume_db = _linear_to_db(AMBIENCE_VOL_SCALE)
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
	# Zone entry (incl. hunt→town): always start town BGM from the beginning.
	play_bgm("town", true)


func on_enter_facility() -> void:
	# Still in town hub flow — keep town theme position if already playing.
	stop_combat_ambience()
	_leave_combat_music_mode()
	play_bgm("town", false)


func on_enter_combat(restart_bgm: bool = false) -> void:
	## restart_bgm=true: town→hunt / dungeon floor entry — start BGM at 0.
	## restart_bgm=false: hunt internal room travel — keep playback position.
	## Hunt maze always uses Tobitate MP3; dungeon uses OGG shuffle / F5 / F10.
	if _is_hunt_context():
		_play_hunt_bgm(restart_bgm)
		ensure_combat_ambience(restart_bgm)
		return
	var intensity := resolve_combat_intensity()
	_apply_combat_intensity(intensity, restart_bgm)
	ensure_combat_ambience(restart_bgm)


func _is_hunt_context() -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	var hunt_id := str(tree.root.get_meta("hunt_id", ""))
	var dungeon_id := str(tree.root.get_meta("dungeon_id", ""))
	return hunt_id != "" and dungeon_id == ""


func _play_hunt_bgm(restart: bool) -> void:
	## Hunting grounds: dedicated MP3 loop. Never fall through to OGG playlist.
	if not _unlocked:
		_pending_combat_intensity = ""
		_pending_bgm = "hunt"
		_combat_mode = "hunt"
		return
	if not restart and _combat_mode == "hunt" and _current_bgm == "hunt" and _bgm and (_bgm.playing or _switching):
		return
	_leave_combat_music_mode()
	_combat_mode = "hunt"
	_switch_to_track("hunt", true, true, restart)
	print("AudioManager: hunt BGM key=hunt path=%s restart=%s" % [BGM_PATHS["hunt"], restart])


func get_bgm_playback_position() -> float:
	if _bgm == null or not _bgm.playing:
		return -1.0
	return _bgm.get_playback_position()


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
	# Same hunt-region intensity: keep current track + playback position.
	# Treat mid-fade (_switching) as still active so room travel cannot restart.
	if not force and _combat_mode == "playlist" and _bgm and (_bgm.playing or _switching):
		return
	_kill_fade()
	_combat_mode = "playlist"
	_rebuild_playlist_queue(true)
	var next := _pop_next_playlist_track()
	if next == "":
		next = "combat_hunting"
	_switch_to_track(next, false, true, force)


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
	_switch_to_track("combat_metal", true, true, force)


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
	_switch_to_track("combat_heroic", true, true, force)


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
	_switch_to_track("combat_boss", true, true, force)


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


func _switch_to_track(track: String, loop: bool, with_fade: bool, restart: bool = false) -> void:
	if not BGM_PATHS.has(track):
		push_warning("AudioManager: unknown BGM '%s'" % track)
		return
	var path: String = BGM_PATHS[track]
	if not ResourceLoader.exists(path):
		push_warning("AudioManager: missing BGM %s" % path)
		return
	# Identical request while already playing: do not stop/seek/restart (unless restart).
	if (
		not restart
		and _current_bgm == track
		and _bgm
		and _bgm.playing
		and not _bgm.stream_paused
		and not _switching
	):
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

	var do_fade_out := with_fade and not restart and _bgm.playing and prev != "" and prev != track
	if do_fade_out:
		_fade_tween = create_tween()
		_fade_tween.tween_property(_bgm, "volume_db", -40.0, FADE_SEC)
		_fade_tween.tween_callback(func():
			_apply_stream(track, path, loop, false)
			_fade_in()
		)
	else:
		# Same track without restart: keep position.
		if not restart and prev == track and _bgm.playing and _bgm.stream != null:
			_bgm.volume_db = 0.0
			_switching = false
			return
		_apply_stream(track, path, loop, false)
		if with_fade and prev != "" and prev != track and not restart:
			_bgm.volume_db = -40.0
			_fade_in()
		else:
			_bgm.volume_db = 0.0
			_switching = false


func _apply_stream(track: String, path: String, loop: bool, keep_position: bool = false) -> void:
	var pos_keep := 0.0
	if keep_position and _bgm.stream != null and _bgm.playing:
		pos_keep = _bgm.get_playback_position()
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
	if keep_position and pos_keep > 0.05:
		_bgm.play(pos_keep)
	else:
		_bgm.play(0.0)
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
