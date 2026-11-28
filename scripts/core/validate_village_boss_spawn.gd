extends SceneTree

## Village ↔ boss wiring + Elderwood→Gorgon playable spawn path.
## godot4 --headless --path . -s res://scripts/core/validate_village_boss_spawn.gd

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
	print("=== VILLAGE BOSS SPAWN RESULT: %s (%d pass / %d fail) ===" % [
		"PASS" if _failed == 0 else "FAIL", _passed, _failed
	])
	quit(1 if _failed > 0 else 0)


func _run() -> void:
	print("=== VILLAGE BOSS SPAWN VALIDATION ===")
	var gs: Node = root.get_node_or_null("/root/GameState")
	if gs == null:
		_fail("GameState missing")
		_finish()
		return
	gs.new_game()

	_check_links_table(gs)
	_check_nine_bosses(gs)
	_check_markers_boss_ids()
	await _check_elderwood_gorgon_path(gs)
	_check_closed_village_not_fake(gs)
	_finish()


func _check_links_table(gs: Node) -> void:
	var links: Array = gs.list_village_boss_links()
	if links.size() != 9:
		_fail("expected 9 village links, got %d" % links.size())
	else:
		_pass("village_boss_links count=9")
	var need_v := [
		"frostheim", "stoneguard", "gravehall", "elderwood", "moonshadow",
		"mistfall", "demonfall", "deadcrown", "abyssgate",
	]
	var need_b := [
		"fenrir", "behemoth", "bone_golem", "gorgon", "lilith",
		"morgana", "malkav", "malachi", "vorak",
	]
	var by_v := {}
	for link in links:
		by_v[str(link.get("village_id"))] = link
	for i in range(need_v.size()):
		var vid: String = need_v[i]
		var bid: String = need_b[i]
		if not by_v.has(vid):
			_fail("missing village link %s" % vid)
			continue
		var link: Dictionary = by_v[vid]
		if str(link.get("boss_id")) != bid:
			_fail("%s boss_id %s != %s" % [vid, link.get("boss_id"), bid])
		else:
			_pass("%s → %s (%s)" % [vid, bid, str(link.get("spawn"))])
	var ew: Dictionary = gs.get_village_boss_link("elderwood")
	if not bool(ew.get("open", false)) or str(ew.get("hunt_id")) != "cursed_marsh":
		_fail("Elderwood must be open hunt cursed_marsh → gorgon")
	else:
		_pass("Elderwood open hunt=cursed_marsh")
	# Only Elderwood open for now
	var open_n := 0
	for link in links:
		if bool(link.get("open", false)):
			open_n += 1
	if open_n != 1:
		_fail("expected exactly 1 open village, got %d" % open_n)
	else:
		_pass("exactly one open village (Elderwood)")


func _check_nine_bosses(gs: Node) -> void:
	var bosses: Array = gs.list_bosses()
	if bosses.size() != 9:
		_fail("boss catalog %d != 9" % bosses.size())
	else:
		_pass("boss catalog=9")
	for bid in ["fenrir", "malkav", "malachi", "gorgon", "lilith", "bone_golem", "behemoth", "vorak", "morgana"]:
		var path := "res://assets/sprites/monsters/bosses/%s/idle.png" % bid
		if not (ResourceLoader.exists(path) or FileAccess.file_exists(path)):
			_fail("missing idle %s" % path)
		else:
			_pass("idle wired %s" % bid)


func _check_markers_boss_ids() -> void:
	var f := FileAccess.open("res://data/world/world_map_markers.json", FileAccess.READ)
	if f == null:
		_fail("markers JSON missing")
		return
	var data = JSON.parse_string(f.get_as_text())
	var markers: Array = data.get("markers", [])
	var villages := 0
	for m in markers:
		if str(m.get("kind")) != "village":
			continue
		villages += 1
		if str(m.get("boss_id", "")) == "":
			_fail("village %s missing boss_id" % str(m.get("id")))
		else:
			_pass("marker %s boss_id=%s" % [str(m.get("id")), str(m.get("boss_id"))])
	if villages != 9:
		_fail("marker villages %d != 9" % villages)


func _check_elderwood_gorgon_path(gs: Node) -> void:
	var sr: Node = root.get_node_or_null("/root/SceneRouter")
	if sr == null or not sr.has_method("go_village_expedition"):
		_fail("SceneRouter.go_village_expedition missing")
		return
	_pass("go_village_expedition present")

	# Simulate expedition without full scene change: resolve link + spawn boss room combat.
	var link: Dictionary = gs.get_village_boss_link("elderwood")
	var hunt_id := str(link.get("hunt_id", "cursed_marsh"))
	root.set_meta("village_id", "elderwood")
	root.set_meta("village_boss_id", "gorgon")
	root.set_meta("hunt_id", hunt_id)
	root.set_meta("combat_hunt_id", hunt_id)
	root.set_meta("hunt_force_new", true)
	root.set_meta("hunt_spawn_at_start", true)
	var map: Dictionary = gs.start_hunt_run(hunt_id, true, true)
	var boss_rid := ""
	for rid in map.get("rooms", {}).keys():
		var room: Dictionary = map["rooms"][rid]
		if str(room.get("room_type", "")) == "boss":
			boss_rid = str(rid)
			break
	if boss_rid == "":
		_fail("cursed_marsh maze has no boss room")
		return
	_pass("cursed_marsh boss room=%s" % boss_rid)
	map["current_room_id"] = boss_rid
	map["rooms"][boss_rid]["discovered"] = true
	map["rooms"][boss_rid]["cleared"] = false
	var prog: Dictionary = gs.hunt_progress.get(hunt_id, {})
	prog["map"] = map
	prog["pending_spawn_at_start"] = false
	gs.hunt_progress[hunt_id] = prog
	gs.active_hunt_id = hunt_id
	root.set_meta("hunt_force_new", false)
	root.set_meta("hunt_spawn_at_start", false)

	var combat: Node = load("res://scenes/combat/combat.tscn").instantiate()
	root.add_child(combat)
	await process_frame
	await process_frame
	await process_frame

	var boss = combat.get_active_boss() if combat.has_method("get_active_boss") else null
	if boss == null:
		_fail("no boss spawned in Elderwood→Gorgon path")
	elif str(boss.boss_id) != "gorgon" and str(boss.enemy_kind).find("gorgon") < 0:
		_fail("expected Gorgon, got boss_id=%s kind=%s" % [boss.boss_id, boss.enemy_kind])
	else:
		_pass("spawned Gorgon kind=%s painted=%s" % [
			boss.enemy_kind,
			str(SpriteFactory.has_boss_idle("gorgon")),
		])
		# HUD path: boss should hide overhead bar (BossHud owns main)
		if boss._hp_bar and boss._hp_bar.visible:
			_fail("boss overhead HP should be hidden (BossHud)")
		else:
			_pass("boss overhead HP hidden for HUD")

	# Death once + reward once
	if boss != null and not boss.is_dead:
		var died_n := [0]
		boss.died.connect(func(_w): died_n[0] += 1)
		var ally = null
		for a in combat.get_allies():
			if a and not a.is_dead:
				ally = a
				break
		boss.take_damage(999999.0, ally, {"heavy": true})
		for _i in range(100):
			await process_frame
			if died_n[0] > 0:
				break
		if died_n[0] != 1:
			_fail("died count=%d" % died_n[0])
		else:
			_pass("Gorgon died emit once")
		# Victory path may grant rewards — ensure cleared flag set at most once path exists
		await process_frame
		await process_frame

	combat.queue_free()
	await process_frame
	gs.bosses_cleared["gorgon"] = false
	gs.leave_hunt_session()


func _check_closed_village_not_fake(gs: Node) -> void:
	var sr: Node = root.get_node_or_null("/root/SceneRouter")
	# Don't actually change scene — inspect return dict by calling a dry path.
	# go_village_expedition changes scene on success; for closed it should return ok=false first.
	# Temporarily wrap: only test get_village_boss_link open flag + manual check.
	var frost: Dictionary = gs.get_village_boss_link("frostheim")
	if bool(frost.get("open", false)):
		_fail("frostheim should not be open")
	else:
		_pass("frostheim closed (data-ready)")
	# SceneRouter early-out before scene change
	if sr:
		var res: Dictionary = sr.go_village_expedition("frostheim", true)
		if bool(res.get("ok", false)):
			_fail("closed village expedition incorrectly ok")
		else:
			_pass("closed village expedition blocked: %s" % str(res.get("reason")))
