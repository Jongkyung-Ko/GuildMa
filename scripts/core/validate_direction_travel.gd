extends SceneTree

## Headless: hunt N/E/S/W direction pad + travel via GameState.hunt_can/move_to.
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

	# During fight — pad must be hidden.
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
	var hidden_null := 0
	for d in ["N", "E", "S", "W"]:
		var btn: Button = pad.get("_buttons")[d]
		var o = cons.get(d, null)
		var expect := o != null and str(o) != ""
		if expect and btn.visible:
			shown += 1
		elif not expect and not btn.visible:
			hidden_null += 1
		elif expect and not btn.visible:
			_fail("missing button for connected %s" % d)
		elif not expect and btn.visible:
			_fail("button shown for null %s" % d)
	if shown > 0:
		_pass("connected dirs shown=%d null-hidden ok" % shown)
	else:
		_fail("no connected direction buttons")

	# Pick a connected direction and travel.
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

	# Disconnected id must fail.
	if gs.hunt_can_move_to("room_no_such"):
		_fail("disconnected room incorrectly allowed")
	else:
		_pass("disconnected room blocked")

	var before := str(gs.get_active_hunt_map().get("current_room_id", ""))
	combat.travel_hunt_direction(travel_dir)
	await process_frame
	await process_frame
	var after := str(gs.get_active_hunt_map().get("current_room_id", ""))
	if after != target_id:
		_fail("travel %s expected %s got %s (from %s)" % [travel_dir, target_id, after, before])
	else:
		_pass("travelled %s → %s" % [travel_dir, after])

	# Cleared destination stays victory + pad; uncleared starts fight.
	var dest: Dictionary = gs.get_current_hunt_room()
	var cleared := bool(dest.get("cleared", false))
	var phase_name := str(combat.get_phase_name())
	if cleared:
		if phase_name == "victory":
			_pass("cleared room stays victory")
		else:
			_fail("cleared room phase=%s" % phase_name)
	else:
		if phase_name == "fighting":
			_pass("uncleared room starts fighting")
		else:
			_fail("uncleared room phase=%s" % phase_name)

	# Dungeon must not get pad travel (is_hunt_combat false with dungeon meta).
	# Soft check: travel_hunt_direction no-ops when not hunt.
	root.set_meta("dungeon_id", "crypt")
	root.set_meta("dungeon_floor", 1)
	# Re-instantiate isn't needed; is_hunt_combat checks dungeon_id on manager.
	# Manager already has hunt_id — simulate by clearing via direct call after setting dungeon fields.
	if combat.has_method("is_dungeon_combat"):
		# Manager reads dungeon_id from its own vars set at start — set them.
		combat.dungeon_id = "crypt"
		combat.dungeon_floor = 1
	var cur_before_dungeon := str(gs.get_active_hunt_map().get("current_room_id", ""))
	combat.travel_hunt_direction(travel_dir)
	await process_frame
	var cur_after_dungeon := str(gs.get_active_hunt_map().get("current_room_id", ""))
	if cur_before_dungeon == cur_after_dungeon:
		_pass("dungeon mode blocks hunt direction travel")
	else:
		_fail("dungeon mode still travelled")

	_finish()


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
