class_name SpriteFactory
extends RefCounted

## Builds SpriteFrames from sliced PNG sequences under assets/sprites.
## Attack FPS tuned so anim length fits job attack intervals.


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
			# Cast raise — projectile fires at active frame (~0.45s)
			_add_seq(sf, "attack", base, "combat_%02d.png", [2, 4, 5, 6], 10.0, false)
		"healer":
			# Staff raise for heal cast (~0.50s)
			_add_seq(sf, "attack", base, "combat_%02d.png", [2, 4, 5, 6], 9.0, false)
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
	match job:
		"tank":
			return 3
		"dps":
			return 1
		"mage":
			return 2  # cast release → spawn projectile
		"healer":
			return 2
		"lord":
			return 2
		"enemy":
			return 1
		_:
			return 2


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
