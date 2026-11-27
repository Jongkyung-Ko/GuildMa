extends SceneTree

## ASSERTS for shop left category scroll (verification only — no UI rewrites).
## DISPLAY=:1 godot4 --path . --display-driver x11 -s res://scripts/core/validate_shop_category_scroll.gd
##
## Checks at 844×390 and 1366×768:
## 1. Last category button visible on screen (at max scroll)
## 2. At max category scroll, Buy/Sell still visible
## 3. Same on both sizes
## 4. Scroll position reaches max
## 5. Last category actually clickable
## 6. Buy/Sell mode switch works
## Also: filter changes after category select.

const OUT := "res://docs/reviews/shop_blacksmith_visual_qa/evidence"
const SIZES := [
	{"tag": "844x390", "size": Vector2i(844, 390)},
	{"tag": "1366x768", "size": Vector2i(1366, 768)},
]
const LAST_CAT := "material"

var _failed := 0
var _passed := 0
var _notes: PackedStringArray = []


func _init() -> void:
	call_deferred("_run")


func _fail(msg: String) -> void:
	printerr("FAIL: ", msg)
	_failed += 1


func _ok(msg: String) -> void:
	print("OK: ", msg)
	_passed += 1


func _note(msg: String) -> void:
	_notes.append(msg)
	print("NOTE: ", msg)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var gs: Node = root.get_node("/root/GameState")
	gs.new_game()
	gs.gold = 50000

	var win: Window = root as Window
	if win == null:
		win = root.get_window()
	# Real short landscape content sizes (project stretch would keep ~720px otherwise).
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	win.content_scale_factor = 1.0

	for spec in SIZES:
		var tag: String = spec["tag"]
		var sz: Vector2i = spec["size"]
		await _prepare_shop(win, sz)
		var shop: Node = _find_shop(root)
		if shop == null:
			_fail("%s: shop panel missing" % tag)
			continue
		shop._on_resized()
		await _settle()
		await _verify_size(tag, sz, shop)

	var report := ProjectSettings.globalize_path(OUT).path_join("category_scroll_verify_report.txt")
	var f := FileAccess.open(report, FileAccess.WRITE)
	if f:
		f.store_line("validate_shop_category_scroll")
		f.store_line("passed=%d failed=%d" % [_passed, _failed])
		for line in _notes:
			f.store_line(line)
		f.close()
		print("WROTE ", report)

	print("=== validate_shop_category_scroll RESULT: %s (ok=%d fail=%d) ===" % [
		"PASS" if _failed == 0 else "FAIL", _passed, _failed
	])
	quit(0 if _failed == 0 else 1)


func _prepare_shop(win: Window, sz: Vector2i) -> void:
	DisplayServer.window_set_size(sz)
	win.size = sz
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.content_scale_factor = 1.0
	await process_frame
	await process_frame
	root.set_meta("facility_id", "shop")
	var err := change_scene_to_file("res://scenes/facilities/facility.tscn")
	if err != OK:
		_fail("scene shop err=%s" % err)
		return
	DisplayServer.window_set_size(sz)
	win.size = sz
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	if root is Viewport:
		(root as Viewport).size = sz
	await _settle()
	await _settle()


func _verify_size(tag: String, sz: Vector2i, shop: Node) -> void:
	print("--- verify %s window=%s shop=%s compact=%s ---" % [tag, sz, shop.size, shop._compact])
	if shop._cat_scroll == null or shop._mode_buy == null or shop._mode_sell == null:
		_fail("%s: missing cat_scroll or mode buttons" % tag)
		return
	if not shop._cat_buttons.has(LAST_CAT):
		_fail("%s: last category '%s' missing" % [tag, LAST_CAT])
		return

	var cat_scroll: ScrollContainer = shop._cat_scroll
	var last_btn: Button = shop._cat_buttons[LAST_CAT]
	var buy: Button = shop._mode_buy
	var sell: Button = shop._mode_sell

	# --- 4. Scroll reaches max ---
	# Godot ScrollBar.max_value includes page; usable max scroll = max_value - page.
	cat_scroll.scroll_vertical = 0
	await _settle()
	var bar: ScrollBar = cat_scroll.get_v_scroll_bar()
	var usable_max := 0
	if bar:
		usable_max = maxi(0, int(bar.max_value - bar.page))
	cat_scroll.scroll_vertical = 999999
	await _settle()
	await _settle()
	# Re-read after layout; some frames recompute page.
	if bar:
		usable_max = maxi(0, int(bar.max_value - bar.page))
	var at_scroll: int = int(cat_scroll.scroll_vertical)
	if usable_max <= 0:
		# Tall layouts may fit all categories without scrolling — still OK if last is visible.
		_ok("%s: scroll max=0 (all categories fit without overflow)" % tag)
		_note("%s: no overflow scroll needed (bar.max=%s page=%s)" % [
			tag, bar.max_value if bar else -1, bar.page if bar else -1
		])
	else:
		# Allow 1px slack for integer rounding.
		if at_scroll >= usable_max - 1:
			_ok("%s: scroll reached max (%d/%d)" % [tag, at_scroll, usable_max])
		else:
			_fail("%s: scroll not at max (pos=%d usable_max=%d bar.max=%s page=%s)" % [
				tag, at_scroll, usable_max, bar.max_value if bar else -1, bar.page if bar else -1
			])

	await _capture("verify_cat_scroll_max_%s" % tag)

	# --- 1. Last category visible on screen (at max scroll) ---
	if _control_on_screen(last_btn, sz) and _control_in_scroll_view(last_btn, cat_scroll):
		_ok("%s: last category '%s' visible on screen at max scroll" % [tag, LAST_CAT])
	else:
		_fail("%s: last category '%s' NOT visible (global=%s scroll=%s win=%s)" % [
			tag, LAST_CAT, last_btn.get_global_rect(), cat_scroll.get_global_rect(), sz
		])

	# --- 2. Buy/Sell still visible at max category scroll ---
	# Must be on the window AND inside the left column clip host (compact clamps via _left_host).
	var clip_host: Control = shop._left_host if shop._left_host else shop._left_panel
	var buy_ok := _control_on_screen(buy, sz) and _control_in_clip_host(buy, clip_host)
	var sell_ok := _control_on_screen(sell, sz) and _control_in_clip_host(sell, clip_host)
	if buy_ok and sell_ok:
		_ok("%s: Buy/Sell visible at max category scroll" % tag)
	else:
		_fail("%s: Buy/Sell visibility buy=%s sell=%s (buy_rect=%s sell_rect=%s clip=%s)" % [
			tag, buy_ok, sell_ok, buy.get_global_rect(), sell.get_global_rect(),
			clip_host.get_global_rect() if clip_host else Rect2()
		])

	await _capture("verify_buy_sell_at_max_%s" % tag)

	# --- 5. Last category clickable ---
	var before_cat: String = str(shop.category)
	last_btn.pressed.emit()
	await _settle()
	if str(shop.category) == LAST_CAT:
		_ok("%s: last category clickable → category=%s" % [tag, LAST_CAT])
	else:
		_fail("%s: last category click did not stick (before=%s after=%s)" % [
			tag, before_cat, shop.category
		])

	# Filter changes after category select (also covers armor mid-list).
	await _assert_filter_change(tag, shop, "armor")
	await _assert_filter_change(tag, shop, LAST_CAT)
	await _capture("verify_filter_%s_%s" % [LAST_CAT, tag])

	# --- 6. Buy/Sell mode switch works ---
	sell.pressed.emit()
	await _settle()
	if str(shop.mode) == "sell":
		_ok("%s: Sell mode switch works" % tag)
	else:
		_fail("%s: Sell mode switch failed (mode=%s)" % [tag, shop.mode])
	await _capture("verify_mode_sell_%s" % tag)

	buy.pressed.emit()
	await _settle()
	if str(shop.mode) == "buy":
		_ok("%s: Buy mode switch works" % tag)
	else:
		_fail("%s: Buy mode switch failed (mode=%s)" % [tag, shop.mode])
	await _capture("verify_mode_buy_%s" % tag)

	_note("%s: asserts complete compact=%s scroll_usable_max=%d scroll_pos=%d buy=%s sell=%s" % [
		tag, shop._compact, usable_max, at_scroll, buy.get_global_rect(), sell.get_global_rect()
	])


func _assert_filter_change(tag: String, shop: Node, cat: String) -> void:
	if not shop._cat_buttons.has(cat):
		_fail("%s: category button missing for filter test (%s)" % [tag, cat])
		return
	var btn: Button = shop._cat_buttons[cat]
	# Ensure button is scrolled into view before click when needed.
	if shop._cat_scroll and cat == LAST_CAT:
		shop._cat_scroll.scroll_vertical = 999999
		await _settle()
	btn.pressed.emit()
	await _settle()
	if str(shop.category) != cat:
		_fail("%s: filter category not set to %s (got %s)" % [tag, cat, shop.category])
		return
	# Grid should only show items of that category (buy mode).
	shop.mode = "buy"
	shop._refresh()
	await _settle()
	var gs: Node = root.get_node("/root/GameState")
	var expected: Array = gs.items_by_category(cat)
	if expected.is_empty():
		_fail("%s: no catalog items for category %s" % [tag, cat])
		return
	# Spot-check: selected item (auto) matches category.
	var sel: Dictionary = gs.get_item(str(shop.selected_id))
	if sel.is_empty() or str(sel.get("category", "")) != cat:
		_fail("%s: after select %s, selected item category mismatch (id=%s)" % [
			tag, cat, shop.selected_id
		])
		return
	_ok("%s: filter changes after category select → %s (selected=%s)" % [
		tag, cat, shop.selected_id
	])


func _control_on_screen(ctrl: Control, win_sz: Vector2i) -> bool:
	if ctrl == null or not is_instance_valid(ctrl):
		return false
	if not ctrl.is_visible_in_tree():
		return false
	var r: Rect2 = ctrl.get_global_rect()
	if r.size.x < 1.0 or r.size.y < 1.0:
		return false
	var screen := Rect2(Vector2.ZERO, Vector2(win_sz))
	# Require meaningful overlap (not a 1px sliver).
	var inter: Rect2 = r.intersection(screen)
	return inter.size.x >= 8.0 and inter.size.y >= 8.0


func _control_in_scroll_view(ctrl: Control, scroll: ScrollContainer) -> bool:
	if ctrl == null or scroll == null:
		return false
	var cr: Rect2 = ctrl.get_global_rect()
	var sr: Rect2 = scroll.get_global_rect()
	var inter: Rect2 = cr.intersection(sr)
	return inter.size.x >= 8.0 and inter.size.y >= 8.0


func _control_in_clip_host(ctrl: Control, host: Control) -> bool:
	## Buy/Sell must remain inside the left column clip bounds (not eaten by category overflow).
	if ctrl == null or host == null:
		return false
	if not ctrl.is_visible_in_tree() or not host.is_visible_in_tree():
		return false
	var inter: Rect2 = ctrl.get_global_rect().intersection(host.get_global_rect())
	return inter.size.x >= 8.0 and inter.size.y >= 8.0


func _find_shop(n: Node) -> Node:
	if n is Control and n.has_method("_refresh"):
		var props: Dictionary = {}
		for p in n.get_property_list():
			props[str(p.get("name", ""))] = true
		if props.has("mode") and props.has("category") and props.has("_cat_scroll"):
			return n
	for c in n.get_children():
		var found := _find_shop(c)
		if found:
			return found
	return null


func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame


func _capture(name: String) -> void:
	await process_frame
	var img: Image = root.get_texture().get_image()
	if img == null or img.get_width() < 2:
		_fail("null capture %s" % name)
		return
	var path := ProjectSettings.globalize_path(OUT).path_join("%s.png" % name)
	var err := img.save_png(path)
	if err != OK:
		_fail("save %s" % path)
		return
	print("WROTE ", path, " ", img.get_width(), "x", img.get_height())
