extends SceneTree

## In-game evidence for painted boss idle art (PR #24 art wiring).
## Real display required (x11). Captures 844×390 and 1366×768.
##
##   DISPLAY=:1 godot4 --path . --display-driver x11 -s res://scripts/core/capture_boss_assets.gd
##
## STORE_DIR can override evidence output (default Project store path below).

const OUT_RES := "docs/reviews/boss-assets/captures"
const DEFAULT_STORE := "/cursor/stores/bc-e37588d2-6890-4fb7-945a-c6a1997eb0b9/media/boss-assets/evidence"

const BOSS_SHOTS := [
	{"id": "fenrir", "mode": "hunt", "hunt_id": "beginner_forest"},
	{"id": "malkav", "mode": "hunt", "hunt_id": "blue_meadow"},
	{"id": "malachi", "mode": "hunt", "hunt_id": "twilight_ruins"},
	{"id": "gorgon", "mode": "hunt", "hunt_id": "cursed_marsh"},
	{"id": "lilith", "mode": "hunt", "hunt_id": "abyss_border"},
	{"id": "bone_golem", "mode": "dungeon", "floor": 5},
	{"id": "behemoth", "mode": "dungeon", "floor": 10},
	{"id": "vorak", "mode": "special", "encounter": "vorak_rift"},
	{"id": "morgana", "mode": "special", "encounter": "morgana_sanctum"},
]

const SIZES := [
	{"tag": "844x390", "w": 844, "h": 390},
	{"tag": "1366x768", "w": 1366, "h": 768},
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var ds := str(DisplayServer.get_name())
	print("=== BOSS ASSETS CAPTURE ===")
	print("DisplayServer: ", ds)
	if ds == "headless":
		printerr("ABORT: headless — refuse visual capture")
		quit(2)
		return

	var store := OS.get_environment("STORE_DIR")
	if store == "":
		store = DEFAULT_STORE
	var out_abs := ProjectSettings.globalize_path("res://" + OUT_RES)
	DirAccess.make_dir_recursive_absolute(out_abs)
	DirAccess.make_dir_recursive_absolute(store)

	var gs: Node = root.get_node_or_null("/root/GameState")
	if gs == null:
		printerr("ABORT: GameState missing")
		quit(2)
		return

	# Verify all 9 idle textures resolve before combat shots.
	var missing: Array = []
	for b in BOSS_SHOTS:
		var path := "res://assets/sprites/monsters/bosses/%s/idle.png" % str(b["id"])
		if not (ResourceLoader.exists(path) or FileAccess.file_exists(path)):
			missing.append(path)
			printerr("MISSING ", path)
		else:
			print("OK texture ", path)
	if not missing.is_empty():
		printerr("ABORT: missing textures ", missing)
		quit(2)
		return

	var win := root.get_window()
	for sz in SIZES:
		var target := Vector2i(int(sz["w"]), int(sz["h"]))
		if win:
			win.size = target
			win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
			win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
			win.content_scale_factor = 1.0
		DisplayServer.window_set_size(target)
		var ui: Node = root.get_node_or_null("/root/UIStyle")
		if ui and ui.has_method("_apply_display_adapt"):
			ui.call("_apply_display_adapt")
		await process_frame
		await process_frame
		await process_frame
		print("SIZE ", sz["tag"], " win=", win.size if win else Vector2i.ZERO)
		# Fenrir first (README), then rest.
		for entry in BOSS_SHOTS:
			gs.new_game()
			# Unlock special gates for capture only (does not change shipped logic files beyond this script).
			gs.bosses_cleared["lilith"] = true
			gs.bosses_cleared["behemoth"] = true
			gs.hunt_progress["cursed_marsh"] = {"goal_boss_cleared": true}
			await _capture_boss(gs, entry, str(sz["tag"]), out_abs, store)

	print("=== BOSS ASSETS CAPTURE DONE === store=", store)
	quit(0)


func _capture_boss(gs: Node, entry: Dictionary, size_tag: String, out_abs: String, store: String) -> void:
	var bid := str(entry["id"])
	root.set_meta("hunt_id", "")
	root.set_meta("dungeon_id", "")
	root.set_meta("dungeon_floor", 0)
	root.set_meta("special_encounter_id", "")
	root.set_meta("hunt_force_new", false)
	root.set_meta("hunt_spawn_at_start", true)

	match str(entry["mode"]):
		"hunt":
			var hid := str(entry["hunt_id"])
			# Build maze, jump to boss room, then enter combat WITHOUT spawn_at_start reset.
			root.set_meta("hunt_id", hid)
			root.set_meta("combat_hunt_id", hid)
			var map: Dictionary = gs.start_hunt_run(hid, true, true)
			var boss_rid := ""
			for rid in map.get("rooms", {}).keys():
				var r: Dictionary = map["rooms"][rid]
				if str(r.get("room_type", "")) == "boss":
					boss_rid = str(rid)
					break
			if boss_rid != "":
				map["current_room_id"] = boss_rid
				map["rooms"][boss_rid]["discovered"] = true
				map["rooms"][boss_rid]["cleared"] = false
				var prog: Dictionary = gs.hunt_progress.get(hid, {})
				prog["map"] = map
				prog["pending_spawn_at_start"] = false
				gs.hunt_progress[hid] = prog
				gs.active_hunt_id = hid
			root.set_meta("hunt_force_new", false)
			root.set_meta("hunt_spawn_at_start", false)
		"dungeon":
			var floor := int(entry["floor"])
			gs.ensure_dungeon_progress("shadow_crypt")
			for f in range(1, floor):
				gs.mark_dungeon_floor_cleared("shadow_crypt", f)
			gs.dungeon_set_floor("shadow_crypt", floor)
			root.set_meta("dungeon_id", "shadow_crypt")
			root.set_meta("dungeon_floor", floor)
			root.set_meta("combat_hunt_id", "dungeon_shadow_crypt_f%d" % floor)
		"special":
			var enc := str(entry["encounter"])
			root.set_meta("special_encounter_id", enc)
			root.set_meta("combat_hunt_id", "special_%s" % enc)

	var combat: Node = load("res://scenes/combat/combat.tscn").instantiate()
	root.add_child(combat)
	await process_frame
	await process_frame
	await process_frame
	# Settle so boss art is visible mid-field.
	var t := 0.0
	while t < 1.2:
		await process_frame
		t += 1.0 / 60.0

	var fname := "%s_%s.png" % [bid, size_tag]
	await _shot(combat, fname, out_abs, store)
	# Sanity: active boss present + painted idle path
	var boss = combat.get_active_boss() if combat.has_method("get_active_boss") else null
	if boss == null:
		printerr("WARN: no active boss for ", bid)
	else:
		print("SHOT ", fname, " boss=", boss.display_name, " kind=", boss.enemy_kind)

	combat.queue_free()
	await process_frame
	await process_frame


func _shot(combat: Node, filename: String, out_abs: String, store: String) -> void:
	RenderingServer.force_draw(true)
	await process_frame
	await process_frame
	var img: Image = combat.get_viewport().get_texture().get_image()
	if img == null or img.get_width() < 2:
		printerr("FAIL null image ", filename)
		return
	var p1 := "%s/%s" % [out_abs, filename]
	var p2 := "%s/%s" % [store, filename]
	var err1 := img.save_png(p1)
	var err2 := img.save_png(p2)
	print("WROTE ", p2, " ", img.get_width(), "x", img.get_height(), " err=", err1, "/", err2)
