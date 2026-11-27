extends SceneTree

## Capture shop/blacksmith ChatGPT visual-QA evidence at 1366×768.
## DISPLAY=:1 godot4 --path . --display-driver x11 -s res://scripts/core/capture_shop_blacksmith_visual_qa.gd
## Optional: OUT_DIR=... STORE_DIR=...
## Note: SceneTree -s scripts cannot resolve autoload identifiers at compile time; use /root/GameState.

const SIZE := Vector2i(1366, 768)
const DEFAULT_OUT := "res://docs/reviews/shop_blacksmith_visual_qa/evidence"
const GOLD_BRIGHT := Color(1.0, 0.86, 0.35)
const DANGER := Color(0.9, 0.3, 0.25)

var _out_dir: String = DEFAULT_OUT
var _store_dir: String = ""
var _failed := 0
var _notes: PackedStringArray = []
var _gs: Node


func _init() -> void:
	call_deferred("_run")


func _fail(msg: String) -> void:
	printerr("FAIL: ", msg)
	_failed += 1


func _note(msg: String) -> void:
	_notes.append(msg)
	print("NOTE: ", msg)


func _run() -> void:
	var env_out := OS.get_environment("OUT_DIR")
	if env_out != "":
		_out_dir = env_out
	_store_dir = OS.get_environment("STORE_DIR")
	DirAccess.make_dir_recursive_absolute(_resolve_user_path(_out_dir))
	if _store_dir != "":
		DirAccess.make_dir_recursive_absolute(_store_dir)

	_gs = root.get_node("/root/GameState")
	_gs.new_game()
	# Seed inventory for sell + enhance flows.
	_gs.gold = 50000
	_gs.buy_item("sword_basic", 3)
	_gs.buy_item("armor_leather", 2)
	_gs.buy_item("ring_copper", 1)
	_gs.buy_item("potion_hp_s", 3)
	_gs.add_item("enhance_stone", 40)
	_gs.add_item("ore_iron", 10)
	_gs.add_item("ore_mithril", 6)
	_gs.add_item("crystal_fire", 4)
	# Pre-enhanced sword for blacksmith target chrome.
	if _gs.inventory_qty("sword_basic", 0) > 0:
		_gs.remove_item("sword_basic", 1, 0)
		_gs.add_item("sword_basic", 1, 2)
	# High-level sword for fail attempt (+9, 25% success).
	_gs.add_item("sword_steel", 1, 9)

	var win := root.get_window()
	win.size = SIZE
	await process_frame
	await process_frame

	await _capture_shop_suite()
	await _capture_blacksmith_suite()

	var notes_path := _resolve_user_path(_out_dir).path_join("_capture_notes.txt")
	var nf := FileAccess.open(notes_path, FileAccess.WRITE)
	if nf:
		for line in _notes:
			nf.store_line(line)
		nf.close()

	print("=== capture_shop_blacksmith_visual_qa done fails=%d ===" % _failed)
	quit(0 if _failed == 0 else 1)


func _capture_shop_suite() -> void:
	var shop: Node = await _open_facility("shop")
	if shop == null:
		_fail("shop panel missing")
		return

	# Default buy + weapon category (auto-select first item).
	shop.mode = "buy"
	shop.category = "weapon"
	shop.selected_id = ""
	shop.selected_enhance = 0
	shop._refresh()
	await _settle()
	await _capture("shop_main")
	await _capture("shop_weapon")

	for cat in ["armor", "accessory", "consumable", "material"]:
		shop.category = cat
		shop.selected_id = ""
		shop._refresh()
		await _settle()
		await _capture("shop_%s" % cat)

	# Item detail: weapon category with a mid-list item selected if possible.
	shop.category = "weapon"
	shop.mode = "buy"
	var weapons: Array = _gs.items_by_category("weapon")
	if weapons.size() > 1:
		shop.selected_id = str(weapons[mini(2, weapons.size() - 1)].get("id", ""))
	elif weapons.size() > 0:
		shop.selected_id = str(weapons[0].get("id", ""))
	else:
		shop.selected_id = ""
	shop.selected_enhance = 0
	shop.buy_qty = 1
	shop._refresh()
	await _settle()
	await _capture("shop_item_detail")

	# Purchase confirm dialog (AcceptDialog) — real modal.
	if str(shop.selected_id) != "":
		shop._on_buy_pressed()
		await _settle()
		await process_frame
		await _capture("shop_purchase")
		# Dismiss dialog without buying if still open.
		if shop._confirm and shop._confirm.visible:
			shop._confirm.hide()
		await _settle()
	else:
		_fail("shop_purchase: no selected item")

	# Sell mode with inventory in weapon category.
	shop.mode = "sell"
	shop.category = "weapon"
	shop.selected_id = ""
	shop.selected_enhance = 0
	if shop._dialogue:
		shop._dialogue.text = "팔고 싶은 물건이 있으면 언제든 말씀하세요."
	shop._refresh()
	await _settle()
	await _capture("shop_sell")
	_note("shop_purchase: real AcceptDialog confirm modal (not a custom purchase result screen).")
	_note("shop_sell: sell mode + inventory cards + sell CTA (no separate sell-result modal).")


func _capture_blacksmith_suite() -> void:
	var smith: Node = await _open_facility("blacksmith")
	if smith == null:
		_fail("blacksmith panel missing")
		return

	# Main: UI auto-selects first enhanceable on refresh.
	smith.selected_id = ""
	smith.selected_enhance = 0
	smith._refresh()
	await _settle()
	await _capture("blacksmith_main")
	_note("blacksmith_main: UI auto-selects first enhanceable gear; no empty-selection state.")

	# Target selected: prefer +2 sword_basic.
	smith.selected_id = "sword_basic"
	smith.selected_enhance = 2
	if int(_gs.inventory_qty("sword_basic", 2)) <= 0:
		smith.selected_id = ""
		smith.selected_enhance = 0
		smith._refresh()
	else:
		smith._refresh()
	await _settle()
	await _capture("blacksmith_target")

	# Upgrade detail + stat compare share the same center panel when a target is selected.
	await _capture("blacksmith_upgrade_detail")
	await _capture("blacksmith_stat_compare")
	_note("blacksmith_upgrade_detail / blacksmith_stat_compare: same center panel (before/after icons + delta lines + cost); no separate screens.")

	# Success: +0 enhance always succeeds (rate 100%). Use a fresh +0 sword.
	if int(_gs.inventory_qty("sword_basic", 0)) <= 0:
		_gs.add_item("sword_basic", 1, 0)
	smith.selected_id = "sword_basic"
	smith.selected_enhance = 0
	smith._refresh()
	await _settle()
	await _run_enhance_and_capture(smith, true, "blacksmith_upgrade_success")

	# Fail: +9 sword_steel has 25% success — force fail via seed right before enhance_item.
	await _force_fail_capture(smith)


func _run_enhance_and_capture(smith: Node, expect_success: bool, name: String) -> void:
	if str(smith.selected_id) == "" or bool(smith._busy):
		_fail("%s: cannot enhance" % name)
		return
	smith._busy = true
	await smith._play_enhance_vfx()
	var before_enh: int = int(smith.selected_enhance)
	var result: Dictionary = _gs.enhance_item(str(smith.selected_id), before_enh)
	smith._busy = false
	if not bool(result.get("ok", false)):
		_fail("%s: enhance not ok: %s" % [name, result.get("message", "")])
		smith._refresh()
		return
	var success := bool(result.get("success", false))
	if expect_success and not success:
		_fail("%s: expected success" % name)
	if success:
		smith.selected_enhance = int(result.get("new_enhance", smith.selected_enhance))
		smith._feedback.text = str(result.get("message", "성공"))
		smith._feedback.add_theme_color_override("font_color", GOLD_BRIGHT)
		smith._dialogue.text = "망치가 울리면 강함이 깃든다!"
		var flash := ColorRect.new()
		flash.color = Color(1.0, 0.85, 0.2, 0.55)
		flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		smith.add_child(flash)
		smith._refresh()
		await process_frame
		await process_frame
		await _capture(name)
		flash.queue_free()
		_note("%s: real enhance success (+%d→+%d) with gold flash overlay." % [name, before_enh, int(smith.selected_enhance)])
	else:
		smith._feedback.text = str(result.get("message", "실패"))
		smith._feedback.add_theme_color_override("font_color", DANGER)
		smith._dialogue.text = "실패해도 낙담 말게. 다시 벼리면 된다."
		var flash2 := ColorRect.new()
		flash2.color = Color(0.9, 0.2, 0.15, 0.55)
		flash2.set_anchors_preset(Control.PRESET_FULL_RECT)
		flash2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		smith.add_child(flash2)
		smith._refresh()
		await process_frame
		await process_frame
		await _capture(name)
		flash2.queue_free()
		_note("%s: real enhance fail with red flash overlay." % name)


func _force_fail_capture(smith: Node) -> void:
	if int(_gs.inventory_qty("sword_steel", 9)) <= 0:
		_gs.add_item("sword_steel", 1, 9)
	_gs.add_item("enhance_stone", 20)
	_gs.add_item("ore_mithril", 4)
	_gs.gold = maxi(int(_gs.gold), 10000)

	smith.selected_id = "sword_steel"
	smith.selected_enhance = 9
	smith._refresh()
	await _settle()

	var rate: int = int(_gs.enhance_success_rate(9))
	# Seed RNG so the *next* randi()%100 fails. Call seed immediately before enhance_item
	# (skip spark VFX to avoid consuming RNG with randf).
	var fail_seed := _find_fail_seed(rate)
	smith._busy = true
	if smith._hammer:
		smith._hammer.visible = true
	if smith._furnace_glow:
		smith._furnace_glow.color.a = 0.55
	await process_frame
	seed(fail_seed)
	var result: Dictionary = _gs.enhance_item("sword_steel", 9)
	smith._busy = false
	if smith._hammer:
		smith._hammer.visible = false
	if not bool(result.get("ok", false)):
		_fail("blacksmith_upgrade_fail: enhance not ok: %s" % result.get("message", ""))
		smith._refresh()
		return
	if bool(result.get("success", false)):
		_fail("blacksmith_upgrade_fail: seed produced success unexpectedly (seed=%d rate=%d)" % [fail_seed, rate])
		smith._refresh()
		return
	smith.selected_enhance = int(result.get("new_enhance", 9))
	smith._feedback.text = str(result.get("message", "실패"))
	smith._feedback.add_theme_color_override("font_color", DANGER)
	smith._dialogue.text = "실패해도 낙담 말게. 다시 벼리면 된다."
	var flash := ColorRect.new()
	flash.color = Color(0.9, 0.2, 0.15, 0.55)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	smith.add_child(flash)
	smith._refresh()
	await process_frame
	await process_frame
	await _capture("blacksmith_upgrade_fail")
	flash.queue_free()
	_note("blacksmith_upgrade_fail: real enhance_item fail at +9 (seeded RNG); red flash overlay; hammer shown without spark randf to keep seed stable.")


func _find_fail_seed(rate: int) -> int:
	for s in 200000:
		seed(s)
		if (randi() % 100) >= rate:
			return s
	return 1


func _open_facility(fid: String) -> Node:
	root.set_meta("facility_id", fid)
	var err := change_scene_to_file("res://scenes/facilities/facility.tscn")
	if err != OK:
		_fail("scene %s err=%s" % [fid, err])
		return null
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	var panel := _find_trade_panel(root)
	if panel == null:
		_fail("trade panel not found for %s" % fid)
	return panel


func _find_trade_panel(n: Node) -> Node:
	# ShopPanelRoot has mode+category; BlacksmithPanelRoot has _equip_grid.
	if n is Control and n.has_method("_refresh"):
		var props: Dictionary = {}
		for p in n.get_property_list():
			props[str(p.get("name", ""))] = true
		if props.has("mode") and props.has("category"):
			return n
		if props.has("_equip_grid") and props.has("selected_id"):
			return n
	for c in n.get_children():
		var found := _find_trade_panel(c)
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
		_fail("null image %s" % name)
		return
	if img.get_width() != SIZE.x or img.get_height() != SIZE.y:
		_note("%s captured at %dx%d (requested %dx%d)" % [name, img.get_width(), img.get_height(), SIZE.x, SIZE.y])
	var path := _resolve_user_path(_out_dir).path_join("%s.png" % name)
	var err := img.save_png(path)
	if err != OK:
		_fail("save %s err=%s" % [path, err])
		return
	print("WROTE ", path, " ", img.get_width(), "x", img.get_height())
	if _store_dir != "":
		var store_path := _store_dir.path_join("%s.png" % name)
		img.save_png(store_path)
		print("WROTE ", store_path)


func _resolve_user_path(p: String) -> String:
	if p.begins_with("res://"):
		return ProjectSettings.globalize_path(p)
	return p
