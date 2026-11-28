extends Control

## Guild Hall HQ — landscape-only split layout + stage composition.
## Portrait stacked-scroll layout is disabled (game is landscape-only).

const PartyFormationPanelScript = preload("res://scripts/ui/party_formation_panel.gd")

const HALL_BG := "res://assets/backgrounds/guild_interior.png"
const PORTRAIT_DIR := "res://assets/sprites/characters/"
## Match hunt on-screen size (combat base 0.95 × COMBAT_RENDER_SCALE). Do not edit combat 0.8.
const SPRITE_SCALE := 0.95 * CombatFieldBounds.COMBAT_RENDER_SCALE
## Lord slightly larger than members (same relative emphasis as prior 1.28/1.05).
const LORD_SCALE := 1.22 * CombatFieldBounds.COMBAT_RENDER_SCALE
const HALL_MEMBER_CAP := 10
## Floor line as fraction of the interior texture height (stone floor / rug).
const INTERIOR_FLOOR_T := 0.78
const INTERIOR_ASPECT := 720.0 / 520.0
const ACTOR_FOOT_MARGIN := 32.0
const NAMEPLATE_H := 16.0
const SPRITE_FOOT_OFFSET_Y := -30.0
## Mild zoom on centered cover so furniture/actors fill the hall frame.
const INTERIOR_ZOOM := 1.14
## Target clear air between opaque sprite edges (combat_00 content, recentered).
const VISUAL_GAP := 32.0
## Padding from opaque sprite edge to hall gold frame.
const EDGE_SPRITE_PAD := 20.0
const MENU_MEMBERS := "members"
const MENU_PARTY := "party"
const MENU_STATS := "stats"
const MENU_FACILITY := "facility"
## Left guild menu — extracted from Party Art Kit `04_Components_Reference.png`.
const NAV_TEX := {
	MENU_MEMBERS: "res://assets/ui/party/menu/nav_members.png",
	MENU_PARTY: "res://assets/ui/party/menu/nav_party_normal.png",
	MENU_STATS: "res://assets/ui/party/menu/nav_stats.png",
	MENU_FACILITY: "res://assets/ui/party/menu/nav_facility.png",
}
const NAV_TEX_SELECTED := {
	MENU_MEMBERS: "res://assets/ui/party/menu/nav_members.png",
	MENU_PARTY: "res://assets/ui/party/menu/nav_party_selected.png",
	MENU_STATS: "res://assets/ui/party/menu/nav_stats.png",
	MENU_FACILITY: "res://assets/ui/party/menu/nav_facility.png",
}
## Content-area layout ratios (1280×720 target).
const RATIO_NAV := 0.08
const RATIO_LIST := 0.62
const RATIO_DETAIL := 0.30

var _mode: String = MENU_MEMBERS
var _assign_kind: String = ""
var _draft_ids: Array = []
var _toast: Label
## Dense packing for short landscape windows (e.g. 844×390). Never portrait-stack.
var _dense: bool = false

var _top_bar: PanelContainer
var _top_info: Label
var _town_btn: Button
var _body_scroll: ScrollContainer
var _body_host: Control
var _nav_box: Container
var _hall_wrap: PanelContainer
var _hall_root: Control
var _hall_layer: Control
var _detail_wrap: PanelContainer
var _detail_box: VBoxContainer
var _party_wrap: PanelContainer
var _party_host: Container
var _footer: HBoxContainer
var _overlay: ColorRect
var _overlay_panel: PanelContainer
var _nav_buttons: Dictionary = {}
var _layout_built: bool = false
var _formation: Control = null
var _formation_state: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	_build_shell()
	GameState.state_changed.connect(_on_state)
	GameState.message_emitted.connect(_on_message)
	var win := get_window()
	if win and not win.size_changed.is_connected(_on_window_resized):
		win.size_changed.connect(_on_window_resized)
	if GameState.selected_guild_member_id == "" and not GameState.members.is_empty():
		GameState.selected_guild_member_id = str(GameState.members[0].get("id", ""))
	call_deferred("_first_layout")


func _first_layout() -> void:
	_apply_responsive_layout()
	await get_tree().process_frame
	_fit_interior()
	_refresh_all()


func _on_window_resized() -> void:
	_apply_responsive_layout()
	call_deferred("_deferred_hall_refresh")


func _deferred_hall_refresh() -> void:
	_fit_interior()
	_refresh_hall()


func _is_dense_landscape() -> bool:
	## Short physical landscape window — tighten chrome so hall/parties/detail fit.
	var win := get_window()
	if win == null:
		return false
	var wsz: Vector2i = win.size
	if wsz.x < 8 or wsz.y < 8:
		return false
	# Landscape only; portrait is out of scope (never enable vertical stack).
	if wsz.y > wsz.x:
		return false
	return wsz.y <= 420 or float(wsz.x) / float(wsz.y) >= 2.0


func _build_shell() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.1)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_top_bar = UIStyle.make_panel()
	add_child(_top_bar)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_top_bar.add_child(top_row)
	_top_info = UIStyle.label("", 12)
	_top_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top_info.autowrap_mode = TextServer.AUTOWRAP_OFF
	_top_info.clip_text = true
	top_row.add_child(_top_info)
	_town_btn = Button.new()
	_town_btn.text = "마을로"
	_town_btn.custom_minimum_size = Vector2(72, 28)
	UIStyle.apply_button(_town_btn)
	_town_btn.pressed.connect(func(): SceneRouter.go_town())
	top_row.add_child(_town_btn)

	_body_scroll = ScrollContainer.new()
	_body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_body_scroll)
	_body_host = Control.new()
	_body_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_scroll.add_child(_body_host)

	# Scroll so all menu entries stay reachable at 844/1280/1366.
	var nav_scroll := ScrollContainer.new()
	nav_scroll.name = "NavScroll"
	nav_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	nav_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	nav_scroll.clip_contents = true
	_body_host.add_child(nav_scroll)
	_nav_box = VBoxContainer.new()
	_nav_box.add_theme_constant_override("separation", 8)
	_nav_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_nav_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	nav_scroll.add_child(_nav_box)
	for mid in [MENU_MEMBERS, MENU_PARTY, MENU_STATS, MENU_FACILITY]:
		var wrap := PanelContainer.new()
		wrap.name = "NavWrap_%s" % mid
		wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var empty := StyleBoxEmpty.new()
		wrap.add_theme_stylebox_override("panel", empty)
		var b := TextureButton.new()
		b.name = "NavBtn_%s" % mid
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.custom_minimum_size = Vector2(72, 88)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var tex_path := str(NAV_TEX.get(mid, ""))
		if ResourceLoader.exists(tex_path):
			b.texture_normal = load(tex_path) as Texture2D
		b.pressed.connect(_make_mode_cb(mid))
		wrap.add_child(b)
		_nav_box.add_child(wrap)
		_nav_buttons[mid] = b

	_hall_wrap = UIStyle.make_panel()
	_hall_wrap.clip_contents = true
	_hall_wrap.z_index = 0
	_body_host.add_child(_hall_wrap)
	# Single PanelContainer child so we can freely position interior art.
	_hall_root = Control.new()
	_hall_root.name = "HallRoot"
	_hall_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hall_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hall_root.clip_contents = true
	_hall_wrap.add_child(_hall_root)
	var interior := TextureRect.new()
	interior.name = "Interior"
	interior.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interior.texture = load(HALL_BG)
	# Manual cover + true center in _fit_interior (no bottom-only crop).
	interior.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	interior.stretch_mode = TextureRect.STRETCH_SCALE
	interior.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	interior.modulate = Color(0.92, 0.9, 0.88, 1)
	_hall_root.add_child(interior)
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.set_anchors_preset(PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.04, 0.08, 0.18)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hall_root.add_child(dim)
	_hall_layer = Control.new()
	_hall_layer.name = "HallLayer"
	_hall_layer.set_anchors_preset(PRESET_FULL_RECT)
	_hall_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	_hall_layer.clip_contents = true
	_hall_root.add_child(_hall_layer)
	var hall_title := UIStyle.label("길드 홀", 15, UIStyle.GOLD_BRIGHT)
	hall_title.name = "HallTitle"
	hall_title.set_anchors_preset(PRESET_TOP_LEFT)
	hall_title.position = Vector2(10, 8)
	hall_title.z_index = 2
	_hall_root.add_child(hall_title)

	_detail_wrap = UIStyle.make_panel()
	_body_host.add_child(_detail_wrap)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.set_anchors_preset(PRESET_FULL_RECT)
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_wrap.add_child(detail_scroll)
	_detail_box = VBoxContainer.new()
	_detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_box.add_theme_constant_override("separation", 6)
	detail_scroll.add_child(_detail_box)

	_party_wrap = UIStyle.make_panel()
	_party_wrap.z_index = 4
	_party_wrap.clip_contents = true
	_body_host.add_child(_party_wrap)
	var party_root := Control.new()
	party_root.name = "PartyRoot"
	party_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	party_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	party_root.clip_contents = true
	_party_wrap.add_child(party_root)
	var party_vb := VBoxContainer.new()
	party_vb.name = "PartyVB"
	party_vb.set_anchors_preset(PRESET_TOP_WIDE)
	party_vb.anchor_bottom = 0.0
	party_vb.offset_left = 0
	party_vb.offset_right = 0
	party_vb.offset_top = 0
	party_vb.grow_horizontal = Control.GROW_DIRECTION_BOTH
	party_vb.add_theme_constant_override("separation", 3)
	party_vb.alignment = BoxContainer.ALIGNMENT_BEGIN
	party_root.add_child(party_vb)
	party_vb.add_child(UIStyle.label("임무 파티", 12, UIStyle.GOLD_BRIGHT))
	_party_host = HBoxContainer.new()
	_party_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_party_host.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_party_host.add_theme_constant_override("separation", 8)
	party_vb.add_child(_party_host)

	_footer = HBoxContainer.new()
	_footer.add_theme_constant_override("separation", 10)
	add_child(_footer)
	var save_btn := Button.new()
	save_btn.text = "파티 저장"
	save_btn.custom_minimum_size = Vector2(0, 44)
	UIStyle.apply_button(save_btn)
	save_btn.pressed.connect(_on_save_parties)
	_footer.add_child(save_btn)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_footer.add_child(spacer)
	var close_btn := Button.new()
	close_btn.text = "닫기"
	close_btn.custom_minimum_size = Vector2(0, 44)
	UIStyle.apply_button(close_btn)
	close_btn.pressed.connect(func(): SceneRouter.go_town())
	_footer.add_child(close_btn)

	_toast = UIStyle.label("", 13, UIStyle.OK)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_toast)

	_build_overlay()
	_layout_built = true


func _apply_responsive_layout() -> void:
	if not _layout_built:
		return
	_dense = _is_dense_landscape()
	var pad := 6.0 if _dense else 8.0
	var w := size.x
	var h := size.y
	if w < 8.0 or h < 8.0:
		return
	# Top HUD compact — guild info + town only (formation toolbar is separate).
	# Keep HUD+formation header ≤ ~15% of 720 when combined (~108px).
	var top_h := clampf(h * 0.07, 42.0, 52.0)
	if _dense:
		top_h = mini(top_h, 42.0)
	var foot_h := 36.0 if _dense else 44.0
	var toast_h := 14.0 if _dense else 18.0

	_top_bar.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
	_top_bar.offset_left = pad
	_top_bar.offset_right = -pad
	_top_bar.offset_top = pad
	_top_bar.offset_bottom = pad + top_h
	_top_bar.clip_contents = true
	_top_bar.custom_minimum_size = Vector2(0, top_h)
	_top_bar.size = Vector2(maxf(w - pad * 2.0, 8.0), top_h)
	_town_btn.text = "마을로"
	_town_btn.custom_minimum_size = Vector2(64, maxf(24.0, top_h - 12.0))
	if _top_info:
		_top_info.add_theme_font_size_override("font_size", 11 if _dense else 12)

	_toast.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	_toast.offset_left = pad
	_toast.offset_right = -pad

	# Landscape-only: always wide split. Portrait stacked scroll is disabled.
	var compact_actions := _body_host.get_node_or_null("CompactActions")
	if compact_actions:
		compact_actions.visible = false
	var formation_open := _formation != null and is_instance_valid(_formation) and _formation.visible
	_footer.visible = not formation_open
	_footer.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	_footer.offset_left = pad
	_footer.offset_right = -pad
	_footer.offset_top = -(pad + foot_h)
	_footer.offset_bottom = -pad
	var bottom_reserve := (toast_h + 4.0) if formation_open else (foot_h + toast_h + 4.0)
	_toast.offset_top = -(pad + bottom_reserve)
	_toast.offset_bottom = -(pad + (4.0 if formation_open else foot_h))
	_body_scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_body_scroll.offset_left = pad
	_body_scroll.offset_right = -pad
	# Clear the top bar fully (content can grow past top_h without clip alone).
	var top_clear := maxf(top_h, _top_bar.size.y if _top_bar.size.y > 0.0 else top_h)
	_body_scroll.offset_top = pad + top_clear + 4.0
	_body_scroll.offset_bottom = -(pad + bottom_reserve)
	var body_h := _body_scroll.size.y if _body_scroll.size.y > 8.0 else h - top_h - foot_h - toast_h - 24.0
	_layout_wide(w - pad * 2.0, body_h)

	_fit_overlay()


func _layout_wide(content_w: float, content_h: float) -> void:
	_body_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var compact_actions := _body_host.get_node_or_null("CompactActions")
	if compact_actions:
		compact_actions.visible = false
	_ensure_nav_orientation(false)
	_ensure_party_orientation(false)
	# Minimize left chrome; keep detail wide enough to read ATK/DEF rows.
	# When formation is open, use the same narrow nav as `_fit_formation`.
	var formation_open := _formation != null and is_instance_valid(_formation) and _formation.visible
	var nav_w := clampf(content_w * RATIO_NAV, 72.0, 104.0) if formation_open else (96.0 if _dense else 112.0)
	var detail_w := clampf(content_w * RATIO_DETAIL, 220.0, 380.0) if formation_open else (248.0 if _dense else 268.0)
	var gap := 6.0 if _dense else 8.0
	var mid_w := content_w - nav_w - detail_w - gap * 2.0
	# Compact party strip — tall enough for 5 readable roster slots + 편성 above footer.
	var party_h := 132.0 if _dense else 156.0
	var hall_h := maxf(200.0 if _dense else 240.0, content_h - party_h - gap)

	var nav_host := _body_host.get_node_or_null("NavHost") as Control
	var nav_scroll := _body_host.get_node_or_null("NavScroll") as ScrollContainer
	if nav_host == null and nav_scroll == null:
		var maybe_host := _body_host.get_node_or_null("NavHost")
		if maybe_host:
			nav_scroll = maybe_host.get_node_or_null("NavScroll") as ScrollContainer
	if formation_open:
		nav_host = _ensure_nav_host()
		nav_host.position = Vector2(0, 0)
		nav_host.size = Vector2(nav_w, content_h)
		nav_host.custom_minimum_size = Vector2(nav_w, content_h)
		nav_host.clip_contents = true
		nav_scroll = nav_host.get_node_or_null("NavScroll") as ScrollContainer
		if nav_scroll:
			nav_scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	elif nav_scroll:
		nav_scroll.position = Vector2(0, 0)
		nav_scroll.size = Vector2(nav_w, content_h)
		nav_scroll.custom_minimum_size = Vector2(nav_w, content_h)
	elif nav_host:
		nav_host.position = Vector2(0, 0)
		nav_host.size = Vector2(nav_w, content_h)
		nav_host.custom_minimum_size = Vector2(nav_w, content_h)
	_nav_box.custom_minimum_size = Vector2(nav_w - 4.0, 0)
	for mid in _nav_buttons.keys():
		var b: TextureButton = _nav_buttons[mid]
		if is_instance_valid(b):
			b.custom_minimum_size = Vector2(64 if _dense else 72, 80 if _dense else 88)

	_hall_wrap.position = Vector2(nav_w + gap, 0)
	_hall_wrap.size = Vector2(mid_w, hall_h)
	_hall_wrap.custom_minimum_size = Vector2(mid_w, hall_h)
	_fit_interior()

	_party_wrap.position = Vector2(nav_w + gap, hall_h + gap)
	_party_wrap.size = Vector2(mid_w + detail_w + gap, party_h)
	_party_wrap.custom_minimum_size = Vector2(0, party_h)

	_detail_wrap.position = Vector2(nav_w + gap + mid_w + gap, 0)
	_detail_wrap.size = Vector2(detail_w, hall_h)
	_detail_wrap.custom_minimum_size = Vector2(detail_w, hall_h)

	_body_host.custom_minimum_size = Vector2(content_w, content_h)
	_body_host.size = Vector2(content_w, content_h)
	# PanelContainer sizes HallRoot on the next layout pass.
	call_deferred("_fit_interior")
	if _formation and _formation.visible:
		call_deferred("_fit_formation")


func _hall_area() -> Vector2:
	if _hall_root and _hall_root.size.x > 8.0 and _hall_root.size.y > 8.0:
		return _hall_root.size
	if _hall_wrap and _hall_wrap.size.x > 8.0:
		return _hall_wrap.size
	return Vector2(640, 280)


func _fit_interior() -> void:
	## Aspect-safe cover, centered on both axes (no bottom-only crop / Y nudge).
	if _hall_root == null:
		return
	var interior := _hall_root.get_node_or_null("Interior") as TextureRect
	if interior == null:
		return
	var area := _hall_area()
	UIStyle.fit_texture_cover_centered(interior, area, INTERIOR_ASPECT, INTERIOR_ZOOM)


func _ensure_nav_orientation(horizontal: bool) -> void:
	var want_h := horizontal
	var is_h := _nav_box is HBoxContainer
	if want_h == is_h and _nav_box.get_child_count() > 0:
		return
	var kids: Array = []
	for c in _nav_box.get_children():
		kids.append(c)
		_nav_box.remove_child(c)
	var old := _nav_box
	var parent := old.get_parent()
	var idx := old.get_index()
	parent.remove_child(old)
	old.queue_free()
	_nav_box = HBoxContainer.new() if want_h else VBoxContainer.new()
	_nav_box.add_theme_constant_override("separation", 6)
	parent.add_child(_nav_box)
	parent.move_child(_nav_box, idx)
	if want_h:
		# Skip old "길드 메뉴" label crowding the row — buttons only.
		for c2 in kids:
			if c2 is Label:
				c2.queue_free()
			else:
				_nav_box.add_child(c2)
				if c2 is Button:
					c2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		_nav_box.add_child(UIStyle.label("길드 메뉴", 13, UIStyle.TEXT_DIM))
		for c3 in kids:
			if c3 is Label:
				c3.queue_free()
			else:
				_nav_box.add_child(c3)
				if c3 is Button:
					c3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					c3.custom_minimum_size = Vector2(0, 44)


func _ensure_party_orientation(vertical: bool) -> void:
	var want_v := vertical
	var is_v := _party_host is VBoxContainer
	if want_v == is_v:
		return
	var kids: Array = []
	for c in _party_host.get_children():
		kids.append(c)
		_party_host.remove_child(c)
	var parent := _party_host.get_parent()
	var idx := _party_host.get_index()
	parent.remove_child(_party_host)
	_party_host.queue_free()
	_party_host = VBoxContainer.new() if want_v else HBoxContainer.new()
	_party_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_party_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_party_host.add_theme_constant_override("separation", 8)
	parent.add_child(_party_host)
	parent.move_child(_party_host, idx)
	for c2 in kids:
		_party_host.add_child(c2)
		if c2 is Control:
			c2.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _make_mode_cb(mode: String) -> Callable:
	return func(): _set_mode(mode)


func _set_mode(mode: String) -> void:
	_mode = mode
	_close_overlay()
	if mode == MENU_FACILITY:
		_hide_formation()
		_open_facility_panel()
	elif mode == MENU_PARTY:
		_open_formation("hunt")
	else:
		_hide_formation()
	_refresh_all()


func _build_overlay() -> void:
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.55)
	_overlay.set_anchors_preset(PRESET_FULL_RECT)
	_overlay.visible = false
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	# Must sit above hall sprites (they use local z_index for depth sorting).
	_overlay.z_index = 80
	add_child(_overlay)
	_overlay_panel = UIStyle.make_panel(true)
	_overlay.add_child(_overlay_panel)
	_fit_overlay()


func _fit_overlay() -> void:
	if _overlay_panel == null:
		return
	var vw := maxf(size.x, 320.0)
	var vh := maxf(size.y, 360.0)
	var pw := minf(720.0, vw - 24.0)
	var ph := minf(520.0, vh - 48.0)
	if _dense:
		pw = minf(vw - 20.0, 900.0)
		ph = minf(vh - 24.0, vh * 0.92)
	_overlay_panel.set_anchors_preset(PRESET_CENTER)
	_overlay_panel.custom_minimum_size = Vector2(pw, ph)
	_overlay_panel.offset_left = -pw * 0.5
	_overlay_panel.offset_right = pw * 0.5
	_overlay_panel.offset_top = -ph * 0.5
	_overlay_panel.offset_bottom = ph * 0.5


func _on_state() -> void:
	_refresh_all()


func _on_message(text: String, is_error: bool) -> void:
	_toast.add_theme_color_override("font_color", UIStyle.DANGER if is_error else UIStyle.OK)
	_toast.text = text


func _on_save_parties() -> void:
	GameState.save_game()
	GameState.emit_message("길드 파티 편성을 저장했습니다.")


func _refresh_all() -> void:
	_refresh_top()
	_refresh_nav()
	if _formation and _formation.visible:
		_fit_formation()
		return
	_refresh_hall()
	_refresh_detail()
	_refresh_party_cards()


func _refresh_top() -> void:
	_top_info.text = "%s  Lv.%d  ·  명성 %d  ·  길드원 %s  ·  골드 %d" % [
		GameState.guild_name, GameState.guild_level, GameState.reputation,
		GameState.member_count_text(), GameState.gold,
	]


func _refresh_nav() -> void:
	for mid in _nav_buttons.keys():
		var b: TextureButton = _nav_buttons[mid]
		if not is_instance_valid(b):
			continue
		var selected: bool = str(mid) == _mode
		var path := str(NAV_TEX_SELECTED.get(mid, "")) if selected else str(NAV_TEX.get(mid, ""))
		if mid == MENU_PARTY:
			path = "res://assets/ui/party/menu/nav_party_selected.png" if selected else "res://assets/ui/party/menu/nav_party_normal.png"
		if ResourceLoader.exists(path):
			b.texture_normal = load(path) as Texture2D
		b.modulate = Color(1.12, 1.06, 0.92, 1.0) if selected else Color(0.88, 0.86, 0.82, 1.0)
		var wrap := b.get_parent() as PanelContainer
		if wrap:
			if selected:
				var rim := StyleBoxFlat.new()
				rim.bg_color = Color(0, 0, 0, 0)
				rim.border_color = Color(0.95, 0.78, 0.28, 1)
				rim.set_border_width_all(2)
				rim.set_corner_radius_all(4)
				rim.content_margin_left = 2
				rim.content_margin_right = 2
				rim.content_margin_top = 2
				rim.content_margin_bottom = 2
				wrap.add_theme_stylebox_override("panel", rim)
			else:
				wrap.add_theme_stylebox_override("panel", StyleBoxEmpty.new())


func _refresh_hall() -> void:
	if _hall_layer == null or _hall_wrap == null:
		return
	while _hall_layer.get_child_count() > 0:
		var c := _hall_layer.get_child(0)
		_hall_layer.remove_child(c)
		c.free()

	var lord: Dictionary = {}
	var others: Array = []
	for m in GameState.members:
		if str(m.get("job", "")) == "lord" and lord.is_empty():
			lord = m
		else:
			others.append(m)
	if lord.is_empty() and not GameState.members.is_empty():
		lord = GameState.members[0]
		others = GameState.members.slice(1)

	_fit_interior()
	var area := _hall_area()
	_hall_layer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_hall_layer.size = area
	_hall_layer.position = Vector2.ZERO
	_compose_stage(lord, others, area)


func _floor_y_for_hall(area: Vector2) -> float:
	## Shared foot baseline on the interior stone floor, above the party border.
	var interior: TextureRect = null
	if _hall_root:
		interior = _hall_root.get_node_or_null("Interior") as TextureRect
	var floor_y: float
	if interior and interior.size.y > 8.0:
		floor_y = interior.position.y + interior.size.y * INTERIOR_FLOOR_T
	else:
		floor_y = area.y * 0.78
	var max_y := area.y - ACTOR_FOOT_MARGIN
	var min_y := area.y * 0.55
	return clampf(floor_y, min_y, max_y)


func _compose_stage(lord: Dictionary, others: Array, area: Vector2) -> void:
	## Guildmaster centered; L/R use per-side steps so opaque-edge gaps match.
	## Sprites are optically recentered so foot X == content center.
	var floor_y := _floor_y_for_hall(area)
	var center_x := area.x * 0.5
	var scale_mem := SPRITE_SCALE
	var scale_lord := LORD_SCALE
	var show: Array = []
	for i in mini(others.size(), HALL_MEMBER_CAP):
		show.append(others[i])
	var left_n := int(floor(float(show.size()) / 2.0))
	var left_list: Array = show.slice(0, left_n)
	var right_list: Array = show.slice(left_n, show.size())
	left_list.reverse()

	var lord_r := _content_radius(str(lord.get("job", "lord")) if not lord.is_empty() else "lord", scale_lord)
	var left_inner_r := 0.0
	var right_inner_r := 0.0
	if not left_list.is_empty():
		left_inner_r = _content_radius(str(left_list[0].get("job", "dps")), scale_mem)
	if not right_list.is_empty():
		right_inner_r = _content_radius(str(right_list[0].get("job", "dps")), scale_mem)
	# Per-side clearances — equal VISUAL air, not equal foot distances.
	var clear_l := lord_r + left_inner_r + VISUAL_GAP if not left_list.is_empty() else VISUAL_GAP
	var clear_r := lord_r + right_inner_r + VISUAL_GAP if not right_list.is_empty() else VISUAL_GAP
	var left_steps: Array = _flank_visual_steps(left_list, scale_mem)
	var right_steps: Array = _flank_visual_steps(right_list, scale_mem)

	var lo := EDGE_SPRITE_PAD
	var hi := area.x - EDGE_SPRITE_PAD
	if not left_list.is_empty():
		lo = _content_radius(str(left_list[left_list.size() - 1].get("job", "dps")), scale_mem) + EDGE_SPRITE_PAD
	if not right_list.is_empty():
		hi = area.x - (
			_content_radius(str(right_list[right_list.size() - 1].get("job", "dps")), scale_mem) + EDGE_SPRITE_PAD
		)

	var gap_scale := 1.0
	var left_xs: Array = []
	var right_xs: Array = []
	for _attempt in 8:
		left_xs = [] if left_list.is_empty() else _flank_xs_from_steps(
			center_x - clear_l * gap_scale, -1.0, left_steps, gap_scale
		)
		right_xs = [] if right_list.is_empty() else _flank_xs_from_steps(
			center_x + clear_r * gap_scale, 1.0, right_steps, gap_scale
		)
		var min_x := center_x
		var max_x := center_x
		for v in left_xs:
			min_x = minf(min_x, float(v))
		for v2 in right_xs:
			max_x = maxf(max_x, float(v2))
		if min_x >= lo - 0.5 and max_x <= hi + 0.5:
			break
		var need_l := maxf(0.0, lo - min_x)
		var need_r := maxf(0.0, max_x - hi)
		var span := maxf(1.0, max_x - min_x)
		gap_scale = clampf(gap_scale * maxf(0.45, (span - need_l - need_r) / span), 0.45, 1.0)

	for i in left_list.size():
		_spawn_hall_actor(left_list[i], Vector2(float(left_xs[i]), floor_y), scale_mem, false, 40 - i * 2, false)
	for j in right_list.size():
		_spawn_hall_actor(right_list[j], Vector2(float(right_xs[j]), floor_y), scale_mem, false, 40 - j * 2, true)

	if not lord.is_empty():
		_spawn_hall_actor(lord, Vector2(center_x, floor_y), scale_lord, true, 55)

	print(
		"LOG: hall stage area=", area,
		" floor_y=", floor_y,
		" center_x=", center_x,
		" clear_l=", clear_l * gap_scale,
		" clear_r=", clear_r * gap_scale,
		" gap_scale=", gap_scale,
		" left=", left_list.size(),
		" right=", right_list.size()
	)

	if others.size() > HALL_MEMBER_CAP:
		var more := UIStyle.label("+%d명 더 있음" % (others.size() - HALL_MEMBER_CAP), 11, UIStyle.TEXT_DIM)
		more.position = Vector2(10, 8)
		_hall_layer.add_child(more)


func _content_radius(job: String, scale_v: float) -> float:
	## Half-width of opaque combat_00 content (after optical recenter).
	var half := 64.0
	match job:
		"tank":
			half = 61.0
		"dps":
			half = 64.0
		"healer":
			half = 49.0
		"mage":
			half = 65.0
		"lord":
			half = 48.0
		_:
			half = 64.0
	return half * scale_v


func _sprite_recenter_x(job: String) -> float:
	## Sheet-space shift so opaque content centers on the foot (combat_00).
	match job:
		"tank":
			return 10.5
		"dps":
			return 17.5
		"healer":
			return -8.5
		"mage":
			return 36.5
		"lord":
			return 33.5
		_:
			return 0.0


func _flank_visual_steps(list: Array, scale_v: float) -> Array:
	## Center-to-center steps that keep VISUAL_GAP between opaque edges.
	var steps: Array = []
	for i in range(1, list.size()):
		var a := _content_radius(str(list[i - 1].get("job", "dps")), scale_v)
		var b := _content_radius(str(list[i].get("job", "dps")), scale_v)
		steps.append(a + b + VISUAL_GAP)
	return steps


func _flank_xs_from_steps(inner_x: float, dir: float, steps: Array, gap_scale: float) -> Array:
	var xs: Array = []
	var x := inner_x
	xs.append(x)
	for i in steps.size():
		x = x + dir * float(steps[i]) * gap_scale
		xs.append(x)
	return xs


func _spawn_hall_actor(
	member: Dictionary,
	pos: Vector2,
	scale_v: float,
	is_lord: bool,
	z: int = 50,
	force_face_left: bool = false
) -> void:
	var mid := str(member.get("id", ""))
	var selected := mid == GameState.selected_guild_member_id
	# Selection/hit box ≈ visible idle body (sheet ~64px * scale, foot offset).
	var body_w := (34.0 if is_lord else 30.0) * scale_v
	var body_h := (40.0 if is_lord else 36.0) * scale_v
	var box_w := maxf(body_w + 8.0, 56.0)
	var box_h := NAMEPLATE_H + 3.0 + body_h
	var root := Control.new()
	# Keep z modest so modal overlay (z=80) always covers hall actors.
	root.z_index = mini(z + (6 if selected else 0) + (10 if is_lord else 0), 70)
	root.z_as_relative = true
	# pos = shared foot point on the floor line.
	root.position = Vector2(pos.x - box_w * 0.5, pos.y - box_h)
	root.custom_minimum_size = Vector2(box_w, box_h)
	root.size = Vector2(box_w, box_h)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	root.clip_contents = false
	_hall_layer.add_child(root)

	# Nameplate above the body — always readable (dense 844 needs contrast + size).
	var plate := PanelContainer.new()
	plate.position = Vector2(0, 0)
	plate.custom_minimum_size = Vector2(box_w, NAMEPLATE_H)
	plate.size = Vector2(box_w, NAMEPLATE_H)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.z_index = 2
	var plate_sb := StyleBoxFlat.new()
	plate_sb.bg_color = Color(0.04, 0.04, 0.07, 0.88)
	plate_sb.border_color = Color(0.82, 0.68, 0.32, 0.55 if (selected or is_lord) else 0.35)
	plate_sb.set_border_width_all(1)
	plate_sb.set_corner_radius_all(3)
	plate_sb.content_margin_left = 3
	plate_sb.content_margin_right = 3
	plate_sb.content_margin_top = 1
	plate_sb.content_margin_bottom = 1
	plate.add_theme_stylebox_override("panel", plate_sb)
	var name_fs := 12
	if _dense:
		name_fs = 13
	elif is_lord or selected:
		name_fs = 12
	var name_col := UIStyle.GOLD_BRIGHT if (selected or is_lord) else Color(0.98, 0.96, 0.9)
	var name_l := UIStyle.label(str(member.get("name", "")), name_fs, name_col)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(name_l)
	root.add_child(plate)

	var body_x := (box_w - body_w) * 0.5
	var body_y := NAMEPLATE_H + 3.0
	if selected:
		# Thin ring only — sized to character body, not nameplate.
		var pad := 2.0
		var rx := body_x - pad
		var ry := body_y - pad
		var rw := body_w + pad * 2.0
		var rh := body_h + pad * 2.0
		var glow := ColorRect.new()
		glow.position = Vector2(rx, ry)
		glow.size = Vector2(rw, rh)
		glow.color = Color(1.0, 0.85, 0.35, 0.12)
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(glow)
		for edge in [
			[Vector2(rx, ry), Vector2(rw, 2)],
			[Vector2(rx, ry + rh - 2.0), Vector2(rw, 2)],
			[Vector2(rx, ry), Vector2(2, rh)],
			[Vector2(rx + rw - 2.0, ry), Vector2(2, rh)],
		]:
			var line := ColorRect.new()
			line.position = edge[0]
			line.size = edge[1]
			line.color = UIStyle.GOLD_BRIGHT
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			root.add_child(line)

	var job := str(member.get("job", "dps"))
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = SpriteFactory.ally_frames(job)
	spr.animation = &"idle"
	spr.play()
	spr.scale = Vector2(scale_v, scale_v)
	# Feet on shared floor line; nudge X so opaque content centers on foot.
	var rcx := _sprite_recenter_x(job) * scale_v
	if force_face_left:
		rcx = -rcx
	spr.position = Vector2(box_w * 0.5 + rcx, box_h)
	spr.centered = true
	spr.offset = Vector2(0, SPRITE_FOOT_OFFSET_Y)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if force_face_left:
		spr.flip_h = true
	root.add_child(spr)

	var btn := Button.new()
	btn.flat = true
	btn.position = Vector2(body_x, body_y)
	btn.size = Vector2(body_w, body_h)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.pressed.connect(_make_select_cb(mid))
	root.add_child(btn)


func _make_select_cb(member_id: String) -> Callable:
	return func():
		GameState.select_guild_member(member_id)
		if _mode == MENU_STATS:
			_open_detail_stats()


func _refresh_detail() -> void:
	for c in _detail_box.get_children():
		c.queue_free()
	_detail_box.add_child(UIStyle.label("선택된 길드원", 15, UIStyle.GOLD_BRIGHT))
	var m := GameState.get_member_by_id(GameState.selected_guild_member_id)
	if m.is_empty() and not GameState.members.is_empty():
		m = GameState.members[0]
		GameState.selected_guild_member_id = str(m.get("id", ""))
	if m.is_empty():
		_detail_box.add_child(UIStyle.label("길드원이 없습니다.", 13, UIStyle.TEXT_DIM))
		return

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	_detail_box.add_child(head)
	var portrait := TextureRect.new()
	portrait.texture = _portrait_for(str(m.get("job", "lord")))
	portrait.custom_minimum_size = Vector2(64, 64)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	head.add_child(portrait)
	var meta := VBoxContainer.new()
	head.add_child(meta)
	meta.add_child(UIStyle.label(str(m.get("name", "")), 17, UIStyle.GOLD_BRIGHT))
	meta.add_child(UIStyle.label("%s  ·  Lv.%d" % [UIStyle.job_name(str(m.get("job", ""))), int(m.get("level", 1))], 13))
	meta.add_child(UIStyle.label("EXP %d / 100" % int(m.get("exp", 0)), 12, UIStyle.TEXT_DIM))
	var pk := GameState.member_party_kind(str(m.get("id", "")))
	var party_txt := GameState.guild_party_label(pk) if pk != "" else "대기"
	meta.add_child(UIStyle.label("배정: %s" % party_txt, 12, UIStyle.TEXT_DIM))
	if bool(m.get("injured", false)):
		meta.add_child(UIStyle.label("상태: 부상", 12, UIStyle.DANGER))

	var preview := GameState.compute_combat_preview(m)
	_detail_box.add_child(HSeparator.new())
	_detail_box.add_child(UIStyle.label("전투 능력치", 14, UIStyle.GOLD))
	_detail_box.add_child(_stat_row("공격력 (ATK)", str(preview.get("atk", 0))))
	_detail_box.add_child(_stat_row("방어력 (DEF)", str(preview.get("def", 0))))
	_detail_box.add_child(_stat_row("체력 (HP)", str(preview.get("hp", 0))))
	_detail_box.add_child(_stat_row("이동속도 (SPD)", str(preview.get("spd", 0))))

	var stats: Dictionary = m.get("stats", {})
	_detail_box.add_child(HSeparator.new())
	_detail_box.add_child(UIStyle.label("기본 STAT", 14, UIStyle.GOLD))
	_detail_box.add_child(_stat_row("힘 (STR)", str(int(stats.get("str", 0)))))
	_detail_box.add_child(_stat_row("활력 (VIT)", str(int(stats.get("vit", 0)))))
	_detail_box.add_child(_stat_row("민첩 (AGI)", str(int(stats.get("agi", 0)))))
	_detail_box.add_child(_stat_row("지능 (INT)", str(int(stats.get("int", 0)))))
	_detail_box.add_child(_stat_row("지혜 (WIS)", str(int(stats.get("wis", 0)))))

	var detail_btn := Button.new()
	detail_btn.text = "상세 능력치"
	detail_btn.custom_minimum_size = Vector2(0, 40)
	UIStyle.apply_button(detail_btn)
	detail_btn.pressed.connect(_open_detail_stats)
	_detail_box.add_child(detail_btn)

	if _mode == MENU_MEMBERS:
		_detail_box.add_child(HSeparator.new())
		_detail_box.add_child(UIStyle.label("전체 길드원", 13, UIStyle.TEXT_DIM))
		for om in GameState.members:
			var row := Button.new()
			var oid := str(om.get("id", ""))
			row.text = "%s  %s Lv.%d" % [om.get("name"), UIStyle.job_name(str(om.get("job", ""))), int(om.get("level", 1))]
			row.alignment = HORIZONTAL_ALIGNMENT_LEFT
			row.custom_minimum_size = Vector2(0, 40)
			UIStyle.apply_button(row)
			if oid == GameState.selected_guild_member_id:
				row.add_theme_stylebox_override("normal", UIStyle.button_pressed())
			row.pressed.connect(_make_select_cb(oid))
			_detail_box.add_child(row)


func _stat_row(label: String, value: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := UIStyle.label(label, 12, UIStyle.TEXT_DIM)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	row.add_child(UIStyle.label(value, 13, UIStyle.TEXT))
	return row


func _refresh_party_cards() -> void:
	for c in _party_host.get_children():
		c.queue_free()
	for kind in GameState.GUILD_PARTY_KINDS:
		_party_host.add_child(_make_party_card(kind))
	call_deferred("_equalize_party_card_heights")


func _equalize_party_card_heights() -> void:
	if _party_host == null:
		return
	var max_h := 0.0
	for c in _party_host.get_children():
		if c is Control:
			max_h = maxf(max_h, (c as Control).get_combined_minimum_size().y)
	if max_h < 8.0:
		return
	# Pad so 편성 + bottom margin never sit on the clip edge.
	max_h += 8.0 if _dense else 12.0
	# Never grow past the layout-reserved strip (overflow was covering the footer).
	if _party_wrap:
		var avail := maxf(64.0, _party_wrap.size.y - 26.0)
		max_h = minf(max_h, avail)
	for c2 in _party_host.get_children():
		if c2 is Control:
			(c2 as Control).custom_minimum_size.y = max_h


func _make_party_card(kind: String) -> PanelContainer:
	var accent := Color(0.35, 0.55, 0.32)
	match kind:
		"hunt":
			accent = Color(0.28, 0.5, 0.3)
		"train":
			accent = Color(0.55, 0.42, 0.18)
		"defend":
			accent = Color(0.25, 0.38, 0.58)
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	# Height comes from content; equalized after refresh.
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(accent.r * 0.35, accent.g * 0.35, accent.b * 0.35, 0.92)
	sb.border_color = accent.lightened(0.35)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 4
	sb.content_margin_bottom = 6
	card.add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	vb.alignment = BoxContainer.ALIGNMENT_BEGIN
	vb.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	card.add_child(vb)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	head.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	vb.add_child(head)
	var title := UIStyle.label(GameState.guild_party_label(kind), 12 if _dense else 13, UIStyle.GOLD_BRIGHT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var ids: Array = GameState.get_guild_party(kind)
	var max_n: int = int(GameState.GUILD_PARTY_MAX.get(kind, 5))
	head.add_child(UIStyle.label("%d/%d" % [ids.size(), max_n], 11, UIStyle.TEXT_DIM))

	var portraits := HBoxContainer.new()
	# Dense 844: spread slots across the card — tiny left-clumped faces read as “missing”.
	portraits.add_theme_constant_override("separation", 4 if _dense else 3)
	portraits.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portraits.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	vb.add_child(portraits)
	# Viewport→screen scale on 844 shrinks chrome; keep dense slots larger so 5/5 stay readable.
	var slot_sz := 34.0 if _dense else 28.0
	var face_sz := 30.0 if _dense else 24.0
	for i in max_n:
		var slot := PanelContainer.new()
		var ssb := StyleBoxFlat.new()
		ssb.bg_color = Color(0.08, 0.09, 0.12, 0.85)
		ssb.border_color = accent
		ssb.set_border_width_all(1)
		ssb.set_corner_radius_all(3)
		ssb.content_margin_left = 2
		ssb.content_margin_right = 2
		ssb.content_margin_top = 2
		ssb.content_margin_bottom = 2
		slot.add_theme_stylebox_override("panel", ssb)
		slot.custom_minimum_size = Vector2(slot_sz, slot_sz)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		slot.clip_contents = true
		if i < ids.size():
			var mem := GameState.get_member_by_id(str(ids[i]))
			var tr := TextureRect.new()
			tr.texture = _portrait_for(str(mem.get("job", "lord")))
			tr.custom_minimum_size = Vector2(face_sz, face_sz)
			tr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tr.size_flags_vertical = Control.SIZE_EXPAND_FILL
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			tr.tooltip_text = "%s Lv.%d" % [mem.get("name", ""), int(mem.get("level", 1))]
			slot.add_child(tr)
		else:
			var plus := UIStyle.label("+", 14 if _dense else 12, UIStyle.TEXT_DIM)
			plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			plus.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			plus.size_flags_vertical = Control.SIZE_EXPAND_FILL
			plus.custom_minimum_size = Vector2(face_sz, face_sz)
			slot.add_child(plus)
		portraits.add_child(slot)

	var edit := Button.new()
	edit.text = "편성"
	edit.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIStyle.apply_button(edit)
	# Override mobile 48px min from UIStyle — keep 편성 fully inside the card.
	var btn_h := 26.0 if _dense else 32.0
	edit.custom_minimum_size = Vector2(0, btn_h)
	edit.clip_text = false
	for style_name in ["normal", "hover", "pressed"]:
		var base_sb: StyleBoxFlat
		match style_name:
			"hover":
				base_sb = UIStyle.button_hover()
			"pressed":
				base_sb = UIStyle.button_pressed()
			_:
				base_sb = UIStyle.button_normal()
		var compact_sb := base_sb.duplicate() as StyleBoxFlat
		compact_sb.content_margin_top = 4
		compact_sb.content_margin_bottom = 4
		compact_sb.content_margin_left = 8
		compact_sb.content_margin_right = 8
		edit.add_theme_stylebox_override(style_name, compact_sb)
	var kind_copy: String = kind
	edit.pressed.connect(func(): _open_assign(kind_copy))
	vb.add_child(edit)
	return card


func _open_assign(kind: String) -> void:
	_mode = MENU_PARTY
	_refresh_nav()
	_open_formation(kind)


func _open_formation(kind: String) -> void:
	_assign_kind = kind
	_mode = MENU_PARTY
	_refresh_nav()
	_close_overlay()
	if _hall_wrap:
		_hall_wrap.visible = false
	if _detail_wrap:
		_detail_wrap.visible = false
	if _party_wrap:
		_party_wrap.visible = false
	if _formation == null:
		_formation = PartyFormationPanelScript.new()
		_formation.name = "PartyFormation"
		_body_host.add_child(_formation)
		_formation.closed.connect(_on_formation_closed)
		_formation.saved.connect(func(_k): _refresh_party_cards())
	_formation.visible = true
	# Avoid duplicate bottom chrome while formation shows its own party strip + actions.
	if _footer:
		_footer.visible = false
	_apply_responsive_layout()
	_fit_formation()
	if not _formation_state.is_empty() and str(_formation_state.get("party_kind", "")) == kind:
		_formation.call("restore_view_state", _formation_state)
	else:
		_formation.call("setup", kind)
	# Re-lock shell after rebuild so content min-width cannot spill past the body.
	_fit_formation()


func _fit_formation() -> void:
	if _formation == null or not is_instance_valid(_formation):
		return
	## Content ratios: nav 8% / list+detail 92% (list 62% + detail 30% of content).
	var area := _body_host.size
	if area.x < 8.0 or area.y < 8.0:
		area = Vector2(maxf(size.x - 16.0, 640.0), maxf(size.y - 120.0, 280.0))
	var gap := 4.0
	var right_pad := 12.0
	var usable := maxf(area.x - gap - right_pad, 400.0)
	var nav_w := clampf(usable * RATIO_NAV, 72.0, 104.0)
	if _dense:
		nav_w = clampf(usable * RATIO_NAV, 64.0, 88.0)
	var form_w := maxf(200.0, usable - nav_w)
	var detail_w := clampf(usable * RATIO_DETAIL, 200.0, 380.0)
	var nav_host := _ensure_nav_host()
	nav_host.position = Vector2(0, 0)
	nav_host.size = Vector2(nav_w, area.y)
	nav_host.custom_minimum_size = Vector2(nav_w, area.y)
	nav_host.clip_contents = true
	var nav_scroll := nav_host.get_node_or_null("NavScroll") as ScrollContainer
	if nav_scroll == null:
		nav_scroll = _body_host.get_node_or_null("NavScroll") as ScrollContainer
	if nav_scroll:
		nav_scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		nav_scroll.clip_contents = true
	if _nav_box:
		_nav_box.custom_minimum_size = Vector2(maxi(1.0, nav_w - 4.0), 0)
		_nav_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for mid in _nav_buttons.keys():
		var b: TextureButton = _nav_buttons[mid]
		if is_instance_valid(b):
			b.custom_minimum_size = Vector2(maxi(56.0, nav_w - 12.0), 80 if _dense else 88)
	var fpos := Vector2(nav_w + gap, 0)
	var fsize := Vector2(form_w, maxf(200.0, area.y))
	_formation.position = fpos
	_formation.clip_contents = true
	_formation.custom_minimum_size = fsize
	_formation.size = fsize
	if _formation.has_method("set_layout_ratios"):
		_formation.call("set_layout_ratios", RATIO_LIST, RATIO_DETAIL, detail_w)
	if _formation.has_method("_apply_shell_size"):
		_formation.call("_apply_shell_size", fsize)


func _ensure_nav_host() -> Control:
	## Clip host so ScrollContainer content min-width cannot spill into formation.
	var host := _body_host.get_node_or_null("NavHost") as Control
	if host != null:
		return host
	host = Control.new()
	host.name = "NavHost"
	host.clip_contents = true
	_body_host.add_child(host)
	_body_host.move_child(host, 0)
	var nav_scroll := _body_host.get_node_or_null("NavScroll") as ScrollContainer
	if nav_scroll and nav_scroll.get_parent() == _body_host:
		_body_host.remove_child(nav_scroll)
		host.add_child(nav_scroll)
		nav_scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	return host


func _hide_formation() -> void:
	if _formation and is_instance_valid(_formation):
		var st: Variant = _formation.call("view_state")
		if typeof(st) == TYPE_DICTIONARY:
			_formation_state = st
		_formation.visible = false
	if _footer:
		_footer.visible = true
	if _hall_wrap:
		_hall_wrap.visible = true
	if _detail_wrap:
		_detail_wrap.visible = true
	if _party_wrap:
		_party_wrap.visible = true
	_apply_responsive_layout()


func _on_formation_closed() -> void:
	if _formation and is_instance_valid(_formation):
		var st: Variant = _formation.call("view_state")
		if typeof(st) == TYPE_DICTIONARY:
			_formation_state = st
	_hide_formation()
	_mode = MENU_MEMBERS
	_refresh_all()


func _open_detail_stats() -> void:
	var m := GameState.get_member_by_id(GameState.selected_guild_member_id)
	if m.is_empty():
		return
	_clear_overlay_body()
	_fit_overlay()
	if _hall_layer:
		_hall_layer.visible = false
	_overlay.visible = true
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	_overlay_panel.add_child(root)
	root.add_child(UIStyle.label("상세 능력치 — %s" % m.get("name", ""), 18, UIStyle.GOLD_BRIGHT))
	root.add_child(UIStyle.label("%s  Lv.%d  EXP %d" % [
		UIStyle.job_name(str(m.get("job", ""))), int(m.get("level", 1)), int(m.get("exp", 0))
	], 13))

	var preview := GameState.compute_combat_preview(m)
	var stats: Dictionary = m.get("stats", {})
	root.add_child(UIStyle.label("전투 파생 (전투 공식과 동일)", 14, UIStyle.GOLD))
	root.add_child(UIStyle.label("ATK %d · DEF %d · HP %d · SPD %d" % [
		int(preview.get("atk", 0)), int(preview.get("def", 0)),
		int(preview.get("hp", 0)), int(preview.get("spd", 0))
	], 13))
	root.add_child(UIStyle.label("기본 STAT", 14, UIStyle.GOLD))
	root.add_child(UIStyle.label("STR %d · VIT %d · AGI %d · INT %d · WIS %d" % [
		int(stats.get("str", 0)), int(stats.get("vit", 0)), int(stats.get("agi", 0)),
		int(stats.get("int", 0)), int(stats.get("wis", 0))
	], 13))

	var skills: Array = m.get("skills", [])
	root.add_child(UIStyle.label("스킬", 14, UIStyle.GOLD))
	if skills.is_empty():
		root.add_child(UIStyle.label("(없음)", 12, UIStyle.TEXT_DIM))
	else:
		root.add_child(UIStyle.label(", ".join(PackedStringArray(skills)), 13))

	var traits: Array = m.get("traits", [])
	root.add_child(UIStyle.label("특성", 14, UIStyle.GOLD))
	if traits.is_empty():
		root.add_child(UIStyle.label("(없음)", 12, UIStyle.TEXT_DIM))
	else:
		root.add_child(UIStyle.label(", ".join(PackedStringArray(traits)), 13))

	var eq: Dictionary = m.get("equipment", {})
	root.add_child(UIStyle.label("장비", 14, UIStyle.GOLD))
	var eq_parts: PackedStringArray = PackedStringArray()
	for slot in ["weapon", "armor", "accessory"]:
		var eid := str(eq.get(slot, ""))
		if eid == "":
			eq_parts.append("%s: —" % slot)
		else:
			var it := GameState.get_item(eid)
			eq_parts.append("%s: %s" % [slot, str(it.get("name", eid))])
	root.add_child(UIStyle.label(" · ".join(eq_parts), 12))
	root.add_child(UIStyle.label("장비 수치 보정은 전투에 아직 적용되지 않습니다.", 11, UIStyle.TEXT_DIM))

	var close_b := Button.new()
	close_b.text = "닫기"
	close_b.custom_minimum_size = Vector2(0, 44)
	UIStyle.apply_button(close_b)
	close_b.pressed.connect(_close_overlay)
	root.add_child(close_b)


func _open_facility_panel() -> void:
	_clear_overlay_body()
	_fit_overlay()
	if _hall_layer:
		_hall_layer.visible = false
	_overlay.visible = true
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	_overlay_panel.add_child(root)
	root.add_child(UIStyle.label("시설 이동", 18, UIStyle.GOLD_BRIGHT))
	root.add_child(UIStyle.label("기존 마을 시설 화면으로 이동합니다.", 12, UIStyle.TEXT_DIM))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 240)
	root.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	for fid in ["inn", "shop", "blacksmith", "training", "warehouse", "infirmary", "quest", "gate"]:
		var b := Button.new()
		b.text = UIStyle.facility_name(fid)
		b.custom_minimum_size = Vector2(0, 44)
		UIStyle.apply_button(b)
		var id_copy: String = str(fid)
		b.pressed.connect(func(): SceneRouter.go_facility(id_copy))
		box.add_child(b)
	var cancel := Button.new()
	cancel.text = "닫기"
	cancel.custom_minimum_size = Vector2(0, 44)
	UIStyle.apply_button(cancel)
	cancel.pressed.connect(func():
		_close_overlay()
		_mode = MENU_MEMBERS
		_refresh_all()
	)
	root.add_child(cancel)


func _clear_overlay_body() -> void:
	for c in _overlay_panel.get_children():
		c.queue_free()


func _close_overlay() -> void:
	_overlay.visible = false
	if _hall_layer and not (_formation and _formation.visible):
		_hall_layer.visible = true
	_assign_kind = ""
	_draft_ids.clear()
	_clear_overlay_body()


func _portrait_for(job: String) -> Texture2D:
	## Prefer hunt/combat idle sheet for quality; fall back to portrait thumbs.
	var sheet := PORTRAIT_DIR + "%s/combat_00.png" % job
	if ResourceLoader.exists(sheet):
		return load(sheet) as Texture2D
	var path := PORTRAIT_DIR + "portrait_%s.png" % job
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return load(PORTRAIT_DIR + "portrait_lord.png") as Texture2D


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _overlay.visible:
			_close_overlay()
			get_viewport().set_input_as_handled()
		else:
			SceneRouter.go_town()
			get_viewport().set_input_as_handled()
