extends Node

## Central SFX / BGM. MIDI sources are kept under assets/audio/bgm/*.mid but
## playback uses FluidSynth-rendered OGG (Godot 4.3 + web have no GM synth).

const SFX_PATHS := {
	"ui_click": "res://assets/audio/sfx/01_ui_button_click.wav",
	"ambience": "res://assets/audio/sfx/02_battle_ambience_loop.wav",
	"hit": "res://assets/audio/sfx/03_combat_hit.wav",
	"magic": "res://assets/audio/sfx/04_magic_cast.wav",
	"equip": "res://assets/audio/sfx/05_item_equip.wav",
}

const BGM_PATHS := {
	"town": "res://assets/audio/bgm/01_town_theme.ogg",
	"combat": "res://assets/audio/bgm/02_hunting_grounds_rock.ogg",
}

const SFX_POOL_SIZE := 6

var _bgm: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_idx: int = 0

var _unlocked: bool = false
var _pending_bgm: String = ""
var _pending_ambience: bool = false
var _current_bgm: String = ""

var bgm_linear: float = 0.72
var sfx_linear: float = 0.85


func _ready() -> void:
	_ensure_buses()
	_bgm = AudioStreamPlayer.new()
	_bgm.name = "BgmPlayer"
	_bgm.bus = "BGM"
	# Stream mode: full Godot audio path (needed for reliable loop on web Sample limits).
	_bgm.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(_bgm)

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
	if _pending_bgm != "":
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


func _linear_to_db(v: float) -> float:
	if v <= 0.0001:
		return -80.0
	return linear_to_db(v)


func play_bgm(track: String, force: bool = false) -> void:
	if not BGM_PATHS.has(track):
		push_warning("AudioManager: unknown BGM '%s'" % track)
		return
	if not _unlocked:
		_pending_bgm = track
		return
	if not force and _current_bgm == track and _bgm.playing:
		return
	var path: String = BGM_PATHS[track]
	if not ResourceLoader.exists(path):
		push_warning("AudioManager: missing BGM %s" % path)
		return
	var stream: AudioStream = (load(path) as AudioStream).duplicate()
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_bgm.stop()
	_bgm.stream = stream
	_bgm.play()
	_current_bgm = track
	_pending_bgm = ""


func stop_bgm() -> void:
	_pending_bgm = ""
	_current_bgm = ""
	if _bgm:
		_bgm.stop()


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
	stop_bgm()


func on_enter_town() -> void:
	stop_combat_ambience()
	play_bgm("town")


func on_enter_facility() -> void:
	# Still in town hub flow — keep town theme, no stack.
	stop_combat_ambience()
	play_bgm("town")


func on_enter_combat() -> void:
	play_bgm("combat")
	start_combat_ambience()
