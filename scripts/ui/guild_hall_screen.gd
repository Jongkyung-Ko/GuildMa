extends Control

## Guild Hall HQ — responsive layout (portrait scroll / landscape split) + stage composition.

const HALL_BG := "res://assets/backgrounds/guild_interior.png"
const PORTRAIT_DIR := "res://assets/sprites/characters/"
const SPRITE_SCALE := 0.48
const LORD_SCALE := 0.62
const HALL_MEMBER_CAP := 10
const COMPACT_WIDTH := 900.0

const MENU_MEMBERS := "members"
const MENU_PARTY := "party"
const MENU_STATS := "stats"
const MENU_FACILITY := "facility"

var _mode: String = MENU_MEMBERS
var _assign_kind: String = ""
var _draft_ids: Array = []
var _toast: Label
var _compact: bool = false

var _top_bar: PanelContainer
var _top_info: Label
var _town_btn: Button
var _body_scroll: ScrollContainer
var _body_host: Control
var _nav_box: Container
var _hall_wrap: PanelContainer
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
	_refresh_all()


func _on_window_resized() -> void:
	_apply_responsive_layout()
	call_deferred("_refresh_hall")


func _is_compact() -> bool:
	var sz := size
	if sz.x < 8.0 or sz.y < 8.0:
		var win := get_window()
		if win:
			sz = Vector2(win.size)
	# Portrait or narrow design viewport → stacked scroll layout.
	return sz.y > sz.x or sz.x < COMPACT_WIDTH


func _build_shell() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.1)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_top_bar = UIStyle.make_panel()
	add_child(_top_bar)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	_top_bar.add_child(top_row)
	top_row.add_child(UIStyle.label("길드", 18, UIStyle.GOLD_BRIGHT))
	_top_info = UIStyle.label("", 14)
	_top_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top_row.add_child(_top_info)
	_town_btn = Button.new()
	_town_btn.text = "마을로"
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

	_nav_box = VBoxContainer.new()
	_nav_box.add_theme_constant_override("separation", 6)
	_body_host.add_child(_nav_box)
	_nav_box.add_child(UIStyle.label("길드 메뉴", 13, UIStyle.TEXT_DIM))
	for entry in [
		[MENU_MEMBERS, "길드원"],
		[MENU_PARTY, "파티 편성"],
		[MENU_STATS, "능력치"],
		[MENU_FACILITY, "시설"],
	]:
		var b := Button.new()
		b.text = str(entry[1])
		b.custom_minimum_size = Vector2(0, 44)
		UIStyle.apply_button(b)
		var mid: String = str(entry[0])
		b.pressed.connect(_make_mode_cb(mid))
		_nav_box.add_child(b)
		_nav_buttons[mid] = b

	_hall_wrap = UIStyle.make_panel()
	_hall_wrap.clip_contents = true
	_body_host.add_child(_hall_wrap)
	var interior := TextureRect.new()
	interior.name = "Interior"
	interior.set_anchors_preset(PRESET_FULL_RECT)
	interior.texture = load(HALL_BG)
	interior.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	interior.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	interior.modulate = Color(0.92, 0.9, 0.88, 1)
	_hall_wrap.add_child(interior)
	var dim := ColorRect.new()
	dim.set_anchors_preset(PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.04, 0.08, 0.22)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hall_wrap.add_child(dim)
	_hall_layer = Control.new()
	_hall_layer.set_anchors_preset(PRESET_FULL_RECT)
	_hall_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	_hall_layer.clip_contents = true
	_hall_wrap.add_child(_hall_layer)
	var hall_title := UIStyle.label("길드 홀", 15, UIStyle.GOLD_BRIGHT)
	hall_title.set_anchors_preset(PRESET_TOP_LEFT)
	hall_title.position = Vector2(10, 8)
	_hall_wrap.add_child(hall_title)

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
	_body_host.add_child(_party_wrap)
	var party_vb := VBoxContainer.new()
	party_vb.set_anchors_preset(PRESET_FULL_RECT)
	party_vb.add_theme_constant_override("separation", 6)
	_party_wrap.add_child(party_vb)
	party_vb.add_child(UIStyle.label("임무 파티", 14, UIStyle.GOLD_BRIGHT))
	_party_host = HBoxContainer.new()
	_party_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_party_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
	_compact = _is_compact()
	var pad := 8.0
	var top_h := 56.0 if _compact else 52.0
	var foot_h := 52.0
	var toast_h := 22.0
	var w := size.x
	var h := size.y
	if w < 8.0 or h < 8.0:
		return

	_top_bar.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
	_top_bar.offset_left = pad
	_top_bar.offset_right = -pad
	_top_bar.offset_top = pad
	_top_bar.offset_bottom = pad + top_h
	_town_btn.text = "마을로" if _compact else "마을로 돌아가기"

	_toast.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	_toast.offset_left = pad
	_toast.offset_right = -pad

	if _compact:
		# Footer lives at end of scroll content so portrait never leaves a huge empty void.
		_footer.visible = false
		_toast.offset_top = -(pad + toast_h)
		_toast.offset_bottom = -pad
		_body_scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		_body_scroll.offset_left = pad
		_body_scroll.offset_right = -pad
		_body_scroll.offset_top = pad + top_h + 4.0
		_body_scroll.offset_bottom = -(pad + toast_h + 4.0)
		_layout_compact(w - pad * 2.0)
	else:
		_footer.visible = true
		_footer.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
		_footer.offset_left = pad
		_footer.offset_right = -pad
		_footer.offset_top = -(pad + foot_h)
		_footer.offset_bottom = -pad
		_toast.offset_top = -(pad + foot_h + toast_h)
		_toast.offset_bottom = -(pad + foot_h)
		_body_scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		_body_scroll.offset_left = pad
		_body_scroll.offset_right = -pad
		_body_scroll.offset_top = pad + top_h + 4.0
		_body_scroll.offset_bottom = -(pad + foot_h + toast_h + 4.0)
		var body_h := _body_scroll.size.y if _body_scroll.size.y > 8.0 else h - top_h - foot_h - toast_h - 24.0
		_layout_wide(w - pad * 2.0, body_h)

	_fit_overlay()


func _layout_compact(content_w: float) -> void:
	# Vertical stack inside scroll — hall on top, then detail, then parties, then actions.
	_body_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var compact_actions := _ensure_compact_actions()
	compact_actions.visible = true
	var gap := 8.0
	var y := 0.0
	var nav_h := 56.0
	_ensure_nav_orientation(true)
	_nav_box.position = Vector2(0, y)
	_nav_box.size = Vector2(content_w, nav_h)
	y += nav_h + gap

	var hall_h := clampf(content_w * 0.72, 240.0, 360.0)
	_hall_wrap.position = Vector2(0, y)
	_hall_wrap.size = Vector2(content_w, hall_h)
	_hall_wrap.custom_minimum_size = Vector2(content_w, hall_h)
	y += hall_h + gap

	var detail_h := 300.0
	_detail_wrap.position = Vector2(0, y)
	_detail_wrap.size = Vector2(content_w, detail_h)
	_detail_wrap.custom_minimum_size = Vector2(content_w, detail_h)
	y += detail_h + gap

	_ensure_party_orientation(true)
	var party_h := 540.0
	_party_wrap.position = Vector2(0, y)
	_party_wrap.size = Vector2(content_w, party_h)
	_party_wrap.custom_minimum_size = Vector2(content_w, party_h)
	y += party_h + gap

	# Inline action row (always reachable by scrolling to end).
	compact_actions.position = Vector2(0, y)
	compact_actions.size = Vector2(content_w, 52.0)
	y += 60.0

	_body_host.custom_minimum_size = Vector2(content_w, y)
	_body_host.size = Vector2(content_w, y)


func _ensure_compact_actions() -> HBoxContainer:
	var existing := _body_host.get_node_or_null("CompactActions")
	if existing:
		return existing as HBoxContainer
	var row := HBoxContainer.new()
	row.name = "CompactActions"
	row.add_theme_constant_override("separation", 10)
	_body_host.add_child(row)
	var save_btn := Button.new()
	save_btn.text = "파티 저장"
	save_btn.custom_minimum_size = Vector2(0, 48)
	save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIStyle.apply_button(save_btn)
	save_btn.pressed.connect(_on_save_parties)
	row.add_child(save_btn)
	var close_btn := Button.new()
	close_btn.text = "닫기"
	close_btn.custom_minimum_size = Vector2(0, 48)
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIStyle.apply_button(close_btn)
	close_btn.pressed.connect(func(): SceneRouter.go_town())
	row.add_child(close_btn)
	return row


func _layout_wide(content_w: float, content_h: float) -> void:
	_body_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var compact_actions := _body_host.get_node_or_null("CompactActions")
	if compact_actions:
		compact_actions.visible = false
	_ensure_nav_orientation(false)
	_ensure_party_orientation(false)
	var nav_w := 150.0
	var detail_w := 260.0
	var gap := 8.0
	var mid_w := content_w - nav_w - detail_w - gap * 2.0
	var hall_h := maxf(200.0, content_h * 0.58)
	var party_h := maxf(150.0, content_h - hall_h - gap)

	_nav_box.position = Vector2(0, 0)
	_nav_box.size = Vector2(nav_w, content_h)

	_hall_wrap.position = Vector2(nav_w + gap, 0)
	_hall_wrap.size = Vector2(mid_w, hall_h)
	_hall_wrap.custom_minimum_size = Vector2(mid_w, hall_h)

	_party_wrap.position = Vector2(nav_w + gap, hall_h + gap)
	_party_wrap.size = Vector2(mid_w + detail_w + gap, party_h)
	_party_wrap.custom_minimum_size = Vector2(0, party_h)

	_detail_wrap.position = Vector2(nav_w + gap + mid_w + gap, 0)
	_detail_wrap.size = Vector2(detail_w, hall_h)
	_detail_wrap.custom_minimum_size = Vector2(detail_w, hall_h)

	_body_host.custom_minimum_size = Vector2(content_w, content_h)
	_body_host.size = Vector2(content_w, content_h)


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
		_open_facility_panel()
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
	var vh := maxf(size.y, 480.0)
	var pw := minf(720.0, vw - 24.0)
	var ph := minf(520.0, vh - 48.0)
	if _compact:
		pw = vw - 16.0
		ph = minf(vh * 0.82, vh - 32.0)
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
	_refresh_hall()
	_refresh_detail()
	_refresh_party_cards()


func _refresh_top() -> void:
	if _compact:
		_top_info.text = "%s Lv.%d · 명성 %d · %s · %dG" % [
			GameState.guild_name, GameState.guild_level, GameState.reputation,
			GameState.member_count_text(), GameState.gold,
		]
	else:
		_top_info.text = "%s   Lv.%d   명성 %d   길드원 %s   골드 %d" % [
			GameState.guild_name, GameState.guild_level, GameState.reputation,
			GameState.member_count_text(), GameState.gold,
		]


func _refresh_nav() -> void:
	for mid in _nav_buttons.keys():
		var b: Button = _nav_buttons[mid]
		if not is_instance_valid(b):
			continue
		if mid == _mode:
			b.add_theme_stylebox_override("normal", UIStyle.button_pressed())
		else:
			UIStyle.apply_button(b)


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

	# Use wrap size explicitly — child full-rect layer may still report 0,0 this frame.
	var area := _hall_wrap.size
	if area.x < 20.0 or area.y < 20.0:
		area = Vector2(640, 280)
	_hall_layer.size = area
	_hall_layer.position = Vector2.ZERO
	_compose_stage(lord, others, area)


func _compose_stage(lord: Dictionary, others: Array, area: Vector2) -> void:
	## Guildmaster front-center near the hearth; members balanced L/R on the floor.
	var margin_x := clampf(area.x * 0.07, 28.0, 56.0)
	# Interior art floor sits in the lower third — keep feet on stone, not the panel rim.
	var floor_y := area.y * 0.70
	var center_x := area.x * 0.5
	var lord_clear := clampf(area.x * 0.13, 78.0, 120.0)
	var scale_mem := SPRITE_SCALE if area.x >= 480.0 else SPRITE_SCALE * 0.85
	var scale_lord := LORD_SCALE if area.x >= 480.0 else LORD_SCALE * 0.88

	var show: Array = []
	for i in mini(others.size(), HALL_MEMBER_CAP):
		show.append(others[i])
	var left_n := int(ceili(float(show.size()) / 2.0))
	var left_list: Array = show.slice(0, left_n)
	var right_list: Array = show.slice(left_n, show.size())

	# Farther flanks first; lord last (highest z) so he reads as the focus.
	_place_flank(left_list, margin_x, center_x - lord_clear, floor_y - 10.0, scale_mem, false)
	_place_flank(right_list, center_x + lord_clear, area.x - margin_x, floor_y - 10.0, scale_mem, true)

	if not lord.is_empty():
		_spawn_hall_actor(lord, Vector2(center_x, floor_y + 6.0), scale_lord, true, 60)

	if others.size() > HALL_MEMBER_CAP:
		var more := UIStyle.label("+%d명 더 있음" % (others.size() - HALL_MEMBER_CAP), 11, UIStyle.TEXT_DIM)
		more.position = Vector2(10, area.y - 22)
		_hall_layer.add_child(more)


func _place_flank(list: Array, x0: float, x1: float, floor_y: float, scale_v: float, face_left: bool) -> void:
	if list.is_empty():
		return
	var span := x1 - x0
	var n := list.size()
	for i in n:
		var t := 0.5 if n == 1 else float(i) / float(n - 1)
		var x := x0 + span * t
		# Outer members slightly farther (higher); near-center slightly forward.
		var depth := absf(t - 0.5) * 18.0
		var y := floor_y - depth
		var z := 30 + int(y)
		_spawn_hall_actor(list[i], Vector2(x, y), scale_v, false, z, face_left)


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
	var box_w := 88.0 if is_lord else 76.0
	var box_h := 110.0 if is_lord else 96.0
	var root := Control.new()
	# Keep z modest so modal overlay (z=80) always covers hall actors.
	root.z_index = mini(z + (8 if selected else 0) + (12 if is_lord else 0), 70)
	root.z_as_relative = true
	# pos = foot point on the floor line.
	root.position = Vector2(pos.x - box_w * 0.5, pos.y - box_h)
	root.custom_minimum_size = Vector2(box_w, box_h)
	root.size = Vector2(box_w, box_h)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	root.clip_contents = true
	_hall_layer.add_child(root)

	if selected:
		var glow := ColorRect.new()
		glow.size = Vector2(box_w - 4.0, box_h - 4.0)
		glow.position = Vector2(2, 2)
		glow.color = Color(1.0, 0.85, 0.35, 0.2)
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(glow)
		var border := Panel.new()
		border.size = Vector2(box_w, box_h)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.border_color = UIStyle.GOLD_BRIGHT
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(4)
		border.add_theme_stylebox_override("panel", sb)
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(border)

	# Nameplate above the sprite so it never covers the body.
	var name_l := UIStyle.label(
		str(member.get("name", "")),
		12 if is_lord else 11,
		UIStyle.GOLD_BRIGHT if selected or is_lord else UIStyle.TEXT
	)
	name_l.position = Vector2(0, 0)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.custom_minimum_size = Vector2(box_w, 16)
	name_l.size = Vector2(box_w, 16)
	root.add_child(name_l)

	var job := str(member.get("job", "dps"))
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = SpriteFactory.ally_frames(job)
	spr.animation = &"idle"
	spr.play()
	spr.scale = Vector2(scale_v, scale_v)
	# Feet near bottom of the hit box; keep drawing inside the clipped root.
	spr.position = Vector2(box_w * 0.5, box_h - 6.0)
	spr.centered = true
	spr.offset = Vector2(0, -32)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if force_face_left:
		spr.flip_h = true
	root.add_child(spr)

	var btn := Button.new()
	btn.flat = true
	btn.set_anchors_preset(PRESET_FULL_RECT)
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
	if _compact:
		card.custom_minimum_size = Vector2(0, 150)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(accent.r * 0.35, accent.g * 0.35, accent.b * 0.35, 0.92)
	sb.border_color = accent.lightened(0.35)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	card.add_child(vb)
	vb.add_child(UIStyle.label(GameState.guild_party_label(kind), 14, UIStyle.GOLD_BRIGHT))
	vb.add_child(UIStyle.label(GameState.guild_party_purpose(kind), 11, UIStyle.TEXT_DIM))

	var ids: Array = GameState.get_guild_party(kind)
	var max_n: int = int(GameState.GUILD_PARTY_MAX.get(kind, 5))
	vb.add_child(UIStyle.label("인원 %d / %d" % [ids.size(), max_n], 12))

	var portraits := HBoxContainer.new()
	portraits.add_theme_constant_override("separation", 4)
	vb.add_child(portraits)
	for i in max_n:
		var slot := PanelContainer.new()
		var ssb := StyleBoxFlat.new()
		ssb.bg_color = Color(0.08, 0.09, 0.12, 0.85)
		ssb.border_color = accent
		ssb.set_border_width_all(1)
		ssb.set_corner_radius_all(3)
		slot.add_theme_stylebox_override("panel", ssb)
		slot.custom_minimum_size = Vector2(36, 36)
		if i < ids.size():
			var mem := GameState.get_member_by_id(str(ids[i]))
			var tr := TextureRect.new()
			tr.texture = _portrait_for(str(mem.get("job", "lord")))
			tr.custom_minimum_size = Vector2(32, 32)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			tr.tooltip_text = "%s Lv.%d" % [mem.get("name", ""), int(mem.get("level", 1))]
			slot.add_child(tr)
		else:
			var plus := UIStyle.label("+", 16, UIStyle.TEXT_DIM)
			plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			plus.custom_minimum_size = Vector2(32, 32)
			slot.add_child(plus)
		portraits.add_child(slot)

	if kind == "train":
		vb.add_child(UIStyle.label("상태: 배정만 (훈련 실행은 훈련장)", 11, UIStyle.TEXT_DIM))
	elif kind == "defend":
		vb.add_child(UIStyle.label("상태: 배정만 (방어 이벤트 없음)", 11, UIStyle.TEXT_DIM))
	else:
		vb.add_child(UIStyle.label("출정 전투 파티로 동기화", 11, UIStyle.TEXT_DIM))

	var edit := Button.new()
	edit.text = "편성"
	edit.custom_minimum_size = Vector2(0, 40)
	UIStyle.apply_button(edit)
	var kind_copy: String = kind
	edit.pressed.connect(func(): _open_assign(kind_copy))
	vb.add_child(edit)
	return card


func _open_assign(kind: String) -> void:
	_assign_kind = kind
	_draft_ids = GameState.get_guild_party(kind).duplicate()
	_mode = MENU_PARTY
	_show_overlay_assign()


func _show_overlay_assign() -> void:
	_clear_overlay_body()
	_fit_overlay()
	if _hall_layer:
		_hall_layer.visible = false
	_overlay.visible = true
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	_overlay_panel.add_child(root)
	root.add_child(UIStyle.label("%s 편성" % GameState.guild_party_label(_assign_kind), 18, UIStyle.GOLD_BRIGHT))
	root.add_child(UIStyle.label("같은 길드원은 한 임무 파티에만 배치됩니다. 사냥 파티는 전투 출정 명단과 동기화됩니다.", 12, UIStyle.TEXT_DIM))
	var count := UIStyle.label("", 13)
	root.add_child(count)
	_update_assign_count_label(count)

	var split: Container
	if _compact:
		split = VBoxContainer.new()
	else:
		split = HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 12)
	root.add_child(split)

	var left_scroll := ScrollContainer.new()
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_scroll.custom_minimum_size = Vector2(280, 220)
	split.add_child(left_scroll)
	var left_box := VBoxContainer.new()
	left_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.add_child(left_box)
	left_box.add_child(UIStyle.label("전체 길드원", 14, UIStyle.GOLD))
	for m in GameState.members:
		left_box.add_child(_assign_member_row(m))

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(200, 0)
	split.add_child(right)
	right.add_child(UIStyle.label("현재 파티", 14, UIStyle.GOLD))
	var roster := VBoxContainer.new()
	right.add_child(roster)
	_rebuild_draft_roster(roster)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	root.add_child(actions)
	var save_b := Button.new()
	save_b.text = "저장"
	save_b.custom_minimum_size = Vector2(0, 44)
	UIStyle.apply_button(save_b)
	save_b.pressed.connect(func():
		if GameState.set_guild_party(_assign_kind, _draft_ids):
			_close_overlay()
			_refresh_all()
	)
	actions.add_child(save_b)
	var cancel_b := Button.new()
	cancel_b.text = "취소"
	cancel_b.custom_minimum_size = Vector2(0, 44)
	UIStyle.apply_button(cancel_b)
	cancel_b.pressed.connect(_close_overlay)
	actions.add_child(cancel_b)


func _assign_member_row(m: Dictionary) -> PanelContainer:
	var mid := str(m.get("id", ""))
	var row := UIStyle.make_panel(_draft_ids.has(mid))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	row.add_child(hb)
	var tr := TextureRect.new()
	tr.texture = _portrait_for(str(m.get("job", "lord")))
	tr.custom_minimum_size = Vector2(36, 36)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hb.add_child(tr)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(info)
	info.add_child(UIStyle.label("%s  Lv.%d" % [m.get("name"), int(m.get("level", 1))], 13))
	var other := GameState.member_party_kind(mid)
	var note := ""
	if _draft_ids.has(mid):
		note = "선택됨"
	elif other != "" and other != _assign_kind:
		note = "다른 파티: %s" % GameState.guild_party_label(other)
	else:
		note = UIStyle.job_name(str(m.get("job", "")))
	info.add_child(UIStyle.label(note, 11, UIStyle.TEXT_DIM))
	var btn := Button.new()
	btn.text = "해제" if _draft_ids.has(mid) else "배치"
	btn.custom_minimum_size = Vector2(0, 40)
	UIStyle.apply_button(btn)
	btn.pressed.connect(func():
		_toggle_draft(mid)
		_show_overlay_assign()
	)
	hb.add_child(btn)
	return row


func _toggle_draft(member_id: String) -> void:
	var sid := str(member_id)
	if _draft_ids.has(sid):
		_draft_ids.erase(sid)
		return
	var max_n: int = int(GameState.GUILD_PARTY_MAX.get(_assign_kind, 5))
	if _draft_ids.size() >= max_n:
		GameState.emit_message("파티 인원이 가득 찼습니다. (최대 %d)" % max_n, true)
		return
	_draft_ids.append(sid)


func _rebuild_draft_roster(box: VBoxContainer) -> void:
	for c in box.get_children():
		c.queue_free()
	if _draft_ids.is_empty():
		box.add_child(UIStyle.label("(비어 있음)", 12, UIStyle.TEXT_DIM))
		return
	for mid in _draft_ids:
		var m := GameState.get_member_by_id(str(mid))
		box.add_child(UIStyle.label("· %s (%s)" % [m.get("name", mid), UIStyle.job_name(str(m.get("job", "")))], 12))


func _update_assign_count_label(label: Label) -> void:
	var max_n: int = int(GameState.GUILD_PARTY_MAX.get(_assign_kind, 5))
	label.text = "선택 %d / %d" % [_draft_ids.size(), max_n]


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
	if _hall_layer:
		_hall_layer.visible = true
	_assign_kind = ""
	_draft_ids.clear()
	_clear_overlay_body()


func _portrait_for(job: String) -> Texture2D:
	var path := PORTRAIT_DIR + "portrait_%s.png" % job
	if ResourceLoader.exists(path):
		return load(path)
	return load(PORTRAIT_DIR + "portrait_lord.png")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _overlay.visible:
			_close_overlay()
			get_viewport().set_input_as_handled()
		else:
			SceneRouter.go_town()
			get_viewport().set_input_as_handled()
