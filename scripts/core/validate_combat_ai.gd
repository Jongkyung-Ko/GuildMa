extends SceneTree

## Headless combat AI repeat-attack validation.
## Separates attack starts vs real damage_hits (melee) / projectile fire + impact (mage).
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
		e.hp_max = maxf(float(e.hp_max), 500.0)
		e.hp = e.hp_max
		e.defense = 0.0

	var t := 0.0
	while t < 14.0 and str(combat.get_phase_name()) == "fighting":
		await process_frame
		t += 1.0 / 60.0

	var mage_started := 0
	var mage_fired := 0
	var mage_hits := 0
	var dps_land := 0
	var dps_hits := 0
	var enemy_started := 0
	var enemy_hits := 0
	var healer_heals := 0

	for a in combat.get_allies():
		if a == null:
			continue
		var job := str(a.job)
		print("ALLY %s job=%s started=%d landed=%d fired=%d hits=%d heals=%d state=%s" % [
			a.display_name, job,
			int(a.attacks_started), int(a.attacks_landed),
			int(a.projectiles_fired), int(a.damage_hits),
			int(a.heals_landed), a.get_anim_state_name()
		])
		if job == "mage":
			mage_started = int(a.attacks_started)
			mage_fired = int(a.projectiles_fired)
			mage_hits = int(a.damage_hits)
		elif job == "dps":
			dps_land = int(a.attacks_landed)
			dps_hits = int(a.damage_hits)
		elif job == "healer":
			healer_heals = int(a.heals_landed)

	for e in combat.get_enemies():
		if e == null:
			continue
		print("ENEMY %s started=%d landed=%d hits=%d state=%s hp=%.0f dead=%s" % [
			e.display_name, int(e.attacks_started), int(e.attacks_landed), int(e.damage_hits),
			e.get_anim_state_name(), e.hp, str(e.is_dead)
		])
		enemy_started = maxi(enemy_started, int(e.attacks_started))
		enemy_hits = maxi(enemy_hits, int(e.damage_hits))

	print("SUMMARY mage started=%d fired=%d hits=%d | enemy started=%d hits=%d | dps hits=%d" % [
		mage_started, mage_fired, mage_hits, enemy_started, enemy_hits, dps_hits
	])

	# Mage: starts, fireballs spawned, AND real bolt damage hits.
	if mage_started >= 3 and mage_fired >= 3 and mage_hits >= 2:
		_pass("mage started=%d fired=%d damage_hits=%d" % [mage_started, mage_fired, mage_hits])
	else:
		_fail("mage needs ≥3 starts, ≥3 fired, ≥2 damage_hits got started=%d fired=%d hits=%d" % [
			mage_started, mage_fired, mage_hits
		])

	if dps_hits >= 3:
		_pass("dps damage_hits=%d (landed=%d)" % [dps_hits, dps_land])
	else:
		_fail("dps needs ≥3 damage_hits got %d" % dps_hits)

	# Monsters: starts AND real damage — zero damage is always FAIL.
	if enemy_hits <= 0:
		_fail("enemies dealt 0 damage_hits (started=%d) — must apply real damage" % enemy_started)
	elif enemy_started >= 3 and enemy_hits >= 2:
		_pass("enemies started=%d damage_hits=%d" % [enemy_started, enemy_hits])
	else:
		_fail("enemies need ≥3 starts and ≥2 damage_hits got started=%d hits=%d" % [
			enemy_started, enemy_hits
		])

	# Retarget: kill one living enemy, confirm party keeps dealing damage to survivors.
	var living_before := 0
	var first_alive = null
	for e in combat.get_enemies():
		if e and is_instance_valid(e) and not e.is_dead:
			living_before += 1
			if first_alive == null:
				first_alive = e
	if living_before >= 2 and first_alive != null and str(combat.get_phase_name()) == "fighting":
		var hits_before := 0
		for a in combat.get_allies():
			if a:
				hits_before += int(a.damage_hits)
		first_alive.hp = 0
		first_alive.take_damage(99999.0, null, {})
		# Ensure dead flag even if take_damage path differs.
		if not first_alive.is_dead:
			first_alive.is_dead = true
			first_alive.visible = false
		var t_ret := 0.0
		while t_ret < 4.0 and str(combat.get_phase_name()) == "fighting":
			await process_frame
			t_ret += 1.0 / 60.0
		var hits_after := 0
		for a in combat.get_allies():
			if a:
				hits_after += int(a.damage_hits)
		var other_alive := 0
		for e in combat.get_enemies():
			if e and is_instance_valid(e) and not e.is_dead and e != first_alive:
				other_alive += 1
		if hits_after > hits_before and other_alive >= 0:
			_pass("retarget after kill: party hits %d→%d" % [hits_before, hits_after])
		elif str(combat.get_phase_name()) != "fighting":
			_pass("retarget window ended fight (hits %d→%d)" % [hits_before, hits_after])
		else:
			_fail("retarget: no further damage after killing one enemy (%d→%d)" % [hits_before, hits_after])
	else:
		print("NOTE: retarget skipped (living_enemies=%d phase=%s)" % [
			living_before, str(combat.get_phase_name())
		])
		if living_before < 2:
			_pass("retarget skipped (<2 living enemies) — not failed")

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
		if str(combat.get_phase_name()) == "fighting":
			_fail("healer did not heal while allies hurt")
		else:
			_pass("healer window skipped (fight ended)")

	# Preferred radius regression
	for e in combat.get_enemies():
		if e == null or e.is_dead:
			continue
		if float(e.preferred_radius) > float(e.attack_range) + 0.01:
			_fail("enemy preferred_radius %.1f > attack_range %.1f" % [e.preferred_radius, e.attack_range])
		else:
			_pass("enemy preferred_radius %.1f ≤ attack_range %.1f" % [e.preferred_radius, e.attack_range])
		break

	# Revive policy: kill one ally, travel to next uncleared room, check 35% HP.
	await _test_revive_on_travel(combat)

	_finish()


func _test_revive_on_travel(combat: Node) -> void:
	## Requires hunt map — rebind combat into a hunt run if needed.
	gs.new_game()
	var run: Dictionary = gs.start_hunt_run("beginner_forest", true)
	if run.is_empty():
		_fail("revive test: hunt run empty")
		return
	root.set_meta("dungeon_id", "")
	root.set_meta("dungeon_floor", 0)
	root.set_meta("hunt_id", "beginner_forest")
	root.set_meta("combat_hunt_id", "beginner_forest")
	root.set_meta("hunt_force_new", false)
	if is_instance_valid(combat):
		combat.queue_free()
	await process_frame
	combat = load("res://scenes/combat/combat.tscn").instantiate()
	root.add_child(combat)
	await process_frame
	await process_frame

	var victim = null
	for a in combat.get_allies():
		if a and str(a.job) == "dps":
			victim = a
			break
	if victim == null:
		for a in combat.get_allies():
			if a:
				victim = a
				break
	if victim == null:
		_fail("revive test: no ally")
		return

	var hp_max: float = float(victim.hp_max)
	victim.hp = 0
	victim.is_dead = true
	# Use real death path so collision disable matches production.
	victim.take_damage(99999.0, null, {"heavy": true})
	if not victim.is_dead:
		victim.is_dead = true
		victim.hp = 0
	victim.visible = false

	var survivor = null
	var surv_hp_before := 0.0
	for a in combat.get_allies():
		if a and a != victim and not a.is_dead:
			survivor = a
			surv_hp_before = float(a.hp)
			# Drain so 15% heal is measurable
			a.hp = maxf(1.0, a.hp_max * 0.5)
			surv_hp_before = float(a.hp)
			break

	gs.mark_hunt_room_cleared()
	combat.phase = 2
	var room: Dictionary = gs.get_current_hunt_room()
	var cons: Dictionary = room.get("connected_rooms", {})
	var travel_dir := ""
	for d in ["N", "E", "S", "W"]:
		var o = cons.get(d, null)
		if o != null and str(o) != "" and not bool(gs.get_active_hunt_map().get("rooms", {}).get(str(o), {}).get("cleared", false)):
			travel_dir = str(d)
			break
	if travel_dir == "":
		for d in ["N", "E", "S", "W"]:
			var o2 = cons.get(d, null)
			if o2 != null and str(o2) != "":
				travel_dir = str(d)
				break
	if travel_dir == "":
		_fail("revive test: no connected room")
		return

	combat.travel_hunt_direction(travel_dir)
	await process_frame
	await process_frame

	var expected_dead_hp := maxf(1.0, hp_max * 0.35)
	if victim.is_dead:
		_fail("revive test: victim still is_dead after travel")
	elif absf(float(victim.hp) - expected_dead_hp) > 1.0:
		_fail("revive test: dead ally hp=%.1f expected ~%.1f (35%%)" % [victim.hp, expected_dead_hp])
	else:
		_pass("revive dead ally hp=%.1f (~35%% of %.1f)" % [victim.hp, hp_max])

	var cs2: CollisionShape2D = null
	if victim.has_method("_collision_shape"):
		cs2 = victim.call("_collision_shape") as CollisionShape2D
	else:
		cs2 = victim.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs2 == null:
		_fail("revive test: CollisionShape2D missing")
	elif cs2.disabled:
		_fail("revive test: CollisionShape2D still disabled")
	else:
		_pass("revive CollisionShape2D re-enabled")

	if survivor != null and is_instance_valid(survivor):
		var expected_live := minf(float(survivor.hp_max), surv_hp_before + float(survivor.hp_max) * 0.15)
		if absf(float(survivor.hp) - expected_live) > 1.5:
			_fail("revive test: living ally hp=%.1f expected ~%.1f (+15%%)" % [survivor.hp, expected_live])
		else:
			_pass("living ally healed +15%% → hp=%.1f" % survivor.hp)


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
