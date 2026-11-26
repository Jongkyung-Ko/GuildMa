extends Node

## Cross-scene BGM. Tracks loop on Master bus; volume follows settings.

const TRACKS := {
	"title": "res://assets/audio/music/sovereign_of_the_keep.mp3",
	"town": "res://assets/audio/music/morning_dew_on_stone.mp3",
	"combat": "res://assets/audio/music/tobitate_aoi_sora.mp3",
}

var _player: AudioStreamPlayer
var _current_key: String = ""
var _streams: Dictionary = {}
var _volume_linear: float = 0.8
var _fade_tween: Tween
var _web_unlocked: bool = false


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	_player.volume_db = linear_to_db(maxf(_volume_linear, 0.0001))
	add_child(_player)
	_load_streams()
	# HTML5 browsers block audio until a user gesture — unlock on first click/key.
	if not _web_unlocked:
		set_process_input(true)


func _input(event: InputEvent) -> void:
	if _web_unlocked:
		return
	if event is InputEventMouseButton or event is InputEventKey or event is InputEventScreenTouch:
		_web_unlocked = true
		set_process_input(false)
		if _current_key != "" and _streams.has(_current_key) and not _player.playing:
			_player.stream = _streams[_current_key]
			_player.volume_db = _target_db()
			_player.play()


func _load_streams() -> void:
	for key in TRACKS:
		var path: String = TRACKS[key]
		if not ResourceLoader.exists(path):
			push_warning("MusicManager: missing %s" % path)
			continue
		var stream: AudioStream = load(path)
		if stream == null:
			continue
		_enable_loop(stream)
		_streams[key] = stream


func _enable_loop(stream: AudioStream) -> void:
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD


func play(key: String, fade_sec: float = 0.6) -> void:
	if key == _current_key and _player.playing:
		return
	if not _streams.has(key):
		push_warning("MusicManager: unknown track '%s'" % key)
		return
	_current_key = key
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	var target_db := _target_db()
	if _player.playing:
		_fade_tween = create_tween()
		_fade_tween.tween_property(_player, "volume_db", -40.0, maxf(0.05, fade_sec * 0.45))
		_fade_tween.tween_callback(func():
			_player.stream = _streams[key]
			_player.play()
		)
		_fade_tween.tween_property(_player, "volume_db", target_db, maxf(0.05, fade_sec * 0.55))
	else:
		_player.stream = _streams[key]
		_player.volume_db = -40.0
		_player.play()
		_fade_tween = create_tween()
		_fade_tween.tween_property(_player, "volume_db", target_db, maxf(0.05, fade_sec))


func stop(fade_sec: float = 0.4) -> void:
	_current_key = ""
	if not _player.playing:
		return
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_player, "volume_db", -40.0, maxf(0.05, fade_sec))
	_fade_tween.tween_callback(func():
		_player.stop()
	)


func set_volume_percent(pct: float) -> void:
	_volume_linear = clampf(pct / 100.0, 0.0, 1.0)
	if _player.playing and (_fade_tween == null or not _fade_tween.is_running()):
		_player.volume_db = _target_db()


func get_volume_percent() -> float:
	return _volume_linear * 100.0


func current_track() -> String:
	return _current_key


func _target_db() -> float:
	if _volume_linear <= 0.001:
		return -80.0
	return linear_to_db(_volume_linear)
