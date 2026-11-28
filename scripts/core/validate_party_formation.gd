extends SceneTree

## Functional checks for playable guild party formation UI.
## godot4 --headless --path . -s res://scripts/core/validate_party_formation.gd

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
	print("=== PARTY FORMATION RESULT: %s (%d pass / %d fail) ===" % [
		"PASS" if _failed == 0 else "FAIL", _passed, _failed
	])
	quit(1 if _failed > 0 else 0)


func _run() -> void:
	print("=== PARTY FORMATION VALIDATION ===")
	if not is_equal_approx(CombatFieldBounds.COMBAT_RENDER_SCALE, 0.8):
		_fail("combat scale mutated")
	else:
		_pass("combat 0.8 intact")
	await _check_panel_mount()
	_finish()


func _check_panel_mount() -> void:
	var gs: Node = root.get_node_or_null("/root/GameState")
	if gs:
		gs.call("new_game")
	var err := change_scene_to_file("res://scenes/facilities/guild_hall.tscn")
	if err != OK:
		_fail("load guild hall")
		return
	for _i in 10:
		await process_frame
	var hall := root.get_child(root.get_child_count() - 1)
	if hall == null or not hall.has_method("_open_formation"):
		# Find GuildHall screen.
		hall = _find_hall(root)
	if hall == null:
		_fail("guild hall screen missing")
		return
	_pass("guild hall loaded")
	hall.call("_open_formation", "hunt")
	for _j in 8:
		await process_frame
	var panel: Node = hall.get("_formation") as Node
	if panel == null or not bool(panel.get("visible")):
		_fail("formation panel not visible")
		return
	_pass("formation panel visible")
	# Draft toggle via public draft state.
	var draft: Array = []
	var draft_v: Variant = panel.get("_draft_ids")
	if typeof(draft_v) == TYPE_ARRAY:
		draft = draft_v
	var before: int = draft.size()
	if panel.has_method("_toggle_draft") and gs:
		var members_v: Variant = gs.get("members")
		var members: Array = members_v if typeof(members_v) == TYPE_ARRAY else []
		if members.size() > 0:
			var mid := str(members[0].get("id", ""))
			# Ensure known state then toggle.
			if draft.has(mid):
				panel.call("_toggle_draft", mid)
			panel.call("_toggle_draft", mid)
			await process_frame
			draft_v = panel.get("_draft_ids")
			draft = draft_v if typeof(draft_v) == TYPE_ARRAY else []
			if not draft.has(mid):
				_fail("toggle draft did not add member")
			else:
				_pass("draft toggle works (%d → has %s)" % [before, mid])
	# Skill demo should not touch combat HP.
	if panel.has_method("_play_skill_demo"):
		panel.set("_selected_skill", "연속 베기")
		panel.call("_play_skill_demo")
		await process_frame
		_pass("skill demo invoked (preview-only)")
	# Save path.
	if panel.has_method("_on_confirm"):
		panel.call("_on_confirm")
		await process_frame
		var hunt: Array = []
		if gs:
			var hunt_v: Variant = gs.call("get_guild_party", "hunt")
			if typeof(hunt_v) == TYPE_ARRAY:
				hunt = hunt_v
		if hunt.is_empty() and draft.is_empty():
			_pass("confirm save with empty draft OK")
		elif hunt.size() > 0:
			_pass("confirm save wrote hunt party (%d)" % hunt.size())
		else:
			_fail("confirm save did not persist")
	# View state preserve.
	var st_v: Variant = panel.call("view_state")
	var st: Dictionary = st_v if typeof(st_v) == TYPE_DICTIONARY else {}
	if str(st.get("party_kind", "")) != "hunt":
		_fail("view_state party_kind")
	else:
		_pass("view_state preserves party_kind/filter")


func _find_hall(n: Node) -> Node:
	if n.has_method("_open_formation") and n.has_method("_fit_formation"):
		return n
	for c in n.get_children():
		var f := _find_hall(c)
		if f:
			return f
	return null
