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

@onready var _battlefield: Node2D = $Battlefield
@onready var _ally_root: Node2D = $Battlefield/Allies
@onready var _enemy_root: Node2D = $Battlefield/Enemies
@onready var _ui: CanvasLayer = $UILayer


func _ready() -> void:
	balance = _read_json(BALANCE_PATH)
	enemy_catalog = _read_json(ENEMIES_PATH)
	_ensure_game_state()
	_build_ground()
	_spawn_party()
	_spawn_enemies()
	_ui.setup(self)
	log_combat("전투 시작 — 자동전투 (Phase 2-1)")
	set_process(true)


func _process(_delta: float) -> void:
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
		log_combat("일시정지")
	elif phase == Phase.PAUSED:
		phase = Phase.FIGHTING
		log_combat("전투 재개")


func return_to_town() -> void:
	SceneRouter.go_town()


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
	var list: Array = enemy_catalog.get("enemies", [])
	if list.is_empty():
		return
	# Prefer a mixed encounter of up to 3 distinct monsters when available.
	var roster: Array = []
	for id_wanted in ["wolf", "slime", "goblin"]:
		for e in list:
			if str(e.get("id", "")) == id_wanted:
				roster.append(e)
				break
	if roster.is_empty():
		roster.append(list[0])
	var count: int = int(balance.get("enemy_count_phase_2_1", 3))
	count = clampi(count, 1, maxi(3, roster.size()))
	# Keep enemies left of the right HUD (~268px) so sprites are not clipped.
	var slots := [Vector2(860, 240), Vector2(920, 360), Vector2(800, 440)]
	for i in range(count):
		var data: Dictionary = roster[i % roster.size()]
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
		log_combat("승리 — 적 전멸 (보상은 후속 Phase)")
		return
	var allies_alive := false
	for a in _allies:
		if a and not a.is_dead:
			allies_alive = true
			break
	if not allies_alive:
		phase = Phase.DEFEAT
		log_combat("패배 — 파티 전원 전투불능 (보상은 후속 Phase)")


func _read_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Failed to read %s" % path)
		return {}
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	return data
