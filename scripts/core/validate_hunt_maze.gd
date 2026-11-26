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

	# --- Fresh seeds: 3 new maps must differ ---
	var seeds: Array = []
	var layouts: Array = []
	for i in 3:
		gs.new_game()
		var run: Dictionary = gs.start_hunt_run("beginner_forest", true)
		if run.is_empty():
			_fail("fresh run %d empty" % i)
			continue
		var seed_v := int(run.get("seed", -1))
		var prog_seed := int(gs.hunt_progress.get("beginner_forest", {}).get("seed", -2))
		if seed_v < 0:
			_fail("run %d missing map.seed" % i)
		elif seed_v != prog_seed:
			_fail("run %d map.seed %d != progress.seed %d" % [i, seed_v, prog_seed])
		else:
			_pass("run %d seed=%d persisted" % [i, seed_v])
		seeds.append(seed_v)
		layouts.append(_layout_fingerprint(run))
		# Tiny delay so Time.get_ticks_usec differs across rapid force_new calls
		OS.delay_usec(1500)

	if seeds[0] == seeds[1] or seeds[1] == seeds[2] or seeds[0] == seeds[2]:
		_fail("expected 3 distinct seeds, got %s" % str(seeds))
	else:
		_pass("3 new maps have distinct seeds %s" % str(seeds))

	if layouts[0] == layouts[1] and layouts[1] == layouts[2]:
		_fail("3 maps share identical layout fingerprint (seed not applied?)")
	else:
		_pass("at least one layout differs across 3 runs")

	# --- Resume keeps layout + position ---
	gs.new_game()
	var first: Dictionary = gs.start_hunt_run("beginner_forest", true)
	var seed_a := int(first.get("seed", -1))
	var cur := str(first.get("current_room_id", ""))
	var neighbors: Array = gs.hunt_connected_room_ids(cur)
	gs.mark_hunt_room_cleared(cur)
	if neighbors.is_empty():
		_fail("no neighbors to move")
	else:
		var nxt := str(neighbors[0])
		gs.hunt_move_to(nxt)
	var after_move_cur := str(gs.get_active_hunt_map().get("current_room_id", ""))
	var fp_before := _layout_fingerprint(gs.get_active_hunt_map())
	# Resume (force_new=false) must NOT regenerate
	var resumed: Dictionary = gs.start_hunt_run("beginner_forest", false)
	if int(resumed.get("seed", -1)) != seed_a:
		_fail("resume changed seed %d -> %d" % [seed_a, int(resumed.get("seed", -1))])
	else:
		_pass("resume keeps seed %d" % seed_a)
	if str(resumed.get("current_room_id", "")) != after_move_cur:
		_fail("resume lost current room")
	else:
		_pass("resume keeps current room %s" % after_move_cur)
	if _layout_fingerprint(resumed) != fp_before:
		_fail("resume changed room layout")
	else:
		_pass("resume keeps room layout")

	# 출정 without 새 맵 after progress must not roll a new maze
	var seed_mid := int(gs.get_active_hunt_map().get("seed", -1))
	gs.start_hunt_run("beginner_forest", false)
	if int(gs.get_active_hunt_map().get("seed", -1)) != seed_mid:
		_fail("second 출정 regenerated map")
	else:
		_pass("second 출정 resumes in-progress map")

	# --- Graph quality (deterministic seed) ---
	var map: Dictionary = MazeGenerator.generate(def, 42)
	var verr := MazeGenerator.validate(map)
	if verr != "":
		_fail("generate validate: %s" % verr)
	else:
		_pass("generated map validates (seed 42)")
	_pass("room count=%d" % map.get("rooms", {}).size())

	var rooms: Dictionary = map.get("rooms", {})
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

	# --- Boss separation ---
	var goal_id := str(map.get("goal_boss_room_id", ""))
	if goal_id == "" or not rooms.has(goal_id):
		_fail("goal_boss_room_id missing")
	else:
		var gb: Dictionary = rooms[goal_id]
		if not bool(gb.get("boss_flag", false)):
			_fail("goal room missing boss_flag")
		elif str(gb.get("boss_kind", "")) != MazeGenerator.BOSS_KIND_HUNT_GOAL:
			_fail("goal boss_kind expected hunt_goal got %s" % str(gb.get("boss_kind")))
		else:
			_pass("maze goal boss tagged hunt_goal at %s" % goal_id)

	# Clearing hunt goal must NOT set dungeon mid/final flags
	gs.new_game()
	gs.start_hunt_run("beginner_forest", true)
	gs.ensure_dungeon_progress("shadow_crypt")
	var goal := str(gs.get_active_hunt_map().get("goal_boss_room_id", ""))
	# Walk-clear isn't needed — mark goal directly
	gs.mark_hunt_room_cleared(goal)
	var dprog: Dictionary = gs.ensure_dungeon_progress("shadow_crypt")
	if bool(dprog.get("mid_boss_defeated", false)) or bool(dprog.get("final_boss_defeated", false)):
		_fail("hunt goal clear polluted dungeon boss flags")
	else:
		_pass("hunt goal clear leaves dungeon mid/final flags false")
	var hprog: Dictionary = gs.hunt_progress.get("beginner_forest", {})
	if not bool(hprog.get("goal_boss_cleared", false)):
		_fail("goal_boss_cleared not set on hunt_progress")
	else:
		_pass("goal_boss_cleared set on hunt_progress only")

	# Dungeon boss_floors still 5 mid / 10 final
	var ddef: Dictionary = gs.get_dungeon_def("shadow_crypt")
	var bosses: Dictionary = ddef.get("boss_floors", {})
	if bosses.has("5") and bosses.has("10"):
		_pass("dungeon boss_floors 5 mid + 10 final intact")
	else:
		_fail("dungeon boss_floors missing 5/10")

	# Move rules smoke
	gs.new_game()
	gs.start_hunt_run("beginner_forest", true)
	cur = str(gs.get_active_hunt_map().get("current_room_id"))
	neighbors = gs.hunt_connected_room_ids(cur)
	if neighbors.is_empty():
		_fail("start has no neighbors")
	else:
		_pass("start neighbors=%d" % neighbors.size())
	var nxt2 := str(neighbors[0])
	if gs.hunt_can_move_to(nxt2):
		_fail("should NOT move before clearing current")
	else:
		_pass("move blocked before clear")
	gs.mark_hunt_room_cleared(cur)
	if not gs.hunt_can_move_to(nxt2):
		_fail("should move after clear to neighbor")
	else:
		_pass("move allowed after clear to connected room")

	if not gs.get_dungeon_def("shadow_crypt").is_empty():
		_pass("dungeon catalog intact")
	else:
		_fail("dungeon catalog broken")

	_finish()


func _layout_fingerprint(map: Dictionary) -> String:
	var rooms: Dictionary = map.get("rooms", {})
	var keys: Array = rooms.keys()
	keys.sort()
	var parts: PackedStringArray = PackedStringArray()
	for rid in keys:
		var r: Dictionary = rooms[rid]
		var p: Array = r.get("position", [0, 0])
		var cons: Dictionary = r.get("connected_rooms", {})
		var links: PackedStringArray = PackedStringArray()
		for d in MazeGenerator.DIRS:
			var o = cons.get(d, null)
			links.append("%s:%s" % [d, str(o) if o != null else "-"])
		parts.append("%s@%d,%d|%s|%s" % [
			str(rid), int(p[0]), int(p[1]), str(r.get("room_type", "")), "|".join(links)
		])
	return "||".join(parts)


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
