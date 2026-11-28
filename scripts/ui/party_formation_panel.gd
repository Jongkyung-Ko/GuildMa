extends Control
class_name PartyFormationPanel

## Playable guild party formation UI (reference layout, real GameState data).
## Skill demo is visual preview only — no HP/MP/CD combat side effects.

const JOB_FILTERS := ["all", "lord", "tank", "dps", "healer", "mage"]
const SORT_LEVEL_DESC := "level_desc"
const SORT_LEVEL_ASC := "level_asc"
const SORT_NAME := "name"

## Real skill strings on members → short preview metadata (not mock numbers).
const SKILL_INFO := {
	"지휘": {"desc": "아군의 전투 지휘. 전투에서는 기본 공격으로 표현됩니다.", "pattern": "기본 공격", "demo": "attack"},
	"방패 막기": {"desc": "방패로 전방을 막아 피해를 줄입니다.", "pattern": "강공격", "demo": "attack"},
	"연속 베기": {"desc": "빠른 연속 베기로 단일 대상을 공격합니다.", "pattern": "강공격", "demo": "attack"},
	"치유": {"desc": "아군의 체력을 회복합니다.", "pattern": "지원", "demo": "attack"},
	"마력탄": {"desc": "마력 탄환을 발사합니다.", "pattern": "원거리", "demo": "attack"},
	"화염구": {"desc": "화염 구체를 날립니다.", "pattern": "원거리", "demo": "attack"},
	"도발": {"desc": "적의 시선을 끌어 탱킹합니다.", "pattern": "유틸", "demo": "attack"},
	"견고함": {"desc": "일시적으로 방어 태세를 강화합니다.", "pattern": "방어", "demo": "idle"},
	"급습": {"desc": "그림자를 이용해 급습합니다.", "pattern": "돌진", "demo": "attack"},
}

signal closed
signal saved(kind: String)

var party_kind: String = "hunt"
var _draft_ids: Array = []
var _filter_job: String = "all"
var _sort_mode: String = SORT_LEVEL_DESC
var _focus_id: String = ""
var _selected_skill: String = ""
var _scroll_y: float = 0.0

var _dense: bool = false
var _grid_scroll: ScrollContainer
var _grid: GridContainer
var _detail_box: VBoxContainer
var _party_row: HBoxContainer
var _count_label: Label
var _comp_label: Label
var _avg_label: Label
var _skill_desc: Label
var _demo_host: Control
var _demo_sprite: AnimatedSprite2D
var _demo_note: Label
var _filter_buttons: Dictionary = {}
var _kind_buttons: Dictionary = {}


func setup(kind: String = "hunt") -> void:
	party_kind = kind if GameState.GUILD_PARTY_KINDS.has(kind) else "hunt"
	_draft_ids = GameState.get_guild_party(party_kind).duplicate()
	_focus_id = str(GameState.selected_guild_member_id)
	if _focus_id == "" and not GameState.members.is_empty():
		_focus_id = str(GameState.members[0].get("id", ""))
	_selected_skill = ""
	_rebuild()


func restore_view_state(state: Dictionary) -> void:
	_filter_job = str(state.get("filter_job", _filter_job))
	_sort_mode = str(state.get("sort_mode", _sort_mode))
	_focus_id = str(state.get("focus_id", _focus_id))
	_selected_skill = str(state.get("selected_skill", _selected_skill))
	_scroll_y = float(state.get("scroll_y", 0.0))
	party_kind = str(state.get("party_kind", party_kind))
	var draft = state.get("draft_ids", _draft_ids)
	if typeof(draft) == TYPE_ARRAY:
		_draft_ids = draft.duplicate()
	_rebuild()
	if _grid_scroll:
		_grid_scroll.scroll_vertical = int(_scroll_y)


func view_state() -> Dictionary:
	return {
		"filter_job": _filter_job,
		"sort_mode": _sort_mode,
		"focus_id": _focus_id,
		"selected_skill": _selected_skill,
		"scroll_y": float(_grid_scroll.scroll_vertical) if _grid_scroll else _scroll_y,
		"party_kind": party_kind,
		"draft_ids": _draft_ids.duplicate(),
	}


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_on_resized)
	_on_resized()


func _on_resized() -> void:
	var win := get_window()
	var wsz: Vector2i = win.size if win else Vector2i(1280, 720)
	_dense = wsz.y <= 420 or (wsz.x > 0 and float(wsz.x) / float(wsz.y) >= 2.0)
	if get_child_count() > 0:
		# Preserve scroll when density flips.
		if _grid_scroll:
			_scroll_y = float(_grid_scroll.scroll_vertical)
		_rebuild()
		if _grid_scroll:
			_grid_scroll.scroll_vertical = int(_scroll_y)


func _rebuild() -> void:
	for c in get_children():
		c.free()
	_filter_buttons.clear()
	_kind_buttons.clear()
	_demo_sprite = null

	var root := VBoxContainer.new()
	root.set_anchors_preset(PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 6 if _dense else 8)
	add_child(root)

	root.add_child(_build_header())
	var mid := HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 8 if _dense else 10)
	root.add_child(mid)
	mid.add_child(_build_member_column())
	mid.add_child(_build_detail_column())
	root.add_child(_build_party_strip())


func _build_header() -> Control:
	var panel := UIStyle.make_panel()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	vb.add_child(top)
	top.add_child(UIStyle.label("파티 편성", 18 if not _dense else 15, UIStyle.GOLD_BRIGHT))
	_count_label = UIStyle.label("", 13)
	top.add_child(_count_label)
	_avg_label = UIStyle.label("", 12, UIStyle.TEXT_DIM)
	top.add_child(_avg_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var close_b := Button.new()
	close_b.text = "닫기"
	close_b.custom_minimum_size = Vector2(0, 36 if _dense else 40)
	UIStyle.apply_button(close_b)
	close_b.pressed.connect(func(): closed.emit())
	top.add_child(close_b)

	_comp_label = UIStyle.label("", 12, UIStyle.TEXT_DIM)
	vb.add_child(_comp_label)

	# Mission party kind tabs (real guild_parties taxonomy).
	var kinds := HBoxContainer.new()
	kinds.add_theme_constant_override("separation", 6)
	vb.add_child(kinds)
	for kind in GameState.GUILD_PARTY_KINDS:
		var b := Button.new()
		b.text = GameState.guild_party_label(str(kind))
		b.custom_minimum_size = Vector2(0, 32 if _dense else 36)
		UIStyle.apply_button(b)
		var k := str(kind)
		b.pressed.connect(func(): _switch_kind(k))
		kinds.add_child(b)
		_kind_buttons[k] = b
	_style_kind_buttons()

	# Sort + job filters (real jobs only).
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 6)
	vb.add_child(filters)
	var sort := OptionButton.new()
	sort.add_item("레벨 높은 순", 0)
	sort.add_item("레벨 낮은 순", 1)
	sort.add_item("이름순", 2)
	match _sort_mode:
		SORT_LEVEL_ASC:
			sort.select(1)
		SORT_NAME:
			sort.select(2)
		_:
			sort.select(0)
	sort.item_selected.connect(func(i):
		match i:
			1:
				_sort_mode = SORT_LEVEL_ASC
			2:
				_sort_mode = SORT_NAME
			_:
				_sort_mode = SORT_LEVEL_DESC
		_refresh_lists_only()
	)
	filters.add_child(sort)
	for job in JOB_FILTERS:
		var fb := Button.new()
		fb.text = "전체" if job == "all" else UIStyle.job_name(job)
		fb.custom_minimum_size = Vector2(0, 30 if _dense else 34)
		UIStyle.apply_button(fb)
		var jid := str(job)
		fb.pressed.connect(func():
			_filter_job = jid
			_refresh_lists_only()
		)
		filters.add_child(fb)
		_filter_buttons[jid] = fb
	_style_filter_buttons()
	_update_summary_labels()
	return panel


func _build_member_column() -> Control:
	var panel := UIStyle.make_panel()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.35
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)
	vb.add_child(UIStyle.label("길드원 목록", 14, UIStyle.GOLD))
	_grid_scroll = ScrollContainer.new()
	_grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(_grid_scroll)
	_grid = GridContainer.new()
	_grid.columns = 2 if _dense else 3
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid_scroll.add_child(_grid)
	_populate_grid()
	return panel


func _build_detail_column() -> Control:
	var panel := UIStyle.make_panel(true)
	panel.custom_minimum_size = Vector2(260 if not _dense else 220, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.0
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	_detail_box = VBoxContainer.new()
	_detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_box.add_theme_constant_override("separation", 6)
	scroll.add_child(_detail_box)
	_populate_detail()
	return panel


func _build_party_strip() -> Control:
	var panel := UIStyle.make_panel()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	vb.add_child(head)
	var max_n: int = int(GameState.GUILD_PARTY_MAX.get(party_kind, 5))
	head.add_child(UIStyle.label("선택 파티 (%d/%d)" % [_draft_ids.size(), max_n], 14, UIStyle.GOLD_BRIGHT))
	head.add_child(UIStyle.label(GameState.guild_party_purpose(party_kind), 11, UIStyle.TEXT_DIM))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	# Simple composition buffs from real roster (honest, not mock %).
	var buff := _party_effect_text()
	head.add_child(UIStyle.label(buff, 12, UIStyle.OK))

	_party_row = HBoxContainer.new()
	_party_row.add_theme_constant_override("separation", 8)
	_party_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(_party_row)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	vb.add_child(actions)
	var clear_b := Button.new()
	clear_b.text = "선택 비우기"
	clear_b.custom_minimum_size = Vector2(0, 40 if not _dense else 34)
	UIStyle.apply_button(clear_b)
	clear_b.pressed.connect(func():
		_draft_ids.clear()
		_refresh_lists_only()
	)
	actions.add_child(clear_b)
	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(sp2)
	var save_b := Button.new()
	save_b.text = "편성 완료"
	save_b.custom_minimum_size = Vector2(160 if not _dense else 120, 44 if not _dense else 38)
	UIStyle.apply_button(save_b)
	save_b.add_theme_stylebox_override("normal", UIStyle.button_pressed())
	save_b.pressed.connect(_on_confirm)
	actions.add_child(save_b)
	_populate_party_strip()
	return panel


func _party_effect_text() -> String:
	if _draft_ids.is_empty():
		return "파티 효과: —"
	var jobs := {}
	for mid in _draft_ids:
		var m := GameState.get_member_by_id(str(mid))
		var j := str(m.get("job", ""))
		jobs[j] = int(jobs.get(j, 0)) + 1
	var parts: PackedStringArray = PackedStringArray()
	if jobs.has("tank"):
		parts.append("탱커 편성")
	if jobs.has("healer"):
		parts.append("힐러 편성")
	if jobs.has("mage") or jobs.has("dps"):
		parts.append("딜러 편성")
	if jobs.has("lord"):
		parts.append("군주 편성")
	return "파티 구성: " + (" · ".join(parts) if parts.size() > 0 else "혼합")


func _filtered_members() -> Array:
	var out: Array = []
	for m in GameState.members:
		var job := str(m.get("job", ""))
		if _filter_job != "all" and job != _filter_job:
			continue
		out.append(m)
	out.sort_custom(func(a, b):
		match _sort_mode:
			SORT_LEVEL_ASC:
				var la := int(a.get("level", 1))
				var lb := int(b.get("level", 1))
				if la != lb:
					return la < lb
				return str(a.get("name", "")) < str(b.get("name", ""))
			SORT_NAME:
				return str(a.get("name", "")) < str(b.get("name", ""))
			_:
				var xa := int(a.get("level", 1))
				var xb := int(b.get("level", 1))
				if xa != xb:
					return xa > xb
				return str(a.get("name", "")) < str(b.get("name", ""))
	)
	return out


func _populate_grid() -> void:
	if _grid == null:
		return
	for c in _grid.get_children():
		c.free()
	var list := _filtered_members()
	if list.is_empty():
		_grid.add_child(UIStyle.label("해당 직업 길드원이 없습니다.", 13, UIStyle.TEXT_DIM))
		return
	for m in list:
		_grid.add_child(_make_member_card(m))


func _make_member_card(m: Dictionary) -> Control:
	## Namecard: top ~70% identity/stats, bottom ~30% equal 3-col skill grid.
	## Skills stay subordinate — small squares + captions; no oversized chips.
	var mid := str(m.get("id", ""))
	var in_draft := _draft_ids.has(mid)
	var focused := mid == _focus_id
	var card_w := 158.0 if _dense else 176.0
	var card_h := 188.0 if _dense else 220.0
	var card := Button.new()
	card.flat = true
	card.custom_minimum_size = Vector2(card_w, card_h)
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	UIStyle.apply_button(card)
	var wrap := PanelContainer.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.set_anchors_preset(PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.08, 0.1, 0.96)
	sb.border_color = UIStyle.GOLD_BRIGHT if (in_draft or focused) else UIStyle.GOLD
	sb.set_border_width_all(3 if (in_draft or focused) else 2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 7
	sb.content_margin_right = 7
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	wrap.add_theme_stylebox_override("panel", sb)
	card.add_child(wrap)

	var root := VBoxContainer.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_constant_override("separation", 4)
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.add_child(root)

	# --- Top ~70%: portrait + name/job/level + HP/ATK/DEF ---
	var top := VBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 3)
	top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top.size_flags_stretch_ratio = 7.0
	root.add_child(top)

	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("separation", 6)
	head.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top.add_child(head)
	var tr := TextureRect.new()
	tr.texture = _portrait_for(str(m.get("job", "dps")))
	tr.custom_minimum_size = Vector2(52 if _dense else 64, 52 if _dense else 64)
	tr.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(tr)
	var meta := VBoxContainer.new()
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	meta.add_theme_constant_override("separation", 2)
	head.add_child(meta)
	meta.add_child(UIStyle.label(str(m.get("name", "")), 13 if not _dense else 12, UIStyle.GOLD_BRIGHT))
	meta.add_child(UIStyle.label("%s Lv.%d" % [UIStyle.job_name(str(m.get("job", ""))), int(m.get("level", 1))], 11, UIStyle.TEXT))
	if in_draft:
		meta.add_child(UIStyle.label("✓ 선택", 10, UIStyle.OK))

	var preview := GameState.compute_combat_preview(m)
	var stats_l := UIStyle.label("HP %d · ATK %d · DEF %d" % [
		int(preview.get("hp", 0)), int(preview.get("atk", 0)), int(preview.get("def", 0))
	], 10 if _dense else 11, UIStyle.TEXT_DIM)
	stats_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(stats_l)

	# Divider between identity block and skill zone.
	var div := HSeparator.new()
	div.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(div)

	# --- Bottom ~30%: full-width equal 3-column skill grid ---
	var skill_zone := VBoxContainer.new()
	skill_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skill_zone.size_flags_vertical = Control.SIZE_EXPAND_FILL
	skill_zone.size_flags_stretch_ratio = 3.0
	# Lock a true ~30% floor so skills never collapse into oversized chips again.
	skill_zone.custom_minimum_size = Vector2(0, card_h * 0.28)
	skill_zone.add_theme_constant_override("separation", 2)
	root.add_child(skill_zone)
	skill_zone.add_child(_build_card_skill_grid(m.get("skills", [])))

	card.pressed.connect(func():
		if _focus_id == mid:
			_toggle_draft(mid)
		else:
			_focus_id = mid
			GameState.select_guild_member(mid)
			_selected_skill = ""
		_refresh_lists_only()
	)
	return card


func _build_card_skill_grid(skills_raw: Variant) -> Control:
	## Equal-width 3 columns; max 3 real skills; empty slots keep the grid stable.
	var grid := GridContainer.new()
	grid.columns = 3
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 2)

	var skills: Array = skills_raw if typeof(skills_raw) == TYPE_ARRAY else []
	for i in 3:
		var cell := VBoxContainer.new()
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.add_theme_constant_override("separation", 2)

		var icon_sz := 20.0 if _dense else 24.0
		var icon := PanelContainer.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.custom_minimum_size = Vector2(icon_sz, icon_sz)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var isb := StyleBoxFlat.new()
		isb.set_corner_radius_all(4)
		isb.set_border_width_all(1)
		isb.content_margin_left = 1
		isb.content_margin_right = 1
		isb.content_margin_top = 1
		isb.content_margin_bottom = 1

		var caption := Label.new()
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.autowrap_mode = TextServer.AUTOWRAP_OFF
		caption.clip_text = true
		caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		caption.add_theme_font_size_override("font_size", 9 if _dense else 10)
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		caption.custom_minimum_size = Vector2(0, 14)

		if i < skills.size() and str(skills[i]) != "":
			var sk := str(skills[i])
			isb.bg_color = _skill_icon_color(sk)
			isb.border_color = UIStyle.GOLD
			icon.add_theme_stylebox_override("panel", isb)
			var glyph := UIStyle.label(_skill_glyph(sk), 10 if _dense else 11, Color(0.98, 0.95, 0.88))
			glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon.add_child(glyph)
			caption.text = sk
			caption.add_theme_color_override("font_color", UIStyle.TEXT)
		else:
			isb.bg_color = Color(0.08, 0.08, 0.1, 0.7)
			isb.border_color = Color(0.35, 0.32, 0.28, 0.55)
			icon.add_theme_stylebox_override("panel", isb)
			caption.text = "—"
			caption.add_theme_color_override("font_color", UIStyle.TEXT_DIM)

		cell.add_child(icon)
		cell.add_child(caption)
		grid.add_child(cell)
	return grid


func _skill_glyph(skill_name: String) -> String:
	var s := skill_name.strip_edges()
	if s.is_empty():
		return "·"
	return s.substr(0, 1)


func _skill_icon_color(skill_name: String) -> Color:
	## Tiny tinted tile — not a fake catalog icon; keeps skills readable without dominating.
	var key := skill_name
	if SKILL_INFO.has(key):
		var pattern := str(SKILL_INFO[key].get("pattern", ""))
		match pattern:
			"원거리":
				return Color(0.28, 0.22, 0.42, 1)
			"지원":
				return Color(0.18, 0.36, 0.28, 1)
			"방어", "유틸":
				return Color(0.22, 0.28, 0.38, 1)
			"돌진":
				return Color(0.38, 0.22, 0.18, 1)
			_:
				return Color(0.32, 0.26, 0.14, 1)
	return Color(0.22, 0.2, 0.18, 1)


func _populate_detail() -> void:
	if _detail_box == null:
		return
	for c in _detail_box.get_children():
		c.free()
	var m := GameState.get_member_by_id(_focus_id)
	if m.is_empty() and not GameState.members.is_empty():
		m = GameState.members[0]
		_focus_id = str(m.get("id", ""))
	if m.is_empty():
		_detail_box.add_child(UIStyle.label("길드원을 선택하세요.", 13, UIStyle.TEXT_DIM))
		return

	_detail_box.add_child(UIStyle.label(str(m.get("name", "")), 18, UIStyle.GOLD_BRIGHT))
	_detail_box.add_child(UIStyle.label("%s · Lv.%d" % [
		UIStyle.job_name(str(m.get("job", ""))), int(m.get("level", 1))
	], 13))

	# Large character preview (hunt sheet / idle anim).
	var stage := PanelContainer.new()
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = Color(0.05, 0.06, 0.09, 0.95)
	ssb.border_color = UIStyle.GOLD
	ssb.set_border_width_all(2)
	ssb.set_corner_radius_all(6)
	stage.add_theme_stylebox_override("panel", ssb)
	stage.custom_minimum_size = Vector2(0, 120 if _dense else 150)
	_detail_box.add_child(stage)
	var stage_host := Control.new()
	stage_host.custom_minimum_size = Vector2(0, 110 if _dense else 140)
	stage.add_child(stage_host)
	var idle := AnimatedSprite2D.new()
	idle.sprite_frames = SpriteFactory.ally_frames(str(m.get("job", "dps")))
	idle.animation = &"idle"
	idle.play()
	idle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	idle.scale = Vector2(1.1, 1.1) if _dense else Vector2(1.35, 1.35)
	idle.position = Vector2(110 if _dense else 130, 95 if _dense else 120)
	idle.centered = true
	idle.offset = Vector2(0, -28)
	stage_host.add_child(idle)

	var preview := GameState.compute_combat_preview(m)
	_detail_box.add_child(UIStyle.label("기본 정보", 14, UIStyle.GOLD))
	_detail_box.add_child(_bar_stat("HP", int(preview.get("hp", 0)), 300))
	_detail_box.add_child(_bar_stat("ATK", int(preview.get("atk", 0)), 80))
	_detail_box.add_child(_bar_stat("DEF", int(preview.get("def", 0)), 60))
	_detail_box.add_child(_bar_stat("SPD", int(preview.get("spd", 0)), 220))

	_detail_box.add_child(UIStyle.label("공격 패턴 (직업 기본)", 13, UIStyle.GOLD))
	for line in _job_patterns(str(m.get("job", ""))):
		_detail_box.add_child(UIStyle.label("· " + line, 12, UIStyle.TEXT_DIM))

	_detail_box.add_child(UIStyle.label("스킬", 14, UIStyle.GOLD))
	var skills: Array = m.get("skills", [])
	if skills.is_empty():
		_detail_box.add_child(UIStyle.label("(등록된 스킬 없음)", 12, UIStyle.TEXT_DIM))
	else:
		var sk_row := HBoxContainer.new()
		sk_row.add_theme_constant_override("separation", 6)
		_detail_box.add_child(sk_row)
		if _selected_skill == "" or not skills.has(_selected_skill):
			_selected_skill = str(skills[0])
		for sk in skills:
			var sb := Button.new()
			sb.text = str(sk)
			sb.custom_minimum_size = Vector2(0, 36)
			UIStyle.apply_button(sb)
			if str(sk) == _selected_skill:
				sb.add_theme_stylebox_override("normal", UIStyle.button_pressed())
			var sk_name := str(sk)
			sb.pressed.connect(func():
				_selected_skill = sk_name
				_populate_detail()
			)
			sk_row.add_child(sb)

	_skill_desc = UIStyle.label("", 12, UIStyle.TEXT)
	_skill_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_box.add_child(_skill_desc)
	_update_skill_desc()

	_detail_box.add_child(UIStyle.label("스킬 미리보기", 13, UIStyle.GOLD))
	_demo_host = Control.new()
	_demo_host.custom_minimum_size = Vector2(0, 100 if _dense else 120)
	_demo_host.clip_contents = true
	var demo_bg := ColorRect.new()
	demo_bg.color = Color(0.08, 0.1, 0.12, 1)
	demo_bg.set_anchors_preset(PRESET_FULL_RECT)
	demo_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_demo_host.add_child(demo_bg)
	_detail_box.add_child(_demo_host)
	_demo_note = UIStyle.label("", 11, UIStyle.TEXT_DIM)
	_detail_box.add_child(_demo_note)
	var demo_btn := Button.new()
	demo_btn.text = "스킬 미리보기 재생"
	demo_btn.custom_minimum_size = Vector2(0, 36)
	UIStyle.apply_button(demo_btn)
	demo_btn.pressed.connect(_play_skill_demo)
	_detail_box.add_child(demo_btn)
	_play_skill_demo()


func _bar_stat(label: String, value: int, cap: int) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var head := HBoxContainer.new()
	head.add_child(UIStyle.label(label, 12, UIStyle.TEXT_DIM))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	head.add_child(UIStyle.label(str(value), 12, UIStyle.TEXT))
	row.add_child(head)
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = maxf(1.0, float(cap))
	bar.value = float(value)
	bar.custom_minimum_size = Vector2(0, 10)
	bar.show_percentage = false
	row.add_child(bar)
	return row


func _job_patterns(job: String) -> Array:
	match job:
		"tank":
			return ["기본 공격", "방패 강타", "버티기"]
		"dps":
			return ["기본 공격", "연속 베기", "돌진"]
		"mage":
			return ["기본 공격", "마력탄", "집중 시전"]
		"healer":
			return ["기본 공격", "치유", "지원 시전"]
		"lord":
			return ["기본 공격", "지휘 강타", "돌격"]
		_:
			return ["기본 공격"]


func _update_skill_desc() -> void:
	if _skill_desc == null:
		return
	if _selected_skill == "":
		_skill_desc.text = "스킬을 선택하세요."
		return
	var info: Dictionary = SKILL_INFO.get(_selected_skill, {})
	if info.is_empty():
		_skill_desc.text = "%s\n(상세 수치 데이터 없음 — 이름만 보유. 데모는 직업 공격 애니로 대체하거나 불가 표시.)" % _selected_skill
	else:
		_skill_desc.text = "%s\n%s\n패턴: %s · 미리보기 전용(전투 HP/MP/CD 영향 없음)" % [
			_selected_skill, str(info.get("desc", "")), str(info.get("pattern", ""))
		]


func _play_skill_demo() -> void:
	if _demo_host == null:
		return
	# Clear previous sprite children except bg.
	for c in _demo_host.get_children():
		if c is AnimatedSprite2D or c is Label:
			c.queue_free()
	_demo_sprite = null
	var m := GameState.get_member_by_id(_focus_id)
	if m.is_empty():
		if _demo_note:
			_demo_note.text = "대상 없음"
		return
	var job := str(m.get("job", "dps"))
	var info: Dictionary = SKILL_INFO.get(_selected_skill, {})
	var demo := str(info.get("demo", "attack" if _selected_skill != "" else "idle"))
	var frames := SpriteFactory.ally_frames(job)
	if frames == null:
		if _demo_note:
			_demo_note.text = "미리보기 불가 — 스프라이트 없음"
		return
	var anim := &"attack" if demo == "attack" and frames.has_animation("attack") else &"idle"
	if not frames.has_animation(anim):
		if _demo_note:
			_demo_note.text = "미리보기 불가 — 애니 없음"
		return
	_demo_sprite = AnimatedSprite2D.new()
	_demo_sprite.sprite_frames = frames
	_demo_sprite.animation = anim
	_demo_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_demo_sprite.scale = Vector2(1.15, 1.15)
	_demo_sprite.position = Vector2(90, 85)
	_demo_sprite.centered = true
	_demo_sprite.offset = Vector2(0, -26)
	_demo_host.add_child(_demo_sprite)
	_demo_sprite.play()
	if anim == &"attack":
		_demo_sprite.animation_finished.connect(func():
			if is_instance_valid(_demo_sprite):
				_demo_sprite.animation = &"idle"
				_demo_sprite.play()
		, CONNECT_ONE_SHOT)
	if _demo_note:
		if info.is_empty() and _selected_skill != "":
			_demo_note.text = "등록 메타 없음 → 직업 공격/대기 애니로 대체 미리보기"
		else:
			_demo_note.text = "미리보기 전용 · 전투 수치/쿨다운 적용 안 함"


func _populate_party_strip() -> void:
	if _party_row == null:
		return
	for c in _party_row.get_children():
		c.free()
	var max_n: int = int(GameState.GUILD_PARTY_MAX.get(party_kind, 5))
	for i in max_n:
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(110 if _dense else 128, 56 if _dense else 64)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var ssb := StyleBoxFlat.new()
		ssb.bg_color = Color(0.08, 0.09, 0.12, 0.92)
		ssb.border_color = UIStyle.GOLD
		ssb.set_border_width_all(2)
		ssb.set_corner_radius_all(6)
		ssb.content_margin_left = 6
		ssb.content_margin_right = 6
		ssb.content_margin_top = 4
		ssb.content_margin_bottom = 4
		slot.add_theme_stylebox_override("panel", ssb)
		if i < _draft_ids.size():
			var mid := str(_draft_ids[i])
			var m := GameState.get_member_by_id(mid)
			var hb := HBoxContainer.new()
			hb.add_theme_constant_override("separation", 6)
			slot.add_child(hb)
			var tr := TextureRect.new()
			tr.texture = _portrait_for(str(m.get("job", "dps")))
			tr.custom_minimum_size = Vector2(36, 36)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			hb.add_child(tr)
			var meta := VBoxContainer.new()
			meta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hb.add_child(meta)
			meta.add_child(UIStyle.label(str(m.get("name", mid)), 12, UIStyle.GOLD_BRIGHT))
			meta.add_child(UIStyle.label("%s Lv.%d" % [UIStyle.job_name(str(m.get("job", ""))), int(m.get("level", 1))], 10, UIStyle.TEXT_DIM))
			var xbtn := Button.new()
			xbtn.text = "×"
			xbtn.custom_minimum_size = Vector2(28, 28)
			UIStyle.apply_button(xbtn)
			var mid_copy := mid
			xbtn.pressed.connect(func():
				_draft_ids.erase(mid_copy)
				_refresh_lists_only()
			)
			hb.add_child(xbtn)
		else:
			var empty := UIStyle.label("+", 18, UIStyle.TEXT_DIM)
			empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
			slot.add_child(empty)
		_party_row.add_child(slot)


func _toggle_draft(member_id: String) -> void:
	var sid := str(member_id)
	if _draft_ids.has(sid):
		# Focus-only when already selected via card double semantics:
		# first click focuses+toggles; if already in draft and focused, keep (remove via ×).
		# Card press always toggles for snappy formation.
		_draft_ids.erase(sid)
		return
	var max_n: int = int(GameState.GUILD_PARTY_MAX.get(party_kind, 5))
	if _draft_ids.size() >= max_n:
		GameState.emit_message("파티 인원이 가득 찼습니다. (최대 %d)" % max_n, true)
		return
	var other := GameState.member_party_kind(sid)
	if other != "" and other != party_kind and not _draft_ids.has(sid):
		# Exclusive on save; warn early.
		GameState.emit_message("저장 시 다른 파티(%s)에서 해제됩니다." % GameState.guild_party_label(other))
	_draft_ids.append(sid)


func _switch_kind(kind: String) -> void:
	if kind == party_kind:
		return
	party_kind = kind
	_draft_ids = GameState.get_guild_party(party_kind).duplicate()
	_style_kind_buttons()
	_refresh_lists_only()


func _on_confirm() -> void:
	if GameState.set_guild_party(party_kind, _draft_ids):
		saved.emit(party_kind)
		closed.emit()


func _refresh_lists_only() -> void:
	_style_filter_buttons()
	_style_kind_buttons()
	_update_summary_labels()
	_populate_grid()
	_populate_detail()
	_populate_party_strip()


func _update_summary_labels() -> void:
	var max_n: int = int(GameState.GUILD_PARTY_MAX.get(party_kind, 5))
	if _count_label:
		_count_label.text = "선택 %d/%d" % [_draft_ids.size(), max_n]
	var sum_lv := 0
	var jobs := {}
	for mid in _draft_ids:
		var m := GameState.get_member_by_id(str(mid))
		sum_lv += int(m.get("level", 1))
		var j := str(m.get("job", ""))
		jobs[j] = int(jobs.get(j, 0)) + 1
	if _avg_label:
		if _draft_ids.is_empty():
			_avg_label.text = "평균 Lv. —"
		else:
			_avg_label.text = "평균 Lv.%d" % int(round(float(sum_lv) / float(_draft_ids.size())))
	if _comp_label:
		var parts: PackedStringArray = PackedStringArray()
		for j in JOB_FILTERS:
			if j == "all":
				continue
			var n: int = int(jobs.get(j, 0))
			if n > 0:
				parts.append("%s %d" % [UIStyle.job_name(j), n])
		_comp_label.text = "구성: " + (" / ".join(parts) if parts.size() > 0 else "없음")


func _style_filter_buttons() -> void:
	for job in _filter_buttons.keys():
		var b: Button = _filter_buttons[job]
		if not is_instance_valid(b):
			continue
		if str(job) == _filter_job:
			b.add_theme_stylebox_override("normal", UIStyle.button_pressed())
		else:
			UIStyle.apply_button(b)


func _style_kind_buttons() -> void:
	for kind in _kind_buttons.keys():
		var b: Button = _kind_buttons[kind]
		if not is_instance_valid(b):
			continue
		if str(kind) == party_kind:
			b.add_theme_stylebox_override("normal", UIStyle.button_pressed())
		else:
			UIStyle.apply_button(b)


func _portrait_for(job: String) -> Texture2D:
	var sheet := "res://assets/sprites/characters/%s/combat_00.png" % job
	if ResourceLoader.exists(sheet):
		return load(sheet) as Texture2D
	var path := "res://assets/sprites/characters/portrait_%s.png" % job
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return load("res://assets/sprites/characters/portrait_lord.png") as Texture2D
