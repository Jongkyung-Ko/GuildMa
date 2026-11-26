extends SceneTree

## Multi-resolution Guild Hall layout captures for PR16.
## godot --path . -s res://scripts/core/capture_guild_hall_responsive.gd

const ART := "/opt/cursor/artifacts/guild-hall-responsive"

const SIZES := [
	["mobile_portrait_390x844", Vector2i(390, 844)],
	["mobile_portrait_430x932", Vector2i(430, 932)],
	["mobile_landscape_844x390", Vector2i(844, 390)],
	["pc_1366x768", Vector2i(1366, 768)],
]


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

	var win := root.get_window()
	var hall: Node = null
	for entry in SIZES:
		var tag: String = entry[0]
		var sz: Vector2i = entry[1]
		if win:
			win.size = sz
		# Force UIStyle adapt after resize.
		var ui: Node = root.get_node_or_null("/root/UIStyle")
		if ui and ui.has_method("_apply_display_adapt"):
			ui.call("_apply_display_adapt")
		await process_frame
		await process_frame

		if hall and is_instance_valid(hall):
			hall.queue_free()
			await process_frame
		hall = load("res://scenes/facilities/guild_hall.tscn").instantiate()
		root.add_child(hall)
		await process_frame
		await process_frame
		await process_frame
		if hall.has_method("_apply_responsive_layout"):
			hall.call("_apply_responsive_layout")
			hall.call("_refresh_all")
		await process_frame
		await process_frame
		await _capture("%s_main" % tag)

		# Select flank member + open assign to prove controls reachable.
		gs.call("select_guild_member", "m_dps")
		await process_frame
		await process_frame
		await _capture("%s_selected" % tag)

		if hall.has_method("_open_assign"):
			hall.call("_open_assign", "hunt")
			await process_frame
			await process_frame
			await _capture("%s_assign" % tag)
			if hall.has_method("_close_overlay"):
				hall.call("_close_overlay")
		print("LOG: captured ", tag, " win=", win.size if win else Vector2i.ZERO, " hall_size=", hall.size)

	print("=== GUILD HALL RESPONSIVE CAPTURE DONE ===")
	quit(0)


func _capture(name: String) -> void:
	await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	if img == null:
		print("WARN: null image ", name)
		return
	var path := "%s/%s.png" % [ART, name]
	img.save_png(path)
	print("saved ", path, " ", img.get_width(), "x", img.get_height())
