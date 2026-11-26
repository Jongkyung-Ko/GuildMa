extends Node2D

## Phase 2-1 combat orchestrator: spawn party + wolves, auto-fight, win/lose UI.
## No rewards, tactics, or HuntSelect.

enum Phase { FIGHTING, PAUSED, VICTORY, DEFEAT }

const BALANCE_PATH := "res://data/combat/balance_combat.json"
const ENEMIES_PATH := "res://data/combat/enemies.json"

const LORD_SCRIPT := preload("res://scripts/combat/player_lord_actor.gd")
const ALLY_SCRIPT := preload("res://scripts/combat/party_member_actor.gd")
const ENEMY_SCRIPT := preload("res://scripts/combat/enemy_base.gd")

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
	_ensure_game_state()
	if hunt_id != "" and dungeon_id == "":
		GameState.start_hunt_run(hunt_id, bool(get_tree().root.get_meta("hunt_force_new", false)))
		get_tree().root.set_meta("hunt_force_new", false)
	_build_ground()
	_setup_camera()
	_spawn_party()
	_spawn_enemies()
	_ui.setup(self)
	if dungeon_id != "" and dungeon_floor > 0:
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
		log_combat("사냥 시작 — %s / %s" % [
			str(GameState.get_active_hunt_map().get("hunt_name", hunt_id)),
			str(room.get("name", "")),
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
	if phase == Phase.FIGHTING:
		_check_end_conditions()
	_ui.refresh()


func is_combat_active() -> bool:
	return phase == Phase.FIGHTING


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
	if dungeon_id != "":
		SceneRouter.go_dungeon_hub(dungeon_id)
	else:
		SceneRouter.go_town()


func is_dungeon_combat() -> bool:
	return dungeon_id != "" and dungeon_floor > 0


func is_hunt_combat() -> bool:
	return hunt_id != "" and dungeon_id == "" and not GameState.get_active_hunt_map().is_empty()


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


func _reload_room_encounter() -> void:
	_clear_living_enemies_quiet()
	var room := GameState.get_current_hunt_room()
	log_combat("이동 — %s" % str(room.get("name", room_id_safe())))
	if bool(room.get("cleared", false)):
		phase = Phase.VICTORY
		log_combat("클리어된 방 — 지도에서 다른 방으로 이동 가능")
		_ui.refresh()
		return
	# Revive allies lightly for next fight
	for a in _allies:
		if a == null or not is_instance_valid(a):
			continue
		if bool(a.is_dead):
			a.is_dead = false
			a.hp = maxf(1.0, float(a.hp_max) * 0.35)
			a.visible = true
			a.modulate = Color(1, 1, 1, 1)
		else:
			a.hp = minf(float(a.hp_max), float(a.hp) + float(a.hp_max) * 0.15)
		if a.has_signal("hp_changed"):
			a.hp_changed.emit(a.hp, a.hp_max)
	_spawn_enemies()
	phase = Phase.FIGHTING
	_ui.refresh()


func room_id_safe() -> String:
	return str(GameState.get_active_hunt_map().get("current_room_id", ""))


func _clear_living_enemies_quiet() -> void:
	for e in _enemies:
		if e and is_instance_valid(e):
			e.queue_free()
	_enemies.clear()


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
		actor.global_position = slots[i]
		actor.died.connect(_on_combatant_died)
		actor.hp_changed.connect(func(_c, _m): _ui.refresh())
		_allies.append(actor)
		i += 1


func _spawn_enemies() -> void:
	var roster: Array = _resolve_enemy_roster()
	if roster.is_empty():
		return
	var count: int = roster.size()
	# Keep enemies left of the right HUD (~268px) so sprites are not clipped.
	var slots := [
		Vector2(860, 240),
		Vector2(920, 360),
		Vector2(800, 440),
		Vector2(940, 300),
		Vector2(820, 500),
	]
	for i in range(count):
		var data: Dictionary = roster[i]
		var enemy: Node = ENEMY_SCRIPT.new()
		enemy.name = "Enemy_%s_%d" % [str(data.get("id", "mob")), i]
		_enemy_root.add_child(enemy)
		enemy.bind_manager(self)
		enemy.setup_from_enemy(data)
		if enemy.has_method("assign_formation"):
			enemy.assign_formation(i)
		# Keep enemies spread on spawn so they don't start stacked.
		var spread := Vector2((i - 1) * 18.0, (i - 1) * 78.0)
		enemy.global_position = slots[i % slots.size()] + spread + Vector2(randf_range(-10, 10), randf_range(-6, 6))
		enemy.died.connect(_on_combatant_died)
		enemy.hp_changed.connect(func(_c, _m): _ui.refresh())
		_enemies.append(enemy)


func _resolve_enemy_roster() -> Array:
	var list: Array = enemy_catalog.get("enemies", [])
	if list.is_empty():
		return []
	# Dungeon floor encounter from dungeons.json (vertical progression).
	if dungeon_id != "" and dungeon_floor > 0:
		var fdef := GameState.get_dungeon_floor_def(dungeon_id, dungeon_floor)
		var ids: Array = fdef.get("enemies", [])
		var out: Array = []
		for eid in ids:
			var data := _enemy_def_by_id(str(eid))
			if not data.is_empty():
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
			if not data.is_empty():
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
			return e
	return {}


func _on_combatant_died(_who: Node) -> void:
	_check_end_conditions()
	_ui.refresh()


func _check_end_conditions() -> void:
	if phase != Phase.FIGHTING:
		return
	var enemies_alive := false
	for e in _enemies:
		if e and not e.is_dead:
			enemies_alive = true
			break
	if not enemies_alive:
		phase = Phase.VICTORY
		Engine.time_scale = 1.0
		_hit_stop_t = 0.0
		log_combat("승리 — 적 전멸 (보상은 후속 Phase)")
		_on_dungeon_victory()
		_on_hunt_victory()
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
		log_combat("패배 — 파티 전원 전투불능 (보상은 후속 Phase)")


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


func _read_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Failed to read %s" % path)
		return {}
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	return data
