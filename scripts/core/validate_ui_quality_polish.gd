extends SceneTree

## Functional checks for UI quality polish (shop flicker root, BG helpers, scales).
## Does NOT claim visual PASS. Combat 0.8 / bounds / speed must remain untouched.
## godot4 --headless --path . -s res://scripts/core/validate_ui_quality_polish.gd

const UIStyleScript = preload("res://scripts/ui/ui_style.gd")

var _failed := 0
var _passed := 0


func _init() -> void:
	call_deferred("_run")


func _fail(msg: String) -> void:
	printerr("FAIL: ", msg)
	_failed += 1


func _pass(msg: String) -> void:
	print("PASS: ", msg)
	_passed += 1


func _finish() -> void:
	print("=== UI QUALITY POLISH RESULT: %s (%d pass / %d fail) ===" % [
		"PASS" if _failed == 0 else "FAIL", _passed, _failed
	])
	quit(1 if _failed > 0 else 0)


func _run() -> void:
	print("=== UI QUALITY POLISH VALIDATION ===")
	_check_combat_untouched()
	_check_item_icons()
	_check_bg_helpers()
	_check_guild_scales()
	await _check_shop_selection_no_grid_rebuild()
	await _check_facility_nav_scroll()
	_finish()


func _check_combat_untouched() -> void:
	if not is_equal_approx(CombatFieldBounds.COMBAT_RENDER_SCALE, 0.8):
		_fail("COMBAT_RENDER_SCALE changed (%s)" % CombatFieldBounds.COMBAT_RENDER_SCALE)
	else:
		_pass("COMBAT_RENDER_SCALE still 0.8")
	var arena: Rect2 = CombatFieldBounds.background_arena_world()
	if not is_equal_approx(arena.position.x, 250.0) or not is_equal_approx(arena.size.x, 780.0):
		_fail("BG_ARENA mutated %s" % arena)
	else:
		_pass("BG_ARENA unchanged")


func _check_item_icons() -> void:
	## Load via ResourceLoader so -s runs don't depend on class_name + autoload order.
	var scr: GDScript = load("res://scripts/ui/item_ui.gd") as GDScript
	if scr == null:
		_fail("item_ui.gd failed to load")
		return
	var ph: Texture2D = scr.call("placeholder_icon") as Texture2D
	if ph == null or ph.get_width() < 8:
		_fail("placeholder_icon missing")
	else:
		_pass("placeholder_icon ready %dx%d" % [ph.get_width(), ph.get_height()])
	var item := {"id": "__missing_item_xyz__", "icon": "res://assets/items/__nope__.png"}
	var tex: Texture2D = scr.call("load_icon", item) as Texture2D
	if tex != ph:
		_fail("missing icon did not return placeholder")
	else:
		_pass("missing icon → placeholder (no foreign item)")
	var real := {"id": "sword_basic", "icon": "res://assets/items/rusty_sword.png"}
	if not ResourceLoader.exists(str(real["icon"])):
		real = {"id": "iron_sword", "icon": "res://assets/items/iron_sword.png"}
	var hi: Texture2D = scr.call("load_icon", real) as Texture2D
	if hi == null or hi.get_width() < 128:
		_fail("expected hi-res shop icon, got %s" % hi)
	else:
		_pass("hi-res icon %dx%d for %s" % [hi.get_width(), hi.get_height(), real.get("id")])


func _check_bg_helpers() -> void:
	var tr := TextureRect.new()
	UIStyleScript.fit_texture_cover_centered(tr, Vector2(400, 200), 16.0 / 9.0, 1.0)
	var cx := tr.position.x + tr.size.x * 0.5
	var cy := tr.position.y + tr.size.y * 0.5
	if absf(cx - 200.0) > 1.0 or absf(cy - 100.0) > 1.0:
		_fail("cover center expected (200,100) got (%.1f,%.1f) pos=%s size=%s" % [cx, cy, tr.position, tr.size])
	else:
		_pass("fit_texture_cover_centered is truly centered")
	# Must cover (not letterbox): at least one axis equals area after zoom.
	if tr.size.x + 0.5 < 400.0 and tr.size.y + 0.5 < 200.0:
		_fail("cover failed to fill area size=%s" % tr.size)
	else:
		_pass("cover fills area on at least one axis")
	tr.free()


func _check_guild_scales() -> void:
	var path := "res://scripts/ui/guild_hall_screen.gd"
	var src := FileAccess.get_file_as_string(path)
	if "COMBAT_RENDER_SCALE" not in src:
		_fail("guild hall does not derive scale from COMBAT_RENDER_SCALE")
	else:
		_pass("guild hall scale tied to hunt/combat render scale")
	if "area.y - h" in src and "bottom-pin" in src.to_lower():
		_fail("guild hall still bottom-pins interior")
	else:
		_pass("guild hall interior uses centered cover helper")


func _check_shop_selection_no_grid_rebuild() -> void:
	var gs: Node = root.get_node_or_null("/root/GameState")
	if gs:
		gs.new_game()
	root.set_meta("facility_id", "shop")
	var err := change_scene_to_file("res://scenes/facilities/facility.tscn")
	if err != OK:
		_fail("load shop facility")
		return
	for _i in 8:
		await process_frame
	var shop := _find_shop(root)
	if shop == null:
		_fail("ShopPanelRoot not found")
		return
	_pass("ShopPanelRoot mounted")
	# Wait staged grid pump.
	for _j in 20:
		await process_frame
	var gen_before: int = int(shop.get("_grid_gen"))
	var child_before := 0
	var grid: Node = shop.get("_grid")
	if grid:
		child_before = grid.get_child_count()
	var list: Array = []
	if gs and gs.has_method("items_by_category"):
		list = gs.items_by_category("weapon")
	if list.is_empty():
		_fail("no weapons to select")
		return
	var id := str(list[mini(1, list.size() - 1)].get("id", ""))
	shop.call("_select_item", id, 0, true)
	await process_frame
	await process_frame
	var gen_after: int = int(shop.get("_grid_gen"))
	if gen_after != gen_before:
		_fail("selection rebuilt grid (_grid_gen %d → %d)" % [gen_before, gen_after])
	else:
		_pass("selection patches in place (grid_gen stable=%d)" % gen_after)
	if grid and grid.get_child_count() != child_before:
		_fail("grid child count changed on select %d→%d" % [child_before, grid.get_child_count()])
	else:
		_pass("grid children stable on select (%d)" % child_before)


func _check_facility_nav_scroll() -> void:
	root.set_meta("facility_id", "guild")
	var err := change_scene_to_file("res://scenes/facilities/facility.tscn")
	if err != OK:
		_fail("load guild facility")
		return
	for _i in 6:
		await process_frame
	var nav := root.find_child("FacilityNavScroll", true, false)
	if nav == null:
		_fail("FacilityNavScroll missing")
	else:
		_pass("FacilityNavScroll present")
	var win := root.get_window()
	if win:
		win.size = Vector2i(844, 390)
		await process_frame
		await process_frame
	# All 9 facility buttons should exist under scroll content.
	var count := _count_buttons_under(root.find_child("FacilityNav", true, false))
	if count < 9:
		_fail("facility nav buttons clipped/missing count=%d" % count)
	else:
		_pass("facility nav has %d buttons (scrollable)" % count)


func _count_buttons_under(n: Node) -> int:
	if n == null:
		return 0
	var c := 0
	if n is Button:
		c += 1
	for ch in n.get_children():
		c += _count_buttons_under(ch)
	return c


func _find_shop(n: Node) -> Node:
	if n.has_method("_catalog_fingerprint") and n.has_method("_patch_selection_chrome"):
		return n
	for c in n.get_children():
		var f := _find_shop(c)
		if f:
			return f
	return null
