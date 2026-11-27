extends SceneTree

## Full-screen guild hall captures for independent QA (landscape only).
## Targets: 844×390 mobile landscape + 1366×768 PC.
## godot --path . --display-driver x11 -s res://scripts/core/capture_guild_hall_audit.gd

const ART := "/opt/cursor/artifacts/guild-hall-audit"

const SIZES := [
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

		gs.call("select_guild_member", "m_lord")
		if hall.has_method("_refresh_all"):
			hall.call("_refresh_all")
		await process_frame
		await process_frame
		await _capture("%s_lord_selected" % tag)

		gs.call("select_guild_member", "m_dps")
		if hall.has_method("_refresh_all"):
			hall.call("_refresh_all")
		await process_frame
		await process_frame
		await _capture("%s_member_selected" % tag)

		if hall.has_method("_open_assign"):
			hall.call("_open_assign", "hunt")
			await process_frame
			await process_frame
			await _capture("%s_assign_hunt" % tag)
			if hall.has_method("_close_overlay"):
				hall.call("_close_overlay")
		print("LOG: audit capture ", tag, " win=", win.size if win else Vector2i.ZERO)

	print("=== GUILD HALL AUDIT CAPTURE DONE ===")
	print("NOTE: Visual PASS/FAIL is owned by independent QA — not this script.")
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
