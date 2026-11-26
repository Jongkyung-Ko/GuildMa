extends SceneTree

## Headless validation for hunting-ground maze navigation.
## Autoload globals are NOT injected into -s scripts; use /root/GameState.
## godot --headless --path . -s res://scripts/core/validate_hunt_maze.gd

var _failed := 0
var _passed := 0
var gs: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== HUNT MAZE VALIDATION ===")
	gs = root.get_node_or_null("/root/GameState")
	if gs == null:
		_fail("GameState autoload missing")
		_finish()
		return

	var def: Dictionary = {}
	for h in gs.list_hunts():
		if str(h.get("id")) == "beginner_forest":
			def = h
			break
	if def.is_empty():
		_fail("beginner_forest missing from hunts.json")
		_finish()
		return
	_pass("hunt catalog has beginner_forest")

	var map: Dictionary = MazeGenerator.generate(def, 42)
	var verr := MazeGenerator.validate(map)
	if verr != "":
		_fail("generate validate: %s" % verr)
	else:
		_pass("generated map validates (seed 42)")

	var rooms: Dictionary = map.get("rooms", {})
	_pass("room count=%d" % rooms.size())

	var dead := 0
	var branch := 0
	for rid in rooms.keys():
		var cons: Dictionary = rooms[rid].get("connected_rooms", {})
		var deg := 0
		for d in MazeGenerator.DIRS:
			if cons.get(d, null) != null:
				deg += 1
		if deg == 1:
			dead += 1
		if deg >= 3:
			branch += 1
	if dead < 1:
		_fail("expected dead-end rooms")
	else:
		_pass("dead-ends=%d" % dead)
	if branch < 1:
		_fail("expected branch (deg>=3)")
	else:
		_pass("branch rooms=%d" % branch)

	var bosses := 0
	for rid in rooms.keys():
		if bool(rooms[rid].get("boss_flag", false)):
			bosses += 1
	if bosses != 1:
		_fail("expected 1 boss room got %d" % bosses)
	else:
		_pass("boss room present")

	var sample_id := str(map.get("current_room_id"))
	var sample: Dictionary = rooms[sample_id]
	var blocked := false
	for d in MazeGenerator.DIRS:
		if sample.get("connected_rooms", {}).get(d, null) == null:
			blocked = true
			break
	if blocked:
		_pass("start has at least one blocked direction")
	else:
		_fail("start unexpectedly open all 4 ways")

	gs.new_game()
	var run: Dictionary = gs.start_hunt_run("beginner_forest", true)
	if run.is_empty():
		_fail("start_hunt_run failed")
		_finish()
		return
	_pass("start_hunt_run ok")

	var cur := str(gs.get_active_hunt_map().get("current_room_id"))
	var neighbors: Array = gs.hunt_connected_room_ids(cur)
	if neighbors.is_empty():
		_fail("start has no neighbors")
	else:
		_pass("start neighbors=%d" % neighbors.size())

	var nxt := str(neighbors[0])
	if gs.hunt_can_move_to(nxt):
		_fail("should NOT move before clearing current")
	else:
		_pass("move blocked before clear")

	gs.mark_hunt_room_cleared(cur)
	if not gs.hunt_can_move_to(nxt):
		_fail("should move after clear to neighbor")
	else:
		_pass("move allowed after clear to connected room")

	var stranger := ""
	for rid in gs.get_active_hunt_map().get("rooms", {}).keys():
		var id := str(rid)
		if id != cur and not neighbors.has(id):
			stranger = id
			break
	if stranger != "":
		gs.get_active_hunt_map()["rooms"][stranger]["discovered"] = true
		if gs.hunt_can_move_to(stranger):
			_fail("non-adjacent discovered room wrongly movable")
		else:
			_pass("non-adjacent room blocked")

	if not gs.hunt_move_to(nxt):
		_fail("hunt_move_to failed")
	else:
		_pass("hunt_move_to neighbor")

	var before_cur := str(gs.get_active_hunt_map().get("current_room_id"))
	gs.save_game()
	gs.active_hunt_id = ""
	gs.hunt_progress = {}
	if not gs.load_game():
		_fail("load_game failed")
	else:
		var after := str(gs.get_active_hunt_map().get("current_room_id"))
		if after != before_cur:
			_fail("reload current room mismatch %s vs %s" % [after, before_cur])
		else:
			_pass("save/load preserves hunt map position")

	if not gs.get_dungeon_def("shadow_crypt").is_empty():
		_pass("dungeon catalog intact")
	else:
		_fail("dungeon catalog broken")

	_finish()


func _pass(msg: String) -> void:
	_passed += 1
	print("PASS: ", msg)


func _fail(msg: String) -> void:
	_failed += 1
	print("FAIL: ", msg)


func _finish() -> void:
	print("=== HUNT MAZE RESULT: %s (%d pass / %d fail) ===" % [
		"PASS" if _failed == 0 else "FAIL", _passed, _failed
	])
	quit(0 if _failed == 0 else 1)
