class_name CombatProjectile
extends Node2D

## Homing magic bolt: travels from caster to target, deals damage on arrival.

var target: CombatCharacter = null
var damage: float = 0.0
var travel_time: float = 0.35
var _elapsed: float = 0.0
var _start: Vector2 = Vector2.ZERO
var _sprite: AnimatedSprite2D
var _alive: bool = true
var _attacker: CombatCharacter = null
var _manager: Node = null


func setup(
	from: Vector2,
	tgt: CombatCharacter,
	dmg: float,
	attacker: CombatCharacter,
	manager: Node,
	duration: float = 0.35
) -> void:
	_start = from
	global_position = from
	target = tgt
	damage = dmg
	_attacker = attacker
	_manager = manager
	travel_time = clampf(duration, 0.25, 0.45)
	_build_visual()


func _build_visual() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.centered = true
	_sprite.z_index = 50
	_sprite.scale = Vector2(1.8, 1.8)
	_sprite.sprite_frames = SpriteFactory.vfx_frames("magic")
	add_child(_sprite)
	if _sprite.sprite_frames and _sprite.sprite_frames.has_animation("play"):
		_sprite.play("play")
	# Bright core so flight is obvious even at distance
	modulate = Color(1.3, 1.15, 1.0, 1.0)
	# Failsafe lifetime
	var life := Timer.new()
	life.wait_time = travel_time + 0.8
	life.one_shot = true
	add_child(life)
	life.timeout.connect(_expire)
	life.start()


func _process(delta: float) -> void:
	if not _alive:
		return
	_elapsed += delta
	var t := clampf(_elapsed / travel_time, 0.0, 1.0)
	var end := _start + Vector2(80, -20)
	if target != null and is_instance_valid(target) and not target.is_dead:
		end = target.global_position + Vector2(0, -18)
	# Ease-out for readable flight
	var ease_t := 1.0 - pow(1.0 - t, 2.0)
	global_position = _start.lerp(end, ease_t)
	rotation = (_start.direction_to(end).angle()) if end != _start else 0.0
	# Spin for liveliness
	if _sprite:
		_sprite.rotation += delta * 8.0
	if t >= 1.0:
		_impact()


func _impact() -> void:
	if not _alive:
		return
	_alive = false
	# Explosion flash
	var boom := AnimatedSprite2D.new()
	boom.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	boom.centered = true
	boom.z_index = 55
	boom.scale = Vector2(1.6, 1.6)
	boom.sprite_frames = SpriteFactory.vfx_frames("hit")
	var parent_node := get_parent()
	if parent_node:
		parent_node.add_child(boom)
		boom.global_position = global_position
	else:
		add_child(boom)
	if boom.sprite_frames and boom.sprite_frames.has_animation("play"):
		boom.play("play")
	boom.animation_finished.connect(boom.queue_free)
	var boom_life := Timer.new()
	boom_life.wait_time = 0.45
	boom_life.one_shot = true
	boom.add_child(boom_life)
	boom_life.timeout.connect(boom.queue_free)
	boom_life.start()

	if target != null and is_instance_valid(target) and not target.is_dead and damage > 0.0:
		target.take_damage(damage, _attacker, {"heavy": true, "magic": true})
		if _manager != null and _manager.has_method("log_combat") and _attacker != null:
			_manager.log_combat("%s → %s  %d" % [_attacker.display_name, target.display_name, int(round(damage))])
		if _manager != null and _manager.has_method("shake_camera"):
			_manager.shake_camera(3.5, 0.12)
		CombatFx.hit_stop(_manager, 0.05)
	queue_free()


func _expire() -> void:
	if _alive:
		_alive = false
		queue_free()
