extends Node2D

## Combat orchestrator: party + hunt/dungeon encounters, wave fill, boss kits, rewards.

enum Phase { FIGHTING, PAUSED, VICTORY, DEFEAT }

const BALANCE_PATH := "res://data/combat/balance_combat.json"
const ENEMIES_PATH := "res://data/combat/enemies.json"

const LORD_SCRIPT := preload("res://scripts/combat/player_lord_actor.gd")
const ALLY_SCRIPT := preload("res://scripts/combat/party_member_actor.gd")
const ENEMY_SCRIPT := preload("res://scripts/combat/enemy_base.gd")
const BOSS_SCRIPT := preload("res://scripts/combat/boss_actor.gd")

var balance: Dictionary = {}
var enemy_catalog: Dictionary = {}
var phase: Phase = Phase.FIGHTING
var _allies: Array = []
var _enemies: Array = []
var _log_lines: PackedStringArray = PackedStringArray()
var _camera: Camera2D
var _shake_t: float = 0.0
var _shake_amp: float = 0.0
var _hit_stop_t: float = 0.0
var _cam_home: Vector2 = Vector2(640, 360)
## Dungeon vertical mode (empty = hunt / phase test combat). Separate from hunt maze.
var dungeon_id: String = ""
var dungeon_floor: int = 0
var _floor_cleared_reported: bool = false
## Hunting-ground maze run id (empty = legacy phase test or dungeon).
var hunt_id: String = ""
var _hunt_clear_reported: bool = false
## Special named encounter (vorak_rift / morgana_sanctum) — not maze/dungeon floor.
var special_encounter_id: String = ""
var _spawn_queue: Array = []
var _respawn_timer: float = 0.0
var _active_boss: Node = null
var _rewards_granted: bool = false
var _kill_gold: int = 0
var _kill_exp: int = 0
var _kill_items: Dictionary = {}
## Combat playback speed (1 → 2 → 4 → 1). Default 1x. Independent of Engine.time_scale (hit-stop).
var combat_speed: float = 1.0
const COMBAT_SPEED_STEPS := [1.0, 2.0, 4.0]

@onready var _battlefield: Node2D = $Battlefield
@onready var _ally_root: Node2D = $Battlefield/Allies
@onready var _enemy_root: Node2D = $Battlefield/Enemies
@onready var _ui: CanvasLayer = $UILayer


func _ready() -> void:
	balance = _read_json(BALANCE_PATH)
	enemy_catalog = _read_json(ENEMIES_PATH)
	dungeon_id = str(get_tree().root.get_meta("dungeon_id", ""))
	dungeon_floor = int(get_tree().root.get_meta("dungeon_floor", 0))
	hunt_id = str(get_tree().root.get_meta("hunt_id", ""))
	special_encounter_id = str(get_tree().root.get_meta("special_encounter_id", ""))
	_ensure_game_state()
	if hunt_id != "" and dungeon_id == "" and special_encounter_id == "":
		var force_new := bool(get_tree().root.get_meta("hunt_force_new", false))
		# Town→hunt / re-entry always requests entrance spawn (not mid-maze resume).
		var spawn_at_start := bool(get_tree().root.get_meta("hunt_spawn_at_start", true))
		GameState.start_hunt_run(hunt_id, force_new, spawn_at_start)
		get_tree().root.set_meta("hunt_force_new", false)
		get_tree().root.set_meta("hunt_spawn_at_start", false)
	_build_ground()
	_setup_camera()
	_spawn_party()
	_spawn_enemies()
	_ui.setup(self)
	if special_encounter_id != "":
		log_combat("특수 조우 — %s" % special_encounter_id)
	elif dungeon_id != "" and dungeon_floor > 0:
		var fdef := GameState.get_dungeon_floor_def(dungeon_id, dungeon_floor)
		var boss := str(fdef.get("boss", ""))
		var tag := "중층 보스" if boss == "mid" else ("최종 보스" if boss == "final" else "일반")
		log_combat("던전 전투 시작 — %s %d층 (%s)" % [
			str(GameState.get_dungeon_def(dungeon_id).get("name", dungeon_id)),
			dungeon_floor,
			tag,
		])
	elif is_hunt_combat():
		var room := GameState.get_current_hunt_room()
		log_combat("사냥 시작 — %s / %s (room=%s type=%s)" % [
			str(GameState.get_active_hunt_map().get("hunt_name", hunt_id)),
			str(room.get("name", "")),
			str(room.get("room_id", "")),
			str(room.get("room_type", "")),
		])
		if bool(room.get("cleared", false)):
			# Revisit cleared room: no fight, allow map travel.
			phase = Phase.VICTORY
			_clear_living_enemies_quiet()
			log_combat("이미 클리어한 방 — 지도를 열어 이동하세요")
	else:
		log_combat("전투 시작 — 자동전투 (Phase 2-2)")
	set_process(true)


func _setup_camera() -> void:
	_camera = Camera2D.new()
	_camera.name = "CombatCamera"
	_camera.enabled = true
	_camera.position = _cam_home
	add_child(_camera)
	_camera.make_current()


func shake_camera(amplitude: float = 3.0, duration: float = 0.12) -> void:
	_shake_amp = maxf(_shake_amp, amplitude)
	_shake_t = maxf(_shake_t, duration)


func request_hit_stop(duration: float = 0.05) -> void:
	# Local combat slowdown only — never leave Engine.time_scale stuck.
	_hit_stop_t = maxf(_hit_stop_t, clampf(duration, 0.02, 0.08))
	Engine.time_scale = 0.15


func _process(delta: float) -> void:
	if _hit_stop_t > 0.0:
		_hit_stop_t -= delta / maxf(Engine.time_scale, 0.01)
		if _hit_stop_t <= 0.0:
			Engine.time_scale = 1.0
	if _shake_t > 0.0 and _camera:
		_shake_t -= delta
		var falloff := clampf(_shake_t / 0.12, 0.0, 1.0)
		_camera.position = _cam_home + Vector2(
			randf_range(-_shake_amp, _shake_amp) * falloff,
			randf_range(-_shake_amp, _shake_amp) * falloff * 0.7
		)
		if _shake_t <= 0.0:
			_camera.position = _cam_home
			_shake_amp = 0.0

	if Input.is_action_just_pressed("ui_cancel"):
		toggle_pause()
	# Wave timers follow combat speed; pause freezes via phase gate.
	var cd := delta * combat_speed if phase == Phase.FIGHTING else 0.0
	if phase == Phase.FIGHTING:
		_tick_wave_spawns(cd)
		_check_end_conditions()
	_ui.refresh()


func is_combat_active() -> bool:
	return phase == Phase.FIGHTING


func get_combat_speed() -> float:
	return combat_speed if phase == Phase.FIGHTING else 1.0


func cycle_combat_speed() -> float:
	var idx := 0
	for i in range(COMBAT_SPEED_STEPS.size()):
		if is_equal_approx(float(COMBAT_SPEED_STEPS[i]), combat_speed):
			idx = i
			break
	idx = (idx + 1) % COMBAT_SPEED_STEPS.size()
	combat_speed = float(COMBAT_SPEED_STEPS[idx])
	log_combat("전투 속도 ×%d" % int(combat_speed))
	return combat_speed


func get_def_mitigation() -> float:
	return float(balance.get("def_mitigation", 0.5))


func get_opponents(team: int) -> Array:
	# CombatCharacter.Team.ALLY == 0, ENEMY == 1
	if team == 0:
		return _enemies
	return _allies


func get_allies() -> Array:
	return _allies


func get_enemies() -> Array:
	return _enemies


func get_phase() -> Phase:
	return phase


func get_phase_name() -> String:
	match phase:
		Phase.FIGHTING:
			return "fighting"
		Phase.PAUSED:
			return "paused"
		Phase.VICTORY:
			return "victory"
		Phase.DEFEAT:
			return "defeat"
		_:
			return "unknown"


func get_log_text() -> String:
	var n := mini(8, _log_lines.size())
	var start := _log_lines.size() - n
	var out := ""
	for i in range(start, _log_lines.size()):
		out += _log_lines[i] + "\n"
	return out


func log_combat(line: String) -> void:
	_log_lines.append(line)
	if _log_lines.size() > 40:
		_log_lines = _log_lines.slice(_log_lines.size() - 40)


func toggle_pause() -> void:
	if phase == Phase.VICTORY or phase == Phase.DEFEAT:
		return
	if phase == Phase.FIGHTING:
		phase = Phase.PAUSED
		Engine.time_scale = 1.0
		_hit_stop_t = 0.0
		if AudioManager:
			AudioManager.pause_bgm()
		log_combat("일시정지")
	elif phase == Phase.PAUSED:
		phase = Phase.FIGHTING
		if AudioManager:
			AudioManager.resume_bgm()
		log_combat("전투 재개")


func return_to_town() -> void:
	Engine.time_scale = 1.0
	_hit_stop_t = 0.0
	get_tree().root.set_meta("special_encounter_id", "")
	if dungeon_id != "":
		SceneRouter.go_dungeon_hub(dungeon_id)
	else:
		# Full leave: always pass local hunt_id so reset works even if active_hunt_id was cleared.
		if hunt_id != "" and GameState and special_encounter_id == "":
			GameState.leave_hunt_session(hunt_id)
		SceneRouter.go_town()


func is_dungeon_combat() -> bool:
	return dungeon_id != "" and dungeon_floor > 0


func is_hunt_combat() -> bool:
	return (
		hunt_id != ""
		and dungeon_id == ""
		and special_encounter_id == ""
		and not GameState.get_active_hunt_map().is_empty()
	)


func is_special_encounter() -> bool:
	return special_encounter_id != ""


func get_active_boss() -> Node:
	return _active_boss if _active_boss != null and is_instance_valid(_active_boss) else null


func travel_hunt_room(room_id: String) -> void:
	if not is_hunt_combat():
		return
	if phase == Phase.FIGHTING:
		log_combat("전투 중에는 이동할 수 없습니다")
		GameState.emit_message("전투 종료 후 이동 가능합니다.", true)
		return
	if not GameState.hunt_move_to(room_id):
		return
	_hunt_clear_reported = false
	_reload_room_encounter()


func travel_hunt_direction(dir: String) -> void:
	## Convenience for N/E/S/W pad — still validates via hunt_can_move_to / hunt_move_to.
	if not is_hunt_combat():
		return
	var room := GameState.get_current_hunt_room()
	var cons: Dictionary = room.get("connected_rooms", {})
	var o = cons.get(dir, null)
	if o == null:
		GameState.emit_message("그 방향으로는 통로가 없습니다.", true)
		return
	travel_hunt_room(str(o))


func _reload_room_encounter() -> void:
	_clear_living_enemies_quiet()
	_rewards_granted = false
	_kill_gold = 0
	_kill_exp = 0
	_kill_items.clear()
	_active_boss = null
	var room := GameState.get_current_hunt_room()
	log_combat("이동 — %s" % str(room.get("name", room_id_safe())))
	if bool(room.get("cleared", false)):
		phase = Phase.VICTORY
		log_combat("클리어된 방 — 지도에서 다른 방으로 이동 가능")
		_ui.refresh()
		return
	# Revive allies lightly for next fight and clear attack soft-locks.
	# Capture death BEFORE reset_for_next_encounter() clears is_dead.
	for a in _allies:
		if a == null or not is_instance_valid(a):
			continue
		var was_dead: bool = bool(a.get("is_dead")) or float(a.hp) <= 0.0
		var hp_before: float = float(a.hp)
		if a.has_method("reset_for_next_encounter"):
			a.reset_for_next_encounter()
		if was_dead:
			a.hp = maxf(1.0, float(a.hp_max) * 0.35)
		else:
			a.hp = minf(float(a.hp_max), hp_before + float(a.hp_max) * 0.15)
		if a.has_signal("hp_changed"):
			a.hp_changed.emit(a.hp, a.hp_max)
	_spawn_enemies()
	phase = Phase.FIGHTING
	# Intensity refresh only — AudioManager keeps playback position when mode/track unchanged.
	if AudioManager:
		AudioManager.on_enter_combat()
	_ui.refresh()


func room_id_safe() -> String:
	return str(GameState.get_active_hunt_map().get("current_room_id", ""))


func _clear_living_enemies_quiet() -> void:
	for e in _enemies:
		if e and is_instance_valid(e):
			e.queue_free()
	_enemies.clear()
	_spawn_queue.clear()
	_active_boss = null
	if _ui and _ui.has_method("bind_boss"):
		_ui.bind_boss(null)


func _ensure_game_state() -> void:
	if GameState.members.is_empty():
		GameState.new_game()


func _build_ground() -> void:
	var ground := Sprite2D.new()
	ground.name = "Ground"
	ground.centered = false
	ground.position = Vector2(0, 0)
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists("res://assets/backgrounds/combat_bg.png"):
		ground.texture = load("res://assets/backgrounds/combat_bg.png")
	_battlefield.add_child(ground)
	_battlefield.move_child(ground, 0)


func _spawn_party() -> void:
	var party: Array = []
	for m in GameState.members:
		if bool(m.get("in_party", false)):
			party.append(m)
	if party.is_empty():
		party = GameState.members.duplicate()

	var slots := [
		Vector2(220, 280),
		Vector2(180, 360),
		Vector2(260, 420),
		Vector2(160, 220),
		Vector2(300, 340),
	]
	var i := 0
	for m in party:
		if i >= 5:
			break
		var actor: Node
		var job := str(m.get("job", ""))
		if job == "lord":
			actor = LORD_SCRIPT.new()
		else:
			actor = ALLY_SCRIPT.new()
		actor.name = "Ally_%s" % str(m.get("id", i))
		_ally_root.add_child(actor)
		actor.bind_manager(self)
		actor.setup_from_member(m, balance)
		if actor.has_method("assign_formation"):
			actor.assign_formation(i)
		actor.global_position = CombatFieldBounds.clamp_point(slots[i], actor)
		actor.died.connect(_on_combatant_died)
		actor.hp_changed.connect(func(_c, _m): _ui.refresh())
		_allies.append(actor)
		i += 1


func _spawn_enemies() -> void:
	_spawn_queue.clear()
	_respawn_timer = 0.0
	_active_boss = null
	var roster: Array = _resolve_enemy_roster()
	if roster.is_empty():
		return
	var live_cap := _max_live_enemies()
	var initial := mini(roster.size(), live_cap)
	for i in range(initial):
		_spawn_one_enemy(roster[i], i)
	for j in range(initial, roster.size()):
		_spawn_queue.append(roster[j])
	if _ui and _ui.has_method("bind_boss"):
		_ui.bind_boss(get_active_boss())


func _max_live_enemies() -> int:
	var hc: Dictionary = balance.get("hunt_content", {})
	return clampi(int(hc.get("max_live_enemies", 12)), 3, 16)


func _enemy_slot(i: int) -> Vector2:
	# Keep enemies left of the right HUD (~268px) so sprites are not clipped.
	var slots := [
		Vector2(860, 240),
		Vector2(920, 360),
		Vector2(800, 440),
		Vector2(940, 300),
		Vector2(820, 500),
		Vector2(780, 320),
		Vector2(900, 480),
		Vector2(840, 200),
		Vector2(960, 400),
		Vector2(760, 460),
		Vector2(880, 280),
		Vector2(820, 380),
	]
	var base: Vector2 = slots[i % slots.size()]
	var ring := int(i / slots.size())
	var spread := Vector2((i % 5 - 2) * 16.0, (i % 4 - 1) * 36.0) + Vector2(ring * 12.0, ring * 10.0)
	return base + spread + Vector2(randf_range(-8, 8), randf_range(-5, 5))


func _spawn_one_enemy(data: Dictionary, slot_i: int) -> Node:
	var scaled := _apply_hunt_difficulty(data)
	var is_boss := _is_boss_def(scaled)
	var enemy: Node
	if is_boss:
		enemy = BOSS_SCRIPT.new()
		enemy.name = "Boss_%s_%d" % [str(scaled.get("id", "boss")), slot_i]
		_enemy_root.add_child(enemy)
		enemy.bind_manager(self)
		var boss_id := str(scaled.get("boss_id", ""))
		var bdef := GameState.get_boss_def(boss_id) if boss_id != "" else {}
		if bdef.is_empty() and scaled.has("id"):
			bdef = GameState.get_boss_def_by_enemy_id(str(scaled.get("id")))
		if not bdef.is_empty() and enemy.has_method("setup_from_boss"):
			enemy.setup_from_boss(bdef, scaled)
		else:
			enemy.setup_from_enemy(scaled)
		_active_boss = enemy
	else:
		enemy = ENEMY_SCRIPT.new()
		enemy.name = "Enemy_%s_%d" % [str(scaled.get("id", "mob")), slot_i]
		_enemy_root.add_child(enemy)
		enemy.bind_manager(self)
		enemy.setup_from_enemy(scaled)
	if enemy.has_method("assign_formation"):
		enemy.assign_formation(slot_i % 8)
	enemy.global_position = CombatFieldBounds.clamp_point(_enemy_slot(slot_i), enemy)
	enemy.died.connect(_on_combatant_died)
	enemy.hp_changed.connect(func(_c, _m): _ui.refresh())
	_enemies.append(enemy)
	return enemy


func _is_boss_def(data: Dictionary) -> bool:
	var tier := str(data.get("tier", ""))
	if tier.begins_with("boss"):
		return true
	if str(data.get("behavior", "")) == "boss":
		return true
	return str(data.get("boss_id", "")) != ""


func _apply_hunt_difficulty(data: Dictionary) -> Dictionary:
	var out := data.duplicate(true)
	if not is_hunt_combat():
		return out
	var hunt := GameState.get_hunt_def(hunt_id)
	var diff: Dictionary = hunt.get("difficulty", {})
	if diff.is_empty():
		return out
	out["hp"] = float(out.get("hp", 40)) * float(diff.get("hp_mult", 1.0))
	out["atk"] = float(out.get("atk", 8)) * float(diff.get("atk_mult", 1.0))
	out["def"] = float(out.get("def", 2)) * float(diff.get("def_mult", 1.0))
	out["aspd"] = float(out.get("aspd", 1.0)) * float(diff.get("aspd_mult", 1.0))
	out["aggro_range"] = float(out.get("aggro_range", 900)) * float(diff.get("aggro_mult", 1.0))
	out["exp"] = int(round(float(out.get("exp", 10)) * float(diff.get("reward_exp_mult", 1.0))))
	out["gold_min"] = int(round(float(out.get("gold_min", 3)) * float(diff.get("reward_gold_mult", 1.0))))
	out["gold_max"] = int(round(float(out.get("gold_max", 8)) * float(diff.get("reward_gold_mult", 1.0))))
	return out


func _tick_wave_spawns(delta: float) -> void:
	if _spawn_queue.is_empty():
		return
	if _is_boss_only_encounter():
		return
	var live := 0
	for e in _enemies:
		if e and is_instance_valid(e) and not e.is_dead:
			live += 1
	var cap := _max_live_enemies()
	if live >= cap:
		return
	var hunt := GameState.get_hunt_def(hunt_id) if is_hunt_combat() else {}
	var resp: Dictionary = hunt.get("respawn", {})
	var delay := float(resp.get("delay_sec", 3.0))
	if not bool(resp.get("enabled", true)):
		# Still drain queue immediately up to cap without delay when respawn disabled.
		delay = 0.0
	_respawn_timer -= delta
	if _respawn_timer > 0.0:
		return
	while live < cap and not _spawn_queue.is_empty():
		var data: Dictionary = _spawn_queue.pop_front()
		_spawn_one_enemy(data, _enemies.size())
		live += 1
		_respawn_timer = delay
		if delay > 0.0:
			break


func _is_boss_only_encounter() -> bool:
	if get_active_boss() != null:
		return true
	if special_encounter_id != "":
		return true
	if is_hunt_combat():
		var room := GameState.get_current_hunt_room()
		return str(room.get("room_type", "")) == "boss"
	if is_dungeon_combat():
		var fdef := GameState.get_dungeon_floor_def(dungeon_id, dungeon_floor)
		return str(fdef.get("boss", "")) != ""
	return false


func _resolve_enemy_roster() -> Array:
	var list: Array = enemy_catalog.get("enemies", [])
	if list.is_empty():
		return []
	# Special named boss encounter (Vorak / Morgana) — one boss, never a hunt pack.
	if special_encounter_id != "":
		var bdef := GameState.get_boss_for_special_encounter(special_encounter_id)
		if bdef.is_empty():
			return []
		var data := _enemy_def_by_id(str(bdef.get("enemy_id", "")))
		if data.is_empty():
			data = {
				"id": str(bdef.get("enemy_id", bdef.get("id"))),
				"boss_id": str(bdef.get("id")),
				"name": str(bdef.get("name")),
				"tier": "boss_special",
				"behavior": "boss",
				"hp": bdef.get("hp", 1000),
				"atk": bdef.get("atk", 20),
				"def": bdef.get("def", 8),
				"move": bdef.get("move", 100),
				"aspd": bdef.get("aspd", 1.0),
				"sprite": bdef.get("sprite", "wolf"),
				"color": bdef.get("color", [1, 1, 1, 1]),
			}
		else:
			data["boss_id"] = str(bdef.get("id"))
		return [data]
	# Dungeon floor encounter from dungeons.json (vertical progression).
	if dungeon_id != "" and dungeon_floor > 0:
		var fdef := GameState.get_dungeon_floor_def(dungeon_id, dungeon_floor)
		var ids: Array = fdef.get("enemies", [])
		var out: Array = []
		for eid in ids:
			var data := _enemy_def_by_id(str(eid))
			if not data.is_empty():
				if str(fdef.get("boss_id", "")) != "":
					data["boss_id"] = str(fdef.get("boss_id"))
				out.append(data)
		if out.is_empty() and not list.is_empty():
			out.append(list[0])
		return out
	# Hunting maze room encounter from active map room.monsters.
	if is_hunt_combat():
		var room := GameState.get_current_hunt_room()
		if bool(room.get("cleared", false)):
			return []
		var ids: Array = room.get("monsters", [])
		var hout: Array = []
		for eid in ids:
			var data := _enemy_def_by_id(str(eid))
			if data.is_empty():
				continue
			if str(room.get("room_type", "")) == "boss":
				var hunt := GameState.get_hunt_def(hunt_id)
				if str(hunt.get("boss_id", "")) != "":
					data["boss_id"] = str(hunt.get("boss_id"))
			hout.append(data)
		if hout.is_empty() and not list.is_empty():
			hout.append(list[0])
		return hout
	# Legacy phase test: mixed encounter of up to 3 distinct monsters.
	var roster: Array = []
	for id_wanted in ["wolf", "slime", "goblin"]:
		var data := _enemy_def_by_id(id_wanted)
		if not data.is_empty():
			roster.append(data)
	if roster.is_empty():
		roster.append(list[0])
	var count: int = int(balance.get("enemy_count_phase_2_1", 3))
	count = clampi(count, 1, maxi(3, roster.size()))
	var out2: Array = []
	for i in range(count):
		out2.append(roster[i % roster.size()])
	return out2


func _enemy_def_by_id(enemy_id: String) -> Dictionary:
	for e in enemy_catalog.get("enemies", []):
		if str(e.get("id", "")) == enemy_id:
			return (e as Dictionary).duplicate(true)
	return {}


func _on_combatant_died(who: Node) -> void:
	if who != null and who.has_method("setup_from_enemy"):
		_accumulate_kill_rewards(who)
	_check_end_conditions()
	_ui.refresh()


func _accumulate_kill_rewards(who: Node) -> void:
	# Boss kill rewards granted once via GameState.grant_boss_rewards.
	if who == _active_boss:
		return
	if who.get("boss_id") != null and str(who.get("boss_id")) != "":
		return
	var eid := str(who.member_id)
	var data := _enemy_def_by_id(eid)
	if data.is_empty():
		return
	var gmin := int(data.get("gold_min", 2))
	var gmax := int(data.get("gold_max", maxi(gmin, 4)))
	_kill_gold += randi_range(gmin, gmax)
	_kill_exp += int(data.get("exp", 8))
	if is_hunt_combat():
		var hunt := GameState.get_hunt_def(hunt_id)
		var table: Dictionary = hunt.get("reward_table", {})
		if randf() < float(table.get("material_chance", 0.0)):
			var mats: Array = table.get("materials", [])
			if mats.size() > 0:
				var mid := str(mats[randi_range(0, mats.size() - 1)])
				_kill_items[mid] = int(_kill_items.get(mid, 0)) + 1


func _check_end_conditions() -> void:
	if phase != Phase.FIGHTING:
		return
	var enemies_alive := false
	for e in _enemies:
		if e and is_instance_valid(e) and not e.is_dead:
			enemies_alive = true
			break
	if enemies_alive:
		pass
	elif not _spawn_queue.is_empty():
		# Waves remaining — keep fighting.
		return
	else:
		phase = Phase.VICTORY
		Engine.time_scale = 1.0
		_hit_stop_t = 0.0
		log_combat("승리 — 적 전멸")
		_grant_victory_rewards()
		_on_dungeon_victory()
		_on_hunt_victory()
		_on_special_victory()
		return
	var allies_alive := false
	for a in _allies:
		if a and not a.is_dead:
			allies_alive = true
			break
	if not allies_alive:
		phase = Phase.DEFEAT
		Engine.time_scale = 1.0
		_hit_stop_t = 0.0
		log_combat("패배 — 파티 전원 전투불능")
		_grant_defeat_rewards()


func _grant_victory_rewards() -> void:
	if _rewards_granted:
		return
	_rewards_granted = true
	var boss := get_active_boss()
	if boss != null and str(boss.boss_id) != "":
		var summary: Dictionary = GameState.grant_boss_rewards(str(boss.boss_id))
		log_combat("보스 보상 — +%dG / EXP %d" % [int(summary.get("gold", 0)), int(summary.get("exp", 0))])
		for mid in summary.get("items", {}).keys():
			log_combat("  재료 %s x%d" % [mid, int(summary.get("items", {})[mid])])
		return
	if _kill_gold > 0:
		GameState.add_gold(_kill_gold)
	if _kill_exp > 0:
		GameState.grant_party_exp(_kill_exp)
	for mid in _kill_items.keys():
		GameState.add_item(str(mid), int(_kill_items[mid]))
	if _kill_gold > 0 or _kill_exp > 0:
		log_combat("보상 — +%dG / EXP %d" % [_kill_gold, _kill_exp])
	GameState.save_game()


func _grant_defeat_rewards() -> void:
	if _rewards_granted:
		return
	_rewards_granted = true
	var hc: Dictionary = balance.get("hunt_content", {})
	var g := int(round(float(_kill_gold) * float(hc.get("defeat_gold_frac", 0.15))))
	var e := int(round(float(_kill_exp) * float(hc.get("defeat_exp_frac", 0.1))))
	if g > 0:
		GameState.add_gold(g)
	if e > 0:
		GameState.grant_party_exp(e)
	# Items never on defeat (D2).
	if g > 0 or e > 0:
		log_combat("패배 위로 보상 — +%dG / EXP %d" % [g, e])
	GameState.save_game()


func _on_dungeon_victory() -> void:
	if _floor_cleared_reported:
		return
	if dungeon_id == "" or dungeon_floor <= 0:
		return
	_floor_cleared_reported = true
	var kills := _enemies.size()
	GameState.mark_dungeon_floor_cleared(dungeon_id, dungeon_floor, kills)
	log_combat("%s %d층 클리어 기록" % [
		str(GameState.get_dungeon_def(dungeon_id).get("name", dungeon_id)),
		dungeon_floor,
	])


func _on_hunt_victory() -> void:
	if _hunt_clear_reported:
		return
	if not is_hunt_combat():
		return
	_hunt_clear_reported = true
	GameState.mark_hunt_room_cleared()
	log_combat("방 클리어 — 미니맵에서 연결된 방으로 이동하세요")


func _on_special_victory() -> void:
	if special_encounter_id == "":
		return
	GameState.mark_special_encounter_cleared(special_encounter_id)
	log_combat("특수 조우 클리어 — %s" % special_encounter_id)


func _read_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Failed to read %s" % path)
		return {}
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	return data
