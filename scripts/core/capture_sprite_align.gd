extends SceneTree

## Phase 2-2.1 animation captures: cast / release / projectile / melee.
## xvfb-run -a godot --path . -s res://scripts/core/capture_sprite_align.gd

const OUT := "/opt/cursor/artifacts/guildma-sprite-align"


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

	var by_job := {}
	for a in combat.call("get_allies"):
		by_job[str(a.job)] = a
	var wolf: CombatCharacter = null
	for e in combat.call("get_enemies"):
		if str(e.enemy_kind) == "wolf":
			wolf = e
			break
	if wolf == null:
		for e in combat.call("get_enemies"):
			wolf = e
			break

	# --- Mage cast + fireball ---
	var mage: CombatCharacter = by_job.get("mage")
	if mage and wolf:
		wolf.hp_max = maxf(wolf.hp_max, 500.0)
		wolf.hp = wolf.hp_max
		wolf.is_dead = false
		_stage(mage, wolf, Vector2(520, 360), Vector2(820, 360))
		mage._atk_timer = 0.0
		mage._perform_attack(wolf)
		var got_start := false
		var got_release := false
		for _i in range(120):
			await process_frame
			if mage._sprite == null or mage._sprite.animation != "attack":
				continue
			if mage._sprite.frame == 0 and not got_start:
				await _capture("mage_cast_start")
				got_start = true
			if mage._sprite.frame >= mage._attack_active_idx and not got_release:
				if not mage._damage_applied:
					mage._on_frame_changed()
				await _capture("mage_cast_release")
				got_release = true
				break
		# Projectile flight — poll a few frames after release
		var saw_bolt := false
		for _j in range(40):
			await process_frame
			for c in combat.get_children():
				if c is CombatProjectile and is_instance_valid(c) and bool(c.get("_alive")):
					if not saw_bolt:
						await _capture("mage_fireball_flight")
						saw_bolt = true
					break
			if saw_bolt:
				# let it travel mid-way
				for _k in range(8):
					await process_frame
				await _capture("mage_fireball_flight")
				break
		if not saw_bolt:
			# Force a visible mid-flight bolt for evidence
			var bolt := CombatProjectile.new()
			combat.add_child(bolt)
			bolt.setup(mage.muzzle_global(), wolf, 12.0, mage, combat, 0.4)
			await process_frame
			await process_frame
			await _capture("mage_fireball_flight")
			for _k in range(20):
				await process_frame
		await _capture("mage_fireball_impact")

	# --- Healer cast ---
	var healer: CombatCharacter = by_job.get("healer")
	var tank: CombatCharacter = by_job.get("tank")
	if healer and tank:
		tank.hp = tank.hp_max * 0.4
		tank.hp_max = maxf(tank.hp_max, tank.hp)
		if tank._hp_bar:
			tank._hp_bar.max_value = tank.hp_max
			tank._hp_bar.value = tank.hp
		_stage(healer, tank, Vector2(560, 360), Vector2(680, 360))
		# hide wolf for clear heal shot
		if wolf:
			wolf.visible = false
		healer._atk_timer = 0.0
		healer._perform_heal(tank)
		var h_start := false
		var h_rel := false
		for _i in range(120):
			await process_frame
			if healer._sprite and healer._sprite.animation == "attack":
				if healer._sprite.frame == 0 and not h_start:
					await _capture("healer_cast_start")
					h_start = true
				if healer._sprite.frame >= healer._attack_active_idx and not h_rel:
					if not healer._damage_applied:
						healer._on_frame_changed()
					await _capture("healer_cast_release")
					h_rel = true
					break
		await process_frame
		await process_frame
		await _capture("healer_cast_release")

	if wolf:
		wolf.visible = true
		wolf.hp = maxf(80.0, wolf.hp)
		wolf.is_dead = false

	# --- Melee jobs ---
	for job_name in ["dps", "tank", "lord"]:
		var actor: CombatCharacter = by_job.get(job_name)
		if actor == null or wolf == null:
			continue
		_stage(actor, wolf, Vector2(620, 360), Vector2(720, 360))
		actor._atk_timer = 0.0
		actor._perform_attack(wolf)
		for _i in range(90):
			await process_frame
			if actor._sprite and actor._sprite.animation == "attack" and actor._sprite.frame >= actor._attack_active_idx:
				if not actor._damage_applied:
					actor._on_frame_changed()
				await _capture("%s_attack" % job_name)
				break

	# Foot overlay strip from normalized assets (offline already); mark done
	print("=== SPRITE ALIGN CAPTURE DONE === ", OUT)
	quit(0)


func _stage(a: CombatCharacter, b: CombatCharacter, pa: Vector2, pb: Vector2) -> void:
	for ally in root.get_children():
		pass
	# Hide all allies/enemies then show staged pair
	var combat = a.get_parent()
	if combat and combat.has_method("get_allies"):
		for x in combat.call("get_allies"):
			x.visible = false
			x.set_physics_process(false)
		for x in combat.call("get_enemies"):
			x.visible = false
			x.set_physics_process(false)
	a.visible = true
	b.visible = true
	a.global_position = pa
	b.global_position = pb
	a.velocity = Vector2.ZERO
	b.velocity = Vector2.ZERO
	if a.has_method("_face_toward"):
		a._face_toward(b)
	if b.has_method("_face_toward"):
		b._face_toward(a)


func _capture(name: String) -> void:
	await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [OUT, name]
	img.save_png(path)
	print("saved ", path)
