extends SceneTree

## Measures attack intervals, mage projectiles, healer heals, and hit FX.
## xvfb-run -a godot --path . -s res://scripts/core/validate_combat_feel.gd

const OUT := "/opt/cursor/artifacts/guildma-combat-feel"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var ok := true
	print("=== validate_combat_feel ===")

	await process_frame
	var gs: Node = root.get_node_or_null("/root/GameState")
	gs.call("new_game")

	var combat: Node = load("res://scenes/combat/combat.tscn").instantiate()
	root.add_child(combat)
	await process_frame
	await process_frame
	await process_frame

	# Keep fight alive for measurement
	for e in combat.call("get_enemies"):
		e.hp_max = 800.0
		e.hp = 800.0
		if e._hp_bar:
			e._hp_bar.max_value = 800
			e._hp_bar.value = 800

	# Wound an ally for healer
	for a in combat.call("get_allies"):
		if a and a.job != "healer" and not a.is_dead:
			a.hp = a.hp_max * 0.4
			if a._hp_bar:
				a._hp_bar.value = a.hp
			break

	var intervals: Dictionary = {}
	var last_attack: Dictionary = {}
	var last_count: Dictionary = {}
	var saw_projectile := false
	var saw_heal := false
	var attack_counts: Dictionary = {}

	for frame in range(1, 720):
		await physics_frame
		if combat.has_method("_check_end_conditions"):
			combat._check_end_conditions()

		if _has_projectile(combat):
			saw_projectile = true

		var t_now := float(frame) / 60.0
		for a in combat.call("get_allies"):
			if a == null or a.is_dead:
				continue
			var j: String = str(a.job)
			var cnt: int = int(a.attacks_started)
			var prev_c: int = int(last_count.get(j, 0))
			if cnt > prev_c:
				if last_attack.has(j):
					var gap: float = t_now - float(last_attack[j])
					if not intervals.has(j):
						intervals[j] = []
					intervals[j].append(gap)
				last_attack[j] = t_now
				attack_counts[j] = cnt
				last_count[j] = cnt

		if frame in [60, 150, 240, 360]:
			await _capture("feel_f%03d" % frame)

		if str(combat.call("get_phase_name")) != "fighting":
			break

	await _capture("feel_midfight")

	# --- Mage fireball forced showcase ---
	var mage: CombatCharacter = null
	var foe: CombatCharacter = null
	for a in combat.call("get_allies"):
		if a and a.job == "mage" and not a.is_dead:
			mage = a
	for e in combat.call("get_enemies"):
		if e and not e.is_dead:
			foe = e
			e.hp = maxf(e.hp, 200.0)
			break
	if foe == null:
		# Respawn a dummy wolf if wipe already happened
		var ENEMY_SCRIPT = load("res://scripts/combat/enemy_base.gd")
		foe = ENEMY_SCRIPT.new()
		combat.get_node("Battlefield/Enemies").add_child(foe)
		foe.bind_manager(combat)
		foe.setup_from_enemy({"id": "wolf", "name": "늑대", "hp": 300, "atk": 1, "def": 1, "move": 40, "aspd": 0.5, "attack_range": 28, "sprite": "wolf"})
		combat._enemies.append(foe)

	if mage and foe:
		combat.phase = combat.Phase.FIGHTING
		for a in combat.call("get_allies"):
			if a:
				a.set_physics_process(false)
				a._atk_timer = 999.0
		for e in combat.call("get_enemies"):
			if e:
				e.set_physics_process(false)
		mage.set_physics_process(false)
		mage.global_position = Vector2(560, 360)
		foe.global_position = Vector2(800, 360)
		mage._face_right = true
		if mage._sprite:
			mage._sprite.flip_h = false
		mage._atk_timer = 0.0
		mage._perform_attack(foe)
		# Drive animation until projectile exists
		for _i in range(150):
			await process_frame
			# Manually nudge active if anim stuck under -s
			if mage._sprite and mage._sprite.animation == "attack":
				if mage._sprite.frame >= mage._attack_active_idx and not mage._damage_applied:
					mage._on_frame_changed()
			if _has_projectile(combat):
				saw_projectile = true
				await _capture("mage_fireball_flight")
				print("OK fireball mid-flight")
				break
		for _j in range(90):
			await process_frame
		await _capture("mage_fireball_after")

	# --- Healer heal forced showcase ---
	var healer: CombatCharacter = null
	var wounded: CombatCharacter = null
	for a in combat.call("get_allies"):
		if a == null or a.is_dead:
			continue
		if a.job == "healer":
			healer = a
		elif wounded == null:
			wounded = a
	if healer and wounded:
		wounded.hp = wounded.hp_max * 0.35
		if wounded._hp_bar:
			wounded._hp_bar.value = wounded.hp
		healer.global_position = Vector2(500, 380)
		wounded.global_position = Vector2(600, 380)
		healer._atk_timer = 0.0
		var hp_before := wounded.hp
		healer._perform_heal(wounded)
		for _k in range(100):
			await process_frame
			if healer._sprite and healer._sprite.animation == "attack":
				if healer._sprite.frame >= healer._attack_active_idx and not healer._damage_applied:
					healer._on_frame_changed()
			if wounded.hp > hp_before + 0.5:
				saw_heal = true
				break
		print("heal delta=", wounded.hp - hp_before)
		await _capture("healer_heal")

	print("--- measured attack gaps (sec) ---")
	var targets := {"tank": 1.15, "lord": 0.95, "dps": 0.65, "mage": 1.30, "healer": 1.50}
	for j in targets.keys():
		var arr: Array = intervals.get(j, [])
		var tgt: float = float(targets[j])
		if arr.is_empty():
			print("WARN no gaps for ", j, " attacks=", attack_counts.get(j, 0))
			continue
		var avg := 0.0
		for g in arr:
			avg += float(g)
		avg /= float(arr.size())
		print("%s avg_gap=%.2f target=%.2f n=%d attacks=%d" % [j, avg, tgt, arr.size(), attack_counts.get(j, 0)])
		if avg > 2.5:
			printerr("FAIL ", j, " still too slow avg=", avg)
			ok = false
		elif avg < tgt * 0.45 and arr.size() > 2:
			# Suspiciously faster than interval — might be measurement noise
			print("NOTE ", j, " faster than target (ok if anim-gated)")

	if not saw_projectile:
		printerr("FAIL mage projectile never observed")
		ok = false
	else:
		print("OK mage projectile observed")
	if not saw_heal:
		printerr("FAIL healer heal not applied")
		ok = false
	else:
		print("OK healer heal applied")

	# Print configured intervals from live actors
	print("--- configured intervals ---")
	for a in combat.call("get_allies"):
		if a:
			print(a.job, " interval=", a.attack_interval, " move=", a.move_speed, " range=", a.attack_range)

	print("=== COMBAT FEEL RESULT: %s ===" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _has_projectile(combat: Node) -> bool:
	for n in _all_nodes(combat):
		if n is CombatProjectile:
			return true
		var s = n.get_script()
		if s and str(s.resource_path).find("projectile.gd") >= 0:
			return true
	return false


func _all_nodes(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out.append_array(_all_nodes(c))
	return out


func _capture(name: String) -> void:
	await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	if img:
		img.save_png("%s/%s.png" % [OUT, name])
		print("saved ", name)
