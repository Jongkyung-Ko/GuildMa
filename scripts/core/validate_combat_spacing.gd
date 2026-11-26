extends SceneTree

## Validates ally spacing mid-combat and captures screenshots.
## Run: xvfb-run -a godot --path . -s res://scripts/core/validate_combat_spacing.gd

const OUT := "/opt/cursor/artifacts/guildma-combat-fix"
const MIN_OK := 72.0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	await process_frame
	var gs: Node = root.get_node_or_null("/root/GameState")
	if gs == null:
		push_error("GameState autoload missing")
		quit(2)
		return
	gs.call("new_game")
	var combat_ps: PackedScene = load("res://scenes/combat/combat.tscn")
	var combat: Node = combat_ps.instantiate()
	root.add_child(combat)
	await process_frame
	await process_frame
	await process_frame

	var mgr: Node = combat
	var ok := true
	var min_seen := 9999.0
	for frame in range(1, 240):
		await process_frame
		if frame in [30, 90, 150]:
			var allies: Array = mgr.call("get_allies")
			var enemies: Array = mgr.call("get_enemies")
			_log_positions(frame, allies, enemies)
			var m := _min_pair_dist(allies)
			min_seen = minf(min_seen, m)
			print("frame=%d min_ally_dist=%.1f" % [frame, m])
			if m < MIN_OK:
				ok = false
				print("FAIL: allies too close (%.1f < %.1f)" % [m, MIN_OK])
			await _capture("combat_f%03d" % frame)
		if str(mgr.call("get_phase_name")) != "fighting":
			break

	await _capture("combat_end")
	print("min_ally_dist_seen=%.1f" % min_seen)
	print("=== SPACING RESULT: %s ===" % ("PASS" if ok and min_seen >= MIN_OK else "FAIL"))
	quit(0 if ok and min_seen >= MIN_OK else 1)


func _min_pair_dist(allies: Array) -> float:
	var best := 9999.0
	for i in range(allies.size()):
		var a: Node2D = allies[i]
		if a == null or ("is_dead" in a and a.is_dead):
			continue
		for j in range(i + 1, allies.size()):
			var b: Node2D = allies[j]
			if b == null or ("is_dead" in b and b.is_dead):
				continue
			best = minf(best, a.global_position.distance_to(b.global_position))
	return best


func _log_positions(frame: int, allies: Array, enemies: Array) -> void:
	print("--- frame %d ---" % frame)
	for a in allies:
		if a:
			print("  ally %s job=%s pos=(%.0f,%.0f) dead=%s" % [
				a.display_name if "display_name" in a else a.name,
				a.job if "job" in a else "?",
				a.global_position.x, a.global_position.y,
				str(a.is_dead) if "is_dead" in a else "?"
			])
	for e in enemies:
		if e:
			print("  enemy %s pos=(%.0f,%.0f) dead=%s" % [
				e.display_name if "display_name" in e else e.name,
				e.global_position.x, e.global_position.y,
				str(e.is_dead) if "is_dead" in e else "?"
			])


func _capture(tag: String) -> void:
	await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	if img == null:
		print("WARN: no image for ", tag)
		return
	var path := "%s/%s.png" % [OUT, tag]
	img.save_png(path)
	print("SHOT ", path)
