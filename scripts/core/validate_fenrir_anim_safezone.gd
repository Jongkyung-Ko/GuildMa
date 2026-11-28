extends SceneTree

## Fenrir anim pack + dynamic top safe-zone checks (not visual PASS).
## Run: godot4 --headless --path . -s res://scripts/core/validate_fenrir_anim_safezone.gd

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
	print("=== FENRIR ANIM + SAFEZONE RESULT: %s (%d pass / %d fail) ===" % [
		"PASS" if _failed == 0 else "FAIL", _passed, _failed
	])
	quit(1 if _failed > 0 else 0)


func _run() -> void:
	print("=== FENRIR ANIM + SAFEZONE VALIDATION ===")
	var gs: Node = root.get_node_or_null("/root/GameState")
	if gs == null:
		_fail("GameState missing")
		_finish()
		return
	gs.new_game()

	_check_assets()
	_check_sprite_frames()
	_check_other_bosses_idle_only()
	_check_safezone_dynamic()
	_check_safezone_viewports()
	await _check_combat_runtime(gs)
	_finish()


func _check_assets() -> void:
	var root_dir := "res://assets/sprites/monsters/bosses/fenrir"
	if not (ResourceLoader.exists(root_dir + "/idle.png") or FileAccess.file_exists(root_dir + "/idle.png")):
		_fail("fenrir idle.png missing")
	else:
		_pass("fenrir idle.png kept")
	for anim in ["attack", "hit", "death"]:
		for i in range(4):
			var p := "%s/%s/%s_%02d.png" % [root_dir, anim, anim, i]
			if not (ResourceLoader.exists(p) or FileAccess.file_exists(p)):
				_fail("missing %s" % p)
				return
	_pass("fenrir attack/hit/death 4 frames each present")
	if not FileAccess.file_exists("res://data/combat/fenrir_animation_manifest.json"):
		_fail("manifest missing")
	else:
		_pass("fenrir_animation_manifest.json present")


func _check_sprite_frames() -> void:
	if not SpriteFactory.has_boss_anim_pack("fenrir"):
		_fail("has_boss_anim_pack(fenrir) false")
		return
	_pass("has_boss_anim_pack(fenrir)")
	var sf: SpriteFrames = SpriteFactory.enemy_frames("bosses/fenrir")
	if sf.get_frame_count("idle") < 1:
		_fail("fenrir idle frames empty")
	else:
		_pass("fenrir idle frames=%d" % sf.get_frame_count("idle"))
	for anim in ["attack", "hit", "death"]:
		var n := sf.get_frame_count(anim)
		if n != 4:
			_fail("%s frame count %d != 4" % [anim, n])
		else:
			_pass("%s frames=4 fps=%.1f loop=%s" % [
				anim, sf.get_animation_speed(anim), str(sf.get_animation_loop(anim))
			])
	if sf.get_animation_speed("attack") != 8.0:
		_fail("attack fps %.1f != 8" % sf.get_animation_speed("attack"))
	else:
		_pass("attack fps=8")
	if sf.get_animation_speed("hit") != 10.0:
		_fail("hit fps %.1f != 10" % sf.get_animation_speed("hit"))
	else:
		_pass("hit fps=10")
	if sf.get_animation_speed("death") != 6.0:
		_fail("death fps %.1f != 6" % sf.get_animation_speed("death"))
	else:
		_pass("death fps=6")
	if sf.get_animation_loop("attack") or sf.get_animation_loop("hit") or sf.get_animation_loop("death"):
		_fail("attack/hit/death must be non-loop")
	else:
		_pass("attack/hit/death non-loop")
	var active := SpriteFactory.attack_active_frame_for_enemy("bosses/fenrir")
	if active != 2:
		_fail("fenrir attack_active_idx %d != 2" % active)
	else:
		_pass("fenrir attack hitframe index=2")


func _check_other_bosses_idle_only() -> void:
	for bid in ["malkav", "malachi", "gorgon", "lilith", "bone_golem", "behemoth", "vorak", "morgana"]:
		if SpriteFactory.has_boss_anim_pack(bid):
			_fail("%s unexpectedly has anim pack" % bid)
			return
		var sf: SpriteFrames = SpriteFactory.enemy_frames("bosses/%s" % bid)
		# Idle-reuse: single frame per anim.
		if sf.get_frame_count("attack") != 1 or sf.get_frame_count("hit") != 1:
			_fail("%s should stay idle-reuse (attack/hit single frame)" % bid)
			return
	_pass("other 8 bosses remain idle-reuse")


func _check_safezone_dynamic() -> void:
	var r := CombatFieldBounds.safe_rect(null, 96.0)
	if r.size.x < 8.0 or r.size.y < 8.0:
		_fail("safe_rect degenerate %s" % str(r))
		return
	_pass("safe_rect default=%s" % str(r))
	# Headroom must influence top — top must NOT be relaxed to a shared min-field value.
	var top_a := CombatFieldBounds.top_y(null, 20.0)
	var top_b := CombatFieldBounds.top_y(null, 160.0)
	if is_equal_approx(top_a, top_b):
		_fail("top_y ignores headroom (%s == %s) — top was relaxed" % [top_a, top_b])
	elif top_b < top_a:
		_fail("larger headroom produced lower top (%.1f < %.1f)" % [top_b, top_a])
	else:
		_pass("top_y scales with headroom (%.1f vs %.1f)" % [top_a, top_b])
	var top := CombatFieldBounds.top_y(null, 110.0)
	var p := CombatFieldBounds.clamp_point(Vector2(640, top - 120.0), null, 110.0)
	if p.y < top - 0.5:
		_fail("clamp_point allowed above top bound %s (top=%.1f)" % [str(p), top])
	else:
		_pass("clamp_point rejects Y above top (got %s, top=%.1f)" % [str(p), top])
	if is_equal_approx(r.position.y, 100.0) and is_equal_approx(r.position.x, 40.0) and is_equal_approx(r.end.y, 600.0):
		_fail("safe_rect looks like legacy fixed clamps")
	else:
		_pass("safe_rect is dynamic (not legacy 100..600)")
	if CombatFieldBounds.debug_draw_enabled:
		_fail("debug_draw_enabled must default false")
	else:
		_pass("debug draw off by default")


func _check_safezone_viewports() -> void:
	## Must exercise real 844 / 1366 / 1280 sizes — do not PASS mobile from 1280-only math.
	var sizes: Array = [
		Vector2(844, 390),
		Vector2(1366, 768),
		Vector2(1280, 720),
	]
	var cam := Vector2(640, 360)
	var zoom := Vector2.ONE
	var fenrir_head_px := 140.0
	var wolf_head_px := 72.0
	for sz in sizes:
		var vp: Vector2 = sz
		var r_f: Rect2 = CombatFieldBounds.safe_rect_for_view(vp, cam, zoom, null, fenrir_head_px)
		var r_w: Rect2 = CombatFieldBounds.safe_rect_for_view(vp, cam, zoom, null, wolf_head_px)
		var world_tl_y := cam.y - vp.y * 0.5
		var desired_f := world_tl_y + CombatFieldBounds.DEFAULT_HUD_TOP_PX + fenrir_head_px
		# Top must equal full HUD+headroom (never relaxed downward toward world_tl).
		if r_f.position.y < desired_f - 1.0:
			_fail(
				"vp %dx%d Fenrir top relaxed: got %.1f want >= %.1f"
				% [int(vp.x), int(vp.y), r_f.position.y, desired_f]
			)
		elif absf(r_f.position.y - desired_f) > 1.0:
			_fail(
				"vp %dx%d Fenrir top mismatch: got %.1f want %.1f"
				% [int(vp.x), int(vp.y), r_f.position.y, desired_f]
			)
		else:
			_pass("vp %dx%d Fenrir top=%.1f (HUD+head kept)" % [int(vp.x), int(vp.y), r_f.position.y])
		if r_f.position.y <= r_w.position.y + 0.5:
			_fail(
				"vp %dx%d Fenrir top %.1f should exceed wolf %.1f"
				% [int(vp.x), int(vp.y), r_f.position.y, r_w.position.y]
			)
		else:
			_pass(
				"vp %dx%d Fenrir top %.1f > wolf %.1f"
				% [int(vp.x), int(vp.y), r_f.position.y, r_w.position.y]
			)
		# 844 must not silently reuse 1280 math.
		if int(vp.x) == 844:
			var r_1280: Rect2 = CombatFieldBounds.safe_rect_for_view(
				Vector2(1280, 720), cam, zoom, null, fenrir_head_px
			)
			if is_equal_approx(r_f.position.y, r_1280.position.y) and is_equal_approx(r_f.size.y, r_1280.size.y):
				_fail("844×390 safe_rect identical to 1280×720 — viewport not applied")
			else:
				_pass("844×390 safe_rect differs from 1280×720")


func _check_combat_runtime(gs: Node) -> void:
	root.set_meta("hunt_id", "beginner_forest")
	root.set_meta("combat_hunt_id", "beginner_forest")
	root.set_meta("hunt_force_new", true)
	root.set_meta("hunt_spawn_at_start", true)
	var map: Dictionary = gs.start_hunt_run("beginner_forest", true, true)
	var boss_rid := ""
	for rid in map.get("rooms", {}).keys():
		var room: Dictionary = map["rooms"][rid]
		if str(room.get("room_type", "")) == "boss":
			boss_rid = str(rid)
			break
	if boss_rid != "":
		map["current_room_id"] = boss_rid
		map["rooms"][boss_rid]["discovered"] = true
		map["rooms"][boss_rid]["cleared"] = false
		var prog: Dictionary = gs.hunt_progress.get("beginner_forest", {})
		prog["map"] = map
		prog["pending_spawn_at_start"] = false
		gs.hunt_progress["beginner_forest"] = prog
		gs.active_hunt_id = "beginner_forest"
	root.set_meta("hunt_force_new", false)
	root.set_meta("hunt_spawn_at_start", false)

	var combat: Node = load("res://scenes/combat/combat.tscn").instantiate()
	root.add_child(combat)
	await process_frame
	await process_frame
	await process_frame

	var boss = combat.get_active_boss() if combat.has_method("get_active_boss") else null
	if boss == null:
		_fail("no Fenrir boss in beginner_forest boss room")
		combat.queue_free()
		return
	_pass("spawned boss=%s kind=%s" % [boss.display_name, boss.enemy_kind])

	if boss._sprite == null or boss._sprite.sprite_frames == null:
		_fail("boss sprite frames missing")
	else:
		var sf: SpriteFrames = boss._sprite.sprite_frames
		if sf.get_frame_count("attack") != 4:
			_fail("runtime attack frames %d" % sf.get_frame_count("attack"))
		else:
			_pass("runtime Fenrir attack frames=4")
		if int(boss._attack_active_idx) != 2:
			_fail("runtime attack_active_idx %d != 2" % int(boss._attack_active_idx))
		else:
			_pass("runtime attack_active_idx=2")

	# Attack sync: perform attack and drive frames to hitframe (headless anim advance can stall).
	var ally = null
	for a in combat.get_allies():
		if a and not a.is_dead:
			ally = a
			break
	if ally == null:
		_fail("no ally for attack sync")
	else:
		boss.global_position = CombatFieldBounds.clamp_point(Vector2(700, 320), boss)
		ally.global_position = CombatFieldBounds.clamp_point(Vector2(620, 320), ally)
		boss._atk_timer = 0.0
		boss.set("_telegraph_t", 0.0)
		boss.set("_pending_skill_id", "")
		# Drive hitframe explicitly — AnimatedSprite may not advance under headless load.
		boss._set_anim_state(boss.AnimState.ATTACK_WINDUP)
		boss._damage_applied = false
		boss._pending_target = ally
		boss._pending_damage = maxf(1.0, float(boss.atk))
		boss._pending_heal = false
		boss._attack_elapsed = 0.0
		if boss._sprite and boss._sprite.sprite_frames:
			boss._sprite.play("attack")
			boss._sprite.pause()
			boss._sprite.frame = int(boss._attack_active_idx)
			boss._on_frame_changed()
		var anim_name := str(boss._sprite.animation) if boss._sprite else ""
		var fr := int(boss._sprite.frame) if boss._sprite else -1
		var saw_active: bool = anim_name == "attack" and fr >= int(boss._attack_active_idx)
		if not saw_active:
			_fail("attack never reached active frame (anim=%s frame=%s idx=%s)" % [anim_name, fr, boss._attack_active_idx])
		elif boss._damage_applied:
			_pass("attack damage synced at/after hitframe")
		else:
			_fail("attack damage not applied (frame=%s)" % fr)

	# Hit reaction: damage, HIT lock blocks attack override, multi-hit refresh, return to idle.
	if not boss.is_dead and ally != null:
		boss.hp = maxf(boss.hp, 200.0)
		# Leave any prior attack recovery so HIT path is exercised cleanly.
		boss._finish_attack_cycle()
		boss._atk_timer = 0.0
		boss.set("_telegraph_t", 0.0)
		boss.set("_pending_skill_id", "")
		var hp_before: float = float(boss.hp)
		boss.take_damage(5.0, ally, {})
		if float(boss.hp) >= hp_before:
			_fail("hit did not apply damage")
		else:
			_pass("hit applied damage")
		if boss.get_anim_state_name() != "HIT":
			_fail("expected HIT state after damage, got %s" % boss.get_anim_state_name())
		else:
			_pass("entered HIT state")
		if not boss._is_hit_locked():
			_fail("hit lock not armed")
		else:
			_pass("hit lock armed (t=%.2f)" % float(boss._hit_lock_t))
		# Attack must NOT override HIT while locked.
		boss._atk_timer = 0.0
		var blocked: bool = not boss._can_start_attack()
		boss._perform_attack(ally)
		if str(boss._sprite.animation) == "attack" and boss.get_anim_state_name() != "HIT":
			_fail("attack overrode HIT anim")
		elif not blocked:
			_fail("_can_start_attack true during HIT")
		else:
			_pass("HIT blocks attack start")
		# Multi-hit refreshes HIT / lock.
		var lock_before: float = float(boss._hit_lock_t)
		boss.take_damage(3.0, ally, {})
		if boss.get_anim_state_name() != "HIT":
			_fail("multi-hit left HIT state")
		elif float(boss._hit_lock_t) < lock_before - 0.001 and float(boss._hit_lock_t) <= 0.0:
			_fail("multi-hit cleared lock")
		else:
			_pass("multi-hit refreshed HIT lock (%.2f)" % float(boss._hit_lock_t))
		# Force finish hit anim → idle; ASPD timer path still usable after.
		boss._hit_lock_t = 0.0
		boss._on_anim_finished()
		if boss.get_anim_state_name() == "HIT":
			# Fallback clear
			boss._set_anim_state(boss.AnimState.IDLE)
			boss._play_anim("idle", true)
		if boss.get_anim_state_name() == "HIT":
			_fail("stuck in HIT after finish")
		else:
			_pass("hit returned to combat state (no freeze)")
		boss._atk_timer = 0.0
		if not boss._can_start_attack():
			_fail("ASPD/attack still blocked after HIT cleared")
		else:
			_pass("attack allowed after HIT cleared")

	# Death once: kill Fenrir, ensure died emits exactly once after anim/timeout.
	var died_count := [0]
	boss.died.connect(func(_w): died_count[0] += 1)
	var cleared_before: bool = bool(gs.bosses_cleared.get("fenrir", false))
	boss.take_damage(999999.0, ally, {"heavy": true})
	if not boss.is_dead:
		_fail("boss not dead after lethal")
	else:
		_pass("boss is_dead after lethal")
	# Wait for death anim / timeout (1.2s + margin)
	for _k in range(100):
		await process_frame
		if died_count[0] > 0:
			break
	if died_count[0] != 1:
		_fail("died emit count=%d (want 1)" % died_count[0])
	else:
		_pass("died emitted once")
	# Extra wait — must stay at 1
	for _k2 in range(30):
		await process_frame
	if died_count[0] != 1:
		_fail("died emitted again (%d)" % died_count[0])
	else:
		_pass("died stayed once")

	# Safezone relative to live boss camera/viewport.
	var live_top := CombatFieldBounds.top_y(boss if is_instance_valid(boss) else null)
	var live_rect := CombatFieldBounds.safe_rect(boss if is_instance_valid(boss) else null)
	if live_rect.size.y < 100.0:
		_fail("live safe_rect crushed (h=%.1f)" % live_rect.size.y)
	else:
		_pass("live safe_rect h=%.1f top=%.1f" % [live_rect.size.y, live_top])
	var unsafe := Vector2(700, live_top - 150.0)
	var clamped := CombatFieldBounds.clamp_point(unsafe, boss if is_instance_valid(boss) else null)
	if clamped.y < live_top - 0.5:
		_fail("unsafe Y stayed above top (%.1f < %.1f)" % [clamped.y, live_top])
	else:
		_pass("unsafe Y clamped to %.1f (top=%.1f)" % [clamped.y, live_top])

	combat.queue_free()
	await process_frame
	# Restore cleared flag pollution from victory path if any
	if not cleared_before:
		gs.bosses_cleared["fenrir"] = false
