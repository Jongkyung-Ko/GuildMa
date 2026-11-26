extends SceneTree

## Capture victory direction pad + Korean map labels.
## xvfb-run -a /tmp/godot --path . -s res://scripts/core/capture_direction_pad.gd

const OUT := "/cursor/stores/bc-e37588d2-6890-4fb7-945a-c6a1997eb0b9/media/combat-ai-travel"
const ART := "/opt/cursor/artifacts/combat-ai-travel"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	DirAccess.make_dir_recursive_absolute(ART)
	await process_frame
	var gs: Node = root.get_node("/root/GameState")
	gs.new_game()
	gs.start_hunt_run("beginner_forest", true)

	root.set_meta("hunt_id", "beginner_forest")
	root.set_meta("hunt_force_new", false)
	root.set_meta("dungeon_id", "")
	root.set_meta("dungeon_floor", 0)
	root.set_meta("combat_hunt_id", "beginner_forest")

	var combat: Node = load("res://scenes/combat/combat.tscn").instantiate()
	root.add_child(combat)
	await process_frame
	await process_frame
	await process_frame
	await _capture("01_fighting_no_pad")

	# Let AI swing a bit for attack evidence.
	var t := 0.0
	while t < 4.0 and str(combat.get_phase_name()) == "fighting":
		await process_frame
		t += 1.0 / 60.0
	await _capture("02_mid_fight_attacks")

	var ui = combat.get("_ui")
	gs.mark_hunt_room_cleared()
	combat.phase = 2
	# Clear living enemies visually for victory look.
	for e in combat.get_enemies():
		if e and is_instance_valid(e):
			e.hp = 0
			e.is_dead = true
			e.visible = false
	if ui and ui.has_method("refresh"):
		ui.refresh()
	await process_frame
	await process_frame
	await _capture("03_victory_direction_pad")

	if ui and ui.has_method("_open_hunt_modal"):
		ui.call("_open_hunt_modal")
		await process_frame
		await process_frame
		await _capture("04_map_modal_korean")
		var modal = ui.get("_modal")
		if modal and is_instance_valid(modal):
			modal.queue_free()
			ui.set("_modal", null)

	# Travel one connected direction via pad API.
	var room: Dictionary = gs.get_current_hunt_room()
	var cons: Dictionary = room.get("connected_rooms", {})
	for d in ["N", "E", "S", "W"]:
		var o = cons.get(d, null)
		if o != null and str(o) != "":
			combat.travel_hunt_direction(str(d))
			break
	await process_frame
	await process_frame
	await process_frame
	await _capture("05_after_direction_travel")

	var win := root.get_window()
	if win:
		win.size = Vector2i(720, 1280)
		await process_frame
		await process_frame
		if ui and ui.has_method("refresh"):
			ui.refresh()
		await _capture("06_mobile_victory_pad")
		win.size = Vector2i(1280, 720)

	print("=== DIRECTION PAD CAPTURE DONE === ", OUT)
	quit(0)


func _capture(name: String) -> void:
	await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	var p1 := "%s/%s.png" % [OUT, name]
	var p2 := "%s/%s.png" % [ART, name]
	img.save_png(p1)
	img.save_png(p2)
	print("saved ", p1)
