extends SceneTree

## Capture Guild Hall UI evidence (bypasses title input).
## godot --path . -s res://scripts/core/capture_guild_hall.gd

const ART := "/opt/cursor/artifacts/guild-hall"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ART)
	await process_frame
	var gs: Node = root.get_node("/root/GameState")
	var am: Node = root.get_node_or_null("/root/AudioManager")
	if am and am.has_method("unlock_audio"):
		am.call("unlock_audio")
	gs.call("new_game")

	var hall: Node = load("res://scenes/facilities/guild_hall.tscn").instantiate()
	root.add_child(hall)
	await process_frame
	await process_frame
	await process_frame
	await _capture("01_guild_hall_main")

	# Select another member (dps) via GameState — detail panel refresh.
	gs.call("select_guild_member", "m_dps")
	await process_frame
	await process_frame
	await _capture("02_guild_hall_member_selected")

	# Open hunt assign overlay
	if hall.has_method("_open_assign"):
		hall.call("_open_assign", "hunt")
		await process_frame
		await process_frame
		await _capture("03_guild_hall_hunt_assign")
		if hall.has_method("_close_overlay"):
			hall.call("_close_overlay")
		await process_frame

	# Detail stats overlay
	if hall.has_method("_open_detail_stats"):
		hall.call("_open_detail_stats")
		await process_frame
		await process_frame
		await _capture("04_guild_hall_detail_stats")

	print("=== GUILD HALL CAPTURE DONE === ", ART)
	quit(0)


func _capture(name: String) -> void:
	await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	if img == null:
		print("WARN: null viewport image for ", name)
		return
	var path := "%s/%s.png" % [ART, name]
	img.save_png(path)
	print("saved ", path)
