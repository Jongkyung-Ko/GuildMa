extends SceneTree

## Capture single ornate namecard prototype at 844 / 1280 (+ solo zoom).
## DISPLAY=:1 godot4 --path . --display-driver x11 -s res://scripts/core/capture_namecard_single_prototype.gd

const SIZES := [
	{"tag": "844x390", "size": Vector2i(844, 390)},
	{"tag": "1280x720", "size": Vector2i(1280, 720)},
]

var _out_dir: String = "res://docs/reviews/guild-party-ui/evidence/namecard-single"
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
		for _j in 12:
			await process_frame

		# Focus prototype member (m_lord / 아렌).
		var panel = hall.get("_formation")
		if panel:
			panel.set("_focus_id", "m_lord")
			panel.call("_refresh_lists_only")
			for _k in 8:
				await process_frame

		await _capture("namecard_single_main_%s" % tag)

		# Solo zoom: crop ornate prototype card from framebuffer.
		if panel:
			var proto := _find_named(panel, "OrnatePrototypeCard")
			if proto and proto is Control:
				var pc := proto as Control
				# Ensure laid-out size matches the vertical card budget before crop.
				if pc.size.y < pc.custom_minimum_size.y * 0.9:
					pc.size = pc.custom_minimum_size
				for _w in 4:
					await process_frame
				print("LOG: solo rect ", tag, " global=", pc.get_global_rect(), " size=", pc.size, " min=", pc.custom_minimum_size)
				await _capture_control_crop(pc, "namecard_single_solo_%s" % tag)
			else:
				_fail("prototype card missing %s" % tag)

	print("=== capture_namecard_single_prototype done fails=%d ===" % _failed)
	quit(0 if _failed == 0 else 1)


func _find_hall(n: Node) -> Node:
	if n.has_method("_open_formation") and n.has_method("_fit_formation"):
		return n
	for c in n.get_children():
		var f := _find_hall(c)
		if f:
			return f
	return null


func _find_named(n: Node, want: String) -> Node:
	if n.name == want:
		return n
	for c in n.get_children():
		var f := _find_named(c, want)
		if f:
			return f
	return null


func _capture(name: String) -> void:
	await process_frame
	var img: Image = root.get_texture().get_image()
	if img == null or img.get_width() < 2:
		_fail("null image %s" % name)
		return
	_save(img, name)


func _capture_control_crop(ctrl: Control, name: String) -> void:
	var full: Image = root.get_texture().get_image()
	if full == null or full.get_width() < 2:
		_fail("null image crop %s" % name)
		return
	# Map control corners through canvas → screen (handles stretch/expand).
	var vp := root.get_viewport()
	var st: Transform2D = vp.get_screen_transform()
	var gt: Transform2D = ctrl.get_global_transform_with_canvas()
	var pad := Vector2(10, 10)
	var tl: Vector2 = st * (gt * -pad)
	var br: Vector2 = st * (gt * (ctrl.size + pad))
	var x0 := maxi(0, int(floor(minf(tl.x, br.x))))
	var y0 := maxi(0, int(floor(minf(tl.y, br.y))))
	var x1 := mini(full.get_width(), int(ceil(maxf(tl.x, br.x))))
	var y1 := mini(full.get_height(), int(ceil(maxf(tl.y, br.y))))
	var w := x1 - x0
	var h := y1 - y0
	print("LOG: crop_px ", name, " tl=", tl, " br=", br, " rect=", Rect2i(x0, y0, w, h), " img=", full.get_width(), "x", full.get_height())
	if w < 8 or h < 8:
		_fail("bad crop rect %s" % name)
		return
	var crop := full.get_region(Rect2i(x0, y0, w, h))
	_save(crop, name)


func _save(img: Image, name: String) -> void:
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
