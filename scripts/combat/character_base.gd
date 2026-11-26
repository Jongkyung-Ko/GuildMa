class_name CombatCharacter
extends CharacterBody2D

## Phase 2-1: shared ally/enemy combatant with auto-move and basic attack.
## Visuals: premium pixel sprites via AnimatedSprite2D (no ColorRect bodies).

signal hp_changed(current: float, maximum: float)
signal died(who: CombatCharacter)

enum Team { ALLY, ENEMY }

var team: Team = Team.ALLY
var display_name: String = ""
var job: String = ""
var enemy_kind: String = "wolf"
var member_id: String = ""
var hp: float = 1.0
var hp_max: float = 1.0
var atk: float = 1.0
var defense: float = 0.0
var move_speed: float = 80.0
var attack_range: float = 36.0
var attack_interval: float = 1.0
var aggro_range: float = 2000.0
var is_dead: bool = false

var _atk_timer: float = 0.0
var _manager: Node = null
var _sprite: AnimatedSprite2D
var _name_label: Label
var _hp_bar: ProgressBar
var _flash_t: float = 0.0
var _attacking: bool = false
var _face_right: bool = true


func _ready() -> void:
	_build_visuals()


func bind_manager(manager: Node) -> void:
	_manager = manager


func setup_from_member(member: Dictionary, balance: Dictionary) -> void:
	team = Team.ALLY
	member_id = str(member.get("id", ""))
	display_name = str(member.get("name", "길드원"))
	job = str(member.get("job", "dps"))
	var level: int = int(member.get("level", 1))
	var stats: Dictionary = member.get("stats", {})
	var vit: float = float(stats.get("vit", 5))
	var stre: float = float(stats.get("str", 5))
	var agi: float = float(stats.get("agi", 5))
	hp_max = float(balance.get("hp_base", 80)) + vit * float(balance.get("hp_vit", 12)) + level * float(balance.get("hp_level", 8))
	if job == "lord":
		hp_max += float(balance.get("hp_lord_bonus", 20))
	hp = hp_max
	atk = float(balance.get("atk_base", 5)) + stre * float(balance.get("atk_str", 2)) + level * float(balance.get("atk_level", 1))
	defense = float(balance.get("def_base", 2)) + vit * float(balance.get("def_vit", 1)) + level / float(balance.get("def_level_div", 2))
	move_speed = minf(float(balance.get("move_cap", 160)), float(balance.get("move_base", 80)) + agi * float(balance.get("move_agi", 2)))
	var aspd: float = minf(float(balance.get("aspd_cap", 2.0)), float(balance.get("aspd_base", 1.0)) + agi * float(balance.get("aspd_agi", 0.02)))
	attack_interval = 1.0 / maxf(0.2, aspd)
	attack_range = float(balance.get("ally_attack_range", 36))
	aggro_range = 2000.0
	_apply_role_offsets()
	if is_inside_tree():
		_refresh_visuals()


func setup_from_enemy(data: Dictionary) -> void:
	team = Team.ENEMY
	member_id = str(data.get("id", "enemy"))
	display_name = str(data.get("name", "적"))
	job = "enemy"
	enemy_kind = str(data.get("sprite", data.get("id", "wolf")))
	hp_max = float(data.get("hp", 60))
	hp = hp_max
	atk = float(data.get("atk", 8))
	defense = float(data.get("def", 2))
	move_speed = float(data.get("move", 100))
	var aspd: float = float(data.get("aspd", 1.0))
	attack_interval = 1.0 / maxf(0.2, aspd)
	attack_range = float(data.get("attack_range", 28))
	aggro_range = float(data.get("aggro_range", 900))
	if is_inside_tree():
		_refresh_visuals()


func _apply_role_offsets() -> void:
	match job:
		"tank":
			attack_range = 32.0
			move_speed *= 0.92
		"dps":
			attack_range = 34.0
			atk *= 1.08
		"healer":
			attack_range = 42.0
			atk *= 0.7
			move_speed *= 0.95
		"mage":
			attack_range = 70.0
			atk *= 1.05
			move_speed *= 0.9
		"lord":
			attack_range = 38.0


func _build_visuals() -> void:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 14.0
	shape.shape = circle
	add_child(shape)

	_sprite = AnimatedSprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.centered = true
	_sprite.position = Vector2(0, -8)
	_sprite.animation_finished.connect(_on_anim_finished)
	add_child(_sprite)

	_hp_bar = ProgressBar.new()
	_hp_bar.min_value = 0
	_hp_bar.max_value = 100
	_hp_bar.value = 100
	_hp_bar.show_percentage = false
	_hp_bar.size = Vector2(40, 6)
	_hp_bar.position = Vector2(-20, -40)
	_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hp_bar)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.position = Vector2(-48, -56)
	_name_label.size = Vector2(96, 16)
	_name_label.add_theme_font_size_override("font_size", 11)
	_name_label.add_theme_color_override("font_color", Color(0.95, 0.93, 0.88))
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.apply_font(_name_label, 11)
	add_child(_name_label)

	_refresh_visuals()


func _refresh_visuals() -> void:
	if _name_label:
		_name_label.text = display_name
	if _hp_bar:
		_hp_bar.max_value = hp_max
		_hp_bar.value = hp
	if _sprite == null:
		return
	if team == Team.ALLY:
		_sprite.sprite_frames = SpriteFactory.ally_frames(job if job != "" else "dps")
		_face_right = true
	else:
		_sprite.sprite_frames = SpriteFactory.enemy_frames(enemy_kind)
		_face_right = false
	# Source sheets face right; flip_h faces left.
	_sprite.flip_h = not _face_right
	_play_safe("idle")


func _play_safe(anim: String) -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	if not _sprite.sprite_frames.has_animation(anim):
		return
	if _sprite.animation == anim and _sprite.is_playing():
		return
	_sprite.play(anim)


func _on_anim_finished() -> void:
	if is_dead:
		return
	if _attacking:
		_attacking = false
		_play_safe("idle")


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if _manager != null and _manager.has_method("is_combat_active") and not _manager.is_combat_active():
		velocity = Vector2.ZERO
		if not _attacking:
			_play_safe("idle")
		return

	if _flash_t > 0.0:
		_flash_t -= delta
		if _sprite and _flash_t <= 0.0:
			_sprite.modulate = Color(1, 1, 1, 1)

	_atk_timer = maxf(0.0, _atk_timer - delta)
	var target := _find_target()
	if target == null:
		velocity = Vector2.ZERO
		if not _attacking:
			_play_safe("idle")
		return

	var dist := global_position.distance_to(target.global_position)
	var dir := (target.global_position - global_position).normalized()
	if absf(dir.x) > 0.05:
		_face_right = dir.x > 0.0
		_sprite.flip_h = not _face_right

	if dist > attack_range:
		if team == Team.ALLY and job in ["mage", "healer"] and dist < attack_range * 0.55:
			dir = -dir
		velocity = dir * move_speed
		move_and_slide()
		_clamp_to_field()
		if not _attacking:
			_play_safe("walk")
	else:
		velocity = Vector2.ZERO
		if not _attacking:
			_play_safe("idle")
		if _atk_timer <= 0.0:
			_perform_attack(target)


func _clamp_to_field() -> void:
	global_position.x = clampf(global_position.x, 40.0, 1240.0)
	global_position.y = clampf(global_position.y, 80.0, 620.0)


func _find_target() -> CombatCharacter:
	if _manager == null or not _manager.has_method("get_opponents"):
		return null
	var foes: Array = _manager.get_opponents(team)
	var best: CombatCharacter = null
	var best_d := INF
	for f in foes:
		var c := f as CombatCharacter
		if c == null or c.is_dead:
			continue
		var d := global_position.distance_to(c.global_position)
		if d > aggro_range:
			continue
		if d < best_d:
			best_d = d
			best = c
	return best


func _perform_attack(target: CombatCharacter) -> void:
	_atk_timer = attack_interval
	if target == null or target.is_dead:
		return
	_attacking = true
	_play_safe("attack")
	_spawn_attack_vfx(target)
	var mit: float = 0.5
	if _manager != null and _manager.has_method("get_def_mitigation"):
		mit = float(_manager.get_def_mitigation())
	var raw := atk
	var dmg := maxf(1.0, raw - target.defense * mit)
	target.take_damage(dmg, self)
	if _manager != null and _manager.has_method("log_combat"):
		_manager.log_combat("%s → %s  %d" % [display_name, target.display_name, int(round(dmg))])


func _spawn_attack_vfx(target: CombatCharacter) -> void:
	var kind := "slash"
	if team == Team.ALLY:
		match job:
			"mage":
				kind = "magic"
			"healer":
				kind = "heal"
			_:
				kind = "slash"
	else:
		kind = "hit"
	var vfx := AnimatedSprite2D.new()
	vfx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	vfx.sprite_frames = SpriteFactory.vfx_frames(kind)
	vfx.z_index = 20
	var parent_node: Node = get_parent()
	if parent_node:
		parent_node.add_child(vfx)
	else:
		add_child(vfx)
	vfx.global_position = target.global_position + Vector2(0, -12)
	vfx.play("play")
	vfx.animation_finished.connect(func():
		if is_instance_valid(vfx):
			vfx.queue_free()
	)


func take_damage(amount: float, _attacker: CombatCharacter = null) -> void:
	if is_dead:
		return
	hp = maxf(0.0, hp - amount)
	if _hp_bar:
		_hp_bar.value = hp
	hp_changed.emit(hp, hp_max)
	_flash_t = 0.12
	if _sprite:
		_sprite.modulate = Color(1.4, 0.7, 0.7, 1)
		if not _attacking:
			_play_safe("hit")
	if hp <= 0.0:
		_die()


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	_attacking = false
	if _sprite:
		_sprite.modulate = Color(0.45, 0.45, 0.5, 0.75)
		_play_safe("death")
		_sprite.pause()
	if _hp_bar:
		_hp_bar.value = 0
	died.emit(self)
	if _manager != null and _manager.has_method("log_combat"):
		_manager.log_combat("%s 전투불능" % display_name)
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs:
		cs.disabled = true
	set_physics_process(false)


func hp_ratio() -> float:
	if hp_max <= 0.0:
		return 0.0
	return hp / hp_max
