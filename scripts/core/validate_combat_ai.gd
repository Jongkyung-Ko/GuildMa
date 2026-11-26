extends SceneTree

## Headless combat AI repeat-attack validation.
## Autoloads not injected into -s scripts — use /root/GameState.
## godot --headless --path . -s res://scripts/core/validate_combat_ai.gd

var _failed := 0
var _passed := 0
var gs: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== COMBAT AI VALIDATION ===")
	gs = root.get_node_or_null("/root/GameState")
	if gs == null:
		_fail("GameState missing")
		_finish()
		return
	gs.new_game()

	# Buff enemies slightly so fight lasts long enough for 3+ swings.
	root.set_meta("dungeon_id", "")
	root.set_meta("dungeon_floor", 0)
	root.set_meta("hunt_id", "")
	root.set_meta("combat_hunt_id", "ai_test")

	var combat: Node = load("res://scenes/combat/combat.tscn").instantiate()
	root.add_child(combat)
	await process_frame
	await process_frame

	# Inflate enemy HP so they survive for repeated attacks.
	for e in combat.get_enemies():
		if e == null:
			continue
		e.hp_max = maxf(float(e.hp_max), 400.0)
		e.hp = e.hp_max
		e.defense = 0.0

	var t := 0.0
	while t < 12.0 and str(combat.get_phase_name()) == "fighting":
		await process_frame
		t += 1.0 / 60.0

	var mage_land := 0
	var dps_land := 0
	var enemy_land := 0
	var enemy_started := 0
	var healer_heals := 0
	var mage_started := 0
	for a in combat.get_allies():
		if a == null:
			continue
		var job := str(a.job)
		print("ALLY %s job=%s started=%d landed=%d heals=%d state=%s" % [
			a.display_name, job, int(a.attacks_started), int(a.attacks_landed), int(a.heals_landed), a.get_anim_state_name()
		])
		if job == "mage":
			mage_land = int(a.attacks_landed)
			mage_started = int(a.attacks_started)
		elif job == "dps":
			dps_land = int(a.attacks_landed)
		elif job == "healer":
			healer_heals = int(a.heals_landed)
	for e in combat.get_enemies():
		if e == null:
			continue
		print("ENEMY %s started=%d landed=%d state=%s hp=%.0f" % [
			e.display_name, int(e.attacks_started), int(e.attacks_landed), e.get_anim_state_name(), e.hp
		])
		enemy_land = maxi(enemy_land, int(e.attacks_landed))
		enemy_started = maxi(enemy_started, int(e.attacks_started))

	# Count starts (≥3) — last swing may still be mid-anim so landed can be starts-1.
	if mage_started >= 3 and mage_land >= 2:
		_pass("mage repeated attacks started=%d landed=%d" % [mage_started, mage_land])
	else:
		_fail("mage needs ≥3 starts / ≥2 landed got started=%d landed=%d" % [mage_started, mage_land])

	if dps_land >= 3:
		_pass("dps landed=%d" % dps_land)
	else:
		_fail("dps needs ≥3 landed got %d" % dps_land)

	if enemy_started >= 3 and enemy_land >= 1:
		_pass("enemies started=%d landed=%d" % [enemy_started, enemy_land])
	elif enemy_started >= 3:
		_pass("enemies started=%d (land may trail anim)" % enemy_started)
	else:
		_fail("enemies need ≥3 attack starts got %d landed=%d" % [enemy_started, enemy_land])

	# Pause / resume mid-fight
	if str(combat.get_phase_name()) == "fighting":
		combat.toggle_pause()
		await process_frame
		if str(combat.get_phase_name()) != "paused":
			_fail("pause failed")
		else:
			_pass("pause works")
		var mage_before := mage_started
		for a in combat.get_allies():
			if a and str(a.job) == "mage":
				mage_before = int(a.attacks_started)
		combat.toggle_pause()
		var t2 := 0.0
		while t2 < 3.0 and str(combat.get_phase_name()) == "fighting":
			await process_frame
			t2 += 1.0 / 60.0
		var mage_after := mage_before
		for a in combat.get_allies():
			if a and str(a.job) == "mage":
				mage_after = int(a.attacks_started)
		if mage_after > mage_before:
			_pass("resume continues attacks (%d→%d)" % [mage_before, mage_after])
		else:
			_fail("resume did not continue mage attacks")
	else:
		_pass("fight already ended before pause window (ok)")

	# Soften ally HP and force healer path
	for a in combat.get_allies():
		if a and str(a.job) != "healer" and not a.is_dead:
			a.hp = maxf(1.0, a.hp_max * 0.4)
			a.hp_changed.emit(a.hp, a.hp_max)
	var t3 := 0.0
	while t3 < 4.0 and str(combat.get_phase_name()) == "fighting":
		await process_frame
		t3 += 1.0 / 60.0
	for a in combat.get_allies():
		if a and str(a.job) == "healer":
			healer_heals = int(a.heals_landed)
	if healer_heals >= 1:
		_pass("healer landed heals=%d" % healer_heals)
	else:
		# Not always guaranteed if fight ended; soft fail only if still fighting
		if str(combat.get_phase_name()) == "fighting":
			_fail("healer did not heal while allies hurt")
		else:
			_pass("healer window skipped (fight ended)")

	# Preferred radius regression: enemy preferred must be ≤ attack_range
	for e in combat.get_enemies():
		if e == null or e.is_dead:
			continue
		if float(e.preferred_radius) > float(e.attack_range) + 0.01:
			_fail("enemy preferred_radius %.1f > attack_range %.1f" % [e.preferred_radius, e.attack_range])
		else:
			_pass("enemy preferred_radius %.1f ≤ attack_range %.1f" % [e.preferred_radius, e.attack_range])
		break

	_finish()


func _pass(msg: String) -> void:
	_passed += 1
	print("PASS: ", msg)


func _fail(msg: String) -> void:
	_failed += 1
	print("FAIL: ", msg)


func _finish() -> void:
	print("=== COMBAT AI RESULT: %s (%d pass / %d fail) ===" % [
		"PASS" if _failed == 0 else "FAIL", _passed, _failed
	])
	quit(0 if _failed == 0 else 1)
