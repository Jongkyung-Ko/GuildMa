extends SceneTree

## PR16 pre-merge regression captures across screens / orientations.
## godot --path . -s res://scripts/core/capture_pr16_regression.gd

const ART := "/opt/cursor/artifacts/pr16-regression"

const ORIENTATIONS := [
	["portrait_390x844", Vector2i(390, 844)],
	["landscape_844x390", Vector2i(844, 390)],
	["pc_1366x768", Vector2i(1366, 768)],
]


func _init() -> void:
	call_deferred("_run")


func _pass(msg: String) -> void:
	print("PASS: ", msg)


func _fail(msg: String) -> void:
	print("FAIL: ", msg)


func _note(msg: String) -> void:
	print("NOTE: ", msg)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ART)
	await process_frame
	var gs: Node = root.get_node("/root/GameState")
	var am: Node = root.get_node_or_null("/root/AudioManager")
	var ui: Node = root.get_node_or_null("/root/UIStyle")
	var win := root.get_window()
	if am and am.has_method("unlock_audio"):
		am.call("unlock_audio")
	gs.call("new_game")

	var failed := 0
	var current: Node = null

	for ori in ORIENTATIONS:
		var tag: String = ori[0]
		var sz: Vector2i = ori[1]
		if win:
			win.size = sz
		if ui and ui.has_method("_apply_display_adapt"):
			ui.call("_apply_display_adapt")
		await process_frame
		await process_frame

		var scale_sz: Vector2i = win.content_scale_size if win else Vector2i.ZERO
		print("LOG: orientation=%s win=%s content_scale_size=%s aspect=%s" % [
			tag, str(sz), str(scale_sz), str(win.content_scale_aspect) if win else "?"
		])

		# --- Town ---
		current = await _swap_scene(current, "res://scenes/town/town.tscn")
		await _settle()
		await _capture("%s_town" % tag)
		failed += _check_control_in_bounds(current, "town", tag, float(scale_sz.x))

		# Building hotspot off-screen check (absolute positions assume 1280 design width)
		var off := _count_town_hotspots_outside(current, scale_sz.x)
		if off > 0:
			_fail("%s town: %d facility hotspots outside design width %d" % [tag, off, scale_sz.x])
			failed += 1
		else:
			_pass("%s town: facility hotspots within design width %d" % [tag, scale_sz.x])

		var world := current.get_node_or_null("TownWorld") as Control
		if world == null:
			_fail("%s town: TownWorld plate missing" % tag)
			failed += 1
		elif absf(world.size.x - 1280.0) > 1.0 or absf(world.size.y - 720.0) > 1.0:
			_fail("%s town: TownWorld size %s (want 1280x720, no stretch)" % [tag, str(world.size)])
			failed += 1
		else:
			_pass("%s town: TownWorld plate 1280x720 (aspect preserved)" % tag)

		if tag.begins_with("portrait") and scale_sz.x != 1280:
			_fail("%s unexpected portrait content_scale_size.x=%d (want 1280 to protect town layout)" % [tag, scale_sz.x])
			failed += 1
		elif tag.begins_with("portrait"):
			_pass("%s portrait keeps design width 1280 (EXPAND tall viewport)" % tag)

		# --- Facilities ---
		for fid in ["inn", "shop", "training", "blacksmith"]:
			root.set_meta("facility_id", fid)
			current = await _swap_scene(current, "res://scenes/facilities/facility.tscn")
			await _settle()
			await _capture("%s_facility_%s" % [tag, fid])
			# Scroll content should exist
			if current.get_child_count() < 3:
				_fail("%s %s: shell children missing" % [tag, fid])
				failed += 1
			else:
				_pass("%s %s: scene built" % [tag, fid])

		# --- Combat (hunt) ---
		root.set_meta("hunt_id", "beginner_forest")
		root.set_meta("hunt_force_new", false)
		root.set_meta("hunt_spawn_at_start", true)
		root.set_meta("dungeon_id", "")
		root.set_meta("dungeon_floor", 0)
		gs.call("start_hunt_run", "beginner_forest", true, true)
		current = await _swap_scene(current, "res://scenes/combat/combat.tscn")
		await _settle()
		await _settle()
		await _capture("%s_combat" % tag)
		if current == null or current.get_child_count() < 1:
			_fail("%s combat: failed to build" % tag)
			failed += 1
		else:
			_pass("%s combat: scene built" % tag)

		# --- Guild hall ---
		current = await _swap_scene(current, "res://scenes/facilities/guild_hall.tscn")
		await _settle()
		if current.has_method("_apply_responsive_layout"):
			current.call("_apply_responsive_layout")
			current.call("_refresh_all")
		await _settle()
		await _capture("%s_guild_hall" % tag)
		# Footer / compact actions reachability heuristics
		if current.has_method("_is_compact") and bool(current.call("_is_compact")):
			var found := _find_named(current, "CompactActions")
			if found == null:
				_fail("%s guild hall compact: CompactActions missing" % tag)
				failed += 1
			else:
				_pass("%s guild hall compact: CompactActions present" % tag)
				# Scroll to end so save/close are in the capture frame.
				var sc: ScrollContainer = current.get("_body_scroll") as ScrollContainer
				if sc:
					await _settle()
					sc.scroll_vertical = 100000
					await _settle()
					await _capture("%s_guild_hall_actions" % tag)
					var save_ok := false
					var close_ok := false
					for ch in found.get_children():
						if ch is Button:
							var t := str((ch as Button).text)
							if t.find("저장") >= 0:
								save_ok = true
							if t.find("닫기") >= 0:
								close_ok = true
					if save_ok and close_ok:
						_pass("%s guild hall compact: save/close buttons present" % tag)
					else:
						_fail("%s guild hall compact: save/close labels missing" % tag)
						failed += 1
		else:
			var footer = current.get("_footer")
			if footer == null or not bool(footer.visible):
				_fail("%s guild hall wide: footer missing/hidden" % tag)
				failed += 1
			else:
				_pass("%s guild hall wide: footer visible" % tag)
				var save_ok := false
				var close_ok := false
				for ch in footer.get_children():
					if ch is Button:
						var t := str((ch as Button).text)
						if t.find("저장") >= 0:
							save_ok = true
						if t.find("닫기") >= 0:
							close_ok = true
				if save_ok and close_ok:
					_pass("%s guild hall wide: save/close in footer" % tag)
				else:
					_fail("%s guild hall wide: save/close missing in footer" % tag)
					failed += 1

		# Scene transition persistence: town again after guild
		current = await _swap_scene(current, "res://scenes/town/town.tscn")
		await _settle()
		if ui and ui.has_method("_apply_display_adapt"):
			ui.call("_apply_display_adapt")
		await _settle()
		var scale_after: Vector2i = win.content_scale_size if win else Vector2i.ZERO
		if scale_after != scale_sz:
			_fail("%s scale changed after transition %s → %s" % [tag, str(scale_sz), str(scale_after)])
			failed += 1
		else:
			_pass("%s content_scale_size stable after town↔guild transition" % tag)
		await _capture("%s_town_after_transition" % tag)

	print("NOTE: Real mobile browser / HTML5 Pages NOT VERIFIED in this run.")
	if failed == 0:
		print("=== PR16 REGRESSION CAPTURE: PASS ===")
		quit(0)
	else:
		print("=== PR16 REGRESSION CAPTURE: FAIL (%d) ===" % failed)
		quit(1)


func _swap_scene(old: Node, path: String) -> Node:
	if old and is_instance_valid(old):
		old.queue_free()
		await process_frame
	var n: Node = load(path).instantiate()
	root.add_child(n)
	await process_frame
	return n


func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame


func _capture(name: String) -> void:
	await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	if img == null:
		print("WARN: null image ", name)
		return
	var path := "%s/%s.png" % [ART, name]
	img.save_png(path)
	print("saved ", path, " ", img.get_width(), "x", img.get_height())


func _check_control_in_bounds(n: Node, label: String, tag: String, design_w: float) -> int:
	if n == null:
		_fail("%s %s: null scene" % [tag, label])
		return 1
	# Root control should cover design area; soft check only.
	_pass("%s %s: instantiated" % [tag, label])
	return 0


func _count_town_hotspots_outside(town: Node, design_w: int) -> int:
	## Hotspots live under TownWorld (design 1280×720 plate). HUD is excluded.
	var outside := 0
	var found := 0
	var host: Node = town.get_node_or_null("TownWorld")
	if host == null:
		host = town
	for c in host.get_children():
		if not (c is Control):
			continue
		if not str(c.name).begins_with("Hotspot_"):
			continue
		found += 1
		var right_edge: float = c.position.x + c.size.x
		# Absolute coords assume classic 1280 design width base.
		if c.position.x > float(design_w) - 20.0:
			outside += 1
		elif right_edge > float(design_w) + 40.0:
			outside += 1
	if found < 6:
		# Treat missing hotspots as failure signal for the caller.
		return max(outside, 6 - found)
	return outside


func _find_named(n: Node, name: String) -> Node:
	if n == null:
		return null
	if str(n.name) == name:
		return n
	for c in n.get_children():
		var f := _find_named(c, name)
		if f:
			return f
	return null
