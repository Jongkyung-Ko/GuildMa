class_name SpriteFactory
extends RefCounted

## Builds SpriteFrames from sliced PNG sequences under assets/sprites.
## Attack FPS tuned so anim length fits job attack intervals.
## Pivot metadata (foot-aligned canvases) lives in data/combat/sprite_pivots.json.

const PIVOT_PATH := "res://data/combat/sprite_pivots.json"

static var _pivot_cache: Dictionary = {}


static func ally_frames(job: String) -> SpriteFrames:
	var base := "res://assets/sprites/characters/%s" % job
	var sf := SpriteFrames.new()
	_add_seq(sf, "idle", base, "combat_%02d.png", [0, 1], 4.0, true)
	_add_seq(sf, "walk", base, "combat_%02d.png", [0, 1, 2, 3], 10.0, true)
	match job:
		"tank":
			# ~0.55s — heavy slam within 1.15s interval
			_add_seq(sf, "attack", base, "combat_%02d.png", [3, 4, 5, 6, 7], 9.0, false)
		"dps":
			# ~0.40s — snappy within 0.65s interval
			_add_seq(sf, "attack", base, "combat_%02d.png", [4, 5, 6, 7], 12.0, false)
		"mage":
			# Raise staff → energy → thrust release (skip baked fireball frame 7)
			_add_seq(sf, "attack", base, "combat_%02d.png", [2, 3, 4, 5, 6], 9.0, false)
		"healer":
			# Quiet raise → cast sparkles (skip misaligned leftover frame 7)
			_add_seq(sf, "attack", base, "combat_%02d.png", [3, 4, 5, 6], 8.0, false)
		"lord":
			# ~0.50s within 0.95s interval
			_add_seq(sf, "attack", base, "combat_%02d.png", [3, 4, 5, 6, 7], 10.0, false)
		_:
			_add_seq(sf, "attack", base, "combat_%02d.png", [3, 4, 5, 6, 7], 10.0, false)
	_add_seq(sf, "hit", base, "combat_%02d.png", [1, 2], 12.0, false)
	_add_seq(sf, "death", base, "combat_%02d.png", [0], 1.0, false)
	return sf


static func enemy_frames(kind: String) -> SpriteFrames:
	var base := "res://assets/sprites/monsters/%s" % kind
	if not ResourceLoader.exists(base + "/frame_00.png"):
		base = "res://assets/sprites/monsters/wolf"
	var sf := SpriteFrames.new()
	_add_seq(sf, "idle", base, "frame_%02d.png", [0, 1], 4.0, true)
	_add_seq(sf, "walk", base, "frame_%02d.png", [1, 2, 3], 9.0, true)
	_add_seq(sf, "attack", base, "frame_%02d.png", [2, 3, 4, 3], 10.0, false)
	_add_seq(sf, "hit", base, "frame_%02d.png", [4], 10.0, false)
	_add_seq(sf, "death", base, "frame_%02d.png", [5], 1.0, false)
	return sf


static func vfx_frames(kind: String) -> SpriteFrames:
	var base := "res://assets/sprites/vfx/%s" % kind
	var sf := SpriteFrames.new()
	var idxs: Array = []
	for i in range(8):
		if ResourceLoader.exists(base + "/frame_%02d.png" % i):
			idxs.append(i)
	if idxs.is_empty():
		idxs = [0]
	_add_seq(sf, "play", base, "frame_%02d.png", idxs, 16.0, false)
	return sf


static func attack_active_frame(job: String) -> int:
	## Index inside the attack animation sequence (not sheet index).
	match job:
		"tank":
			return 3
		"dps":
			return 1
		"mage":
			return 4  # combat_06 release / staff tip fire
		"healer":
			return 3  # combat_06 cast sparkles
		"lord":
			return 2
		"enemy":
			return 1
		_:
			return 2


static func load_pivots() -> Dictionary:
	if not _pivot_cache.is_empty():
		return _pivot_cache
	if not FileAccess.file_exists(PIVOT_PATH):
		return {}
	var f := FileAccess.open(PIVOT_PATH, FileAccess.READ)
	if f == null:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	_pivot_cache = data
	return _pivot_cache


static func job_pivot(job: String) -> Vector2:
	var root := load_pivots()
	var jobs: Dictionary = root.get("jobs", {})
	if not jobs.has(job):
		return Vector2(48, 72)
	var entry: Dictionary = jobs[job]
	var p: Array = entry.get("pivot", [48, 72])
	return Vector2(float(p[0]), float(p[1]))


static func job_canvas(job: String) -> Vector2i:
	var root := load_pivots()
	var jobs: Dictionary = root.get("jobs", {})
	if not jobs.has(job):
		return Vector2i(96, 96)
	var entry: Dictionary = jobs[job]
	var c: Array = entry.get("canvas", [96, 96])
	return Vector2i(int(c[0]), int(c[1]))


static func muzzle_offset(job: String, face_right: bool) -> Vector2:
	## Staff tip / cast origin relative to foot pivot (facing right in art).
	var root := load_pivots()
	var jobs: Dictionary = root.get("jobs", {})
	var off := Vector2(18, -40)
	if jobs.has(job):
		var entry: Dictionary = jobs[job]
		var key := "staff_tip_offset" if job == "mage" else "heal_origin_offset"
		if entry.has(key) and entry[key] != null:
			var a: Array = entry[key]
			off = Vector2(float(a[0]), float(a[1]))
		elif entry.has("staff_tip_offset") and entry["staff_tip_offset"] != null:
			var b: Array = entry["staff_tip_offset"]
			off = Vector2(float(b[0]), float(b[1]))
	if not face_right:
		off.x = -off.x
	return off


static func _add_seq(
	sf: SpriteFrames,
	anim: String,
	base: String,
	pattern: String,
	indices: Array,
	fps: float,
	loop: bool
) -> void:
	if sf.has_animation(anim):
		sf.remove_animation(anim)
	sf.add_animation(anim)
	sf.set_animation_speed(anim, fps)
	sf.set_animation_loop(anim, loop)
	for i in indices:
		var path := "%s/%s" % [base, pattern % int(i)]
		if not ResourceLoader.exists(path):
			continue
		var tex: Texture2D = load(path)
		if tex:
			sf.add_frame(anim, tex)
	if sf.get_frame_count(anim) == 0:
		var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		sf.add_frame(anim, ImageTexture.create_from_image(img))
