extends Control

## Guild Hall HQ — landscape-only split layout + stage composition.
## Portrait stacked-scroll layout is disabled (game is landscape-only).

const HALL_BG := "res://assets/backgrounds/guild_interior.png"
const PORTRAIT_DIR := "res://assets/sprites/characters/"
## Idle sheets are ~64px tall; scale up so actors read clearly in the hall.
const SPRITE_SCALE := 1.05
const LORD_SCALE := 1.28
const HALL_MEMBER_CAP := 10
## Floor line as fraction of the interior texture height (stone floor / rug).
const INTERIOR_FLOOR_T := 0.78
const INTERIOR_ASPECT := 720.0 / 520.0
const ACTOR_FOOT_MARGIN := 32.0
const NAMEPLATE_H := 16.0
const SPRITE_FOOT_OFFSET_Y := -30.0
## Mild zoom on pinned interior so furniture/actors fill the hall frame.
const INTERIOR_ZOOM := 1.14
## Idle frames are ~150–165px wide; gaps must clear half-width * scale.
const FLANK_MIN_GAP := 160.0
const MENU_MEMBERS := "members"
const MENU_PARTY := "party"
const MENU_STATS := "stats"
const MENU_FACILITY := "facility"

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
	# Manual cover + bottom-pin in _fit_interior so throne/floor stay in frame.
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
	var top_h := 44.0 if _dense else 52.0
	var foot_h := 44.0 if _dense else 52.0
	var toast_h := 18.0 if _dense else 22.0
	var w := size.x
	var h := size.y
	if w < 8.0 or h < 8.0:
		return

	_top_bar.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
	_top_bar.offset_left = pad
	_top_bar.offset_right = -pad
	_top_bar.offset_top = pad
	_top_bar.offset_bottom = pad + top_h
	_town_btn.text = "마을로" if _dense else "마을로 돌아가기"

	_toast.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	_toast.offset_left = pad
	_toast.offset_right = -pad

	# Landscape-only: always wide split. Portrait stacked scroll is disabled.
	var compact_actions := _body_host.get_node_or_null("CompactActions")
	if compact_actions:
		compact_actions.visible = false
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


func _layout_wide(content_w: float, content_h: float) -> void:
	_body_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var compact_actions := _body_host.get_node_or_null("CompactActions")
	if compact_actions:
		compact_actions.visible = false
	_ensure_nav_orientation(false)
	_ensure_party_orientation(false)
	# Minimize left chrome; keep detail wide enough to read ATK/DEF rows.
	var nav_w := 96.0 if _dense else 112.0
	var detail_w := 248.0 if _dense else 268.0
	var gap := 6.0 if _dense else 8.0
	var mid_w := content_w - nav_w - detail_w - gap * 2.0
	# Compact party strip — tall enough that 편성 sits fully above the footer.
	var party_h := 122.0 if _dense else 156.0
	var hall_h := maxf(200.0 if _dense else 240.0, content_h - party_h - gap)

	_nav_box.position = Vector2(0, 0)
	_nav_box.size = Vector2(nav_w, content_h)
	for mid in _nav_buttons.keys():
		var b: Button = _nav_buttons[mid]
		if is_instance_valid(b):
			b.custom_minimum_size = Vector2(0, 34 if _dense else 38)
			if mid == MENU_PARTY:
				b.text = "파티편성" if _dense else "파티 편성"

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


func _hall_area() -> Vector2:
	if _hall_root and _hall_root.size.x > 8.0 and _hall_root.size.y > 8.0:
		return _hall_root.size
	if _hall_wrap and _hall_wrap.size.x > 8.0:
		return _hall_wrap.size
	return Vector2(640, 280)


func _fit_interior() -> void:
	## Cover the hall panel while pinning the art bottom so the stone floor /
	## throne stay visible (center-crop COVERED was cutting the floor away).
	if _hall_root == null:
		return
	var interior := _hall_root.get_node_or_null("Interior") as TextureRect
	if interior == null:
		return
	var area := _hall_area()
	if area.x < 8.0 or area.y < 8.0:
		return
	var w := area.x * INTERIOR_ZOOM
	var h := w / INTERIOR_ASPECT
	if h < area.y:
		h = area.y
		w = h * INTERIOR_ASPECT
	interior.anchor_left = 0.0
	interior.anchor_top = 0.0
	interior.anchor_right = 0.0
	interior.anchor_bottom = 0.0
	# Bottom-pin + horizontal center — throne/fireplace stay framed.
	interior.position = Vector2((area.x - w) * 0.5, area.y - h)
	interior.size = Vector2(w, h)


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
	_refresh_hall()
	_refresh_detail()
	_refresh_party_cards()


func _refresh_top() -> void:
	if _dense:
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
	## Guildmaster at throne center; members balanced L/R on one floor line.
	var floor_y := _floor_y_for_hall(area)
	# Bias slightly toward the hearth/throne in the interior art.
	var center_x := area.x * 0.505
	var scale_mem := SPRITE_SCALE
	var scale_lord := LORD_SCALE
	var show: Array = []
	for i in mini(others.size(), HALL_MEMBER_CAP):
		show.append(others[i])
	var left_n := int(floor(float(show.size()) / 2.0))
	# Prefer equal counts; if odd, put the extra on the right.
	var left_list: Array = show.slice(0, left_n)
	var right_list: Array = show.slice(left_n, show.size())
	# Mirror left order so index 0 is nearest the lord on both flanks.
	left_list.reverse()

	var lord_r := _actor_radius(lord if not lord.is_empty() else {}, scale_lord, true)
	var left_inner_r := _actor_radius(left_list[0] if not left_list.is_empty() else {}, scale_mem, false)
	var right_inner_r := _actor_radius(right_list[0] if not right_list.is_empty() else {}, scale_mem, false)
	var lord_clear_l := maxf(FLANK_MIN_GAP, lord_r + left_inner_r + 12.0)
	var lord_clear_r := maxf(FLANK_MIN_GAP, lord_r + right_inner_r + 12.0)
	# Symmetry: use the larger clearance on both sides so L/R reads even.
	var lord_clear := maxf(lord_clear_l, lord_clear_r)

	var left_xs := _flank_xs(left_list, center_x - lord_clear, -1.0, scale_mem)
	var right_xs := _flank_xs(right_list, center_x + lord_clear, 1.0, scale_mem)
	# If flanks would hit the wall, shrink all gaps uniformly (keeps L/R even).
	var margin := 36.0
	var min_x := center_x
	var max_x := center_x
	for v in left_xs:
		min_x = minf(min_x, float(v))
	for v2 in right_xs:
		max_x = maxf(max_x, float(v2))
	var lo := margin
	var hi := area.x - margin
	if min_x < lo or max_x > hi:
		var span_now := maxf(1.0, max_x - min_x)
		var span_fit := hi - lo
		var s := clampf(span_fit / span_now, 0.55, 1.0)
		lord_clear *= s
		left_xs = _flank_xs(left_list, center_x - lord_clear, -1.0, scale_mem, s)
		right_xs = _flank_xs(right_list, center_x + lord_clear, 1.0, scale_mem, s)

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
		" lord_clear=", lord_clear,
		" left=", left_list.size(),
		" right=", right_list.size()
	)

	if others.size() > HALL_MEMBER_CAP:
		var more := UIStyle.label("+%d명 더 있음" % (others.size() - HALL_MEMBER_CAP), 11, UIStyle.TEXT_DIM)
		more.position = Vector2(10, 8)
		_hall_layer.add_child(more)


func _actor_radius(member: Dictionary, scale_v: float, is_lord: bool = false) -> float:
	## Half-width of idle sheet (~150–165px). Used for collision-free spacing.
	if is_lord:
		return 80.0 * scale_v
	var job := str(member.get("job", "dps"))
	var base := 76.0
	match job:
		"tank":
			base = 78.0
		"mage":
			base = 82.0
		"healer":
			base = 76.0
		"dps":
			base = 78.0
		_:
			base = 76.0
	return base * scale_v


func _flank_xs(list: Array, inner_x: float, dir: float, scale_v: float, gap_scale: float = 1.0) -> Array:
	## X positions outward from the lord; gaps use per-job radii.
	var xs: Array = []
	if list.is_empty():
		return xs
	var x := inner_x
	for i in list.size():
		if i > 0:
			var prev_r := _actor_radius(list[i - 1], scale_v, false)
			var cur_r := _actor_radius(list[i], scale_v, false)
			var step := maxf(FLANK_MIN_GAP, prev_r + cur_r + 12.0) * gap_scale
			x = x + dir * step
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
	# Feet exactly on the shared floor line (bottom of root = pos.y).
	spr.position = Vector2(box_w * 0.5, box_h)
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
	portraits.add_theme_constant_override("separation", 3)
	portraits.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	vb.add_child(portraits)
	var slot_sz := 24.0 if _dense else 28.0
	var face_sz := 20.0 if _dense else 24.0
	for i in max_n:
		var slot := PanelContainer.new()
		var ssb := StyleBoxFlat.new()
		ssb.bg_color = Color(0.08, 0.09, 0.12, 0.85)
		ssb.border_color = accent
		ssb.set_border_width_all(1)
		ssb.set_corner_radius_all(3)
		slot.add_theme_stylebox_override("panel", ssb)
		slot.custom_minimum_size = Vector2(slot_sz, slot_sz)
		slot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		if i < ids.size():
			var mem := GameState.get_member_by_id(str(ids[i]))
			var tr := TextureRect.new()
			tr.texture = _portrait_for(str(mem.get("job", "lord")))
			tr.custom_minimum_size = Vector2(face_sz, face_sz)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			tr.tooltip_text = "%s Lv.%d" % [mem.get("name", ""), int(mem.get("level", 1))]
			slot.add_child(tr)
		else:
			var plus := UIStyle.label("+", 12, UIStyle.TEXT_DIM)
			plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
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

	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 8 if _dense else 12)
	root.add_child(split)

	var left_scroll := ScrollContainer.new()
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_scroll.custom_minimum_size = Vector2(240 if _dense else 280, 160 if _dense else 220)
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
