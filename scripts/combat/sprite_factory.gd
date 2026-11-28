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
	## Prefer boss anim pack (idle + attack/hit/death) when present; else idle-only; else wolf.
	var root := boss_root_path(kind)
	if root != "" and has_boss_anim_pack_at(root):
		return boss_anim_frames(root)
	var idle_path := boss_idle_path(kind)
	if idle_path != "":
		return single_texture_frames(idle_path)
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


static func boss_root_path(kind: String) -> String:
	## Directory res://assets/sprites/monsters/bosses/<id> when it exists.
	var idle := boss_idle_path(kind)
	if idle != "":
		return idle.get_base_dir()
	var k := kind.strip_edges()
	var candidates: Array = []
	if k.begins_with("bosses/"):
		candidates.append("res://assets/sprites/monsters/%s" % k)
	else:
		candidates.append("res://assets/sprites/monsters/bosses/%s" % k)
		if k.begins_with("boss_"):
			candidates.append("res://assets/sprites/monsters/bosses/%s" % k.substr(5))
	for c in candidates:
		var path := str(c)
		if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)) or DirAccess.open(path) != null:
			return path
	return ""


static func has_boss_anim_pack(kind: String) -> bool:
	var root := boss_root_path(kind)
	return root != "" and has_boss_anim_pack_at(root)


static func has_boss_anim_pack_at(root: String) -> bool:
	## True when attack/attack_00.png is present (Fenrir pack and future packs).
	var probe := "%s/attack/attack_00.png" % root
	return ResourceLoader.exists(probe) or FileAccess.file_exists(probe)


static func boss_anim_frames(root: String) -> SpriteFrames:
	## Idle loops existing idle.png; attack 8fps / hit 10fps / death 6fps non-loop.
	var sf := SpriteFrames.new()
	var idle_path := "%s/idle.png" % root
	var idle_tex: Texture2D = _load_tex(idle_path)
	for anim in ["idle", "walk"]:
		if sf.has_animation(anim):
			sf.remove_animation(anim)
		sf.add_animation(anim)
		sf.set_animation_speed(anim, 4.0)
		sf.set_animation_loop(anim, true)
		if idle_tex:
			sf.add_frame(anim, idle_tex)
		else:
			var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
			img.fill(Color(0, 0, 0, 0))
			sf.add_frame(anim, ImageTexture.create_from_image(img))
	_add_dir_seq(sf, "attack", "%s/attack" % root, "attack_%02d.png", 4, 8.0, false)
	_add_dir_seq(sf, "hit", "%s/hit" % root, "hit_%02d.png", 4, 10.0, false)
	_add_dir_seq(sf, "death", "%s/death" % root, "death_%02d.png", 4, 6.0, false)
	return sf


static func boss_idle_path(kind: String) -> String:
	## Resolve bosses/<id>/idle.png from sprite kind / boss id / boss_* enemy id.
	var candidates: Array = []
	var k := kind.strip_edges()
	if k.begins_with("bosses/"):
		candidates.append("res://assets/sprites/monsters/%s/idle.png" % k)
	else:
		candidates.append("res://assets/sprites/monsters/bosses/%s/idle.png" % k)
		if k.begins_with("boss_"):
			candidates.append("res://assets/sprites/monsters/bosses/%s/idle.png" % k.substr(5))
	for p in candidates:
		var path := str(p)
		if ResourceLoader.exists(path):
			return path
		# Pre-import / raw file check
		if FileAccess.file_exists(path):
			return path
	return ""


static func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(
			ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
		)
		if img:
			return ImageTexture.create_from_image(img)
	return null


static func _add_dir_seq(
	sf: SpriteFrames,
	anim: String,
	dir: String,
	pattern: String,
	count: int,
	fps: float,
	loop: bool
) -> void:
	if sf.has_animation(anim):
		sf.remove_animation(anim)
	sf.add_animation(anim)
	sf.set_animation_speed(anim, fps)
	sf.set_animation_loop(anim, loop)
	for i in range(count):
		var path := "%s/%s" % [dir, pattern % i]
		var tex := _load_tex(path)
		if tex:
			sf.add_frame(anim, tex)
	if sf.get_frame_count(anim) == 0:
		var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		sf.add_frame(anim, ImageTexture.create_from_image(img))


static func single_texture_frames(path: String) -> SpriteFrames:
	## Idle-only sheet: reuse same frame for walk/attack/hit/death until anim packs land.
	var sf := SpriteFrames.new()
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
	elif FileAccess.file_exists(path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path) if path.begins_with("res://") else path)
		if img:
			tex = ImageTexture.create_from_image(img)
	if tex == null:
		# Keep placeholder path: empty → caller should fall back; provide transparent 1px.
		var img2 := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img2.fill(Color(0, 0, 0, 0))
		tex = ImageTexture.create_from_image(img2)
	for anim in ["idle", "walk", "attack", "hit", "death"]:
		if sf.has_animation(anim):
			sf.remove_animation(anim)
		sf.add_animation(anim)
		sf.set_animation_speed(anim, 4.0 if anim == "idle" else 8.0)
		sf.set_animation_loop(anim, anim in ["idle", "walk"])
		sf.add_frame(anim, tex)
	return sf


static func has_boss_idle(kind: String) -> bool:
	return boss_idle_path(kind) != ""


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
		"fenrir", "bosses/fenrir", "boss_fenrir":
			return 2  # attack_02 impact in 4-frame pack
		_:
			return 2


static func attack_active_frame_for_enemy(kind: String) -> int:
	## Boss anim packs: impact near mid sequence; other enemies keep legacy index.
	if has_boss_anim_pack(kind):
		if kind.contains("fenrir") or kind.ends_with("/fenrir"):
			return 2
		return 2
	return attack_active_frame("enemy")


static func attack_sheet_indices(job: String) -> Array:
	## Sheet frame indices used by the attack animation (parallel to SpriteFrames order).
	match job:
		"tank":
			return [3, 4, 5, 6, 7]
		"dps":
			return [4, 5, 6, 7]
		"mage":
			return [2, 3, 4, 5, 6]
		"healer":
			return [3, 4, 5, 6]
		"lord":
			return [3, 4, 5, 6, 7]
		"enemy":
			return [2, 3, 4, 3]
		_:
			return [3, 4, 5, 6, 7]


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


static func muzzle_offset(job: String, face_right: bool, sheet_frame: int = -1) -> Vector2:
	## Staff tip / cast origin relative to foot pivot (facing right in art).
	## Optional sheet_frame selects per-frame tip when present (mage cast).
	var root := load_pivots()
	var jobs: Dictionary = root.get("jobs", {})
	var off := Vector2(18, -40)
	if jobs.has(job):
		var entry: Dictionary = jobs[job]
		var by_frame: Dictionary = entry.get("staff_tip_by_frame", {})
		if sheet_frame >= 0 and by_frame.has(str(sheet_frame)):
			var f: Array = by_frame[str(sheet_frame)]
			off = Vector2(float(f[0]), float(f[1]))
		else:
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
