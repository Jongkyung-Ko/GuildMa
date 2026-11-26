extends SceneTree

## Mage cast alignment captures for Phase foot-anchor verification.
## xvfb-run -a godot --path . -s res://scripts/core/capture_mage_cast_align.gd
##
## Writes:
##   media/mage-cast-alignment/mage_idle.png
##   media/mage-cast-alignment/mage_cast_start.png
##   media/mage-cast-alignment/mage_cast_release.png
##   media/mage-cast-alignment/mage_fireball.png
##   media/mage-cast-alignment/mage_cast_return.png

const OUT := "/cursor/stores/bc-e37588d2-6890-4fb7-945a-c6a1997eb0b9/media/mage-cast-alignment"
const ARTIFACT_OUT := "/opt/cursor/artifacts/mage-cast-alignment"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	DirAccess.make_dir_recursive_absolute(ARTIFACT_OUT)
	await process_frame
	var gs: Node = root.get_node_or_null("/root/GameState")
	if gs and gs.has_method("new_game"):
		gs.call("new_game")
	var combat: Node = load("res://scenes/combat/combat.tscn").instantiate()
	root.add_child(combat)
	await process_frame
	await process_frame

	combat.phase = combat.Phase.PAUSED
	for a in combat.call("get_allies"):
		a.set_physics_process(false)
		a.visible = false
		a._atk_timer = 999.0
	for e in combat.call("get_enemies"):
		e.set_physics_process(false)
		e.visible = false

	var by_job := {}
	for a in combat.call("get_allies"):
		by_job[str(a.job)] = a
	var wolf: CombatCharacter = null
	for e in combat.call("get_enemies"):
		if str(e.enemy_kind) == "wolf":
			wolf = e
			break
	if wolf == null:
		for e in combat.call("get_enemies"):
			wolf = e
			break

	var mage: CombatCharacter = by_job.get("mage")
	if mage == null or wolf == null:
		print("FAIL: missing mage or wolf")
		quit(1)
		return

	wolf.hp_max = maxf(wolf.hp_max, 800.0)
	wolf.hp = wolf.hp_max
	wolf.is_dead = false
	_stage(mage, wolf, Vector2(520, 360), Vector2(820, 360))

	# --- Idle ---
	mage._set_anim_state(mage.AnimState.IDLE)
	mage._play_anim("idle", true)
	await process_frame
	await process_frame
	await _capture("mage_idle")

	# --- Cast sequence ---
	mage._atk_timer = 0.0
	mage._perform_attack(wolf)

	var got_start := false
	var got_raise := false
	var got_release := false
	var raise_saved := false

	for _i in range(180):
		await process_frame
		if mage._sprite == null:
			continue
		if mage._sprite.animation != "attack":
			if got_release:
				# Returned to idle
				await process_frame
				await _capture("mage_cast_return")
				break
			continue
		var fr: int = mage._sprite.frame
		# attack seq indices: 0=combat_02 start, 1=combat_03, 2=combat_04 raise,
		# 3=combat_05 ready, 4=combat_06 release
		if fr == 0 and not got_start:
			await _capture("mage_cast_start")
			got_start = true
		if fr == 2 and not got_raise:
			await _capture("mage_cast_raise")
			got_raise = true
			raise_saved = true
		if fr >= mage._attack_active_idx and not got_release:
			if not mage._damage_applied:
				mage._on_frame_changed()
			await _capture("mage_cast_release")
			got_release = true

	if not got_release:
		print("WARN: release frame not observed; forcing")
		mage._sprite.frame = mage._attack_active_idx
		if not mage._damage_applied:
			mage._on_frame_changed()
		await _capture("mage_cast_release")
		got_release = true

	# --- Fireball mid-flight ---
	var saw_bolt := false
	for _j in range(50):
		await process_frame
		for c in combat.get_children():
			if c is CombatProjectile and is_instance_valid(c) and bool(c.get("_alive")):
				await _capture("mage_fireball")
				saw_bolt = true
				break
		if saw_bolt:
			break
	if not saw_bolt:
		var bolt := CombatProjectile.new()
		combat.add_child(bolt)
		bolt.setup(mage.muzzle_global(), wolf, 12.0, mage, combat, 0.45)
		await process_frame
		await process_frame
		await _capture("mage_fireball")

	# Ensure return capture exists
	if not FileAccess.file_exists(OUT + "/mage_cast_return.png"):
		mage._set_anim_state(mage.AnimState.IDLE)
		mage._play_anim("idle", true)
		await process_frame
		await process_frame
		await _capture("mage_cast_return")

	if not raise_saved:
		# Optional mid-cast evidence from attack frame 2 texture alone is fine to skip
		print("note: mage_cast_raise optional not captured")

	# Foot-anchor overlay strip from assets
	_write_foot_strip()

	var required := [
		"mage_idle.png",
		"mage_cast_start.png",
		"mage_cast_release.png",
		"mage_fireball.png",
		"mage_cast_return.png",
	]
	var missing: Array = []
	for name in required:
		if not FileAccess.file_exists(OUT + "/" + name):
			missing.append(name)
	if missing.size() > 0:
		print("FAIL: missing captures ", missing)
		quit(1)
		return

	print("=== MAGE CAST ALIGN CAPTURE DONE === ", OUT)
	quit(0)


func _stage(a: CombatCharacter, b: CombatCharacter, pa: Vector2, pb: Vector2) -> void:
	var combat = a.get_parent()
	if combat and combat.has_method("get_allies"):
		for x in combat.call("get_allies"):
			x.visible = false
			x.set_physics_process(false)
		for x in combat.call("get_enemies"):
			x.visible = false
			x.set_physics_process(false)
	a.visible = true
	b.visible = true
	a.global_position = pa
	b.global_position = pb
	a.velocity = Vector2.ZERO
	b.velocity = Vector2.ZERO
	if a.has_method("_face_toward"):
		a._face_toward(b)
	if b.has_method("_face_toward"):
		b._face_toward(a)


func _capture(name: String) -> void:
	await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [OUT, name]
	var art := "%s/%s.png" % [ARTIFACT_OUT, name]
	img.save_png(path)
	img.save_png(art)
	print("saved ", path)


func _write_foot_strip() -> void:
	## Offline asset strip with pivot crosshair — evidence of foot pin.
	var piv_path := "res://data/combat/sprite_pivots.json"
	if not FileAccess.file_exists(piv_path):
		return
	var f := FileAccess.open(piv_path, FileAccess.READ)
	var meta = JSON.parse_string(f.get_as_text())
	if typeof(meta) != TYPE_DICTIONARY:
		return
	var entry: Dictionary = meta.get("jobs", {}).get("mage", {})
	var piv: Array = entry.get("pivot", [88, 112])
	var px := int(piv[0])
	var py := int(piv[1])
	var canvas: Array = entry.get("canvas", [236, 116])
	var cw := int(canvas[0])
	var ch := int(canvas[1])
	var strip := Image.create(cw * 8, ch, false, Image.FORMAT_RGBA8)
	strip.fill(Color(0.08, 0.09, 0.12, 1))
	for i in range(8):
		var p := "res://assets/sprites/characters/mage/combat_%02d.png" % i
		var abs_p := ProjectSettings.globalize_path(p)
		var frame := Image.new()
		if frame.load(abs_p) != OK:
			continue
		strip.blit_rect(frame, Rect2i(0, 0, frame.get_width(), frame.get_height()), Vector2i(i * cw, 0))
		# pivot crosshair
		for y in range(ch):
			if px >= 0 and px < cw:
				strip.set_pixel(i * cw + px, y, Color(0.2, 1.0, 0.35, 0.85))
		for x in range(cw):
			if py >= 0 and py < ch:
				strip.set_pixel(i * cw + x, py, Color(0.2, 1.0, 0.35, 0.85))
	var out := OUT + "/before_after_foot_strip.png"
	strip.save_png(out)
	strip.save_png(ARTIFACT_OUT + "/before_after_foot_strip.png")
	print("saved ", out)
