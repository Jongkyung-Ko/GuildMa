extends SceneTree

## Capture hunting minimap + expanded map for evidence.
## Autoload globals are NOT injected into -s scripts; use /root/GameState.
## xvfb-run -a godot --path . -s res://scripts/core/capture_hunt_minimap.gd

const OUT := "/cursor/stores/bc-e37588d2-6890-4fb7-945a-c6a1997eb0b9/media/hunt-minimap"
const ART := "/opt/cursor/artifacts/hunt-minimap"


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
	await _capture("combat_minimap_fighting")

	var ui = combat.get("_ui")
	if ui and ui.has_method("_open_hunt_modal"):
		ui.call("_open_hunt_modal")
		await process_frame
		await process_frame
		await _capture("map_modal_during_combat")
		var modal = ui.get("_modal")
		if modal and is_instance_valid(modal):
			modal.queue_free()
			ui.set("_modal", null)

	# Enum Phase { FIGHTING=0, PAUSED=1, VICTORY=2, DEFEAT=3 }
	combat.phase = 2
	gs.mark_hunt_room_cleared()
	if ui and ui.has_method("refresh"):
		ui.refresh()
	await process_frame
	await _capture("combat_minimap_cleared")

	if ui and ui.has_method("_open_hunt_modal"):
		ui.call("_open_hunt_modal")
		await process_frame
		await process_frame
		await _capture("map_modal_after_clear")

	var win := root.get_window()
	if win:
		win.size = Vector2i(720, 1280)
		await process_frame
		await process_frame
		await _capture("map_modal_mobile_portrait")
		win.size = Vector2i(1280, 720)

	print("=== HUNT MINIMAP CAPTURE DONE === ", OUT)
	quit(0)


func _capture(name: String) -> void:
	await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	var p1 := "%s/%s.png" % [OUT, name]
	var p2 := "%s/%s.png" % [ART, name]
	img.save_png(p1)
	img.save_png(p2)
	print("saved ", p1)
