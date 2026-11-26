extends SceneTree

## Force each job attack and capture before / active / after (+ zoom crop).
## xvfb-run -a godot --path . -s res://scripts/core/capture_attack_phases.gd

const OUT := "/opt/cursor/artifacts/guildma-attack-fix"


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

	var enemies: Array = combat.call("get_enemies")
	for e in enemies:
		e.hp_max = 5000.0
		e.hp = 5000.0
		e.atk = 0.0
		e.set_physics_process(false)
		# Park extras off-field
		if str(e.enemy_kind) != "wolf":
			e.visible = false
			e.global_position = Vector2(-500, -500)

	for a in combat.call("get_allies"):
		a.set_physics_process(false)
		a._atk_timer = 999.0
		a.visible = false

	var jobs: Array[String] = ["tank", "dps", "mage", "healer", "lord"]
	for job in jobs:
		var actor: CombatCharacter = null
		for a in combat.call("get_allies"):
			if a and str(a.job) == job and not a.is_dead:
				actor = a
				break
		if actor == null:
			continue
		var foe: CombatCharacter = null
		for e in enemies:
			if e and not e.is_dead and e.visible:
				foe = e
				break
		if foe == null:
			for e in enemies:
				if e and not e.is_dead:
					e.visible = true
					e.global_position = Vector2(760, 380)
					foe = e
					break
		if foe == null:
			break

		# Hide all allies except actor
		for a in combat.call("get_allies"):
			a.visible = (a == actor)
			if a != actor:
				a.global_position = Vector2(-400, -400)

		foe.global_position = Vector2(760, 380)
		foe.visible = true
		actor.global_position = Vector2(640, 380)
		actor.visible = true
		actor._face_right = true
		if actor._sprite:
			actor._sprite.flip_h = false
		actor._atk_timer = 999.0
		actor._pending_target = null
		actor._pending_damage = 0.0
		actor._damage_applied = false
		actor._set_anim_state(0)
		actor._play_anim("idle", true)
		await process_frame
		await process_frame
		await _capture_full_and_zoom("%s_before" % job, actor)

		actor._perform_attack(foe)
		var got_during := false
		for _i in range(180):
			await process_frame
			if actor._sprite == null:
				break
			var anim: String = str(actor._sprite.animation)
			var fr: int = int(actor._sprite.frame)
			if not got_during and anim == "attack" and fr >= int(actor._attack_active_idx):
				got_during = true
				await _capture_full_and_zoom("%s_during" % job, actor)
				print(job, " DURING anim=", anim, " frame=", fr, " state=", actor.get_anim_state_name())
			if got_during and anim != "attack" and actor.get_anim_state_name() == "IDLE":
				break

		for _j in range(60):
			await process_frame
			if actor.get_anim_state_name() == "IDLE" and str(actor._sprite.animation) == "idle":
				break
		if actor.get_anim_state_name() != "IDLE":
			actor._set_anim_state(0)
			actor._play_anim("idle", true)
			await process_frame
		await _capture_full_and_zoom("%s_after" % job, actor)
		print(job, " AFTER got_during=", got_during)

	print("=== capture_attack_phases done ===")
	quit(0)


func _capture_full_and_zoom(name: String, actor: CombatCharacter) -> void:
	await process_frame
	await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	if img == null:
		return
	img.save_png("%s/%s.png" % [OUT, name])
	# Zoom crop around actor (approx screen coords: actor pos maps 1:1 in 1280x720)
	var cx: int = int(actor.global_position.x)
	var cy: int = int(actor.global_position.y - 40.0)
	var half := 120
	var x0: int = clampi(cx - half, 0, img.get_width() - 1)
	var y0: int = clampi(cy - half, 0, img.get_height() - 1)
	var x1: int = clampi(cx + half, 0, img.get_width())
	var y1: int = clampi(cy + half, 0, img.get_height())
	var w: int = maxi(1, x1 - x0)
	var h: int = maxi(1, y1 - y0)
	var crop: Image = img.get_region(Rect2i(x0, y0, w, h))
	crop.resize(w * 3, h * 3, Image.INTERPOLATE_NEAREST)
	crop.save_png("%s/%s_zoom.png" % [OUT, name])
	print("saved ", name, " + zoom")
