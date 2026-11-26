extends SceneTree

## Isolated screenshots: melee hit flash, fireball flight/impact, heal numbers.
## xvfb-run -a godot --path . -s res://scripts/core/capture_combat_feel.gd

const OUT := "/opt/cursor/artifacts/guildma-combat-feel"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	await process_frame
	var gs: Node = root.get_node_or_null("/root/GameState")
	gs.call("new_game")
	var combat: Node = load("res://scenes/combat/combat.tscn").instantiate()
	root.add_child(combat)
	await process_frame
	await process_frame

	combat.phase = combat.Phase.PAUSED
	for a in combat.call("get_allies"):
		a.set_physics_process(false)
		a.visible = false
		a._atk_timer = 999.0
	for e in combat.call("get_enemies"):
		e.set_physics_process(false)
		e.visible = false

	var tank: CombatCharacter = null
	var dps: CombatCharacter = null
	var mage: CombatCharacter = null
	var healer: CombatCharacter = null
	var lord: CombatCharacter = null
	for a in combat.call("get_allies"):
		match str(a.job):
			"tank": tank = a
			"dps": dps = a
			"mage": mage = a
			"healer": healer = a
			"lord": lord = a

	var wolf: CombatCharacter = null
	for e in combat.call("get_enemies"):
		if str(e.enemy_kind) == "wolf":
			wolf = e
			break
	if wolf == null:
		for e in combat.call("get_enemies"):
			wolf = e
			break

	# --- Tank melee hit with flash + number ---
	if tank and wolf:
		_stage(tank, wolf, Vector2(620, 360), Vector2(720, 360))
		await _capture("01_tank_before")
		tank._atk_timer = 0.0
		tank._perform_attack(wolf)
		for _i in range(90):
			await process_frame
			if tank._sprite and tank._sprite.animation == "attack" and tank._sprite.frame >= tank._attack_active_idx:
				if not tank._damage_applied:
					tank._on_frame_changed()
				await _capture("02_tank_hit")
				break
		await process_frame
		await process_frame
		await _capture("03_tank_after_flash")

	# --- DPS rapid slash ---
	if dps and wolf:
		wolf.hp = maxf(wolf.hp, 200.0)
		_stage(dps, wolf, Vector2(620, 360), Vector2(720, 360))
		dps._atk_timer = 0.0
		dps._perform_attack(wolf)
		for _i in range(60):
			await process_frame
			if dps._sprite and dps._sprite.animation == "attack" and dps._sprite.frame >= dps._attack_active_idx:
				if not dps._damage_applied:
					dps._on_frame_changed()
				await _capture("04_dps_hit")
				break

	# --- Mage fireball ---
	if mage and wolf:
		wolf.hp_max = maxf(wolf.hp_max, 400.0)
		wolf.hp = wolf.hp_max
		wolf.is_dead = false
		wolf.visible = true
		if wolf._hp_bar:
			wolf._hp_bar.max_value = wolf.hp_max
			wolf._hp_bar.value = wolf.hp
		_stage(mage, wolf, Vector2(520, 360), Vector2(820, 360))
		await _capture("05_mage_before")
		mage._atk_timer = 0.0
		mage._perform_attack(wolf)
		var saw := false
		for _i in range(120):
			await process_frame
			if mage._sprite and mage._sprite.animation == "attack" and mage._sprite.frame >= mage._attack_active_idx:
				if not mage._damage_applied:
					mage._on_frame_changed()
			if _has_proj(combat):
				saw = true
				await _capture("06_mage_fireball_flight")
				break
		for _j in range(50):
			await process_frame
		await _capture("07_mage_fireball_impact")
		print("fireball saw=", saw)

	# --- Healer ---
	if healer and lord:
		_hide_all(combat)
		healer.visible = true
		lord.visible = true
		healer.global_position = Vector2(560, 380)
		lord.global_position = Vector2(660, 380)
		lord.hp = lord.hp_max * 0.4
		if lord._hp_bar:
			lord._hp_bar.value = lord.hp
		await _capture("08_healer_before")
		healer._atk_timer = 0.0
		healer._perform_heal(lord)
		for _k in range(90):
			await process_frame
			if healer._sprite and healer._sprite.animation == "attack" and healer._sprite.frame >= healer._attack_active_idx:
				if not healer._damage_applied:
					healer._on_frame_changed()
				await _capture("09_healer_heal")
				break
		await process_frame
		await process_frame
		await _capture("10_healer_after")

	print("=== capture_combat_feel done ===")
	quit(0)


func _stage(actor: CombatCharacter, foe: CombatCharacter, ap: Vector2, fp: Vector2) -> void:
	var combat: Node = actor._manager
	_hide_all(combat)
	actor.visible = true
	foe.visible = true
	actor.global_position = ap
	foe.global_position = fp
	actor._face_right = true
	if actor._sprite:
		actor._sprite.flip_h = false
	foe._face_right = false
	if foe._sprite:
		foe._sprite.flip_h = true
		foe._sprite.modulate = Color(1, 1, 1, 1)


func _hide_all(combat: Node) -> void:
	if combat == null:
		return
	for a in combat.call("get_allies"):
		if a:
			a.visible = false
	for e in combat.call("get_enemies"):
		if e:
			e.visible = false


func _has_proj(combat: Node) -> bool:
	for n in _walk(combat):
		if n is CombatProjectile:
			return true
	return false


func _walk(n: Node) -> Array:
	var o: Array = [n]
	for c in n.get_children():
		o.append_array(_walk(c))
	return o


func _capture(name: String) -> void:
	await process_frame
	await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	if img:
		img.save_png("%s/%s.png" % [OUT, name])
		print("saved ", name)
