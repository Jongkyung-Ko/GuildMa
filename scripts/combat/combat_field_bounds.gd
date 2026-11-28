class_name CombatFieldBounds
extends RefCounted

## Shared battlefield safe rect for monsters/bosses/allies.
## Intersects (1) HUD/viewport-safe strip with (2) painted background center arena
## (dirt clearing inside forest rocks/logs on combat_bg.png).
## Top bound = viewport top + HUD + per-actor rendered headroom (pivot→head).
## When the field is tight (e.g. 844×390), NEVER relax the top — reclaim space from
## the bottom margin instead so heads stay clear of the boss HUD.

const DEFAULT_HUD_TOP_PX := 118.0
const DEFAULT_HUD_RIGHT_PX := 268.0
const DEFAULT_MARGIN_X_PX := 40.0
const DEFAULT_MARGIN_BOTTOM_PX := 48.0
const DEFAULT_SPRITE_HEADROOM_WORLD := 96.0
const MIN_FIELD_WORLD := 64.0
const DEFAULT_HALF_WIDTH_WORLD := 28.0

## combat_bg.png is 1280×720, placed at Battlefield (0,0) uncentered.
## Dirt clearing measured from art; inset so feet stay on packed earth, clear of rocks/logs/trees.
const BG_PATH := "res://assets/backgrounds/combat_bg.png"
const BG_SIZE := Vector2(1280, 720)
## Arena in background-local pixels (feet clamp region before per-actor extent inset).
const BG_ARENA := Rect2(250, 195, 780, 395)  # x 250–1030, y 195–590

## Global render scale for combatants (visual only; not source PNGs).
const COMBAT_RENDER_SCALE := 0.8

static var debug_draw_enabled: bool = false
## When non-zero, forces viewport size (capture/QA scripts for 844/1366/1280).
static var debug_force_vp_size: Vector2 = Vector2.ZERO
## Optional override of background arena (tests). Empty = use BG_ARENA.
static var debug_arena_override: Rect2 = Rect2()


static func background_arena_world() -> Rect2:
	if debug_arena_override.size.x >= 32.0 and debug_arena_override.size.y >= 32.0:
		return debug_arena_override
	return BG_ARENA


static func safe_rect(actor: Node2D = null, sprite_headroom: float = -1.0) -> Rect2:
	var view := _view_params(actor)
	var vp_size: Vector2 = view["vp_size"]
	if debug_force_vp_size.x >= 64.0 and debug_force_vp_size.y >= 64.0:
		vp_size = debug_force_vp_size
	return safe_rect_for_view(
		vp_size,
		view["cam_center"],
		view["zoom"],
		actor,
		sprite_headroom
	)


static func safe_rect_for_view(
	vp_size: Vector2,
	cam_center: Vector2,
	zoom: Vector2,
	actor: Node2D = null,
	sprite_headroom: float = -1.0
) -> Rect2:
	var zx := maxf(zoom.x, 0.01)
	var zy := maxf(zoom.y, 0.01)
	var half := Vector2(vp_size.x / zx, vp_size.y / zy) * 0.5
	var world_tl := cam_center - half
	var world_br := cam_center + half

	# HUD strip in screen px → world. Do not shrink on short landscape.
	var hud_world := DEFAULT_HUD_TOP_PX / zy
	# sprite_headroom arg is screen-px override when >= 0; else measure actor.
	var head_world := 0.0
	if sprite_headroom >= 0.0:
		head_world = sprite_headroom / zy
	else:
		head_world = estimate_headroom_world(actor)

	# Top bound is sacred — never move it toward the screen top to invent field height.
	var top := world_tl.y + hud_world + head_world
	var margin_bottom := DEFAULT_MARGIN_BOTTOM_PX / zy
	var bottom := world_br.y - margin_bottom

	# Tight viewport: eat bottom margin first; never decrease `top`.
	if bottom - top < MIN_FIELD_WORLD:
		bottom = world_br.y - minf(margin_bottom, 8.0 / zy)
	if bottom - top < MIN_FIELD_WORLD:
		bottom = maxf(top + MIN_FIELD_WORLD, world_br.y - 4.0 / zy)
	if bottom < top + 8.0:
		bottom = top + 8.0

	var margin_x := DEFAULT_MARGIN_X_PX / zx
	var hud_right := (DEFAULT_HUD_RIGHT_PX * 0.35) / zx
	var left := world_tl.x + margin_x
	var right := world_br.x - margin_x - hud_right
	if right - left < 160.0:
		right = left + 160.0
	left = maxf(left, world_tl.x + margin_x * 0.25)
	right = minf(right, world_br.x - margin_x * 0.25)

	var view_rect := Rect2(left, top, maxf(8.0, right - left), maxf(8.0, bottom - top))
	# Intersect with painted center arena so units stay on dirt, not trees/rocks.
	var arena := background_arena_world()
	var merged := _intersect_rects(view_rect, arena)
	if merged.size.x < 32.0 or merged.size.y < 32.0:
		# Degenerate (camera elsewhere): prefer arena, then view.
		merged = arena if arena.size.x >= 32.0 else view_rect
	return merged


static func clamp_point(pos: Vector2, actor: Node2D = null, sprite_headroom: float = -1.0) -> Vector2:
	var r := safe_rect(actor, sprite_headroom)
	var half_w := estimate_half_width_world(actor)
	var foot_pad := 6.0
	var x0 := r.position.x + half_w
	var x1 := r.end.x - half_w
	var y0 := r.position.y
	var y1 := r.end.y - foot_pad
	if x1 < x0:
		var mid := (r.position.x + r.end.x) * 0.5
		x0 = mid
		x1 = mid
	if y1 < y0:
		y1 = y0
	return Vector2(clampf(pos.x, x0, x1), clampf(pos.y, y0, y1))


static func top_y(actor: Node2D = null, sprite_headroom: float = -1.0) -> float:
	return safe_rect(actor, sprite_headroom).position.y


static func estimate_half_width_world(actor: Node2D) -> float:
	if actor == null or not is_instance_valid(actor):
		return DEFAULT_HALF_WIDTH_WORLD * COMBAT_RENDER_SCALE
	var sprite: AnimatedSprite2D = null
	if actor.get("_sprite") != null:
		sprite = actor.get("_sprite") as AnimatedSprite2D
	if sprite == null:
		sprite = actor.get_node_or_null("VisualPivot/AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		if actor.get("boss_id") != null and str(actor.get("boss_id")) != "":
			return 48.0 * COMBAT_RENDER_SCALE
		return DEFAULT_HALF_WIDTH_WORLD * COMBAT_RENDER_SCALE
	var anim := "idle"
	if not sprite.sprite_frames.has_animation(anim):
		var names := sprite.sprite_frames.get_animation_names()
		if names.is_empty():
			return DEFAULT_HALF_WIDTH_WORLD * COMBAT_RENDER_SCALE
		anim = str(names[0])
	if sprite.sprite_frames.get_frame_count(anim) <= 0:
		return DEFAULT_HALF_WIDTH_WORLD * COMBAT_RENDER_SCALE
	var tex: Texture2D = sprite.sprite_frames.get_frame_texture(anim, 0)
	if tex == null:
		return DEFAULT_HALF_WIDTH_WORLD * COMBAT_RENDER_SCALE
	var sx := absf(sprite.global_scale.x)
	return maxf(12.0, float(tex.get_width()) * 0.5 * sx * 0.55)


static func estimate_headroom_world(actor: Node2D) -> float:
	## World-space distance from actor feet (origin) to the top of the rendered sprite.
	if actor == null or not is_instance_valid(actor):
		return DEFAULT_SPRITE_HEADROOM_WORLD * COMBAT_RENDER_SCALE
	var sprite: AnimatedSprite2D = null
	if actor.get("_sprite") != null:
		sprite = actor.get("_sprite") as AnimatedSprite2D
	if sprite == null:
		sprite = actor.get_node_or_null("VisualPivot/AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		return _fallback_headroom_world(actor)

	var anim := "idle"
	if not sprite.sprite_frames.has_animation(anim):
		var names := sprite.sprite_frames.get_animation_names()
		if names.is_empty():
			return _fallback_headroom_world(actor)
		anim = str(names[0])
	if sprite.sprite_frames.get_frame_count(anim) <= 0:
		return _fallback_headroom_world(actor)
	var tex: Texture2D = sprite.sprite_frames.get_frame_texture(anim, 0)
	if tex == null:
		return _fallback_headroom_world(actor)

	var tex_h := float(tex.get_height())
	var sy := absf(sprite.global_scale.y)
	var half_h_world := tex_h * 0.5 * sy
	var center_y: float
	if sprite.centered:
		center_y = actor.to_local(sprite.global_position).y
	else:
		# Uncentered: global_position is texture top-left; center is half-height down.
		center_y = actor.to_local(sprite.global_position).y + half_h_world
	var top_local := center_y - half_h_world
	return maxf(24.0, -top_local)


static func _fallback_headroom_world(actor: Node2D) -> float:
	var base := DEFAULT_SPRITE_HEADROOM_WORLD * COMBAT_RENDER_SCALE
	if actor != null and actor.get("boss_id") != null and str(actor.get("boss_id")) != "":
		return 140.0 * COMBAT_RENDER_SCALE
	if actor != null and actor.get("_art_fit_scale") != null and float(actor.get("_art_fit_scale")) > 0.0:
		return 140.0 * COMBAT_RENDER_SCALE
	return base


static func _intersect_rects(a: Rect2, b: Rect2) -> Rect2:
	var x0 := maxf(a.position.x, b.position.x)
	var y0 := maxf(a.position.y, b.position.y)
	var x1 := minf(a.end.x, b.end.x)
	var y1 := minf(a.end.y, b.end.y)
	if x1 <= x0 or y1 <= y0:
		return Rect2()
	return Rect2(x0, y0, x1 - x0, y1 - y0)


static func _view_params(actor: Node2D) -> Dictionary:
	var vp_size := Vector2(1280, 720)
	var cam_center := Vector2(640, 360)
	var zoom := Vector2.ONE
	var win: Window = null
	var vp: Viewport = null
	if actor != null and is_instance_valid(actor) and actor.is_inside_tree():
		vp = actor.get_viewport()
		win = actor.get_window()
	elif Engine.get_main_loop():
		var tree := Engine.get_main_loop() as SceneTree
		if tree and tree.root:
			vp = tree.root.get_viewport()
			win = tree.root as Window
	var cam: Camera2D = null
	if vp:
		vp_size = vp.get_visible_rect().size
		cam = vp.get_camera_2d()
		if cam:
			cam_center = cam.get_screen_center_position()
			zoom = cam.zoom
	# Capture / landscape QA often disables content scale so window == logical size.
	# Prefer that window size over a stale stretch visible_rect (e.g. stuck at 1280×720).
	if win != null and win.content_scale_mode == Window.CONTENT_SCALE_MODE_DISABLED:
		var ws := Vector2(win.size)
		if ws.x >= 64.0 and ws.y >= 64.0:
			vp_size = ws
	# Headless / pre-camera scripts: use combat background design space so HUD+headroom
	# math is not crushed by a square default viewport (e.g. 1280×1280).
	if cam == null:
		vp_size = BG_SIZE
		cam_center = BG_SIZE * 0.5
		zoom = Vector2.ONE
	return {"vp_size": vp_size, "cam_center": cam_center, "zoom": zoom}


static func maybe_debug_draw(canvas: CanvasItem, actor: Node2D = null) -> void:
	if not debug_draw_enabled or canvas == null:
		return
	var r := safe_rect(actor)
	canvas.draw_line(Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y), Color(1, 0.3, 0.2, 0.85), 2.0)
	canvas.draw_rect(r, Color(1, 0.4, 0.2, 0.12), false, 1.0)
	var arena := background_arena_world()
	canvas.draw_rect(arena, Color(0.2, 0.85, 0.4, 0.18), false, 1.0)
