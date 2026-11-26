class_name SpriteFactory
extends RefCounted

## Builds SpriteFrames from sliced PNG sequences under assets/sprites.
## Attack sequences use windup → active → recovery frames at readable FPS.


static func ally_frames(job: String) -> SpriteFrames:
	var base := "res://assets/sprites/characters/%s" % job
	var sf := SpriteFrames.new()
	_add_seq(sf, "idle", base, "combat_%02d.png", [0, 1], 3.5, true)
	_add_seq(sf, "walk", base, "combat_%02d.png", [0, 1, 2, 3], 7.0, true)
	# Job-differentiated attack timing / frame picks (all use real attack art 3–7).
	match job:
		"tank":
			# Heavy overhead: slower, full windup through slam.
			_add_seq(sf, "attack", base, "combat_%02d.png", [3, 4, 5, 6, 7], 6.0, false)
		"dps":
			# Fast thrusts: snappier active frames.
			_add_seq(sf, "attack", base, "combat_%02d.png", [3, 4, 5, 6, 7], 8.0, false)
		"mage":
			# Cast raise → burst.
			_add_seq(sf, "attack", base, "combat_%02d.png", [2, 4, 5, 6, 7], 6.5, false)
		"healer":
			# Staff raise → heal sparkle.
			_add_seq(sf, "attack", base, "combat_%02d.png", [2, 4, 5, 6, 7], 6.5, false)
		"lord":
			# Shield press → sword crescent.
			_add_seq(sf, "attack", base, "combat_%02d.png", [3, 4, 5, 6, 7], 7.0, false)
		_:
			_add_seq(sf, "attack", base, "combat_%02d.png", [3, 4, 5, 6, 7], 7.0, false)
	_add_seq(sf, "hit", base, "combat_%02d.png", [1, 2], 10.0, false)
	_add_seq(sf, "death", base, "combat_%02d.png", [0], 1.0, false)
	return sf


static func enemy_frames(kind: String) -> SpriteFrames:
	var base := "res://assets/sprites/monsters/%s" % kind
	if not ResourceLoader.exists(base + "/frame_00.png"):
		base = "res://assets/sprites/monsters/wolf"
	var sf := SpriteFrames.new()
	_add_seq(sf, "idle", base, "frame_%02d.png", [0, 1], 3.5, true)
	_add_seq(sf, "walk", base, "frame_%02d.png", [1, 2, 3], 7.0, true)
	# Windup → lunge → recovery (hold key poses so motion is visible).
	_add_seq(sf, "attack", base, "frame_%02d.png", [2, 3, 4, 4, 3], 6.5, false)
	_add_seq(sf, "hit", base, "frame_%02d.png", [4], 8.0, false)
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
	_add_seq(sf, "play", base, "frame_%02d.png", idxs, 14.0, false)
	return sf


## Frame index inside the "attack" animation where damage / VFX fire.
static func attack_active_frame(job: String) -> int:
	match job:
		"tank":
			return 3  # slam (sheet frame 6)
		"dps":
			return 2  # thrust arc
		"mage", "healer":
			return 3  # burst / sparkle
		"lord":
			return 3  # crescent
		"enemy":
			return 2
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
