extends "res://scripts/combat/enemy_base.gd"

## Data-driven boss: phases (100–70 / 70–30 / ≤30), skill cooldowns, unique kits.
## Art may be placeholder (tinted fallback monster frames) until 3020.jpg splits land.

signal phase_changed(phase_id: String, label: String)
signal skill_used(skill_id: String, skill_name: String)

var boss_id: String = ""
var boss_def: Dictionary = {}
var phase_index: int = 0
var phase_label: String = ""
var _skill_cds: Dictionary = {}
var _aspd_buff: float = 0.0
var _aspd_buff_t: float = 0.0
var _shield: float = 0.0
var _slow_t: float = 0.0
var _base_move: float = 100.0
var _telegraph_t: float = 0.0
var _pending_skill_id: String = ""
var _pending_skill: Dictionary = {}
var sprite_scale_mult: float = 1.0


func setup_from_boss(def: Dictionary, enemy_fallback: Dictionary = {}) -> void:
	boss_def = def.duplicate(true)
	boss_id = str(def.get("id", ""))
	var merged: Dictionary = enemy_fallback.duplicate(true) if not enemy_fallback.is_empty() else {}
	for k in ["hp", "atk", "def", "move", "aspd", "aggro_range", "attack_range", "sprite", "name", "color"]:
		if def.has(k):
			merged[k] = def[k]
	merged["id"] = str(def.get("enemy_id", boss_id))
	merged["tier"] = str(merged.get("tier", "boss_hunt"))
	merged["boss_id"] = boss_id
	merged["behavior"] = "boss"
	setup_from_enemy(merged)
	sprite_scale_mult = float(def.get("scale", 1.5))
	if _visual_root:
		_visual_root.scale = Vector2(sprite_scale_mult, sprite_scale_mult)
	_base_move = move_speed
	_skill_cds.clear()
	var skills: Dictionary = def.get("skills", {})
	for sid in skills.keys():
		_skill_cds[str(sid)] = 0.0
	_enter_phase(0, true)


func setup_from_enemy(data: Dictionary) -> void:
	super.setup_from_enemy(data)
	boss_id = str(data.get("boss_id", boss_id))
	_apply_tint_from_data(data)


func _apply_tint_from_data(data: Dictionary) -> void:
	var c = data.get("color", null)
	if c == null and boss_def.has("color"):
		c = boss_def.get("color")
	if typeof(c) == TYPE_ARRAY and c.size() >= 3 and _sprite:
		var a := float(c[3]) if c.size() > 3 else 1.0
		_sprite.modulate = Color(float(c[0]), float(c[1]), float(c[2]), a)


func _refresh_visuals() -> void:
	super._refresh_visuals()
	if sprite_scale_mult > 0.0 and _visual_root:
		_visual_root.scale = Vector2(sprite_scale_mult, sprite_scale_mult)
	if not boss_def.is_empty():
		_apply_tint_from_data(boss_def)
	# Boss uses larger overhead HP; dedicated BossHud owns the main bar.
	if _hp_bar:
		_hp_bar.visible = false
	if _name_label:
		_name_label.visible = true
		_name_label.text = display_name


func current_phase() -> Dictionary:
	var phases: Array = boss_def.get("phases", [])
	if phase_index < 0 or phase_index >= phases.size():
		return {}
	return phases[phase_index]


func hp_ratio() -> float:
	return 0.0 if hp_max <= 0.0 else clampf(hp / hp_max, 0.0, 1.0)


func _enter_phase(idx: int, silent: bool = false) -> void:
	var phases: Array = boss_def.get("phases", [])
	if phases.is_empty():
		phase_index = 0
		phase_label = ""
		return
	phase_index = clampi(idx, 0, phases.size() - 1)
	var ph: Dictionary = phases[phase_index]
	phase_label = str(ph.get("label", "phase_%d" % phase_index))
	if not silent:
		phase_changed.emit(str(ph.get("id", "p%d" % phase_index)), phase_label)
		if _manager != null and _manager.has_method("log_combat"):
			_manager.log_combat("%s 페이즈 — %s" % [display_name, phase_label])


func _update_phase_from_hp() -> void:
	var phases: Array = boss_def.get("phases", [])
	if phases.is_empty():
		return
	var ratio := hp_ratio()
	var want := phases.size() - 1
	for i in range(phases.size()):
		var ph: Dictionary = phases[i]
		if ratio > float(ph.get("hp_ratio_min", 0.0)):
			want = i
			break
	if want != phase_index:
		_enter_phase(want)


func take_damage(amount: float, source: CombatCharacter = null, opts: Dictionary = {}) -> void:
	var dmg := amount
	if _shield > 0.0:
		var absorb := minf(_shield, dmg)
		_shield -= absorb
		dmg -= absorb
	super.take_damage(dmg, source, opts)
	if not is_dead:
		_update_phase_from_hp()


func _physics_process(delta: float) -> void:
	for sid in _skill_cds.keys():
		_skill_cds[sid] = maxf(0.0, float(_skill_cds[sid]) - delta)
	if _aspd_buff_t > 0.0:
		_aspd_buff_t -= delta
		if _aspd_buff_t <= 0.0:
			_aspd_buff = 0.0
	if _slow_t > 0.0:
		_slow_t -= delta
		if _slow_t <= 0.0:
			move_speed = _base_move

	if _telegraph_t > 0.0:
		_telegraph_t -= delta
		velocity = Vector2.ZERO
		if _telegraph_t <= 0.0 and _pending_skill_id != "":
			_resolve_skill(_pending_skill_id, _pending_skill)
			_pending_skill_id = ""
			_pending_skill = {}
		_apply_separation(delta)
		_clamp_to_field()
		return

	# Prefer boss skill when ready; otherwise fall through to chase-melee.
	if not is_dead and _manager != null and _manager.has_method("is_combat_active") and _manager.is_combat_active():
		if _try_start_skill():
			return

	super._physics_process(delta)


func _can_start_attack() -> bool:
	# Boss basic swing still uses interval; skills are separate.
	var interval := attack_interval
	if _aspd_buff > 0.0:
		interval = maxf(0.45, interval / (1.0 + _aspd_buff))
	return _atk_timer <= 0.0 and not _is_attacking() and _telegraph_t <= 0.0


func _try_start_skill() -> bool:
	if _is_attacking() or not _can_start_attack():
		return false
	var ph := current_phase()
	var skill_ids: Array = ph.get("skills", [])
	if skill_ids.is_empty():
		return false
	var skills: Dictionary = boss_def.get("skills", {})
	# Prefer an off-cooldown non-basic skill; fall back to first ready.
	var ready: Array = []
	for sid_v in skill_ids:
		var sid := str(sid_v)
		if float(_skill_cds.get(sid, 0.0)) > 0.0:
			continue
		if not skills.has(sid):
			continue
		ready.append(sid)
	if ready.is_empty():
		return false
	# Avoid always picking index 0: rotate by phase + hp.
	var pick := str(ready[int(Time.get_ticks_msec() / 500) % ready.size()])
	var skill: Dictionary = skills[pick]
	var kind := str(skill.get("kind", "melee"))
	# Let plain melee fall through to normal attack loop sometimes.
	if kind == "melee" and ready.size() == 1 and randf() < 0.55:
		return false
	_pending_skill_id = pick
	_pending_skill = skill
	_telegraph_t = float(skill.get("telegraph", 0.4))
	_atk_timer = 0.2
	if _manager != null and _manager.has_method("log_combat"):
		_manager.log_combat("%s 준비 — %s" % [display_name, str(skill.get("name", pick))])
	if _sprite:
		_sprite.modulate = Color(1.35, 1.15, 0.7, 1.0)
	return true


func _resolve_skill(skill_id: String, skill: Dictionary) -> void:
	if _sprite and not boss_def.is_empty():
		_apply_tint_from_data(boss_def)
	var cd := float(skill.get("cooldown", 5.0))
	_skill_cds[skill_id] = cd
	skill_used.emit(skill_id, str(skill.get("name", skill_id)))
	var kind := str(skill.get("kind", "melee"))
	var mult := float(skill.get("damage_mult", 1.0))
	var dmg := maxf(1.0, atk * mult)
	var target := _find_target()

	match kind:
		"self_buff":
			_aspd_buff = float(skill.get("self_buff_aspd", 0.0))
			_aspd_buff_t = float(skill.get("duration", 4.0))
			var shield_frac := float(skill.get("shield_frac", 0.0))
			if shield_frac > 0.0:
				_shield = maxf(_shield, hp_max * shield_frac)
			if _manager != null and _manager.has_method("log_combat"):
				_manager.log_combat("%s 사용 — %s" % [display_name, str(skill.get("name", skill_id))])
			_atk_timer = 0.4
			return
		"aoe_near":
			var radius := float(skill.get("radius", 150))
			_hit_allies_in_radius(dmg, radius, skill)
		"ranged", "dash", "melee":
			if kind == "dash" and target != null and is_instance_valid(target):
				var toward := target.global_position - global_position
				if toward.length() > 1.0:
					global_position += toward.normalized() * minf(140.0, toward.length() * 0.65)
			if target != null and is_instance_valid(target) and not target.is_dead:
				_apply_boss_hit(target, dmg, skill)
		_:
			if target != null and is_instance_valid(target) and not target.is_dead:
				_apply_boss_hit(target, dmg, skill)

	if _manager != null and _manager.has_method("log_combat"):
		_manager.log_combat("%s 사용 — %s" % [display_name, str(skill.get("name", skill_id))])
	_atk_timer = 0.55
	_set_anim_state(AnimState.ATTACK_START)
	_play_anim("attack", true)
	_attack_elapsed = 0.0
	_pending_target = target
	_pending_damage = 0.0  # damage already applied for skills
	_damage_applied = true


func _hit_allies_in_radius(dmg: float, radius: float, skill: Dictionary) -> void:
	if _manager == null or not _manager.has_method("get_allies"):
		return
	for a in _manager.get_allies():
		if a == null or not is_instance_valid(a) or a.is_dead:
			continue
		if global_position.distance_to(a.global_position) <= radius:
			_apply_boss_hit(a, dmg, skill)


func _apply_boss_hit(target: CombatCharacter, dmg: float, skill: Dictionary) -> void:
	target.take_damage(dmg, self, {"heavy": true})
	damage_hits += 1
	attacks_landed += 1
	var slow_mult := float(skill.get("slow_mult", 1.0))
	var slow_dur := float(skill.get("slow_duration", 0.0))
	if slow_dur > 0.0 and slow_mult < 1.0 and target.has_method("apply_move_slow"):
		target.apply_move_slow(slow_mult, slow_dur)
	var steal := float(skill.get("lifesteal", 0.0))
	if steal > 0.0:
		var heal_amt := dmg * steal
		hp = minf(hp_max, hp + heal_amt)
		hp_changed.emit(hp, hp_max)
	if _manager != null and _manager.has_method("shake_camera"):
		_manager.shake_camera(3.2, 0.12)
