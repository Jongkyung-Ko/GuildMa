extends SceneTree

## Functional validate for shop buy/sell + blacksmith enhance.
## Run: godot4 --headless --path . -s res://scripts/core/validate_shop_blacksmith.gd

var _failed := 0


func _init() -> void:
	call_deferred("_run")


func _fail(msg: String) -> void:
	printerr("FAIL: ", msg)
	_failed += 1


func _pass(msg: String) -> void:
	print("OK: ", msg)


func _run() -> void:
	print("=== validate_shop_blacksmith ===")
	var gs: Node = root.get_node_or_null("/root/GameState")
	if gs == null:
		_fail("GameState missing")
		quit(1)
		return

	gs.new_game()
	var catalog: Array = gs.catalog_items
	if catalog.size() < 160:
		_fail("item catalog size %d < 160" % catalog.size())
	else:
		_pass("item catalog count=%d" % catalog.size())

	var cats := {}
	var subcats := {}
	var missing_icons := 0
	var seen_ids := {}
	var dup_ids := 0
	for it in catalog:
		var iid := str(it.get("id", ""))
		if seen_ids.has(iid):
			dup_ids += 1
			printerr("  duplicate item id ", iid)
		seen_ids[iid] = true
		cats[str(it.get("category", ""))] = true
		var sub := str(it.get("subcategory", ""))
		if sub != "":
			subcats[sub] = int(subcats.get(sub, 0)) + 1
		var icon := str(it.get("icon", ""))
		if icon == "" or not ResourceLoader.exists(icon):
			missing_icons += 1
			printerr("  missing icon for ", it.get("id"), " -> ", icon)
	for need in ["weapon", "armor", "accessory", "consumable", "material"]:
		if not cats.has(need):
			_fail("missing category %s" % need)
		else:
			# Top-level shop filter must still resolve items.
			var filtered: Array = gs.items_by_category(need)
			if filtered.is_empty():
				_fail("shop filter empty for %s" % need)
			else:
				_pass("shop filter %s count=%d" % [need, filtered.size()])
	if dup_ids > 0:
		_fail("%d duplicate item ids" % dup_ids)
	else:
		_pass("item ids unique")
	# Subcategory minima (brief targets).
	var need_subs := {
		"weapon_1h": 16,
		"weapon_2h": 16,
		"shield": 12,
		"body": 20,
		"special": 8,
	}
	for sk in need_subs.keys():
		var have: int = int(subcats.get(sk, 0))
		if have < int(need_subs[sk]):
			_fail("subcategory %s count %d < %d" % [sk, have, int(need_subs[sk])])
		else:
			_pass("subcategory %s=%d" % [sk, have])
	var ranged_magic: int = int(subcats.get("weapon_ranged", 0)) + int(subcats.get("weapon_magic", 0))
	if ranged_magic < 16:
		_fail("ranged/magic subcategory sum %d < 16" % ranged_magic)
	else:
		_pass("ranged/magic=%d" % ranged_magic)
	var hgb: int = int(subcats.get("helm", 0)) + int(subcats.get("gloves", 0)) + int(subcats.get("boots", 0))
	if hgb < 16:
		_fail("helm/gloves/boots sum %d < 16" % hgb)
	else:
		_pass("helm/gloves/boots=%d" % hgb)
	var acc_n: int = int(subcats.get("ring", 0)) + int(subcats.get("amulet", 0)) + int(subcats.get("belt", 0)) + int(subcats.get("cloak", 0))
	if acc_n < 16:
		_fail("accessory subs sum %d < 16" % acc_n)
	else:
		_pass("accessory subs=%d" % acc_n)
	var cons_n: int = int(subcats.get("potion", 0)) + int(subcats.get("elixir", 0)) + int(subcats.get("food", 0)) + int(subcats.get("scroll", 0))
	if cons_n < 16:
		_fail("consumable subs sum %d < 16" % cons_n)
	else:
		_pass("consumable subs=%d" % cons_n)
	var craft_n: int = int(subcats.get("ore", 0)) + int(subcats.get("crystal", 0)) + int(subcats.get("hide", 0)) + int(subcats.get("part", 0))
	if craft_n < 24:
		_fail("craft mat subs sum %d < 24" % craft_n)
	else:
		_pass("craft mat subs=%d" % craft_n)
	# Preserve baseline starter prices used by shop/smith tests.
	var sword: Dictionary = gs.get_item("sword_basic")
	if int(sword.get("price", 0)) != 2400:
		_fail("sword_basic price changed")
	else:
		_pass("sword_basic price preserved")
	if missing_icons > 0:
		_fail("%d items missing icon assets" % missing_icons)
	else:
		_pass("all item icons resolve")

	var gold0: int = gs.gold
	if not gs.buy_item("sword_basic", 1):
		_fail("buy sword_basic")
	elif gs.inventory_qty("sword_basic") < 1:
		_fail("inventory missing purchased sword")
	elif gs.gold != gold0 - 2400:
		_fail("gold not deducted correctly (%d)" % gs.gold)
	else:
		_pass("buy sword + gold deduct")

	# Insufficient gold block
	gs.gold = 10
	if gs.buy_item("sword_steel", 1):
		_fail("buy should fail when gold insufficient")
	else:
		_pass("insufficient gold blocked")

	gs.gold = 5000
	var before_sell_gold: int = gs.gold
	var sell_price: int = gs.sell_price_of("sword_basic")
	if not gs.sell_item("sword_basic", 1, 0):
		_fail("sell sword")
	elif gs.gold != before_sell_gold + sell_price:
		_fail("sell gold mismatch")
	elif gs.inventory_qty("sword_basic") != 0:
		_fail("sold item still in inventory")
	else:
		_pass("sell sword + gold credit")

	# Re-buy for enhance path
	gs.buy_item("sword_basic", 1)
	var rate0: int = gs.enhance_success_rate(0)
	if rate0 <= 0:
		_fail("enhance success rate +0 invalid")
	else:
		_pass("enhance rate +0 = %d%%" % rate0)

	# Force success by temporarily setting rate path: call many times or patch.
	# Deterministic: set failure_rule keep and retry until success or 40 tries.
	var enhanced := false
	for i in 40:
		if gs.inventory_qty("sword_basic", 0) <= 0 and gs.inventory_qty("sword_basic", 1) > 0:
			enhanced = true
			break
		if gs.inventory_qty("sword_basic", 0) <= 0:
			gs.add_item("sword_basic", 1, 0)
		gs.add_item("enhance_stone", 2, 0)
		gs.gold = maxi(gs.gold, 500)
		var r: Dictionary = gs.enhance_item("sword_basic", 0)
		if bool(r.get("success", false)):
			enhanced = true
			break
	if not enhanced:
		_fail("could not enhance sword to +1 within retries")
	elif gs.inventory_qty("sword_basic", 1) < 1:
		_fail("enhanced sword +1 missing from inventory")
	else:
		_pass("enhance reached +1")

	# Max level gate
	gs.add_item("blade_rune", 1, 10)
	var blocked: Dictionary = gs.enhance_item("blade_rune", 10)
	if bool(blocked.get("ok", false)):
		_fail("max enhance should be blocked")
	else:
		_pass("max +10 enhance blocked")

	# Equip with enhance
	if not gs.equip_item("m_lord", "sword_basic", 1):
		_fail("equip enhanced sword")
	else:
		_pass("equip enhanced gear")

	# Scene loads
	for fid in ["shop", "blacksmith", "warehouse", "guild", "gate"]:
		root.set_meta("facility_id", fid)
		var err := change_scene_to_file("res://scenes/facilities/facility.tscn")
		await process_frame
		await process_frame
		if err != OK:
			_fail("load facility %s err=%s" % [fid, err])
		else:
			_pass("facility scene %s loads" % fid)

	var town_err := change_scene_to_file("res://scenes/town/town.tscn")
	await process_frame
	if town_err != OK:
		_fail("town load")
	else:
		_pass("town loads")

	print("=== RESULT: %s (%d fails) ===" % ["PASS" if _failed == 0 else "FAIL", _failed])
	quit(0 if _failed == 0 else 1)
