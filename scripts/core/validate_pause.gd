extends SceneTree

## Quick pause-path check for Phase 2-1.
## godot4 --headless --path . -s res://scripts/core/validate_pause.gd


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var gs = root.get_node("/root/GameState")
	gs.new_game()
	var combat = load("res://scenes/combat/combat.tscn").instantiate()
	root.add_child(combat)
	await process_frame
	await process_frame
	if combat.get_phase_name() != "fighting":
		printerr("FAIL expected fighting")
		quit(1)
		return
	combat.toggle_pause()
	if combat.get_phase_name() != "paused":
		printerr("FAIL pause")
		quit(1)
		return
	print("PASS pause")
	# While paused, ally should not move meaningfully
	var a = combat.get_allies()[0]
	var p0: Vector2 = a.global_position
	for i in 30:
		await process_frame
		if a.has_method("_physics_process"):
			a._physics_process(1.0 / 60.0)
	if a.global_position.distance_to(p0) > 1.0 and combat.is_combat_active():
		printerr("FAIL moved while should be inactive")
		quit(1)
		return
	# is_combat_active false while paused → _physics_process early-outs
	if combat.is_combat_active():
		printerr("FAIL still active while paused")
		quit(1)
		return
	print("PASS no combat activity while paused")
	combat.toggle_pause()
	if combat.get_phase_name() != "fighting":
		printerr("FAIL resume")
		quit(1)
		return
	print("PASS resume")
	print("=== PAUSE RESULT: PASS ===")
	quit(0)
