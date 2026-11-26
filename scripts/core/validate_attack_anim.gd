extends SceneTree

## Validates attack SpriteFrames + hit-frame damage sync, captures attack phases.
## Run: xvfb-run -a godot --path . -s res://scripts/core/validate_attack_anim.gd

const OUT := "/opt/cursor/artifacts/guildma-attack-fix"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var ok := true
	print("=== validate_attack_anim ===")

	# --- Resource / frame integrity (no scene required) ---
	var jobs: Array[String] = ["lord", "tank", "dps", "healer", "mage"]
	for job in jobs:
		var sf: SpriteFrames = SpriteFactory.ally_frames(job)
		for anim in ["idle", "walk", "attack", "hit", "death"]:
			if not sf.has_animation(anim):
				printerr("FAIL missing anim %s/%s" % [job, anim])
				ok = false
				continue
			var n: int = sf.get_frame_count(anim)
			if n <= 0:
				printerr("FAIL empty anim %s/%s" % [job, anim])
				ok = false
			if anim == "attack" and n < 4:
				printerr("FAIL attack too short %s frames=%d" % [job, n])
				ok = false
			# Reject fully-transparent attack frames.
			for fi in range(n):
				var tex: Texture2D = sf.get_frame_texture(anim, fi)
				if tex == null:
					printerr("FAIL null tex %s/%s#%d" % [job, anim, fi])
					ok = false
					continue
				var img: Image = tex.get_image()
				if img == null:
					continue
				var opaque := 0
				for y in range(img.get_height()):
					for x in range(img.get_width()):
						if img.get_pixel(x, y).a > 0.15:
							opaque += 1
				if anim == "attack" and opaque < 80:
					printerr("FAIL near-empty attack frame %s#%d opaque=%d" % [job, fi, opaque])
					ok = false
		print("OK frames job=%s attack_n=%d active_idx=%d" % [
			job, sf.get_frame_count("attack"), SpriteFactory.attack_active_frame(job)
		])

	for kind in ["wolf", "slime", "goblin"]:
		var esf: SpriteFrames = SpriteFactory.enemy_frames(kind)
		if not esf.has_animation("attack") or esf.get_frame_count("attack") < 3:
			printerr("FAIL monster attack %s" % kind)
			ok = false
		else:
			print("OK monster=%s attack_n=%d" % [kind, esf.get_frame_count("attack")])

	# --- Live combat: force attacks and capture before/during/after ---
	await process_frame
	var gs: Node = root.get_node_or_null("/root/GameState")
	if gs == null:
		printerr("FAIL GameState missing")
		quit(2)
		return
	gs.call("new_game")
	var combat_ps: PackedScene = load("res://scenes/combat/combat.tscn")
	var combat: Node = combat_ps.instantiate()
	root.add_child(combat)
	await process_frame
	await process_frame
	await process_frame

	var allies: Array = combat.call("get_allies")
	var enemies: Array = combat.call("get_enemies")
	if allies.is_empty() or enemies.is_empty():
		printerr("FAIL spawn")
		quit(1)
		return

	# Wait until someone is in range, then watch first ally attack cycle.
	var watched: CombatCharacter = null
	for a in allies:
		var c := a as CombatCharacter
		if c and c.job == "tank":
			watched = c
			break
	if watched == null:
		watched = allies[0] as CombatCharacter

	var saw_windup := false
	var saw_active := false
	var saw_idle_after := false
	var damage_events := 0
	var last_enemy_hp := 0.0
	for e in enemies:
		last_enemy_hp += (e as CombatCharacter).hp

	await _capture("attack_before")

	for frame in range(1, 600):
		await process_frame
		# Drive physics under -s
		var dt := 1.0 / 60.0
		for a in combat.call("get_allies"):
			if a and not a.is_dead:
				a._physics_process(dt)
		for e in combat.call("get_enemies"):
			if e and not e.is_dead:
				e._physics_process(dt)
		if combat.has_method("_check_end_conditions"):
			combat._check_end_conditions()

		var st: String = watched.get_anim_state_name() if watched else ""
		if st in ["ATTACK_START", "ATTACK_WINDUP"]:
			if not saw_windup:
				saw_windup = true
				await _capture("attack_during_windup")
				print("captured windup state=", st, " anim=", watched._sprite.animation, " frame=", watched._sprite.frame)
		if st in ["ATTACK_ACTIVE", "APPLY_DAMAGE", "ATTACK_RECOVERY"]:
			if not saw_active:
				saw_active = true
				await _capture("attack_during_active")
				print("captured active state=", st, " anim=", watched._sprite.animation, " frame=", watched._sprite.frame)

		var enemy_hp_now := 0.0
		for e2 in combat.call("get_enemies"):
			if e2:
				enemy_hp_now += e2.hp
		if enemy_hp_now < last_enemy_hp - 0.5:
			damage_events += 1
			last_enemy_hp = enemy_hp_now
			print("damage_event#", damage_events, " at frame ", frame, " state=", st)

		if saw_active and st == "IDLE":
			saw_idle_after = true
			await _capture("attack_after")
			print("returned to idle after attack")
			break

		if str(combat.call("get_phase_name")) != "fighting":
			break

	if not saw_windup:
		printerr("FAIL never saw ATTACK_WINDUP")
		ok = false
	if not saw_active:
		printerr("FAIL never saw ATTACK_ACTIVE/RECOVERY")
		ok = false
	if not saw_idle_after:
		printerr("FAIL did not return to IDLE after attack")
		ok = false
	if damage_events < 1:
		printerr("FAIL no damage applied during attack")
		ok = false

	# Per-job forced attack showcase (screenshot each job mid-swing).
	for job in jobs:
		var actor: CombatCharacter = null
		for a in combat.call("get_allies"):
			if a and a.job == job and not a.is_dead:
				actor = a
				break
		if actor == null:
			continue
		var foe: CombatCharacter = null
		for e in combat.call("get_enemies"):
			if e and not e.is_dead:
				foe = e
				break
		if foe == null:
			break
		# Place in range and force attack
		actor.global_position = foe.global_position + Vector2(-60, 0)
		actor._atk_timer = 0.0
		actor._perform_attack(foe)
		# Advance frames until active
		for _i in range(90):
			await process_frame
			actor._physics_process(1.0 / 60.0)
			var st2: String = actor.get_anim_state_name()
			if st2 in ["ATTACK_ACTIVE", "APPLY_DAMAGE", "ATTACK_RECOVERY"]:
				await _capture("job_%s_attack" % job)
				print("OK job showcase ", job, " state=", st2, " frame=", actor._sprite.frame)
				break

	print("=== ATTACK ANIM RESULT: %s ===" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _capture(name: String) -> void:
	await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	if img:
		img.save_png("%s/%s.png" % [OUT, name])
		print("saved ", name)
