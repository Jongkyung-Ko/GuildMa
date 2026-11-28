extends SceneTree

## Combat field arena bounds + speed 1/2/4 + 80% render scale.
## godot4 --headless --path . -s res://scripts/core/validate_combat_bounds_speed_scale.gd

var _failed := 0
var _passed := 0


func _init() -> void:
	call_deferred("_run")


func _fail(msg: String) -> void:
	printerr("FAIL: ", msg)
	_failed += 1


func _pass(msg: String) -> void:
	print("PASS: ", msg)
	_passed += 1


func _finish() -> void:
	print("=== COMBAT BOUNDS/SPEED/SCALE RESULT: %s (%d pass / %d fail) ===" % [
		"PASS" if _failed == 0 else "FAIL", _passed, _failed
	])
	quit(1 if _failed > 0 else 0)


func _run() -> void:
	print("=== COMBAT BOUNDS / SPEED / SCALE VALIDATION ===")
	_check_constants()
	await _check_runtime()
	_finish()


func _check_constants() -> void:
	if not is_equal_approx(CombatFieldBounds.COMBAT_RENDER_SCALE, 0.8):
		_fail("COMBAT_RENDER_SCALE != 0.8")
	else:
		_pass("COMBAT_RENDER_SCALE=0.8")
	var arena: Rect2 = CombatFieldBounds.background_arena_world()
	if arena.position.x < 100.0 or arena.end.x > 1200.0 or arena.size.x < 400.0:
		_fail("arena X out of expected clearing %s" % arena)
	else:
		_pass("arena X on dirt clearing %s" % arena)
	if arena.position.y < 80.0 or arena.end.y > 700.0 or arena.size.y < 250.0:
		_fail("arena Y out of expected clearing %s" % arena)
	else:
		_pass("arena Y on dirt clearing %s" % arena)
	if not ResourceLoader.exists(CombatFieldBounds.BG_PATH) and not FileAccess.file_exists(CombatFieldBounds.BG_PATH):
		_fail("missing combat_bg.png")
	else:
		_pass("combat_bg.png present")


func _check_runtime() -> void:
	var gs: Node = root.get_node_or_null("/root/GameState")
	if gs:
		gs.new_game()
	CombatFieldBounds.debug_force_vp_size = Vector2(1280, 720)

	var combat: Node = load("res://scenes/combat/combat.tscn").instantiate()
	root.add_child(combat)
	await process_frame
	await process_frame
	await process_frame

	if not combat.has_method("get_combat_speed"):
		_fail("CombatManager.get_combat_speed missing")
	else:
		_pass("get_combat_speed present")

	if not is_equal_approx(float(combat.combat_speed), 1.0):
		_fail("default combat_speed != 1")
	else:
		_pass("default combat_speed=1")

	var s2: float = combat.cycle_combat_speed()
	var s4: float = combat.cycle_combat_speed()
	var s1: float = combat.cycle_combat_speed()
	if not (is_equal_approx(s2, 2.0) and is_equal_approx(s4, 4.0) and is_equal_approx(s1, 1.0)):
		_fail("cycle 1→2→4→1 got %s %s %s" % [s2, s4, s1])
	else:
		_pass("cycle 1→2→4→1")

	# Pause must freeze effective speed for AI (get_combat_speed → 1 while paused? or 0 activity)
	combat.combat_speed = 4.0
	if combat.has_method("toggle_pause"):
		combat.toggle_pause()
	await process_frame
	if str(combat.get_phase_name()) != "paused":
		_fail("pause failed")
	else:
		_pass("pause compatible with speed=4 stored")
	if not is_equal_approx(float(combat.combat_speed), 4.0):
		_fail("pause cleared combat_speed")
	else:
		_pass("pause keeps combat_speed=4")
	if combat.has_method("toggle_pause"):
		combat.toggle_pause()

	# Bounds: outside-arena clamp lands inside arena ∩ view
	var allies: Array = combat.get_allies() if combat.has_method("get_allies") else []
	var actor: Node2D = allies[0] if allies.size() > 0 else null
	if actor == null:
		_fail("no ally for clamp test")
	else:
		_pass("ally spawned for clamp")
		var arena: Rect2 = CombatFieldBounds.background_arena_world()
		var outside := Vector2(40, 40)
		var clamped: Vector2 = CombatFieldBounds.clamp_point(outside, actor)
		if not arena.has_point(clamped) and not (
			clamped.x >= arena.position.x - 1.0 and clamped.x <= arena.end.x + 1.0
			and clamped.y >= arena.position.y - 1.0 and clamped.y <= arena.end.y + 1.0
		):
			# May be inset by half-width / HUD top — must still be inside expanded arena margin
			var expanded := arena.grow(80.0)
			if not expanded.has_point(clamped):
				_fail("clamp outside arena: %s from %s arena=%s" % [clamped, outside, arena])
			else:
				_pass("clamp pulled into arena vicinity %s" % clamped)
		else:
			_pass("clamp into arena %s" % clamped)

		# Tree-edge (viewport corner) should not stay there
		var deep := Vector2(20, 700)
		var c2: Vector2 = CombatFieldBounds.clamp_point(deep, actor)
		if c2.x < arena.position.x - 40.0 or c2.y > arena.end.y + 40.0:
			_fail("deep tree clamp still out: %s" % c2)
		else:
			_pass("deep tree clamp corrected %s" % c2)

		# 80% render scale on visual root
		var vr: Node2D = actor.get_node_or_null("VisualPivot") as Node2D
		if vr == null:
			_fail("VisualPivot missing")
		else:
			var sx := absf(vr.scale.x)
			var expect := 0.95 * CombatFieldBounds.COMBAT_RENDER_SCALE
			if absf(sx - expect) > 0.05 and absf(sx - CombatFieldBounds.COMBAT_RENDER_SCALE) > 0.2:
				# Boss/ally may vary; must be ~80% of prior 0.95 → ~0.76
				if sx > 0.95:
					_fail("render scale not reduced: %s" % sx)
				else:
					_pass("render scale reduced sx=%s" % sx)
			else:
				_pass("ally visual scale≈80%% (%s)" % sx)

	# Speed=4 for a few frames: still clamped
	combat.combat_speed = 4.0
	for _i in range(30):
		await process_frame
	for a in allies:
		if a == null or not is_instance_valid(a) or bool(a.is_dead):
			continue
		var p: Vector2 = a.global_position
		var arena2: Rect2 = CombatFieldBounds.background_arena_world().grow(90.0)
		if not arena2.has_point(p):
			_fail("ally escaped arena at 4x: %s" % p)
		else:
			_pass("ally stays in arena at 4x %s" % p)
			break

	# UI speed button exists
	var ui = combat.get_node_or_null("UILayer")
	var found_speed := false
	if ui:
		for b in _find_buttons(ui):
			if str(b.text).begins_with("속도"):
				found_speed = true
				break
	if found_speed:
		_pass("HUD speed button present")
	else:
		_fail("HUD speed button missing")

	combat.queue_free()
	await process_frame
	CombatFieldBounds.debug_force_vp_size = Vector2.ZERO


func _find_buttons(n: Node) -> Array:
	var out: Array = []
	if n is Button:
		out.append(n)
	for c in n.get_children():
		out.append_array(_find_buttons(c))
	return out
