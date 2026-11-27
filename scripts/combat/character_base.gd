class_name CombatCharacter
extends CharacterBody2D

## Auto-combat actor: role slots, attack state machine, mage projectiles, healer heals.
## Attack: WINDUP → ACTIVE (damage / projectile / heal) → RECOVERY → IDLE.

signal hp_changed(current: float, maximum: float)
signal died(who: CombatCharacter)

enum Team { ALLY, ENEMY }

enum AnimState {
	IDLE,
	WALK,
	ATTACK_START,
	ATTACK_WINDUP,
	ATTACK_ACTIVE,
	APPLY_DAMAGE,
	ATTACK_RECOVERY,
	HIT,
	DEATH,
}

const MIN_SEPARATION := 100.0
const SEPARATION_STRENGTH := 4.5
const SLOT_ARRIVE := 22.0

var team: Team = Team.ALLY
var display_name: String = ""
var job: String = ""
var enemy_kind: String = "wolf"
var member_id: String = ""
var formation_slot: int = 0
var preferred_radius: float = 40.0
var preferred_angle: float = PI
var hp: float = 1.0
var hp_max: float = 1.0
var atk: float = 1.0
var defense: float = 0.0
var move_speed: float = 80.0
var attack_range: float = 36.0
var attack_interval: float = 1.0
var aggro_range: float = 2000.0
var is_dead: bool = false
var heal_power: float = 0.0

var _atk_timer: float = 0.0
var attacks_started: int = 0
var _manager: Node = null
var _visual_root: Node2D
var _sprite: AnimatedSprite2D
var _name_label: Label
var _hp_bar: ProgressBar
var _flash_t: float = 0.0
var _face_right: bool = true
var _balance: Dictionary = {}
var _sprite_pivot: Vector2 = Vector2(48, 72)
var _sprite_scale: float = 0.95

var _anim_state: AnimState = AnimState.IDLE
var _pending_target: CombatCharacter = null
var _pending_damage: float = 0.0
var _pending_heal: bool = false
var _damage_applied: bool = false
var _attack_active_idx: int = 2
var _hit_lock_t: float = 0.0
var _shake_base: Vector2 = Vector2.ZERO
## Safety: if animation_finished is missed, force leave attack after this many seconds.
var _attack_elapsed: float = 0.0
var _attack_timeout: float = 1.6
## Instrumentation for automated combat AI tests.
## attacks_started: attack anim began
## attacks_landed: melee swing connected OR (legacy) release tick
## projectiles_fired: mage fireball spawned
## damage_hits: actual HP damage applied to a living target (melee or bolt impact)
var attacks_landed: int = 0
var projectiles_fired: int = 0
var damage_hits: int = 0
var heals_landed: int = 0
var _enemy_tint: Color = Color(1, 1, 1, 1)
var _move_slow_t: float = 0.0
var _move_slow_mult: float = 1.0
var _base_move_speed: float = 100.0
var enemy_tier: String = "normal"


func _ready() -> void:
	_build_visuals()


func bind_manager(manager: Node) -> void:
	_manager = manager


func assign_formation(slot: int) -> void:
	formation_slot = slot
	_apply_role_offsets()
	_layout_overhead_ui()


func setup_from_member(member: Dictionary, balance: Dictionary) -> void:
	_balance = balance
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
	move_speed = minf(float(balance.get("move_cap", 220)), float(balance.get("move_base", 115)) + agi * float(balance.get("move_agi", 2.5)))
	attack_interval = _job_interval(job, balance)
	heal_power = atk * float(balance.get("heal_atk_mult", 1.35))
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
	enemy_tier = str(data.get("tier", "normal"))
	hp_max = float(data.get("hp", 60))
	hp = hp_max
	atk = float(data.get("atk", 8))
	defense = float(data.get("def", 2))
	move_speed = float(data.get("move", 100)) * 1.35
	_base_move_speed = move_speed
	var aspd: float = float(data.get("aspd", 1.0))
	attack_interval = clampf(1.15 / maxf(0.5, aspd), 0.7, 1.6)
	# Floor attack_range so chase slot (preferred_radius) can sit inside swing reach.
	attack_range = maxf(40.0, float(data.get("attack_range", 36)))
	aggro_range = float(data.get("aggro_range", 900))
	preferred_radius = attack_range * 0.72
	preferred_angle = 0.0
	_enemy_tint = Color(1, 1, 1, 1)
	var c = data.get("color", null)
	if typeof(c) == TYPE_ARRAY and c.size() >= 3:
		var a := float(c[3]) if c.size() > 3 else 1.0
		_enemy_tint = Color(float(c[0]), float(c[1]), float(c[2]), a)
	_apply_role_offsets()
	if is_inside_tree():
		_refresh_visuals()


func apply_move_slow(mult: float, duration: float) -> void:
	_move_slow_mult = clampf(mult, 0.2, 1.0)
	_move_slow_t = maxf(_move_slow_t, duration)
	move_speed = maxf(40.0, _base_move_speed * _move_slow_mult)


func _job_interval(j: String, balance: Dictionary) -> float:
	var table: Dictionary = balance.get("job_attack_interval", {})
	if table.has(j):
		return float(table[j])
	match j:
		"tank":
			return 1.15
		"lord":
			return 0.95
		"dps":
			return 0.65
		"mage":
			return 1.30
		"healer":
			return 1.50
		_:
			return 1.0


func _apply_role_offsets() -> void:
	match job:
		"tank":
			attack_range = 72.0
			move_speed *= 0.98
			preferred_radius = 62.0
			preferred_angle = PI + 0.08
		"lord":
			attack_range = 70.0
			preferred_radius = 60.0
			preferred_angle = PI - 0.65
		"dps":
			attack_range = 68.0
			atk *= 1.08
			preferred_radius = 58.0
			preferred_angle = PI + 0.8
		"healer":
			attack_range = 160.0
			atk *= 0.55
			move_speed *= 0.95
			preferred_radius = 130.0
			preferred_angle = PI - 1.15
		"mage":
			attack_range = 170.0
			atk *= 1.12
			move_speed *= 0.92
			preferred_radius = 140.0
			preferred_angle = PI + 1.2
		"enemy":
			# Must stay INSIDE attack_range or chase AI never swings.
			# (Previously forced ~52px while wolf attack_range was ~28.)
			preferred_radius = maxf(12.0, attack_range * 0.72)
			preferred_angle = 0.15 + float(formation_slot) * 0.55
		_:
			preferred_radius = 60.0
			preferred_angle = PI


func _build_visuals() -> void:
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var circle := CircleShape2D.new()
	circle.radius = 12.0
	shape.shape = circle
	add_child(shape)

	# Foot pivot parent — sprite frames are foot-aligned; do not rely on centered alone.
	_visual_root = Node2D.new()
	_visual_root.name = "VisualPivot"
	_visual_root.scale = Vector2(_sprite_scale, _sprite_scale)
	add_child(_visual_root)

	_sprite = AnimatedSprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.centered = false
	_sprite.position = Vector2.ZERO
	_shake_base = Vector2.ZERO
	_sprite.animation_finished.connect(_on_anim_finished)
	_sprite.frame_changed.connect(_on_frame_changed)
	_visual_root.add_child(_sprite)

	_hp_bar = ProgressBar.new()
	_hp_bar.min_value = 0
	_hp_bar.max_value = 100
	_hp_bar.value = 100
	_hp_bar.show_percentage = false
	_hp_bar.size = Vector2(36, 4)
	_hp_bar.position = Vector2(-18, -58)
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
	_name_label.visible = false
	var ui: Node = null
	var ml := Engine.get_main_loop()
	if ml:
		ui = ml.root.get_node_or_null("/root/UIStyle")
	if ui and ui.has_method("apply_font"):
		ui.apply_font(_name_label, 11)
	add_child(_name_label)
	_layout_overhead_ui()
	_refresh_visuals()


func _layout_overhead_ui() -> void:
	var x_bias := float(formation_slot - 2) * 10.0
	var y_bias := -96.0 - absf(float(formation_slot - 2)) * 6.0
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
		var j := job if job != "" else "dps"
		_sprite.sprite_frames = SpriteFactory.ally_frames(j)
		_attack_active_idx = SpriteFactory.attack_active_frame(j)
		_sprite_pivot = SpriteFactory.job_pivot(j)
		_face_right = true
	else:
		_sprite.sprite_frames = SpriteFactory.enemy_frames(enemy_kind)
		_attack_active_idx = SpriteFactory.attack_active_frame("enemy")
		# Monsters keep centered art; approximate foot under mid-canvas.
		_sprite_pivot = Vector2(48, 72)
		_face_right = false
		_sprite.modulate = _enemy_tint
	_apply_sprite_pivot()
	_apply_facing()
	_set_anim_state(AnimState.IDLE)
	_play_anim("idle", true)


func _apply_sprite_pivot() -> void:
	if _sprite == null:
		return
	if team == Team.ALLY:
		# Texture top-left so foot pixel lands on VisualPivot origin (actor feet).
		_sprite.centered = false
		_sprite.flip_h = false
		_sprite.position = Vector2(-_sprite_pivot.x, -_sprite_pivot.y)
		_shake_base = _sprite.position
	else:
		_sprite.centered = true
		_sprite.position = Vector2(0, -30)
		_shake_base = _sprite.position


func _apply_facing() -> void:
	## Mirror around foot pivot via visual_root scale — flip_h would shift uncentered art.
	if _visual_root == null or _sprite == null:
		return
	if team == Team.ALLY:
		var sx := _sprite_scale if _face_right else -_sprite_scale
		_visual_root.scale = Vector2(sx, _sprite_scale)
		_sprite.flip_h = false
	else:
		_visual_root.scale = Vector2(_sprite_scale, _sprite_scale)
		_sprite.flip_h = not _face_right


func _attack_sheet_frame() -> int:
	## Current attack SpriteFrames index → sheet combat_XX index, or -1.
	if _sprite == null or _sprite.animation != "attack":
		return -1
	var idxs: Array = SpriteFactory.attack_sheet_indices(job if team == Team.ALLY else "enemy")
	var fr := _sprite.frame
	if fr < 0 or fr >= idxs.size():
		return -1
	return int(idxs[fr])


func muzzle_global() -> Vector2:
	## World-space cast / staff tip. Snapshot at call time — bolt ignores later caster motion.
	if team == Team.ALLY and job != "":
		var sheet := _attack_sheet_frame()
		# Idle / non-attack: use sheet 0 tip when per-frame data exists (mage).
		if sheet < 0 and job == "mage":
			sheet = 0
		var local := SpriteFactory.muzzle_offset(job, _face_right, sheet) * _sprite_scale
		return global_position + local
	return global_position + Vector2(18 if _face_right else -18, -28)


func _is_attacking() -> bool:
	return _anim_state in [
		AnimState.ATTACK_START,
		AnimState.ATTACK_WINDUP,
		AnimState.ATTACK_ACTIVE,
		AnimState.APPLY_DAMAGE,
		AnimState.ATTACK_RECOVERY,
	]


func _set_anim_state(s: AnimState) -> void:
	_anim_state = s


func _play_anim(anim: String, force: bool = false) -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	if not _sprite.sprite_frames.has_animation(anim):
		return
	if not force and _sprite.animation == anim and _sprite.is_playing():
		return
	_sprite.play(anim)


func _on_frame_changed() -> void:
	if is_dead or _sprite == null:
		return
	# Re-pin foot pivot every frame so shake / texture swaps never teleport the actor.
	if team == Team.ALLY:
		_apply_sprite_pivot()
	if not _is_attacking():
		return
	if _sprite.animation != "attack":
		return
	var fr := _sprite.frame
	if fr < _attack_active_idx:
		_set_anim_state(AnimState.ATTACK_WINDUP)
		return
	if fr == _attack_active_idx or (fr > _attack_active_idx and not _damage_applied):
		_set_anim_state(AnimState.ATTACK_ACTIVE)
		_apply_pending_damage()
		_set_anim_state(AnimState.ATTACK_RECOVERY)
		return
	_set_anim_state(AnimState.ATTACK_RECOVERY)


func _on_anim_finished() -> void:
	if is_dead:
		return
	if _is_attacking():
		_finish_attack_cycle()
		return
	if _anim_state == AnimState.HIT:
		_set_anim_state(AnimState.IDLE)
		_play_anim("idle", true)


func _finish_attack_cycle() -> void:
	## Always leave attack states so the next swing can start (missed signals OK).
	_apply_pending_damage()
	_pending_target = null
	_pending_damage = 0.0
	_pending_heal = false
	_damage_applied = false
	_attack_elapsed = 0.0
	_set_anim_state(AnimState.IDLE)
	_play_anim("idle", true)


func _apply_pending_damage() -> void:
	if _damage_applied:
		return
	_damage_applied = true
	_set_anim_state(AnimState.APPLY_DAMAGE)
	var target := _pending_target
	if target == null or not is_instance_valid(target) or target.is_dead:
		return

	if _pending_heal:
		_apply_heal(target)
		return

	if job == "mage" and team == Team.ALLY:
		_launch_fireball(target, _pending_damage)
		# attacks_landed = release/spawn tick; damage_hits increments on bolt impact.
		attacks_landed += 1
		projectiles_fired += 1
		return

	# Melee / monster hit
	_spawn_melee_vfx(target)
	var toward := target.global_position - global_position
	if toward.length() > 1.0:
		global_position += toward.normalized() * (8.0 if job == "tank" else 5.0)
	var heavy := job in ["tank", "lord"]
	target.take_damage(_pending_damage, self, {"heavy": heavy})
	attacks_landed += 1
	damage_hits += 1
	if heavy and _manager != null and _manager.has_method("shake_camera"):
		_manager.shake_camera(2.8 if job == "tank" else 1.8, 0.1)
		CombatFx.hit_stop(_manager, 0.045 if job == "tank" else 0.03)
	if _manager != null and _manager.has_method("log_combat"):
		_manager.log_combat("%s → %s  %d" % [display_name, target.display_name, int(round(_pending_damage))])


func _apply_heal(ally: CombatCharacter) -> void:
	var amount := maxf(8.0, heal_power)
	ally.receive_heal(amount, self)
	heals_landed += 1
	_spawn_heal_vfx(ally)
	var audio_h := get_node_or_null("/root/AudioManager")
	if audio_h and audio_h.has_method("play_magic"):
		audio_h.play_magic()
	if _manager != null and _manager.has_method("log_combat"):
		_manager.log_combat("%s ♥ %s  +%d" % [display_name, ally.display_name, int(round(amount))])


func _launch_fireball(target: CombatCharacter, dmg: float) -> void:
	var audio_m := get_node_or_null("/root/AudioManager")
	if audio_m and audio_m.has_method("play_magic"):
		audio_m.play_magic()
	var bolt := CombatProjectile.new()
	var parent_node: Node = get_parent()
	if parent_node:
		parent_node.add_child(bolt)
	else:
		add_child(bolt)
	# Snapshot staff tip now — bolt keeps its own start and ignores caster motion after.
	var origin := muzzle_global()
	var travel: float = 0.35
	if not _balance.is_empty():
		travel = float(_balance.get("projectile_travel", 0.35))
	bolt.setup(origin, target, dmg, self, _manager, travel)


func _physics_process(delta: float) -> void:
	z_index = int(global_position.y)

	if is_dead:
		return

	if _flash_t > 0.0:
		_flash_t -= delta
		if _sprite and _flash_t <= 0.0 and _anim_state != AnimState.HIT:
			_sprite.modulate = _enemy_tint if team == Team.ENEMY else Color(1, 1, 1, 1)
	if _move_slow_t > 0.0:
		_move_slow_t -= delta
		if _move_slow_t <= 0.0:
			_move_slow_mult = 1.0
			move_speed = _base_move_speed
	if _hit_lock_t > 0.0:
		_hit_lock_t -= delta

	if _manager != null and _manager.has_method("is_combat_active") and not _manager.is_combat_active():
		velocity = Vector2.ZERO
		_apply_separation(delta)
		_clamp_to_field()
		if not _is_attacking() and _anim_state != AnimState.HIT:
			_set_anim_state(AnimState.IDLE)
			_play_anim("idle")
		return

	_atk_timer = maxf(0.0, _atk_timer - delta)

	if _is_attacking():
		_attack_elapsed += delta
		velocity = Vector2.ZERO
		_apply_separation(delta)
		_clamp_to_field()
		# Missed animation_finished / interrupted attack → never soft-lock.
		# Grace window so play() can start before we treat "not playing" as finished.
		var anim_dead := (
			_attack_elapsed > 0.12
			and (
				_sprite == null
				or _sprite.animation != "attack"
				or not _sprite.is_playing()
			)
		)
		if anim_dead or _attack_elapsed >= _attack_timeout:
			_finish_attack_cycle()
		return

	# Healer: prefer heal when someone is hurt
	if job == "healer" and team == Team.ALLY and _can_start_attack():
		var hurt := _find_heal_target()
		if hurt != null:
			_face_toward(hurt)
			_perform_heal(hurt)
			return

	var target := _find_target()
	if target == null:
		velocity = Vector2.ZERO
		_apply_separation(delta)
		if _anim_state != AnimState.HIT:
			_set_anim_state(AnimState.IDLE)
			_play_anim("idle")
		return

	var desired := _desired_slot_position(target)
	var to_slot := desired - global_position
	var slot_dist := to_slot.length()
	var dist_to_target := global_position.distance_to(target.global_position)
	_face_toward(target)

	var in_attack_range := dist_to_target <= attack_range
	# Backline: keep preferred distance; never rush into melee.
	if team == Team.ALLY and job in ["mage", "healer"]:
		if dist_to_target < preferred_radius * 0.72:
			velocity = (global_position - target.global_position).normalized() * move_speed
			_apply_separation(delta)
			move_and_slide()
			_clamp_to_field()
			_set_anim_state(AnimState.WALK)
			_play_anim("walk")
			return
		# In good range — stop and cast/attack
		if in_attack_range:
			velocity = Vector2.ZERO
			if slot_dist > SLOT_ARRIVE:
				global_position = global_position.lerp(desired, clampf(4.0 * delta, 0.0, 0.25))
			_apply_separation(delta)
			_clamp_to_field()
			if _anim_state != AnimState.HIT:
				_set_anim_state(AnimState.IDLE)
				_play_anim("idle")
			if _can_start_attack():
				_perform_attack(target)
			return

	# Melee / monsters: attack as soon as in range — do not wait for perfect slot.
	if in_attack_range:
		velocity = Vector2.ZERO
		# Soft settle toward slot without circling
		if slot_dist > SLOT_ARRIVE:
			global_position = global_position.lerp(desired, clampf(5.0 * delta, 0.0, 0.3))
		# Only nudge out of body-overlap — never push past attack_range.
		var crowd := maxf(14.0, attack_range * 0.4)
		if dist_to_target < crowd:
			var away := global_position - target.global_position
			if away.length() > 0.1:
				global_position += away.normalized() * minf(3.0, crowd - dist_to_target)
		_apply_separation(delta)
		_clamp_to_field()
		if _anim_state != AnimState.HIT:
			_set_anim_state(AnimState.IDLE)
			_play_anim("idle")
		if _can_start_attack():
			_perform_attack(target)
		return

	# Out of range — move to slot / close distance
	var dir := Vector2.ZERO
	if slot_dist > 1.0:
		dir = to_slot.normalized()
	else:
		dir = (target.global_position - global_position).normalized()
	velocity = dir * move_speed
	_apply_separation(delta)
	move_and_slide()
	_clamp_to_field()
	if _anim_state != AnimState.HIT:
		if velocity.length() > 8.0:
			_set_anim_state(AnimState.WALK)
			_play_anim("walk")
		else:
			_set_anim_state(AnimState.IDLE)
			_play_anim("idle")


func _face_toward(who: CombatCharacter) -> void:
	if who == null or _sprite == null:
		return
	if absf(who.global_position.x - global_position.x) > 0.05:
		_face_right = who.global_position.x > global_position.x
		_apply_facing()


func _desired_slot_position(target: CombatCharacter) -> Vector2:
	var ang := preferred_angle
	if team == Team.ENEMY:
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
			delta_pos = Vector2(0, 1 if formation_slot >= other.formation_slot else -1)
			d = 1.0
		if d >= MIN_SEPARATION:
			continue
		var strength := ((MIN_SEPARATION - d) / MIN_SEPARATION)
		push += delta_pos.normalized() * strength * move_speed * SEPARATION_STRENGTH
		if d < MIN_SEPARATION * 0.8:
			global_position += delta_pos.normalized() * minf(5.0, (MIN_SEPARATION - d) * 0.3)
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
	# Nearest living foe (stable; avoids slot-forced far targets delaying attacks)
	var best: CombatCharacter = null
	var best_d := INF
	for c in alive:
		var d := global_position.distance_to(c.global_position)
		# Slight slot bias so allies don't all pile the same target
		if team == Team.ALLY and alive.size() > 1:
			d += float((formation_slot + c.formation_slot) % alive.size()) * 8.0
		if d < best_d:
			best_d = d
			best = c
	return best


func _find_heal_target() -> CombatCharacter:
	if _manager == null or not _manager.has_method("get_allies"):
		return null
	var thresh: float = 0.75
	if not _balance.is_empty():
		thresh = float(_balance.get("heal_threshold", 0.75))
	var best: CombatCharacter = null
	var best_ratio := 2.0
	for a in _manager.get_allies():
		var c := a as CombatCharacter
		if c == null or c.is_dead or c == self:
			continue
		var r := c.hp_ratio()
		if r <= thresh and r < best_ratio:
			best_ratio = r
			best = c
	return best


func _can_start_attack() -> bool:
	return (not _is_attacking()) and _atk_timer <= 0.0


func _arm_attack_cooldown() -> void:
	_atk_timer = attack_interval
	attacks_started += 1


func _perform_attack(target: CombatCharacter) -> void:
	if target == null or target.is_dead:
		return
	if not _can_start_attack():
		return
	_arm_attack_cooldown()
	var mit: float = 0.5
	if _manager != null and _manager.has_method("get_def_mitigation"):
		mit = float(_manager.get_def_mitigation())
	var dmg := maxf(1.0, atk - target.defense * mit)
	_pending_target = target
	_pending_damage = dmg
	_pending_heal = false
	_damage_applied = false
	_attack_elapsed = 0.0
	_attack_timeout = maxf(1.2, attack_interval * 1.25)
	_set_anim_state(AnimState.ATTACK_START)
	_play_anim("attack", true)
	_set_anim_state(AnimState.ATTACK_WINDUP)


func _perform_heal(ally: CombatCharacter) -> void:
	if ally == null or ally.is_dead:
		return
	if not _can_start_attack():
		return
	_arm_attack_cooldown()
	_pending_target = ally
	_pending_damage = 0.0
	_pending_heal = true
	_damage_applied = false
	_attack_elapsed = 0.0
	_attack_timeout = maxf(1.2, attack_interval * 1.25)
	_set_anim_state(AnimState.ATTACK_START)
	_play_anim("attack", true)
	_set_anim_state(AnimState.ATTACK_WINDUP)


func reset_for_next_encounter() -> void:
	## Used after hunt room travel — revive + clear attack soft-locks.
	is_dead = false
	_pending_target = null
	_pending_damage = 0.0
	_pending_heal = false
	_damage_applied = false
	_attack_elapsed = 0.0
	_atk_timer = 0.15
	_hit_lock_t = 0.0
	_flash_t = 0.0
	_set_anim_state(AnimState.IDLE)
	if _sprite:
		_sprite.modulate = Color(1, 1, 1, 1)
		_play_anim("idle", true)
	if _name_label:
		_name_label.modulate = Color(1, 1, 1, 1)
	var cs := _collision_shape()
	if cs:
		cs.disabled = false
	set_physics_process(true)
	visible = true


func _collision_shape() -> CollisionShape2D:
	var named := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if named:
		return named
	for c in get_children():
		if c is CollisionShape2D:
			return c as CollisionShape2D
	return null


func _spawn_melee_vfx(target: CombatCharacter) -> void:
	var kind := "slash"
	var scale := 1.0
	var lift := Vector2(0, -14)
	if team == Team.ALLY:
		match job:
			"tank":
				kind = "hit"
				scale = 1.25
				lift = Vector2(0, -8)
			"lord":
				kind = "slash"
				scale = 1.1
			"dps":
				kind = "slash"
				scale = 0.95
			_:
				kind = "slash"
	else:
		kind = "hit"
		scale = 0.9
	var vfx := AnimatedSprite2D.new()
	vfx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	vfx.sprite_frames = SpriteFactory.vfx_frames(kind)
	vfx.z_index = 40
	vfx.centered = true
	vfx.scale = Vector2(scale, scale)
	var mid := global_position.lerp(target.global_position, 0.65) + lift
	var parent_node: Node = get_parent()
	if parent_node:
		parent_node.add_child(vfx)
	else:
		add_child(vfx)
	vfx.global_position = mid
	vfx.play("play")
	vfx.animation_finished.connect(vfx.queue_free)
	var life := Timer.new()
	life.wait_time = 0.4
	life.one_shot = true
	vfx.add_child(life)
	life.timeout.connect(vfx.queue_free)
	life.start()


func _spawn_heal_vfx(ally: CombatCharacter) -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		parent_node = self
	var origin := muzzle_global()
	var dest := ally.global_position + Vector2(0, -24)

	# Cast spark at staff tip
	var spark := AnimatedSprite2D.new()
	spark.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spark.sprite_frames = SpriteFactory.vfx_frames("heal")
	spark.z_index = 42
	spark.centered = true
	spark.scale = Vector2(0.85, 0.85)
	parent_node.add_child(spark)
	spark.global_position = origin
	spark.play("play")
	spark.animation_finished.connect(spark.queue_free)

	# Traveling heal mote from staff → ally
	var mote := Node2D.new()
	parent_node.add_child(mote)
	mote.global_position = origin
	mote.z_index = 43
	var mote_spr := AnimatedSprite2D.new()
	mote_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mote_spr.sprite_frames = SpriteFactory.vfx_frames("heal")
	mote_spr.centered = true
	mote_spr.scale = Vector2(0.7, 0.7)
	mote.add_child(mote_spr)
	mote_spr.play("play")
	var tw := mote.create_tween()
	tw.tween_property(mote, "global_position", dest, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		var land := AnimatedSprite2D.new()
		land.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		land.sprite_frames = SpriteFactory.vfx_frames("heal")
		land.z_index = 42
		land.centered = true
		land.scale = Vector2(1.25, 1.25)
		parent_node.add_child(land)
		land.global_position = dest
		land.play("play")
		land.animation_finished.connect(land.queue_free)
		var life := Timer.new()
		life.wait_time = 0.5
		life.one_shot = true
		land.add_child(life)
		life.timeout.connect(land.queue_free)
		life.start()
		mote.queue_free()
	)


func take_damage(amount: float, attacker: CombatCharacter = null, opts: Dictionary = {}) -> void:
	if is_dead:
		return
	hp = maxf(0.0, hp - amount)
	if _hp_bar:
		_hp_bar.value = hp
	hp_changed.emit(hp, hp_max)

	var heavy: bool = bool(opts.get("heavy", false))
	var magic: bool = bool(opts.get("magic", false))
	var kind := "heavy" if heavy or magic else "damage"
	if amount >= atk * 1.4:
		kind = "crit"

	var audio := get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_hit"):
		audio.play_hit()

	var parent_node: Node = get_parent()
	CombatFx.spawn_number(parent_node if parent_node else self, global_position, int(round(amount)), kind)
	# White flash for readable hit feedback
	_flash_t = 0.12
	if _sprite:
		CombatFx.white_flash(_sprite, 0.12)
		CombatFx.shake_sprite(_sprite, 5.0 if heavy else 3.2, 3)

	if attacker != null and is_instance_valid(attacker):
		var away := global_position - attacker.global_position
		if away.length() > 0.1:
			var kb := 10.0 if heavy else 5.0
			if magic:
				kb = 7.0
			global_position += away.normalized() * kb

	if not _is_attacking() and _sprite:
		_set_anim_state(AnimState.HIT)
		_hit_lock_t = 0.12
		_play_anim("hit", true)
	if hp <= 0.0:
		_die()


func receive_heal(amount: float, _healer: CombatCharacter = null) -> void:
	if is_dead:
		return
	var before := hp
	hp = minf(hp_max, hp + amount)
	var gained := hp - before
	if _hp_bar:
		_hp_bar.value = hp
	hp_changed.emit(hp, hp_max)
	if gained > 0.0:
		var parent_node: Node = get_parent()
		CombatFx.spawn_number(parent_node if parent_node else self, global_position, int(round(gained)), "heal")
		if _sprite:
			_sprite.modulate = Color(0.75, 1.25, 0.85, 1)
			_flash_t = 0.14


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	_pending_target = null
	_pending_damage = 0.0
	_pending_heal = false
	_damage_applied = true
	_set_anim_state(AnimState.DEATH)
	if _sprite:
		_sprite.modulate = Color(0.55, 0.55, 0.6, 0.7)
		_play_anim("death", true)
		_sprite.pause()
	if _hp_bar:
		_hp_bar.value = 0
	if _name_label:
		_name_label.modulate = Color(1, 1, 1, 0.55)
	died.emit(self)
	if _manager != null and _manager.has_method("log_combat"):
		_manager.log_combat("%s 전투불능" % display_name)
	var cs := _collision_shape()
	if cs:
		cs.disabled = true
	set_physics_process(false)


func hp_ratio() -> float:
	if hp_max <= 0.0:
		return 0.0
	return hp / hp_max


func get_anim_state_name() -> String:
	return String(AnimState.find_key(_anim_state))
