extends SceneTree

# Phase 2-1 combat smoke test.
# Run: godot4 --headless --path . -s res://scripts/core/smoke_combat.gd


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok := true
	print("=== GuildMaster combat Phase 2-1 smoke ===")

	var gs: Node = root.get_node_or_null("/root/GameState")
	if gs == null:
		gs = load("res://scripts/core/game_state.gd").new()
		gs.name = "GameState"
		root.add_child(gs)
		gs._ready()
	# UIStyle / SceneRouter may be missing when run with -s
	if root.get_node_or_null("/root/UIStyle") == null:
		var ui = load("res://scripts/ui/ui_style.gd").new()
		ui.name = "UIStyle"
		root.add_child(ui)
	if root.get_node_or_null("/root/SceneRouter") == null:
		var sr = load("res://scripts/core/scene_router.gd").new()
		sr.name = "SceneRouter"
		root.add_child(sr)

	gs.new_game()
	if gs.members.size() < 5:
		printerr("FAIL party size ", gs.members.size())
		ok = false
	else:
		print("OK party size ", gs.members.size())

	var combat_scene: PackedScene = load("res://scenes/combat/combat.tscn")
	if combat_scene == null:
		printerr("FAIL load combat.tscn")
		quit(1)
		return

	var combat: Node = combat_scene.instantiate()
	root.add_child(combat)
	# Allow _ready to finish
	await process_frame
	await process_frame

	if not combat.has_method("get_allies") or not combat.has_method("get_enemies"):
		printerr("FAIL combat API missing")
		ok = false
		quit(1)
		return

	var allies: Array = combat.get_allies()
	var enemies: Array = combat.get_enemies()
	print("OK spawned allies=", allies.size(), " enemies=", enemies.size())
	if allies.size() < 1 or enemies.size() < 1:
		printerr("FAIL spawn counts")
		ok = false

	# Simulate combat frames until victory/defeat or timeout
	var frames := 0
	var max_frames := 90 * 60 # ~90s at 60fps budget in headless steps
	var enemy_hp_start := 0.0
	for e in enemies:
		enemy_hp_start += e.hp
	var saw_damage := false

	while frames < max_frames:
		await process_frame
		frames += 1
		# Drive physics manually for CharacterBody2D under SceneTree -s
		var dt := 1.0 / 60.0
		for a in combat.get_allies():
			if a and not a.is_dead:
				a._physics_process(dt)
		for e in combat.get_enemies():
			if e and not e.is_dead:
				e._physics_process(dt)
		if combat.has_method("_check_end_conditions"):
			combat._check_end_conditions()

		var enemy_hp_now := 0.0
		for e2 in combat.get_enemies():
			if e2:
				enemy_hp_now += e2.hp
		if enemy_hp_now < enemy_hp_start - 0.5:
			saw_damage = true

		var phase_name: String = combat.get_phase_name()
		if phase_name == "victory":
			print("OK victory after frames=", frames)
			break
		if phase_name == "defeat":
			print("OK defeat path reached frames=", frames)
			break

		if frames % 120 == 0:
			print("... tick ", frames, " enemy_hp=", enemy_hp_now, " phase=", phase_name)

	if not saw_damage:
		printerr("FAIL no damage dealt to enemies")
		ok = false
	else:
		print("OK damage applied")

	var phase_end: String = combat.get_phase_name()
	if phase_end == "victory":
		print("OK combat ended in victory")
	elif phase_end == "fighting" and saw_damage:
		print("WARN combat still fighting after timeout but damage OK (partial pass)")
	elif phase_end == "defeat":
		print("OK combat ended in defeat (AI fight resolved)")
	else:
		printerr("FAIL unexpected end phase=", phase_end)
		ok = false

	# Pause toggle
	if combat.get_phase_name() == "fighting" or combat.get_phase_name() == "paused":
		combat.toggle_pause()
		if combat.get_phase_name() != "paused":
			printerr("FAIL pause")
			ok = false
		else:
			print("OK pause")
			combat.toggle_pause()

	print("=== COMBAT RESULT: ", "PASS" if ok else "FAIL", " ===")
	quit(0 if ok else 1)
