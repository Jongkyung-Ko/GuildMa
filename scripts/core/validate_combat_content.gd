extends SceneTree

## Validates hunt 5-tier expansion + 9-boss data/systems without claiming visual PASS.
## Run: godot4 --headless --path . -s res://scripts/core/validate_combat_content.gd

var _failed := 0
var _passed := 0
var gs: Node


func _init() -> void:
	call_deferred("_run")


func _fail(msg: String) -> void:
	printerr("FAIL: ", msg)
	_failed += 1


func _pass(msg: String) -> void:
	print("PASS: ", msg)
	_passed += 1


func _finish() -> void:
	print("=== COMBAT CONTENT RESULT: %s (%d pass / %d fail) ===" % [
		"PASS" if _failed == 0 else "FAIL", _passed, _failed
	])
	quit(1 if _failed > 0 else 0)


func _run() -> void:
	print("=== COMBAT CONTENT VALIDATION ===")
	gs = root.get_node_or_null("/root/GameState")
	if gs == null:
		_fail("GameState missing")
		_finish()
		return

	gs.new_game()

	# --- Hunt tiers ---
	var hunts: Array = gs.list_hunts()
	if hunts.size() < 5:
		_fail("expected >=5 hunts, got %d" % hunts.size())
	else:
		_pass("hunt count=%d" % hunts.size())

	var expected_ids := ["beginner_forest", "blue_meadow", "twilight_ruins", "cursed_marsh", "abyss_border"]
	var by_id := {}
	for h in hunts:
		by_id[str(h.get("id"))] = h
	for hid in expected_ids:
		if not by_id.has(hid):
			_fail("missing hunt %s" % hid)
		else:
			_pass("hunt present %s" % hid)

	var concurrent_ok := true
	var ranges := {
		"beginner_forest": [8, 12],
		"blue_meadow": [12, 16],
		"twilight_ruins": [14, 20],
		"cursed_marsh": [18, 24],
		"abyss_border": [24, 30],
	}
	for hid in ranges.keys():
		var h: Dictionary = by_id.get(hid, {})
		if h.is_empty():
			continue
		var cmin := int(h.get("concurrent_min", -1))
		var cmax := int(h.get("concurrent_max", -1))
		var want: Array = ranges[hid]
		if cmin != int(want[0]) or cmax != int(want[1]):
			_fail("%s concurrent %d-%d != %d-%d" % [hid, cmin, cmax, want[0], want[1]])
			concurrent_ok = false
		if int(h.get("tier", 0)) < 1:
			_fail("%s missing tier" % hid)
			concurrent_ok = false
		if str(h.get("boss_id", "")) == "":
			_fail("%s missing boss_id" % hid)
			concurrent_ok = false
	if concurrent_ok:
		_pass("all hunt concurrent ranges + tier/boss_id ok")

	# Spawn budget from maze generator for tier 1 vs 5
	var h1: Dictionary = by_id["beginner_forest"]
	var h5: Dictionary = by_id["abyss_border"]
	var map1: Dictionary = MazeGenerator.generate(h1, 42)
	var map5: Dictionary = MazeGenerator.generate(h5, 42)
	var n1 := _avg_monster_count(map1)
	var n5 := _avg_monster_count(map5)
	if n5 <= n1:
		_fail("tier5 avg monsters %.1f should exceed tier1 %.1f" % [n5, n1])
	else:
		_pass("tier spawn scales (t1 avg=%.1f t5 avg=%.1f)" % [n1, n5])

	# Boss room is single named boss
	var boss_room_ok := true
	for rid in map1.get("rooms", {}).keys():
		var r: Dictionary = map1["rooms"][rid]
		if str(r.get("room_type")) != "boss":
			continue
		var mons: Array = r.get("monsters", [])
		if mons.size() != 1 or str(mons[0]) != str(h1.get("boss_enemy")):
			_fail("boss room monsters=%s" % str(mons))
			boss_room_ok = false
	if boss_room_ok:
		_pass("hunt goal boss room is exclusive single boss")

	# --- Nine bosses ---
	var bosses: Array = gs.list_bosses()
	if bosses.size() != 9:
		_fail("expected 9 bosses, got %d" % bosses.size())
	else:
		_pass("boss catalog count=9")
	var need := ["fenrir", "malkav", "malachi", "gorgon", "lilith", "bone_golem", "behemoth", "vorak", "morgana"]
	var b_by := {}
	for b in bosses:
		b_by[str(b.get("id"))] = b
	for bid in need:
		if not b_by.has(bid):
			_fail("missing boss %s" % bid)
			continue
		var b: Dictionary = b_by[bid]
		var phases: Array = b.get("phases", [])
		if phases.size() != 3:
			_fail("%s phases=%d" % [bid, phases.size()])
		else:
			_pass("%s has 3 phases" % bid)
		var skills: Dictionary = b.get("skills", {})
		if skills.is_empty():
			_fail("%s has no skills" % bid)
		var spawn: Dictionary = b.get("spawn", {})
		if str(spawn.get("kind", "")) == "":
			_fail("%s missing spawn.kind" % bid)

	# Exclusive spawn kinds — no single screen dumps all bosses
	var hunt_goal_n := 0
	var dungeon_n := 0
	var special_n := 0
	for b in bosses:
		match str(b.get("spawn", {}).get("kind", "")):
			"hunt_goal":
				hunt_goal_n += 1
			"dungeon_floor":
				dungeon_n += 1
			"special_encounter":
				special_n += 1
	if hunt_goal_n != 5 or dungeon_n != 2 or special_n != 2:
		_fail("spawn split hunt=%d dungeon=%d special=%d" % [hunt_goal_n, dungeon_n, special_n])
	else:
		_pass("spawn conditions split 5 hunt / 2 dungeon / 2 special")

	# Fenrir end-to-end data wiring
	var fenrir: Dictionary = b_by.get("fenrir", {})
	if str(fenrir.get("spawn", {}).get("hunt_id", "")) != "beginner_forest":
		_fail("fenrir not bound to beginner_forest")
	else:
		_pass("fenrir bound to beginner_forest")
	var summary: Dictionary = gs.grant_boss_rewards("fenrir")
	if int(summary.get("gold", 0)) <= 0:
		_fail("fenrir rewards gold missing")
	else:
		_pass("fenrir rewards gold=%d exp=%d" % [int(summary.get("gold")), int(summary.get("exp"))])
	if not gs.is_boss_cleared("fenrir"):
		_fail("fenrir not marked cleared")
	else:
		_pass("fenrir marked cleared")

	# Morgana gate
	var gate: Dictionary = gs.can_start_special_encounter("morgana_sanctum")
	if bool(gate.get("ok", false)):
		_fail("morgana should be gated before lilith+behemoth")
	else:
		_pass("morgana gated: %s" % str(gate.get("reason")))
	gs.bosses_cleared["lilith"] = true
	gs.bosses_cleared["behemoth"] = true
	gate = gs.can_start_special_encounter("morgana_sanctum")
	if not bool(gate.get("ok", false)):
		_fail("morgana should unlock after lilith+behemoth")
	else:
		_pass("morgana unlocks after prerequisites")

	# Dungeon floors use bone_golem / behemoth
	var ddef: Dictionary = gs.get_dungeon_def("shadow_crypt")
	var bf: Dictionary = ddef.get("boss_floors", {})
	if str(bf.get("5", {}).get("enemy_id", "")) != "boss_bone_golem":
		_fail("dungeon F5 not bone_golem")
	else:
		_pass("dungeon F5 = bone_golem")
	if str(bf.get("10", {}).get("enemy_id", "")) != "boss_behemoth":
		_fail("dungeon F10 not behemoth")
	else:
		_pass("dungeon F10 = behemoth")

	# Painted idle art: each boss must resolve bosses/<id>/idle.png
	var painted_ok := 0
	for b in bosses:
		var bid := str(b.get("id", ""))
		var path := "res://assets/sprites/monsters/bosses/%s/idle.png" % bid
		if not (ResourceLoader.exists(path) or FileAccess.file_exists(path)):
			_fail("missing painted idle for %s -> %s" % [bid, path])
			continue
		if bool(b.get("placeholder_art", true)):
			_fail("%s still marked placeholder_art" % bid)
			continue
		painted_ok += 1
	if painted_ok == 9:
		_pass("all 9 bosses have painted idle.png wired")

	# Save/load preserves boss clears
	gs.save_game()
	gs.bosses_cleared = {}
	if not gs.load_game():
		_fail("load_game failed")
	elif not gs.is_boss_cleared("fenrir"):
		_fail("boss clear not persisted")
	else:
		_pass("boss clear persists across save/load")

	# Shop/blacksmith untouched smoke (catalog still 160+)
	if gs.catalog_items.size() < 160:
		_fail("item catalog regressed to %d" % gs.catalog_items.size())
	else:
		_pass("item catalog intact count=%d" % gs.catalog_items.size())
	if not gs.buy_item("sword_basic", 1):
		_fail("shop buy regression")
	else:
		_pass("shop buy still works")

	_finish()


func _avg_monster_count(map: Dictionary) -> float:
	var rooms: Dictionary = map.get("rooms", {})
	var total := 0
	var n := 0
	for rid in rooms.keys():
		var r: Dictionary = rooms[rid]
		if str(r.get("room_type")) == "boss":
			continue
		total += int((r.get("monsters", []) as Array).size())
		n += 1
	return 0.0 if n == 0 else float(total) / float(n)
