extends SceneTree

## Capture party formation UI at 844 / 1280 / 1366.
## DISPLAY=:1 godot4 --path . --display-driver x11 -s res://scripts/core/capture_party_formation.gd

const SIZES := [
	{"tag": "844x390", "size": Vector2i(844, 390)},
	{"tag": "1280x720", "size": Vector2i(1280, 720)},
	{"tag": "1366x768", "size": Vector2i(1366, 768)},
]

var _out_dir: String = "res://docs/reviews/guild-party-ui/evidence"
var _store_dir: String = ""
var _failed := 0


func _init() -> void:
	call_deferred("_run")


func _fail(msg: String) -> void:
	printerr("FAIL: ", msg)
	_failed += 1


func _run() -> void:
	var env_out := OS.get_environment("OUT_DIR")
	if env_out != "":
		_out_dir = env_out
	_store_dir = OS.get_environment("STORE_DIR")
	DirAccess.make_dir_recursive_absolute(_resolve(_out_dir))
	if _store_dir != "":
		DirAccess.make_dir_recursive_absolute(_store_dir)

	var gs: Node = root.get_node("/root/GameState")
	gs.call("new_game")

	var win := root.get_window()
	for spec in SIZES:
		var tag: String = spec["tag"]
		win.size = spec["size"]
		await process_frame
		await process_frame

		var err := change_scene_to_file("res://scenes/facilities/guild_hall.tscn")
		if err != OK:
			_fail("guild hall scene")
			continue
		for _i in 8:
			await process_frame
		var hall := _find_hall(root)
		if hall == null:
			_fail("hall missing %s" % tag)
			continue
		hall.call("_open_formation", "hunt")
		for _j in 10:
			await process_frame
		await _capture("party_formation_main_%s" % tag)

		# Focus second member + skill demo if possible.
		var panel = hall.get("_formation")
		if panel:
			var members: Array = gs.get("members")
			if members.size() > 1:
				panel.set("_focus_id", str(members[1].get("id", "")))
				var skills: Array = members[1].get("skills", [])
				if skills.size() > 0:
					panel.set("_selected_skill", str(skills[0]))
				panel.call("_refresh_lists_only")
				for _k in 6:
					await process_frame
				await _capture("party_formation_detail_%s" % tag)
			# Job filter dps.
			panel.set("_filter_job", "dps")
			panel.call("_refresh_lists_only")
			for _k2 in 4:
				await process_frame
			await _capture("party_formation_filter_dps_%s" % tag)

	print("=== capture_party_formation done fails=%d ===" % _failed)
	quit(0 if _failed == 0 else 1)


func _find_hall(n: Node) -> Node:
	if n.has_method("_open_formation") and n.has_method("_fit_formation"):
		return n
	for c in n.get_children():
		var f := _find_hall(c)
		if f:
			return f
	return null


func _capture(name: String) -> void:
	await process_frame
	var img: Image = root.get_texture().get_image()
	if img == null or img.get_width() < 2:
		_fail("null image %s" % name)
		return
	var path := _resolve(_out_dir).path_join("%s.png" % name)
	var err := img.save_png(path)
	if err != OK:
		_fail("save %s" % path)
		return
	print("WROTE ", path)
	if _store_dir != "":
		img.save_png(_store_dir.path_join("%s.png" % name))
		print("WROTE ", _store_dir.path_join("%s.png" % name))


func _resolve(p: String) -> String:
	if p.begins_with("res://"):
		return ProjectSettings.globalize_path(p)
	return p
