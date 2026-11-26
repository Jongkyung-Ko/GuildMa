class_name CombatCharacter
extends CharacterBody2D

## Auto-combat actor with role-based approach slots + ally separation.
## Visuals: cleaned pixel sprites + compact VFX (no giant dirty rectangles).

signal hp_changed(current: float, maximum: float)
signal died(who: CombatCharacter)

enum Team { ALLY, ENEMY }

const MIN_SEPARATION := 96.0
const SEPARATION_STRENGTH := 5.5

var team: Team = Team.ALLY
var display_name: String = ""
var job: String = ""
var enemy_kind: String = "wolf"
var member_id: String = ""
var formation_slot: int = 0
var preferred_radius: float = 40.0
var preferred_angle: float = PI  # radians around target; PI = approach from left
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


func assign_formation(slot: int) -> void:
	formation_slot = slot
	_apply_role_offsets()
	_layout_overhead_ui()


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
	preferred_radius = attack_range * 0.85
	preferred_angle = 0.0  # approach allies from the right
	if is_inside_tree():
		_refresh_visuals()


func _apply_role_offsets() -> void:
	# Wide role rings west of the target so sprites (≈70px) do not stack.
	# Tank front, DPS flanks, Mage/Healer rear.
	match job:
		"tank":
			attack_range = 64.0
			move_speed *= 0.95
			preferred_radius = 58.0
			preferred_angle = PI + 0.08
		"lord":
			attack_range = 78.0
			preferred_radius = 70.0
			preferred_angle = PI - 0.7
		"dps":
			attack_range = 76.0
			atk *= 1.08
			preferred_radius = 68.0
			preferred_angle = PI + 0.85
		"healer":
			attack_range = 140.0
			atk *= 0.7
			move_speed *= 0.95
			preferred_radius = 120.0
			preferred_angle = PI - 1.15
		"mage":
			attack_range = 150.0
			atk *= 1.05
			move_speed *= 0.92
			preferred_radius = 130.0
			preferred_angle = PI + 1.2
		"enemy":
			preferred_radius = 56.0 + float(formation_slot) * 12.0
			preferred_angle = 0.15 + float(formation_slot) * 0.7
		_:
			preferred_radius = 70.0
			preferred_angle = PI


func _build_visuals() -> void:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 12.0
	shape.shape = circle
	add_child(shape)

	_sprite = AnimatedSprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.centered = true
	# Feet near body origin for ground alignment.
	_sprite.position = Vector2(0, -18)
	_sprite.animation_finished.connect(_on_anim_finished)
	add_child(_sprite)

	_hp_bar = ProgressBar.new()
	_hp_bar.min_value = 0
	_hp_bar.max_value = 100
	_hp_bar.value = 100
	_hp_bar.show_percentage = false
	_hp_bar.size = Vector2(36, 4)
	_hp_bar.position = Vector2(-18, -46)
	_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_bar.z_index = 5
	var hp_bg := StyleBoxFlat.new()
	hp_bg.bg_color = Color(0.08, 0.09, 0.12, 0.75)
	hp_bg.set_corner_radius_all(2)
	var hp_fill := StyleBoxFlat.new()
	hp_fill.bg_color = Color(0.42, 0.86, 0.48, 0.95) if team == Team.ALLY else Color(0.9, 0.4, 0.35, 0.95)
	hp_fill.set_corner_radius_all(2)
	_hp_bar.add_theme_stylebox_override("background", hp_bg)
	_hp_bar.add_theme_stylebox_override("fill", hp_fill)
	add_child(_hp_bar)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.size = Vector2(100, 16)
	_name_label.add_theme_font_size_override("font_size", 11)
	_name_label.add_theme_color_override("font_color", Color(0.95, 0.93, 0.88))
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.z_index = 5
	# Names live in the side HUD — hide world labels to prevent pile-up.
	_name_label.visible = false
	UIStyle.apply_font(_name_label, 11)
	add_child(_name_label)
	_layout_overhead_ui()

	_refresh_visuals()


func _layout_overhead_ui() -> void:
	# Stagger labels by formation slot so nearby actors stay readable.
	var x_bias := float(formation_slot - 2) * 10.0
	var y_bias := -72.0 - absf(float(formation_slot - 2)) * 6.0
	if _name_label:
		_name_label.position = Vector2(-50.0 + x_bias, y_bias)
	if _hp_bar:
		_hp_bar.position = Vector2(-22.0 + x_bias * 0.35, y_bias + 16.0)


func _refresh_visuals() -> void:
	if _name_label:
		_name_label.text = display_name
		if team == Team.ENEMY:
			_name_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.62))
		else:
			_name_label.add_theme_color_override("font_color", Color(0.95, 0.93, 0.88))
	if _hp_bar:
		_hp_bar.max_value = hp_max
		_hp_bar.value = hp
		var hp_fill := StyleBoxFlat.new()
		hp_fill.bg_color = Color(0.42, 0.86, 0.48, 0.95) if team == Team.ALLY else Color(0.9, 0.4, 0.35, 0.95)
		hp_fill.set_corner_radius_all(2)
		_hp_bar.add_theme_stylebox_override("fill", hp_fill)
	if _sprite == null:
		return
	if team == Team.ALLY:
		_sprite.sprite_frames = SpriteFactory.ally_frames(job if job != "" else "dps")
		_face_right = true
	else:
		_sprite.sprite_frames = SpriteFactory.enemy_frames(enemy_kind)
		_face_right = false
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
	# Y-sort so front characters draw above rear ones; labels stay readable.
	z_index = int(global_position.y)

	if is_dead:
		return
	if _manager != null and _manager.has_method("is_combat_active") and not _manager.is_combat_active():
		velocity = Vector2.ZERO
		_apply_separation(delta)
		_clamp_to_field()
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
		_apply_separation(delta)
		if not _attacking:
			_play_safe("idle")
		return

	var desired := _desired_slot_position(target)
	var to_slot := desired - global_position
	var slot_dist := to_slot.length()
	var dist_to_target := global_position.distance_to(target.global_position)

	if absf(target.global_position.x - global_position.x) > 0.05:
		_face_right = target.global_position.x > global_position.x
		_sprite.flip_h = not _face_right

	var in_attack_range := dist_to_target <= attack_range
	var near_slot := slot_dist <= 10.0

	if not in_attack_range or not near_slot:
		var dir := Vector2.ZERO
		if slot_dist > 1.0:
			dir = to_slot.normalized()
		# Soft keep-away for backline if too close to target.
		if team == Team.ALLY and job in ["mage", "healer"] and dist_to_target < preferred_radius * 0.72:
			dir = (global_position - target.global_position).normalized()
		velocity = dir * move_speed
		_apply_separation(delta)
		move_and_slide()
		_clamp_to_field()
		if not _attacking:
			_play_safe("walk" if velocity.length() > 8.0 else "idle")
	else:
		# Hold the role slot while attacking so the party does not collapse inward.
		global_position = global_position.lerp(desired, clampf(6.0 * delta, 0.0, 0.35))
		# Keep a small body gap so attacker/target sprites do not merge.
		if dist_to_target < 48.0:
			var away := (global_position - target.global_position)
			if away.length() > 0.1:
				global_position += away.normalized() * minf(5.0, 48.0 - dist_to_target)
		velocity = Vector2.ZERO
		_apply_separation(delta)
		_clamp_to_field()
		if not _attacking:
			_play_safe("idle")
		if _atk_timer <= 0.0 and in_attack_range:
			_perform_attack(target)


func _desired_slot_position(target: CombatCharacter) -> Vector2:
	var ang := preferred_angle
	if team == Team.ENEMY:
		# Spread enemies around their target instead of stacking.
		ang = preferred_angle + formation_slot * 0.55
	var pos := target.global_position + Vector2(cos(ang), sin(ang)) * preferred_radius
	pos.x = clampf(pos.x, 40.0, 1240.0)
	pos.y = clampf(pos.y, 100.0, 600.0)
	return pos


func _apply_separation(_delta: float) -> void:
	if _manager == null:
		return
	var mates: Array = []
	if team == Team.ALLY and _manager.has_method("get_allies"):
		mates = _manager.get_allies()
	elif team == Team.ENEMY and _manager.has_method("get_enemies"):
		mates = _manager.get_enemies()
	var push := Vector2.ZERO
	for m in mates:
		var other := m as CombatCharacter
		if other == null or other == self or other.is_dead:
			continue
		var delta_pos := global_position - other.global_position
		var d := delta_pos.length()
		if d < 0.001:
			# Identical coords — break the tie with slot bias.
			delta_pos = Vector2(0, 1 if formation_slot >= other.formation_slot else -1)
			d = 1.0
		if d >= MIN_SEPARATION:
			continue
		var strength := ((MIN_SEPARATION - d) / MIN_SEPARATION)
		push += delta_pos.normalized() * strength * move_speed * SEPARATION_STRENGTH
		# Hard positional untangle so sprites never remain stacked.
		if d < MIN_SEPARATION * 0.85:
			global_position += delta_pos.normalized() * minf(6.0, (MIN_SEPARATION - d) * 0.35)
	if push.length() > 0.0:
		velocity += push


func _clamp_to_field() -> void:
	global_position.x = clampf(global_position.x, 40.0, 1240.0)
	global_position.y = clampf(global_position.y, 80.0, 620.0)


func _find_target() -> CombatCharacter:
	if _manager == null or not _manager.has_method("get_opponents"):
		return null
	var foes: Array = _manager.get_opponents(team)
	var alive: Array = []
	for f in foes:
		var c := f as CombatCharacter
		if c == null or c.is_dead:
			continue
		if global_position.distance_to(c.global_position) > aggro_range:
			continue
		alive.append(c)
	if alive.is_empty():
		return null
	# Spread focus: each ally prefers a different living enemy by formation slot.
	if team == Team.ALLY and alive.size() > 1:
		return alive[formation_slot % alive.size()]
	# Otherwise nearest.
	var best: CombatCharacter = null
	var best_d := INF
	for c in alive:
		var d := global_position.distance_to(c.global_position)
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
	var scale := 1.0
	var lift := Vector2(0, -14)
	if team == Team.ALLY:
		match job:
			"mage":
				kind = "magic"
				scale = 1.15
				lift = Vector2(0, -20)
			"healer":
				kind = "heal"
				scale = 1.1
				lift = Vector2(0, -24)
			"tank", "lord":
				kind = "slash"
				scale = 1.05
			_:
				kind = "slash"
				scale = 0.95
	else:
		kind = "hit"
		scale = 0.9

	var vfx := AnimatedSprite2D.new()
	vfx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	vfx.sprite_frames = SpriteFactory.vfx_frames(kind)
	vfx.z_index = 40
	vfx.centered = true
	vfx.scale = Vector2(scale, scale)
	# Place between attacker and target — never full-screen.
	var mid := global_position.lerp(target.global_position, 0.7) + lift
	var parent_node: Node = get_parent()
	if parent_node:
		parent_node.add_child(vfx)
	else:
		add_child(vfx)
	vfx.global_position = mid
	vfx.play("play")
	# Free on anim end; Timer child is a failsafe if the signal is missed.
	vfx.animation_finished.connect(vfx.queue_free)
	var life := Timer.new()
	life.wait_time = 0.55
	life.one_shot = true
	vfx.add_child(life)
	life.timeout.connect(vfx.queue_free)
	life.start()


func take_damage(amount: float, _attacker: CombatCharacter = null) -> void:
	if is_dead:
		return
	hp = maxf(0.0, hp - amount)
	if _hp_bar:
		_hp_bar.value = hp
	hp_changed.emit(hp, hp_max)
	_flash_t = 0.12
	if _sprite:
		_sprite.modulate = Color(1.35, 0.75, 0.75, 1)
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
		_sprite.modulate = Color(0.55, 0.55, 0.6, 0.7)
		_play_safe("death")
		_sprite.pause()
	if _hp_bar:
		_hp_bar.value = 0
	if _name_label:
		_name_label.modulate = Color(1, 1, 1, 0.55)
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
