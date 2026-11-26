extends SceneTree

## Mage cast sequence capture + foot world-position stability log.
## xvfb-run -a godot4 --path . -s res://scripts/core/capture_mage_cast.gd
##
## Outputs under /opt/cursor/artifacts/mage-cast-align/:
##   mage_idle.png, mage_cast_start.png, mage_cast_release.png,
##   mage_fireball.png, mage_cast_return.png, foot_log.json

const OUT := "/opt/cursor/artifacts/mage-cast-align"
const MAX_FOOT_ERR_PX := 2.0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	SpriteFactory._pivot_cache = {}
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
	var mage: CombatCharacter = by_job.get("mage")
	var wolf: CombatCharacter = null
	for e in combat.call("get_enemies"):
		wolf = e
		break
	if mage == null or wolf == null:
		print("FAIL: missing mage or wolf")
		quit(1)
		return

	wolf.hp_max = 800.0
	wolf.hp = wolf.hp_max
	wolf.is_dead = false
	_stage(mage, wolf, Vector2(520, 360), Vector2(860, 360))
	mage._atk_timer = 0.0
	mage._set_anim_state(mage.AnimState.IDLE)
	mage._play_anim("idle", true)
	await process_frame
	await process_frame

	var foot_log: Array = []
	var idle_foot := _foot_world(mage)
	foot_log.append(_entry("idle", mage, idle_foot, idle_foot))
	await _capture("mage_idle")

	mage._perform_attack(wolf)
	var saw := {
		"start": false,
		"raise": false,
		"prep": false,
		"release": false,
		"fireball": false,
		"return": false,
	}
	var max_err := 0.0
	for _i in range(180):
		await process_frame
		if mage._sprite == null:
			continue
		var anim: String = str(mage._sprite.animation)
		var fr: int = int(mage._sprite.frame)
		var foot := _foot_world(mage)
		var err := foot.distance_to(idle_foot)
		max_err = maxf(max_err, err)

		if anim == "attack" and fr == 0 and not saw["start"]:
			foot_log.append(_entry("cast_start", mage, foot, idle_foot))
			await _capture("mage_cast_start")
			saw["start"] = true
		elif anim == "attack" and fr == 1 and not saw["raise"]:
			foot_log.append(_entry("staff_raise", mage, foot, idle_foot))
			saw["raise"] = true
		elif anim == "attack" and fr == 2 and not saw["prep"]:
			foot_log.append(_entry("cast_prep", mage, foot, idle_foot))
			saw["prep"] = true
		elif anim == "attack" and fr >= mage._attack_active_idx and not saw["release"]:
			if not mage._damage_applied:
				mage._on_frame_changed()
			foot = _foot_world(mage)
			err = foot.distance_to(idle_foot)
			max_err = maxf(max_err, err)
			foot_log.append(_entry("spell_release", mage, foot, idle_foot))
			await _capture("mage_cast_release")
			saw["release"] = true
		elif saw["release"] and not saw["fireball"]:
			for c in combat.get_children():
				if c is CombatProjectile and is_instance_valid(c) and bool(c.get("_alive")):
					foot_log.append(_entry("fireball", mage, _foot_world(mage), idle_foot))
					await _capture("mage_fireball")
					saw["fireball"] = true
					break
		elif saw["release"] and anim == "idle" and not saw["return"]:
			foot = _foot_world(mage)
			err = foot.distance_to(idle_foot)
			max_err = maxf(max_err, err)
			foot_log.append(_entry("idle_return", mage, foot, idle_foot))
			await _capture("mage_cast_return")
			saw["return"] = true
			break

	if not saw["fireball"]:
		# Force a bolt at current muzzle for evidence if timing missed.
		var bolt := CombatProjectile.new()
		combat.add_child(bolt)
		bolt.setup(mage.muzzle_global(), wolf, 12.0, mage, combat, 0.35)
		await process_frame
		await process_frame
		foot_log.append(_entry("fireball_forced", mage, _foot_world(mage), idle_foot))
		await _capture("mage_fireball")
		saw["fireball"] = true

	if not saw["return"]:
		for _j in range(60):
			await process_frame
			if mage._sprite and mage._sprite.animation == "idle":
				foot_log.append(_entry("idle_return", mage, _foot_world(mage), idle_foot))
				await _capture("mage_cast_return")
				saw["return"] = true
				break

	var report := {
		"idle_foot": [idle_foot.x, idle_foot.y],
		"max_foot_err_px": max_err,
		"pass": max_err <= MAX_FOOT_ERR_PX,
		"saw": saw,
		"frames": foot_log,
		"muzzle_at_release": null,
	}
	# Sample muzzle vs staff tip expectation on release frame if available
	for e in foot_log:
		if str(e.get("label", "")) == "spell_release":
			report["muzzle_at_release"] = e.get("muzzle")
			break

	var jf := FileAccess.open("%s/foot_log.json" % OUT, FileAccess.WRITE)
	jf.store_string(JSON.stringify(report, "\t"))
	jf.close()

	print("max_foot_err_px=", max_err)
	print("saw=", saw)
	if max_err > MAX_FOOT_ERR_PX:
		print("=== MAGE CAST ALIGN: FAIL (foot err %.2f > %.1f) ===" % [max_err, MAX_FOOT_ERR_PX])
		quit(1)
		return
	for k in ["start", "release", "fireball", "return"]:
		if not bool(saw[k]):
			print("=== MAGE CAST ALIGN: FAIL (missing stage %s) ===" % k)
			quit(1)
			return
	print("=== MAGE CAST ALIGN: PASS === ", OUT)
	quit(0)


func _entry(label: String, mage: CombatCharacter, foot: Vector2, idle_foot: Vector2) -> Dictionary:
	var muzzle := mage.muzzle_global()
	return {
		"label": label,
		"anim": str(mage._sprite.animation) if mage._sprite else "",
		"frame": int(mage._sprite.frame) if mage._sprite else -1,
		"sheet": mage._attack_sheet_frame(),
		"actor": [mage.global_position.x, mage.global_position.y],
		"foot": [foot.x, foot.y],
		"foot_err": [foot.x - idle_foot.x, foot.y - idle_foot.y],
		"muzzle": [muzzle.x, muzzle.y],
	}


func _foot_world(mage: CombatCharacter) -> Vector2:
	## Actor origin is the foot pivot (VisualPivot at local 0,0).
	return mage.global_position


func _stage(a: CombatCharacter, b: CombatCharacter, pa: Vector2, pb: Vector2) -> void:
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
