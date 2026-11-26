extends SceneTree

## PR15 Guild Hall — parties, stats wiring, save compatibility.
## godot4 --headless --path . -s res://scripts/core/validate_guild_hall.gd


func _init() -> void:
	call_deferred("_run")


func _pass(msg: String) -> void:
	print("PASS: ", msg)


func _run() -> void:
	await process_frame
	var failed := 0
	var gs: Node = root.get_node("/root/GameState")
	gs.call("new_game")

	# Scene / router
	var sr: Node = root.get_node("/root/SceneRouter")
	if str(sr.get("GUILD_HALL")).find("guild_hall.tscn") < 0:
		print("FAIL: SceneRouter.GUILD_HALL missing"); failed += 1
	else:
		_pass("SceneRouter.GUILD_HALL wired")

	# Default hunt party mirrors starting in_party
	var hunt: Array = gs.call("get_guild_party", "hunt")
	if hunt.size() != 5:
		print("FAIL: default hunt party size %d" % hunt.size()); failed += 1
	else:
		_pass("New game seeds hunt party with 5 starters")
	for mid in hunt:
		var m: Dictionary = gs.call("get_member_by_id", str(mid))
		if not bool(m.get("in_party", false)):
			print("FAIL: hunt member %s not in_party" % mid); failed += 1
	_pass("Hunt party synced to in_party flags")

	# Combat preview matches stored stats only (no fake DEX/LUK)
	var lord: Dictionary = gs.call("get_member_by_id", "m_lord")
	var preview: Dictionary = gs.call("compute_combat_preview", lord)
	for k in ["hp", "atk", "def", "spd"]:
		if not preview.has(k):
			print("FAIL: preview missing %s" % k); failed += 1
	if int(preview.get("hp", 0)) <= 0 or int(preview.get("atk", 0)) <= 0:
		print("FAIL: preview values invalid %s" % str(preview)); failed += 1
	else:
		_pass("Combat preview ATK/DEF/HP/SPD from real formulas (%s)" % str(preview))
	var stats: Dictionary = lord.get("stats", {})
	if stats.has("dex") or stats.has("luk"):
		print("FAIL: invented dex/luk on member"); failed += 1
	else:
		_pass("Member stats remain str/vit/agi/int/wis only")

	# Assign train exclusive — removes from hunt / clears in_party
	var ok_train := bool(gs.call("set_guild_party", "train", ["m_dps", "m_mage"]))
	if not ok_train:
		print("FAIL: set train party"); failed += 1
	else:
		_pass("Train party saved")
	hunt = gs.call("get_guild_party", "hunt")
	if hunt.has("m_dps") or hunt.has("m_mage"):
		print("FAIL: exclusivity — still in hunt"); failed += 1
	else:
		_pass("Exclusive: train members removed from hunt")
	var dps: Dictionary = gs.call("get_member_by_id", "m_dps")
	if bool(dps.get("in_party", false)):
		print("FAIL: train-only member still in_party"); failed += 1
	else:
		_pass("Train assignment clears combat in_party")

	# Defend assign
	if not bool(gs.call("set_guild_party", "defend", ["m_tank"])):
		print("FAIL: defend party"); failed += 1
	else:
		_pass("Defend party saved")
	if str(gs.call("member_party_kind", "m_tank")) != "defend":
		print("FAIL: tank party kind"); failed += 1
	else:
		_pass("member_party_kind(defend) ok")

	# Cap 5
	var many: Array = ["m_lord", "m_tank", "m_dps", "m_healer", "m_mage"]
	# Restore all to hunt first
	gs.call("set_guild_party", "hunt", many)
	# Toggle overflow via toggle_member when full — need 6th member
	# Recruit simulation: append a temp member
	var members: Array = gs.get("members")
	members.append(gs.call("_member", "m_extra", "테스트", "dps", 1, {"str": 5, "vit": 5, "agi": 5, "int": 5, "wis": 5}, [], false))
	gs.set("members", members)
	gs.call("set_guild_party", "hunt", ["m_lord", "m_tank", "m_dps", "m_healer", "m_mage"])
	var toggled := bool(gs.call("toggle_member_in_party", "hunt", "m_extra"))
	if toggled:
		print("FAIL: should reject 6th hunt member"); failed += 1
	else:
		_pass("Hunt party rejects over-cap toggle")

	# Save / load persistence
	gs.call("set_guild_party", "hunt", ["m_lord", "m_healer", "m_mage"])
	gs.call("set_guild_party", "train", ["m_dps"])
	gs.call("set_guild_party", "defend", ["m_tank"])
	gs.call("select_guild_member", "m_healer")
	gs.call("save_game")
	# Mutate in-memory only (do not save) then reload from disk.
	gs.set("guild_parties", {"hunt": [], "train": [], "defend": []})
	gs.set("selected_guild_member_id", "")
	if not bool(gs.call("load_game")):
		print("FAIL: load_game"); failed += 1
	else:
		_pass("load_game ok")
	hunt = gs.call("get_guild_party", "hunt")
	var train: Array = gs.call("get_guild_party", "train")
	var defend: Array = gs.call("get_guild_party", "defend")
	print("LOG: loaded parties hunt=%s train=%s defend=%s selected=%s" % [
		str(hunt), str(train), str(defend), str(gs.get("selected_guild_member_id"))
	])
	if str(hunt) != str(["m_lord", "m_healer", "m_mage"]):
		print("FAIL: hunt not restored"); failed += 1
	elif str(train) != str(["m_dps"]):
		print("FAIL: train not restored"); failed += 1
	elif str(defend) != str(["m_tank"]):
		print("FAIL: defend not restored"); failed += 1
	elif str(gs.get("selected_guild_member_id")) != "m_healer":
		print("FAIL: selected member not restored"); failed += 1
	else:
		_pass("Parties + selected member persist across save/load")

	# Legacy save without guild_parties key
	var legacy := {
		"gold": 100,
		"reputation": 1,
		"guild_name": "레거시",
		"guild_level": 2,
		"day": 1,
		"season": "봄",
		"hour": 8,
		"minute": 0,
		"members": [
			{"id": "m_lord", "name": "아렌", "job": "lord", "level": 1, "exp": 0,
				"stats": {"str": 7, "vit": 7, "agi": 6, "int": 6, "wis": 6},
				"skills": [], "traits": [], "upkeep": 0, "injured": false,
				"equipment": {"weapon": "", "armor": "", "accessory": ""}, "in_party": true},
			{"id": "m_dps", "name": "리사", "job": "dps", "level": 1, "exp": 0,
				"stats": {"str": 9, "vit": 5, "agi": 10, "int": 3, "wis": 2},
				"skills": [], "traits": [], "upkeep": 20, "injured": false,
				"equipment": {"weapon": "", "armor": "", "accessory": ""}, "in_party": true},
			{"id": "m_mage", "name": "카이", "job": "mage", "level": 1, "exp": 0,
				"stats": {"str": 2, "vit": 4, "agi": 5, "int": 11, "wis": 8},
				"skills": [], "traits": [], "upkeep": 20, "injured": false,
				"equipment": {"weapon": "", "armor": "", "accessory": ""}, "in_party": false},
		],
		"inventory": [],
		"active_quests": [],
		"recruited_ids": [],
		"dungeon_progress": {},
		"hunt_progress": {},
		"active_hunt_id": "",
		"message_log": [],
	}
	var f := FileAccess.open("user://guildmaster_save.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(legacy))
	f = null
	if not bool(gs.call("load_game")):
		print("FAIL: legacy load"); failed += 1
	else:
		_pass("Legacy save loads")
	hunt = gs.call("get_guild_party", "hunt")
	if not hunt.has("m_lord") or not hunt.has("m_dps") or hunt.has("m_mage"):
		print("FAIL: legacy migrate hunt=%s" % str(hunt)); failed += 1
	else:
		_pass("Legacy in_party → hunt party migration")

	# Instantiate guild hall scene smoke
	var packed: PackedScene = load("res://scenes/facilities/guild_hall.tscn")
	if packed == null:
		print("FAIL: guild_hall.tscn missing"); failed += 1
	else:
		var hall: Node = packed.instantiate()
		root.add_child(hall)
		await process_frame
		await process_frame
		if hall.get_child_count() < 3:
			print("FAIL: guild hall UI not built"); failed += 1
		else:
			_pass("Guild hall scene instantiates and builds UI")
		hall.queue_free()
		await process_frame

	# Combat still sees in_party from hunt
	gs.call("new_game")
	var in_party_n := 0
	for m2 in gs.get("members"):
		if bool(m2.get("in_party", false)):
			in_party_n += 1
	if in_party_n != 5:
		print("FAIL: combat roster size %d" % in_party_n); failed += 1
	else:
		_pass("Combat in_party roster remains 5 after new_game")

	if failed == 0:
		print("=== GUILD HALL VALIDATE: PASS ===")
		quit(0)
	else:
		print("=== GUILD HALL VALIDATE: FAIL (%d) ===" % failed)
		quit(1)
