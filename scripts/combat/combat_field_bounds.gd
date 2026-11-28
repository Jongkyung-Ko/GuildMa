class_name CombatFieldBounds
extends RefCounted

## Shared battlefield safe rect for monsters/bosses/allies.
## Top bound is dynamic from viewport + camera + HUD + sprite height — not fixed Y=100.
## Clamp movement *targets* (slots, dash, knockback) before applying motion.
## Screen-space HUD/margins are converted through camera zoom into world units.

const DEFAULT_HUD_TOP_PX := 118.0
const DEFAULT_HUD_RIGHT_PX := 268.0
const DEFAULT_MARGIN_X_PX := 40.0
const DEFAULT_MARGIN_BOTTOM_PX := 48.0
const DEFAULT_SPRITE_HEADROOM_PX := 96.0

static var debug_draw_enabled: bool = false


static func safe_rect(actor: Node2D = null, sprite_headroom: float = -1.0) -> Rect2:
	var vp_size := Vector2(1280, 720)
	var cam_center := Vector2(640, 360)
	var zoom := Vector2.ONE
	if actor != null and is_instance_valid(actor) and actor.is_inside_tree():
		var vp := actor.get_viewport()
		if vp:
			vp_size = vp.get_visible_rect().size
		var cam := actor.get_viewport().get_camera_2d() if actor.get_viewport() else null
		if cam:
			cam_center = cam.get_screen_center_position()
			zoom = cam.zoom
	elif Engine.get_main_loop():
		var tree := Engine.get_main_loop() as SceneTree
		if tree and tree.root:
			var vp2: Viewport = tree.root.get_viewport()
			if vp2:
				vp_size = vp2.get_visible_rect().size
			var cam2 := tree.root.get_viewport().get_camera_2d() if tree.root.get_viewport() else null
			if cam2:
				cam_center = cam2.get_screen_center_position()
				zoom = cam2.zoom

	var zx := maxf(zoom.x, 0.01)
	var zy := maxf(zoom.y, 0.01)
	var half := Vector2(vp_size.x / zx, vp_size.y / zy) * 0.5
	var world_tl := cam_center - half
	var world_br := cam_center + half
	var visible_h := maxf(8.0, world_br.y - world_tl.y)
	var visible_w := maxf(8.0, world_br.x - world_tl.x)

	var head_px := sprite_headroom
	if head_px < 0.0:
		head_px = _estimate_headroom_px(actor)
	# Scale HUD/headroom down on short landscape so the field is not crushed.
	var hud_px := minf(DEFAULT_HUD_TOP_PX, vp_size.y * 0.28)
	var head_cap_px := minf(head_px, vp_size.y * 0.30)
	var hud_world := hud_px / zy
	var head_world := head_cap_px / zy
	var margin_x := DEFAULT_MARGIN_X_PX / zx
	var margin_bottom := DEFAULT_MARGIN_BOTTOM_PX / zy
	var hud_right := (DEFAULT_HUD_RIGHT_PX * 0.35) / zx

	var top := world_tl.y + hud_world + head_world
	var bottom := world_br.y - margin_bottom
	var left := world_tl.x + margin_x
	var right := world_br.x - margin_x - hud_right

	# Keep a usable chase band (~45% of visible height, min 120 world units).
	var min_field := maxf(120.0, visible_h * 0.45)
	if bottom - top < min_field:
		top = bottom - min_field
	# Still clear the absolute screen top a little (HUD strip), even when compressing.
	var min_top := world_tl.y + minf(hud_world, visible_h * 0.10)
	top = maxf(top, min_top)
	if right - left < 160.0:
		right = left + 160.0
	# Keep rect inside visible world horizontally when possible.
	left = maxf(left, world_tl.x + margin_x * 0.25)
	right = minf(right, world_br.x - margin_x * 0.25)
	return Rect2(left, top, maxf(8.0, right - left), maxf(8.0, bottom - top))


static func clamp_point(pos: Vector2, actor: Node2D = null, sprite_headroom: float = -1.0) -> Vector2:
	var r := safe_rect(actor, sprite_headroom)
	return Vector2(clampf(pos.x, r.position.x, r.end.x), clampf(pos.y, r.position.y, r.end.y))


static func top_y(actor: Node2D = null, sprite_headroom: float = -1.0) -> float:
	return safe_rect(actor, sprite_headroom).position.y


static func _estimate_headroom_px(actor: Node2D) -> float:
	if actor == null:
		return DEFAULT_SPRITE_HEADROOM_PX
	# Boss painted idle ~150px tall with feet at origin → ~headroom above feet.
	if actor.get("boss_id") != null and str(actor.get("boss_id")) != "":
		return 110.0
	if actor.get("_art_fit_scale") != null and float(actor.get("_art_fit_scale")) > 0.0:
		return 110.0
	return DEFAULT_SPRITE_HEADROOM_PX


static func maybe_debug_draw(canvas: CanvasItem, actor: Node2D = null) -> void:
	if not debug_draw_enabled or canvas == null:
		return
	var r := safe_rect(actor)
	canvas.draw_line(Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y), Color(1, 0.3, 0.2, 0.85), 2.0)
	canvas.draw_rect(r, Color(1, 0.4, 0.2, 0.12), false, 1.0)
