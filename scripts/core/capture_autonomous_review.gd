extends SceneTree

## Autonomous-review cycle captures for independent visual QA (landscape only).
## Env:
##   REVIEW_PHASE=before|after   (default before) → artifacts subfolder
##   STORE_DIR=/path/to/media/autonomous-review/<phase>  (optional second write)
##
## DISPLAY=:1 godot4 --path . --display-driver x11 -s res://scripts/core/capture_autonomous_review.gd

const ART_ROOT := "/opt/cursor/artifacts/autonomous-review"

const SIZES := [
	["mobile_landscape_844x390", Vector2i(844, 390)],
	["pc_1366x768", Vector2i(1366, 768)],
]


func _init() -> void:
	call_deferred("_run")


func _phase() -> String:
	var p := OS.get_environment("REVIEW_PHASE").strip_edges().to_lower()
	if p != "before" and p != "after":
		p = "before"
	return p


func _art_dir() -> String:
	return "%s/%s" % [ART_ROOT, _phase()]


func _store_dir() -> String:
	return OS.get_environment("STORE_DIR").strip_edges()


func _run() -> void:
	var art := _art_dir()
	DirAccess.make_dir_recursive_absolute(art)
	var store := _store_dir()
	if store != "":
		DirAccess.make_dir_recursive_absolute(store)
	print("LOG: autonomous review phase=", _phase(), " art=", art, " store=", store)
	await process_frame
	var gs: Node = root.get_node("/root/GameState")
	var am: Node = root.get_node_or_null("/root/AudioManager")
	if am and am.has_method("unlock_audio"):
		am.call("unlock_audio")

	var win := root.get_window()
	var hall: Node = null
	for entry in SIZES:
		var tag: String = entry[0]
		var sz: Vector2i = entry[1]

		gs.call("new_game")
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

		gs.call("select_guild_member", "m_tank")
		if hall.has_method("_apply_responsive_layout"):
			hall.call("_apply_responsive_layout")
		if hall.has_method("_refresh_all"):
			hall.call("_refresh_all")
		await process_frame
		await process_frame
		await process_frame
		await _capture(art, store, "%s_main" % tag)

		gs.call("select_guild_member", "m_lord")
		if hall.has_method("_refresh_all"):
			hall.call("_refresh_all")
		await process_frame
		await process_frame
		await process_frame
		await _capture(art, store, "%s_lord_selected" % tag)

		gs.call("select_guild_member", "m_dps")
		if hall.has_method("_refresh_all"):
			hall.call("_refresh_all")
		await process_frame
		await process_frame
		await process_frame
		await _capture(art, store, "%s_member_selected" % tag)

		if hall.has_method("_open_assign"):
			hall.call("_open_assign", "hunt")
			await process_frame
			await process_frame
			await _capture(art, store, "%s_assign_hunt" % tag)
			if hall.has_method("_close_overlay"):
				hall.call("_close_overlay")
		print("LOG: autonomous capture ", tag, " win=", win.size if win else Vector2i.ZERO)

	print("=== AUTONOMOUS REVIEW CAPTURE DONE phase=", _phase(), " ===")
	print("NOTE: Visual PASS/FAIL is owned by independent QA — not this script.")
	quit(0)


func _capture(art: String, store: String, name: String) -> void:
	await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	if img == null:
		print("WARN: null image ", name)
		return
	var path := "%s/%s.png" % [art, name]
	img.save_png(path)
	print("saved ", path, " ", img.get_width(), "x", img.get_height())
	if store != "":
		var sp := "%s/%s.png" % [store, name]
		img.save_png(sp)
		print("saved ", sp)
