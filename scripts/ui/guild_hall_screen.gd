extends Control

## Guild Hall HQ — member review, combat-derived stats, hunt/train/defend parties.
## Design reference: medieval hall with lord center, members flanking, 3 party cards.

const HALL_BG := "res://assets/backgrounds/guild_interior.png"
const PORTRAIT_DIR := "res://assets/sprites/characters/"
const SPRITE_SCALE := 0.42
const LORD_SCALE := 0.55
const HALL_MEMBER_CAP := 10

const MENU_MEMBERS := "members"
const MENU_PARTY := "party"
const MENU_STATS := "stats"
const MENU_FACILITY := "facility"

var _mode: String = MENU_MEMBERS
var _assign_kind: String = ""
var _draft_ids: Array = []
var _toast: Label

var _top_info: Label
var _hall_layer: Control
var _detail_box: VBoxContainer
var _party_row: HBoxContainer
var _overlay: ColorRect
var _overlay_panel: PanelContainer
var _nav_buttons: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	_build()
	GameState.state_changed.connect(_on_state)
	GameState.message_emitted.connect(_on_message)
	if GameState.selected_guild_member_id == "" and not GameState.members.is_empty():
		GameState.selected_guild_member_id = str(GameState.members[0].get("id", ""))
	# Defer once so hall Control has a real size for sprite placement.
	call_deferred("_refresh_all")


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.1)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	_build_top()
	_build_left_nav()
	_build_hall()
	_build_detail()
	_build_party_cards()
	_build_footer()
	_build_overlay()

	_toast = UIStyle.label("", 14, UIStyle.OK)
	_toast.set_anchors_preset(PRESET_BOTTOM_WIDE)
	_toast.offset_top = -28
	_toast.offset_bottom = -6
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_toast)


func _build_top() -> void:
	var top := UIStyle.make_panel()
	top.set_anchors_preset(PRESET_TOP_WIDE)
	top.offset_left = 8
	top.offset_right = -8
	top.offset_top = 6
	top.offset_bottom = 58
	add_child(top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	top.add_child(row)
	row.add_child(UIStyle.label("길드", 18, UIStyle.GOLD_BRIGHT))
	_top_info = UIStyle.label("", 15)
	_top_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_top_info)
	var town := Button.new()
	town.text = "마을로 돌아가기"
	UIStyle.apply_button(town)
	town.pressed.connect(func(): SceneRouter.go_town())
	row.add_child(town)


func _build_left_nav() -> void:
	var nav := UIStyle.make_panel()
	nav.position = Vector2(8, 68)
	nav.custom_minimum_size = Vector2(150, 420)
	add_child(nav)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	nav.add_child(box)
	box.add_child(UIStyle.label("길드 메뉴", 14, UIStyle.TEXT_DIM))
	for entry in [
		[MENU_MEMBERS, "길드원"],
		[MENU_PARTY, "파티 편성"],
		[MENU_STATS, "능력치"],
		[MENU_FACILITY, "시설"],
	]:
		var b := Button.new()
		b.text = str(entry[1])
		b.custom_minimum_size = Vector2(0, 40)
		UIStyle.apply_button(b)
		var mid: String = str(entry[0])
		b.pressed.connect(_make_mode_cb(mid))
		box.add_child(b)
		_nav_buttons[mid] = b


func _make_mode_cb(mode: String) -> Callable:
	return func(): _set_mode(mode)


func _set_mode(mode: String) -> void:
	_mode = mode
	_close_overlay()
	if mode == MENU_FACILITY:
		_open_facility_panel()
	elif mode == MENU_PARTY:
		# Keep hall visible; highlight party section via refresh.
		pass
	_refresh_all()


func _build_hall() -> void:
	var wrap := UIStyle.make_panel()
	wrap.anchor_left = 0.0
	wrap.anchor_right = 1.0
	wrap.anchor_top = 0.0
	wrap.anchor_bottom = 0.0
	wrap.offset_left = 168
	wrap.offset_right = -290
	wrap.offset_top = 68
	wrap.offset_bottom = 430
	add_child(wrap)

	var interior := TextureRect.new()
	interior.set_anchors_preset(PRESET_FULL_RECT)
	interior.texture = load(HALL_BG)
	interior.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	interior.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	interior.modulate = Color(0.92, 0.9, 0.88, 1)
	wrap.add_child(interior)

	var dim := ColorRect.new()
	dim.set_anchors_preset(PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.04, 0.08, 0.28)
	wrap.add_child(dim)

	_hall_layer = Control.new()
	_hall_layer.set_anchors_preset(PRESET_FULL_RECT)
	_hall_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	wrap.add_child(_hall_layer)

	var title := UIStyle.label("길드 홀", 16, UIStyle.GOLD_BRIGHT)
	title.position = Vector2(12, 8)
	wrap.add_child(title)


func _build_detail() -> void:
	var panel := UIStyle.make_panel()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = -278
	panel.offset_right = -8
	panel.offset_top = 68
	panel.offset_bottom = 430
	add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	_detail_box = VBoxContainer.new()
	_detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_box.add_theme_constant_override("separation", 6)
	scroll.add_child(_detail_box)


func _build_party_cards() -> void:
	var wrap := UIStyle.make_panel()
	wrap.anchor_left = 0.0
	wrap.anchor_right = 1.0
	wrap.anchor_top = 0.0
	wrap.anchor_bottom = 1.0
	wrap.offset_left = 168
	wrap.offset_right = -8
	wrap.offset_top = 440
	wrap.offset_bottom = -48
	add_child(wrap)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	wrap.add_child(vb)
	vb.add_child(UIStyle.label("임무 파티", 15, UIStyle.GOLD_BRIGHT))
	_party_row = HBoxContainer.new()
	_party_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_party_row.add_theme_constant_override("separation", 10)
	vb.add_child(_party_row)


func _build_footer() -> void:
	var row := HBoxContainer.new()
	row.set_anchors_preset(PRESET_BOTTOM_WIDE)
	row.offset_left = 168
	row.offset_right = -8
	row.offset_top = -44
	row.offset_bottom = -8
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	var save_btn := Button.new()
	save_btn.text = "파티 저장"
	UIStyle.apply_button(save_btn)
	save_btn.pressed.connect(_on_save_parties)
	row.add_child(save_btn)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var close_btn := Button.new()
	close_btn.text = "닫기"
	UIStyle.apply_button(close_btn)
	close_btn.pressed.connect(func(): SceneRouter.go_town())
	row.add_child(close_btn)


func _build_overlay() -> void:
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.55)
	_overlay.set_anchors_preset(PRESET_FULL_RECT)
	_overlay.visible = false
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)
	_overlay_panel = UIStyle.make_panel(true)
	_overlay_panel.set_anchors_preset(PRESET_CENTER)
	_overlay_panel.custom_minimum_size = Vector2(720, 480)
	_overlay_panel.offset_left = -360
	_overlay_panel.offset_right = 360
	_overlay_panel.offset_top = -240
	_overlay_panel.offset_bottom = 240
	_overlay.add_child(_overlay_panel)


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
	# Guild XP does not exist — show real fields only (level, reputation, roster).
	_top_info.text = "%s   Lv.%d   명성 %d   길드원 %s   골드 %d" % [
		GameState.guild_name,
		GameState.guild_level,
		GameState.reputation,
		GameState.member_count_text(),
		GameState.gold,
	]


func _refresh_nav() -> void:
	for mid in _nav_buttons.keys():
		var b: Button = _nav_buttons[mid]
		if mid == _mode:
			b.add_theme_stylebox_override("normal", UIStyle.button_pressed())
		else:
			UIStyle.apply_button(b)


func _refresh_hall() -> void:
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

	var area := _hall_layer.size
	if area.x < 10 or area.y < 10:
		area = Vector2(780, 340)
	var floor_y := area.y * 0.72
	var center_x := area.x * 0.5

	if not lord.is_empty():
		_spawn_hall_actor(lord, Vector2(center_x, floor_y - 18), LORD_SCALE, true)

	var show_n := mini(others.size(), HALL_MEMBER_CAP)
	var left: Array = []
	var right: Array = []
	for i in show_n:
		if i % 2 == 0:
			left.append(others[i])
		else:
			right.append(others[i])
	_place_side(left, center_x - 70, floor_y, -1)
	_place_side(right, center_x + 70, floor_y, 1)

	if others.size() > HALL_MEMBER_CAP:
		var more := UIStyle.label("+%d명 더 있음 (목록에서 선택)" % (others.size() - HALL_MEMBER_CAP), 12, UIStyle.TEXT_DIM)
		more.position = Vector2(12, area.y - 28)
		_hall_layer.add_child(more)


func _place_side(list: Array, start_x: float, floor_y: float, dir: int) -> void:
	var gap := 58.0
	for i in list.size():
		var m: Dictionary = list[i]
		var x := start_x + dir * (36.0 + i * gap)
		var y := floor_y + float(i % 2) * 10.0
		_spawn_hall_actor(m, Vector2(x, y), SPRITE_SCALE, false)


func _spawn_hall_actor(member: Dictionary, pos: Vector2, scale_v: float, is_lord: bool) -> void:
	var mid := str(member.get("id", ""))
	var selected := mid == GameState.selected_guild_member_id
	var root := Control.new()
	root.position = pos - Vector2(40, 90)
	root.custom_minimum_size = Vector2(80, 110)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_hall_layer.add_child(root)

	if selected:
		var glow := ColorRect.new()
		glow.size = Vector2(76, 100)
		glow.position = Vector2(2, 2)
		glow.color = Color(1.0, 0.85, 0.35, 0.22)
		root.add_child(glow)
		var border := Panel.new()
		border.size = Vector2(80, 104)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.border_color = UIStyle.GOLD_BRIGHT
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(4)
		border.add_theme_stylebox_override("panel", sb)
		root.add_child(border)

	var job := str(member.get("job", "dps"))
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = SpriteFactory.ally_frames(job)
	spr.animation = &"idle"
	spr.play()
	spr.scale = Vector2(scale_v, scale_v)
	spr.position = Vector2(40, 78)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if not is_lord and pos.x > _hall_layer.size.x * 0.5:
		spr.flip_h = true
	root.add_child(spr)

	var name_l := UIStyle.label(str(member.get("name", "")), 11, UIStyle.GOLD_BRIGHT if selected else UIStyle.TEXT)
	name_l.position = Vector2(4, 2)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.custom_minimum_size = Vector2(72, 0)
	root.add_child(name_l)

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
	portrait.custom_minimum_size = Vector2(72, 72)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	head.add_child(portrait)
	var meta := VBoxContainer.new()
	head.add_child(meta)
	meta.add_child(UIStyle.label(str(m.get("name", "")), 18, UIStyle.GOLD_BRIGHT))
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
	for c in _party_row.get_children():
		c.queue_free()
	for kind in GameState.GUILD_PARTY_KINDS:
		_party_row.add_child(_make_party_card(kind))


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
	UIStyle.apply_button(edit)
	var kind_copy := kind
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
	split.add_theme_constant_override("separation", 12)
	root.add_child(split)

	var left_scroll := ScrollContainer.new()
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_scroll.custom_minimum_size = Vector2(320, 280)
	split.add_child(left_scroll)
	var left_box := VBoxContainer.new()
	left_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.add_child(left_box)
	left_box.add_child(UIStyle.label("전체 길드원", 14, UIStyle.GOLD))
	for m in GameState.members:
		left_box.add_child(_assign_member_row(m))

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(260, 0)
	split.add_child(right)
	right.add_child(UIStyle.label("현재 파티", 14, UIStyle.GOLD))
	var roster := VBoxContainer.new()
	roster.name = "DraftRoster"
	right.add_child(roster)
	_rebuild_draft_roster(roster)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	root.add_child(actions)
	var save_b := Button.new()
	save_b.text = "저장"
	UIStyle.apply_button(save_b)
	save_b.pressed.connect(func():
		if GameState.set_guild_party(_assign_kind, _draft_ids):
			_close_overlay()
			_refresh_all()
	)
	actions.add_child(save_b)
	var cancel_b := Button.new()
	cancel_b.text = "취소"
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
	UIStyle.apply_button(close_b)
	close_b.pressed.connect(_close_overlay)
	root.add_child(close_b)


func _open_facility_panel() -> void:
	_clear_overlay_body()
	_overlay.visible = true
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	_overlay_panel.add_child(root)
	root.add_child(UIStyle.label("시설 이동", 18, UIStyle.GOLD_BRIGHT))
	root.add_child(UIStyle.label("기존 마을 시설 화면으로 이동합니다.", 12, UIStyle.TEXT_DIM))
	for fid in ["inn", "shop", "blacksmith", "training", "warehouse", "infirmary", "quest", "gate"]:
		var b := Button.new()
		b.text = UIStyle.facility_name(fid)
		UIStyle.apply_button(b)
		var id_copy: String = str(fid)
		b.pressed.connect(func(): SceneRouter.go_facility(id_copy))
		root.add_child(b)
	var cancel := Button.new()
	cancel.text = "닫기"
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
