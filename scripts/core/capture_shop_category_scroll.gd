extends SceneTree

## Proof captures for left category panel scroll (short landscape + desktop).
## DISPLAY=:1 godot4 --path . --display-driver x11 -s res://scripts/core/capture_shop_category_scroll.gd

const OUT := "res://docs/reviews/shop_blacksmith_visual_qa/evidence"
const SIZES := [
	{"tag": "844x390", "size": Vector2i(844, 390)},
	{"tag": "1366x768", "size": Vector2i(1366, 768)},
]

var _failed := 0


func _init() -> void:
	call_deferred("_run")


func _fail(msg: String) -> void:
	printerr("FAIL: ", msg)
	_failed += 1


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var gs: Node = root.get_node("/root/GameState")
	gs.new_game()
	gs.gold = 50000

	# Root window == SceneTree root in -s mode. Kill project stretch so short
	# mobile-landscape sizes become real content sizes (else expand keeps ~720px).
	var win: Window = root as Window
	if win == null:
		win = root.get_window()
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	win.content_scale_factor = 1.0
	for spec in SIZES:
		var tag: String = spec["tag"]
		var sz: Vector2i = spec["size"]
		DisplayServer.window_set_size(sz)
		win.size = sz
		await process_frame
		await process_frame

		root.set_meta("facility_id", "shop")
		var err := change_scene_to_file("res://scenes/facilities/facility.tscn")
		if err != OK:
			_fail("scene shop")
			continue
		DisplayServer.window_set_size(sz)
		win.size = sz
		win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		win.content_scale_factor = 1.0
		# Force viewport buffer to the target short landscape / desktop size.
		if root is Viewport:
			(root as Viewport).size = sz
		await process_frame
		await process_frame
		await process_frame
		await process_frame
		var shop_early := _find_shop(root)
		if shop_early:
			shop_early._on_resized()
			await process_frame
			await process_frame
		print("WINDOW %s display=%s win=%s vp=%s root_vp=%s" % [
			tag, DisplayServer.window_get_size(), win.size,
			root.get_viewport().get_visible_rect().size,
			(root as Viewport).size if root is Viewport else Vector2i.ZERO
		])

		var shop := _find_shop(root)
		if shop == null:
			_fail("shop panel %s" % tag)
			continue

		# Top of category list.
		if shop._cat_scroll:
			shop._cat_scroll.scroll_vertical = 0
		await process_frame
		await process_frame
		await _capture("shop_category_scroll_%s" % tag)

		# Scroll to bottom — last category + pinned buy/sell must be reachable/visible.
		if shop._cat_scroll:
			shop._cat_scroll.scroll_vertical = 99999
		await process_frame
		await process_frame
		await _capture("shop_category_scroll_bottom_%s" % tag)

		# Report scroll metrics.
		if shop._cat_scroll and shop._left_panel:
			var host_sz: Vector2 = shop._left_host.size if shop._left_host else Vector2.ZERO
			var shop_sz: Vector2 = shop.size
			var left_sz: Vector2 = shop._left_panel.size
			var cat_sz: Vector2 = shop._cat_scroll.size
			var scroll_max: int = int(shop._cat_scroll.get_v_scroll_bar().max_value) if shop._cat_scroll.get_v_scroll_bar() else -1
			print("METRICS %s shop=%s host=%s left=%s cat_scroll=%s scroll_max=%d compact=%s" % [
				tag, shop_sz, host_sz, left_sz, cat_sz, scroll_max, shop._compact
			])

	print("=== capture_shop_category_scroll done fails=%d ===" % _failed)
	quit(0 if _failed == 0 else 1)


func _find_shop(n: Node) -> Node:
	if n is Control and n.has_method("_refresh"):
		var props: Dictionary = {}
		for p in n.get_property_list():
			props[str(p.get("name", ""))] = true
		if props.has("mode") and props.has("category"):
			return n
	for c in n.get_children():
		var f := _find_shop(c)
		if f:
			return f
	return null


func _capture(name: String) -> void:
	await process_frame
	var img: Image = root.get_texture().get_image()
	if img == null or img.get_width() < 2:
		_fail("null %s" % name)
		return
	var path := ProjectSettings.globalize_path(OUT).path_join("%s.png" % name)
	var err := img.save_png(path)
	if err != OK:
		_fail("save %s" % path)
		return
	print("WROTE ", path, " ", img.get_width(), "x", img.get_height())
