extends SceneTree

## Headless: hunt N/E/S/W direction pad — real Button.pressed path, not only API.
## godot --headless --path . -s res://scripts/core/validate_direction_travel.gd

var _failed := 0
var _passed := 0
var gs: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== DIRECTION TRAVEL VALIDATION ===")
	gs = root.get_node_or_null("/root/GameState")
	if gs == null:
		_fail("GameState missing")
		_finish()
		return

	gs.new_game()
	var run: Dictionary = gs.start_hunt_run("beginner_forest", true)
	if run.is_empty():
		_fail("hunt run empty")
		_finish()
		return
	_pass("hunt run started")

	root.set_meta("dungeon_id", "")
	root.set_meta("dungeon_floor", 0)
	root.set_meta("hunt_id", "beginner_forest")
	root.set_meta("combat_hunt_id", "beginner_forest")
	root.set_meta("hunt_force_new", false)

	var combat: Node = load("res://scenes/combat/combat.tscn").instantiate()
	root.add_child(combat)
	await process_frame
	await process_frame

	var ui = combat.get("_ui")
	if ui == null:
		_fail("combat UI missing")
		_finish()
		return

	var pad = ui.get("_dir_pad")
	if pad == null:
		_fail("direction pad not created")
		_finish()
		return
	if ui.has_method("refresh"):
		ui.refresh()
	await process_frame
	if bool(pad.visible):
		_fail("dir pad visible during fight")
	else:
		_pass("dir pad hidden during fight")

	# Force victory / clear current room.
	gs.mark_hunt_room_cleared()
	combat.phase = 2  # VICTORY
	if ui.has_method("refresh"):
		ui.refresh()
	await process_frame
	await process_frame

	if not bool(pad.visible):
		_fail("dir pad not visible after victory")
	else:
		_pass("dir pad visible after victory")

	var room: Dictionary = gs.get_current_hunt_room()
	var cons: Dictionary = room.get("connected_rooms", {})
	var shown := 0
	for d in ["N", "E", "S", "W"]:
		var btn: Button = pad.get("_buttons")[d]
		var o = cons.get(d, null)
		var expect := o != null and str(o) != ""
		if expect and btn.visible:
			shown += 1
			# pressed must be wired (pad._on_pressed and/or external).
			var conns: Array = btn.pressed.get_connections()
			if conns.is_empty():
				_fail("button %s has no pressed connections" % d)
			else:
				_pass("button %s pressed connected (%d)" % [d, conns.size()])
		elif not expect and not btn.visible:
			pass
		elif expect and not btn.visible:
			_fail("missing button for connected %s" % d)
		elif not expect and btn.visible:
			_fail("button shown for null %s" % d)
	if shown > 0:
		_pass("connected dirs shown=%d" % shown)
	else:
		_fail("no connected direction buttons")

	# Disconnected room id blocked at GameState.
	if gs.hunt_can_move_to("room_no_such"):
		_fail("disconnected room incorrectly allowed")
	else:
		_pass("disconnected room blocked")

	# Null-direction button must stay hidden — click path cannot move that way.
	for d in ["N", "E", "S", "W"]:
		var o = cons.get(d, null)
		if o == null or str(o) == "":
			var btn_null: Button = pad.get("_buttons")[d]
			if btn_null.visible:
				_fail("null dir %s still visible" % d)
			else:
				_pass("null dir %s hidden (blocked)" % d)
			break

	# Real button press path → travel.
	var travel_dir := ""
	var target_id := ""
	for d in ["N", "E", "S", "W"]:
		var o = cons.get(d, null)
		if o != null and str(o) != "":
			travel_dir = str(d)
			target_id = str(o)
			break
	if travel_dir == "":
		_fail("no travel dir available")
		_finish()
		return

	if not gs.hunt_can_move_to(target_id):
		_fail("hunt_can_move_to false for connected %s" % target_id)
	else:
		_pass("hunt_can_move_to true for %s" % target_id)

	var before := str(gs.get_active_hunt_map().get("current_room_id", ""))
	var btn_go: Button = pad.get("_buttons")[travel_dir]
	if btn_go == null or not btn_go.visible or btn_go.disabled:
		_fail("travel button %s not clickable visible=%s disabled=%s" % [
			travel_dir, str(btn_go.visible if btn_go else false), str(btn_go.disabled if btn_go else true)
		])
		_finish()
		return

	# Same path as a player click: Button.pressed signal.
	btn_go.pressed.emit()
	await process_frame
	await process_frame
	await process_frame

	var after := str(gs.get_active_hunt_map().get("current_room_id", ""))
	if after != target_id:
		_fail("button click travel %s expected %s got %s (from %s)" % [travel_dir, target_id, after, before])
	else:
		_pass("button click travelled %s → %s" % [travel_dir, after])

	var dest: Dictionary = gs.get_current_hunt_room()
	var cleared := bool(dest.get("cleared", false))
	var phase_name := str(combat.get_phase_name())
	if cleared:
		if phase_name == "victory":
			_pass("cleared room revisit stays victory (no fight)")
		else:
			_fail("cleared room phase=%s" % phase_name)
	else:
		if phase_name == "fighting":
			_pass("uncleared room starts fighting after click travel")
		else:
			_fail("uncleared room phase=%s" % phase_name)

	# Cleared-room revisit: mark current, open pad, travel to a cleared neighbor if any;
	# otherwise clear current and travel back.
	await _test_cleared_revisit(combat, ui, pad)

	# Dungeon mode must not travel via hunt pad API.
	var cur_before_dungeon := str(gs.get_active_hunt_map().get("current_room_id", ""))
	combat.dungeon_id = "crypt"
	combat.dungeon_floor = 1
	# Restore victory + pad visible attempt then click — is_hunt_combat should be false.
	combat.phase = 2
	if ui.has_method("refresh"):
		ui.refresh()
	await process_frame
	# Even if a button is somehow visible, travel_hunt_direction must no-op.
	combat.travel_hunt_direction(travel_dir)
	await process_frame
	var cur_after_dungeon := str(gs.get_active_hunt_map().get("current_room_id", ""))
	if cur_before_dungeon == cur_after_dungeon:
		_pass("dungeon mode blocks hunt direction travel")
	else:
		_fail("dungeon mode still travelled")

	_finish()


func _test_cleared_revisit(combat: Node, ui, pad) -> void:
	# Reset dungeon flags so hunt travel works again.
	combat.dungeon_id = ""
	combat.dungeon_floor = 0
	# Clear current room, force victory, pick a neighbor, clear it first via GameState,
	# move there by button, expect victory / no new fight.
	gs.mark_hunt_room_cleared()
	var cur: Dictionary = gs.get_current_hunt_room()
	var cons: Dictionary = cur.get("connected_rooms", {})
	var next_id := ""
	var next_dir := ""
	for d in ["N", "E", "S", "W"]:
		var o = cons.get(d, null)
		if o != null and str(o) != "":
			next_id = str(o)
			next_dir = str(d)
			break
	if next_id == "":
		_fail("cleared revisit: no neighbor")
		return
	# Mark neighbor cleared without moving, then move.
	var map: Dictionary = gs.get_active_hunt_map()
	var rooms: Dictionary = map.get("rooms", {})
	if rooms.has(next_id):
		rooms[next_id]["cleared"] = true
		rooms[next_id]["discovered"] = true
	combat.phase = 2
	if ui.has_method("refresh"):
		ui.refresh()
	await process_frame
	var btn: Button = pad.get("_buttons")[next_dir]
	if btn == null or not btn.visible:
		# refresh may leave pad hidden if phase mismatch — force refresh after victory
		if ui.has_method("refresh"):
			ui.refresh()
		await process_frame
		btn = pad.get("_buttons")[next_dir]
	if btn == null or not btn.visible or btn.disabled:
		# Fallback: API after ensuring can_move
		if gs.hunt_can_move_to(next_id):
			combat.travel_hunt_room(next_id)
			await process_frame
			if str(combat.get_phase_name()) == "victory":
				_pass("cleared revisit via API stays victory")
			else:
				_fail("cleared revisit via API phase=%s" % str(combat.get_phase_name()))
		else:
			_fail("cleared revisit: cannot move to cleared neighbor")
		return
	btn.pressed.emit()
	await process_frame
	await process_frame
	if str(gs.get_active_hunt_map().get("current_room_id", "")) != next_id:
		_fail("cleared revisit: did not arrive at %s" % next_id)
	elif str(combat.get_phase_name()) == "victory":
		_pass("cleared revisit via button stays victory (no fight)")
	else:
		_fail("cleared revisit phase=%s" % str(combat.get_phase_name()))


func _pass(msg: String) -> void:
	_passed += 1
	print("PASS: ", msg)


func _fail(msg: String) -> void:
	_failed += 1
	print("FAIL: ", msg)


func _finish() -> void:
	print("=== DIRECTION TRAVEL RESULT: %s (%d pass / %d fail) ===" % [
		"PASS" if _failed == 0 else "FAIL", _passed, _failed
	])
	quit(0 if _failed == 0 else 1)
