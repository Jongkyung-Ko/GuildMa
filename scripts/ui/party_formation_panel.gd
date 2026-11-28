extends Control
class_name PartyFormationPanel

## Dark-fantasy guild party formation UI (concept layout, real GameState data).
## Skill demo is visual preview only — no HP/MP/CD combat side effects.

const JOB_FILTERS := ["all", "lord", "tank", "dps", "healer", "mage"]
const SORT_LEVEL_DESC := "level_desc"
const SORT_LEVEL_ASC := "level_asc"
const SORT_NAME := "name"

## Stone / bronze / gold palette — local to formation (does not restyle shop/hall globals).
const STONE_BG := Color(0.10, 0.085, 0.065, 0.98)
const STONE_DEEP := Color(0.07, 0.055, 0.04, 0.99)
const STONE_WELL := Color(0.045, 0.038, 0.028, 1.0)
const BRONZE := Color(0.62, 0.46, 0.24)
const BRONZE_DIM := Color(0.42, 0.32, 0.18)
const METAL_GOLD := Color(0.86, 0.70, 0.32)
const METAL_GOLD_BRIGHT := Color(1.0, 0.88, 0.48)
const INK := Color(0.95, 0.92, 0.86)
const INK_DIM := Color(0.68, 0.64, 0.56)

## Real skill strings → preview metadata (not mock combat numbers).
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

## Map skills → existing project icon paths (facility + item art). Never invent missing paths.
const SKILL_ICON_CANDIDATES := {
	"지휘": ["res://assets/sprites/icons/guild.png", "res://assets/sprites/icons/rep.png"],
	"방패 막기": ["res://assets/items/crest_shield.png", "res://assets/sprites/icons/storage.png"],
	"연속 베기": ["res://assets/items/blade_zwei.png", "res://assets/sprites/icons/train.png"],
	"치유": ["res://assets/items/health_potion.png", "res://assets/sprites/icons/med.png"],
	"마력탄": ["res://assets/items/crystal_shadow.png", "res://assets/sprites/icons/quest.png"],
	"화염구": ["res://assets/items/fire_crystal.png", "res://assets/items/amulet_flame.png"],
	"도발": ["res://assets/sprites/icons/rep.png", "res://assets/sprites/icons/gate.png"],
	"견고함": ["res://assets/items/armor_knight.png", "res://assets/sprites/icons/smith.png"],
	"급습": ["res://assets/items/cloak_shadow.png", "res://assets/sprites/icons/gate.png"],
}

const STAT_ICON_HP := ["res://assets/sprites/icons/med.png", "res://assets/items/health_potion.png"]
const STAT_ICON_ATK := ["res://assets/sprites/icons/train.png", "res://assets/items/blade_zwei.png"]
const STAT_ICON_DEF := ["res://assets/items/crest_shield.png", "res://assets/sprites/icons/storage.png"]

## Art-kit namecards for all roster members (same size/structure — no Aren-only hero card).
## Frames extracted from 01_UI_Frames_Atlas.png. UV from card_frame_default.png.
const KIT_CARD_DEFAULT := "res://assets/ui/party/frames/card_frame_default.png"
const KIT_CARD_SELECTED := "res://assets/ui/party/frames/card_frame_selected.png"
const KIT_DETAIL_PANEL := "res://assets/ui/party/frames/detail_panel.png"
const KIT_PARTY_SLOT := "res://assets/ui/party/frames/party_slot_bar.png"
## Rect2 = (x0, y0, w, h) in 0–1 frame space — always paired with `card_frame_default`
## (340×548). Selected state uses a badge, not the differently-proportioned selected PNG.
const KIT_PORTRAIT_UV := Rect2(0.132, 0.141, 0.730, 0.445)
const KIT_NAME_UV := Rect2(0.14, 0.600, 0.72, 0.078)
const KIT_STATS_UV := Rect2(0.14, 0.678, 0.72, 0.078)
const KIT_SKILL_UVS := [
	Rect2(0.162, 0.766, 0.168, 0.102),
	Rect2(0.421, 0.766, 0.165, 0.100),
	Rect2(0.676, 0.766, 0.162, 0.100),
]

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
var _grid_fit_w: float = 0.0
var _ratio_list: float = 0.62
var _ratio_detail: float = 0.30
var _target_detail_w: float = 0.0


func set_layout_ratios(list_r: float, detail_r: float, detail_w: float = 0.0) -> void:
	_ratio_list = list_r
	_ratio_detail = detail_r
	_target_detail_w = detail_w

var _tex_cache: Dictionary = {}


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
		if _grid_scroll:
			_scroll_y = float(_grid_scroll.scroll_vertical)
		_rebuild()
		if _grid_scroll:
			_grid_scroll.scroll_vertical = int(_scroll_y)


# ---------------------------------------------------------------------------
# Dark-fantasy chrome helpers (formation-local)
# ---------------------------------------------------------------------------

func _style_stone(active: bool = false, compact: bool = false) -> StyleBoxFlat:
	## Outer panel: warm stone fill + bronze rim (not flat navy/yellow admin chrome).
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.16, 0.12, 0.07, 0.97) if active else Color(0.11, 0.09, 0.06, 0.97)
	s.border_color = METAL_GOLD_BRIGHT if active else BRONZE
	s.border_width_left = 2
	s.border_width_right = 2
	s.border_width_top = 2
	s.border_width_bottom = 4
	s.set_corner_radius_all(8)
	var pad := 5 if compact else 8
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = 4 if compact else 6
	s.content_margin_bottom = 4 if compact else 6
	s.shadow_color = Color(0, 0, 0, 0.55)
	s.shadow_size = 6 if compact else 8
	s.shadow_offset = Vector2(0, 2)
	return s


func _style_inset() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = STONE_WELL
	s.border_color = Color(0.28, 0.22, 0.14, 1)
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	s.content_margin_left = 4
	s.content_margin_right = 4
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s


func _style_card_outer(selected: bool) -> StyleBoxFlat:
	## Dual-rim card shell: dark fill + bronze/gold hierarchy for select state.
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.13, 0.10, 0.06, 1) if selected else Color(0.08, 0.065, 0.045, 1)
	s.border_color = METAL_GOLD_BRIGHT if selected else BRONZE_DIM
	s.set_border_width_all(2)
	s.set_corner_radius_all(7)
	s.content_margin_left = 2
	s.content_margin_right = 2
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	s.shadow_color = Color(0.85, 0.62, 0.18, 0.35) if selected else Color(0, 0, 0, 0.45)
	s.shadow_size = 8 if selected else 4
	s.shadow_offset = Vector2(0, 2)
	return s


func _style_card_inner(selected: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.09, 0.07, 0.05, 0.98)
	s.border_color = METAL_GOLD if selected else BRONZE
	s.set_border_width_all(1)
	s.set_corner_radius_all(5)
	s.content_margin_left = 4
	s.content_margin_right = 4
	s.content_margin_top = 3
	s.content_margin_bottom = 3
	return s


func _style_card(selected: bool) -> StyleBoxFlat:
	## Back-compat alias used by older call sites.
	return _style_card_inner(selected)


func _style_metal_cta() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.42, 0.30, 0.10, 1)
	s.border_color = METAL_GOLD_BRIGHT
	s.set_border_width_all(2)
	s.set_corner_radius_all(6)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	s.shadow_color = Color(0.9, 0.7, 0.2, 0.35)
	s.shadow_size = 8
	return s


func _make_stone_panel(active: bool = false, compact: bool = false) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style_stone(active, compact))
	return p


func _apply_metal_button(btn: Button, primary: bool = false) -> void:
	UIStyle.apply_button(btn)
	if primary:
		btn.add_theme_stylebox_override("normal", _style_metal_cta())
		btn.add_theme_color_override("font_color", Color(1, 0.96, 0.82))
		var hover := _style_metal_cta()
		hover.bg_color = Color(0.52, 0.38, 0.12, 1)
		btn.add_theme_stylebox_override("hover", hover)


func _tex(path: String) -> Texture2D:
	if path == "":
		return null
	if _tex_cache.has(path):
		return _tex_cache[path]
	if not ResourceLoader.exists(path):
		_tex_cache[path] = null
		return null
	var t := load(path) as Texture2D
	_tex_cache[path] = t
	return t


func _first_tex(candidates: Array) -> Texture2D:
	for c in candidates:
		var t := _tex(str(c))
		if t != null:
			return t
	return null


func _skill_tex(skill_name: String) -> Texture2D:
	if SKILL_ICON_CANDIDATES.has(skill_name):
		return _first_tex(SKILL_ICON_CANDIDATES[skill_name])
	# Fallback to facility icon set — never a broken path.
	return _first_tex(["res://assets/sprites/icons/quest.png", "res://assets/sprites/icons/train.png"])


# ---------------------------------------------------------------------------
# Layout
# ---------------------------------------------------------------------------

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and visible and _grid != null and is_instance_valid(_grid):
		call_deferred("_layout_member_grid")


var _shell_lock: Vector2 = Vector2.ZERO
var _members_lock_w: float = 0.0


func _apply_shell_size(fsize: Vector2) -> void:
	## Called by guild hall after fitting — keep inner VBox within the shell.
	## Godot 4.3 has no custom_maximum_size; lock via min+size+clip.
	_shell_lock = fsize
	clip_contents = true
	custom_minimum_size = fsize
	size = fsize
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_pin_root_to_shell()
	call_deferred("_layout_mid_split")


func _pin_root_to_shell() -> void:
	if get_child_count() < 1:
		return
	var root := get_child(0) as Control
	if root == null:
		return
	# Anchors only resolve correctly after the node is inside the tree.
	root.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	root.offset_left = 0
	root.offset_top = 0
	root.offset_right = 0
	root.offset_bottom = 0
	root.clip_contents = true
	if _shell_lock != Vector2.ZERO:
		custom_minimum_size = _shell_lock
		set_deferred("size", _shell_lock)


func _rebuild() -> void:
	for c in get_children():
		c.free()
	_filter_buttons.clear()
	_kind_buttons.clear()
	_demo_sprite = null
	_grid_fit_w = 0.0
	_ensure_row_tries = 0
	_grid_scroll = null
	_grid = null

	clip_contents = true
	if _shell_lock != Vector2.ZERO:
		custom_minimum_size = _shell_lock
		set_deferred("size", _shell_lock)
	var root := VBoxContainer.new()
	root.name = "FormationRoot"
	root.clip_contents = true
	root.add_theme_constant_override("separation", 3 if _dense else 4)
	add_child(root)
	# Must pin after add_child so FULL_RECT binds to this panel's size.
	_pin_root_to_shell()

	root.add_child(_build_header())
	var mid := HBoxContainer.new()
	mid.name = "FormationMid"
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.size_flags_stretch_ratio = 1.0
	mid.clip_contents = true
	mid.add_theme_constant_override("separation", 6)
	root.add_child(mid)
	mid.add_child(_build_member_column())
	mid.add_child(_build_detail_column())
	var party := _build_party_strip()
	party.size_flags_vertical = Control.SIZE_SHRINK_END
	party.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(party)
	# Mid-split first so list width is stable; it then reflows the card grid.
	call_deferred("_layout_mid_split")
	call_deferred("_pin_root_to_shell")


func _build_header() -> Control:
	## Two compact rows: party-kind tabs + sort/filter toolbar. No duplicate chrome.
	var host := Control.new()
	host.name = "FormationHeader"
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Tall enough for tabs + filter toolbar; keep HUD+header ≤ ~15% @ 720.
	host.custom_minimum_size = Vector2(0, 48 if _dense else 52)
	host.clip_contents = false
	var panel := _make_stone_panel(false, true)
	host.add_child(panel)
	panel.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	panel.add_child(vb)

	# Row 1 — party kind tabs + summary + close
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	vb.add_child(tabs)
	for kind in GameState.GUILD_PARTY_KINDS:
		var b := Button.new()
		b.text = GameState.guild_party_label(str(kind))
		b.custom_minimum_size = Vector2(0, 20)
		_apply_metal_button(b)
		var k := str(kind)
		b.pressed.connect(func(): _switch_kind(k))
		tabs.add_child(b)
		_kind_buttons[k] = b
	_style_kind_buttons()
	var tab_sp := Control.new()
	tab_sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(tab_sp)
	_count_label = UIStyle.label("", 10, INK)
	tabs.add_child(_count_label)
	_avg_label = UIStyle.label("", 9, INK_DIM)
	tabs.add_child(_avg_label)
	_comp_label = UIStyle.label("", 9, INK_DIM)
	# Keep label for summary updates; hide to save chrome.
	_comp_label.visible = false
	tabs.add_child(_comp_label)
	var close_b := Button.new()
	close_b.text = "닫기"
	close_b.custom_minimum_size = Vector2(52, 20)
	_apply_metal_button(close_b)
	close_b.pressed.connect(func(): closed.emit())
	tabs.add_child(close_b)

	# Row 2 — compact sort + job filter toolbar
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 3)
	vb.add_child(tools)
	var sort := OptionButton.new()
	sort.custom_minimum_size = Vector2(0, 20)
	sort.add_item("레벨↓", 0)
	sort.add_item("레벨↑", 1)
	sort.add_item("이름", 2)
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
	tools.add_child(sort)
	for job in JOB_FILTERS:
		var fb := Button.new()
		fb.text = "전체" if job == "all" else UIStyle.job_name(job)
		fb.custom_minimum_size = Vector2(0, 20)
		_apply_metal_button(fb)
		var jid := str(job)
		fb.pressed.connect(func():
			_filter_job = jid
			_refresh_lists_only()
		)
		tools.add_child(fb)
		_filter_buttons[jid] = fb
	_style_filter_buttons()
	_update_summary_labels()
	return host


const GRID_SIDE_PAD := 8
const GRID_TOP_PAD := 10  ## Keeps kit frame top ornament clear of clip edge.
const GRID_BOTTOM_PAD := 6
const GRID_H_SEP := 10
const GRID_V_SEP := 10


func _screen_width() -> float:
	## Window/viewport width for PC vs short-landscape classing.
	var win := get_window()
	if win != null and win.size.x >= 64:
		return float(win.size.x)
	var vp := get_viewport()
	if vp != null:
		var vw := vp.get_visible_rect().size.x
		if vw >= 64.0:
			return vw
	if size.x >= 64.0:
		return size.x
	return 1280.0


func _list_usable_width() -> float:
	## Actual center list pane (scroll viewport), not full window width.
	if _grid_scroll != null and is_instance_valid(_grid_scroll) and _grid_scroll.size.x >= 32.0:
		return _grid_scroll.size.x
	if _members_lock_w > 64.0:
		return _members_lock_w
	if _shell_lock.x > 64.0:
		var dw := _target_detail_w if _target_detail_w > 64.0 else _shell_lock.x * (_ratio_detail / maxf(_ratio_list + _ratio_detail, 0.01))
		return maxf(160.0, _shell_lock.x - dw - 6.0)
	return maxf(160.0, _screen_width() * 0.55)


func _member_grid_columns() -> int:
	## Columns from list capacity + screen class:
	## 844×390 → 2; 1280/1366 → 4 (never stretch 2-col across a wide list).
	var sw := _screen_width()
	if sw > 0.0 and sw < 1100.0:
		return 2
	var list_w := _list_usable_width()
	var need4 := 4.0 * 168.0 + 3.0 * float(GRID_H_SEP) + float(GRID_SIDE_PAD * 2)
	if list_w >= need4 - 8.0:
		return 4
	# PC window before list settles — still 4; mid_split reserves width.
	if sw >= 1100.0:
		return 4
	return 2


func _build_member_column() -> Control:
	## Widest column — list expands; detail stays a fixed slim column beside it.
	## Plain Control host breaks card-grid min-width inflation into the mid HBox.
	var host := Control.new()
	host.name = "MemberColumn"
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.size_flags_stretch_ratio = 1.0
	host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host.clip_contents = true
	host.custom_minimum_size = Vector2(160, 0)
	var panel := _make_stone_panel()
	panel.name = "MemberPanel"
	panel.clip_contents = true
	host.add_child(panel)
	panel.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	panel.add_child(vb)
	vb.add_child(UIStyle.label("길드원 목록", 11, METAL_GOLD))
	_grid_scroll = ScrollContainer.new()
	_grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(_grid_scroll)
	# MarginContainer: fixed L/T inset only. Grid owns equal inter-card gaps.
	# Content-sized host → left-top aligned in the scroll (no center-spread).
	var grid_host := MarginContainer.new()
	grid_host.name = "GridHost"
	grid_host.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	grid_host.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_grid_scroll.add_child(grid_host)
	_grid = GridContainer.new()
	_grid.columns = _member_grid_columns()
	_grid.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_grid.add_theme_constant_override("h_separation", GRID_H_SEP)
	_grid.add_theme_constant_override("v_separation", GRID_V_SEP)
	grid_host.add_child(_grid)
	_populate_grid()
	return host


func _kit_card_base_size() -> Vector2:
	## Match card footprint to column mode (2-col compact / 4-col PC).
	if _member_grid_columns() <= 2:
		return Vector2(148.0, 210.0)
	return Vector2(168.0, 232.0)


func _uniform_kit_card_size() -> Vector2:
	## One size for every KitNamecard — prefer shared shrunk size, else mode base.
	var base := _kit_card_base_size()
	if _grid == null or not is_instance_valid(_grid):
		return base
	var seen := Vector2.ZERO
	var count := 0
	for c in _grid.get_children():
		if not _is_kit_namecard(c):
			continue
		var sz := (c as Control).custom_minimum_size
		if sz.x <= 8.0 or sz.y <= 8.0:
			continue
		if count == 0:
			seen = sz
		elif absf(sz.x - seen.x) > 0.5 or absf(sz.y - seen.y) > 0.5:
			return base
		count += 1
	if count > 0 and seen.y <= base.y + 0.5:
		return seen
	return base


func _is_kit_namecard(n: Node) -> bool:
	return n is Control and (n as Control).has_meta("kit_namecard")


func _layout_member_grid() -> void:
	## Left-top pack: fixed pads + equal h_sep. Never stretch leftover across the list.
	if _grid_scroll == null or _grid == null or not is_instance_valid(_grid_scroll) or not is_instance_valid(_grid):
		return
	if _grid_scroll.size.x < 32.0:
		call_deferred("_layout_member_grid_retry")
		return
	var cols := _member_grid_columns()
	_grid.columns = cols
	var mode_base := _kit_card_base_size()
	var card_sz := _uniform_kit_card_size()
	if absf(card_sz.x - mode_base.x) > 24.0:
		card_sz = mode_base
	for c in _grid.get_children():
		if not _is_kit_namecard(c):
			continue
		var card := c as Control
		if absf(card.custom_minimum_size.x - card_sz.x) > 0.5 or absf(card.custom_minimum_size.y - card_sz.y) > 0.5:
			card.custom_minimum_size = card_sz
		card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var host := _grid_scroll.get_node_or_null("GridHost") as MarginContainer
	var side := GRID_SIDE_PAD
	var top := GRID_TOP_PAD
	var bottom := GRID_BOTTOM_PAD
	var sep := GRID_H_SEP
	# If 4 cards cannot fit with fixed pads, tighten sep slightly (still equal).
	var list_w := _list_usable_width()
	var need := float(cols) * card_sz.x + float(maxi(cols - 1, 0)) * float(sep) + float(side * 2)
	if cols >= 4 and need > list_w + 0.5:
		var room := maxf(0.0, list_w - float(cols) * card_sz.x - float(side * 2))
		sep = int(floor(room / float(maxi(cols - 1, 1))))
		sep = clampi(sep, 4, GRID_H_SEP)
	var content_w := float(cols) * card_sz.x + float(maxi(cols - 1, 0)) * float(sep)
	if host:
		host.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		host.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		host.add_theme_constant_override("margin_left", side)
		host.add_theme_constant_override("margin_right", side)
		host.add_theme_constant_override("margin_top", top)
		host.add_theme_constant_override("margin_bottom", bottom)
		# Content-sized — leftover list width stays empty on the right (no center-spread).
		host.custom_minimum_size = Vector2(content_w + float(side * 2), 0)
	_grid.add_theme_constant_override("h_separation", sep)
	_grid.add_theme_constant_override("v_separation", GRID_V_SEP)
	_grid.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_grid.queue_sort()


func _layout_member_grid_retry() -> void:
	if _grid_scroll == null or not is_instance_valid(_grid_scroll):
		return
	if _grid_scroll.size.x >= 32.0:
		_layout_member_grid()


var _ensure_row_tries: int = 0

func _ensure_first_row_uncut() -> void:
	## Scale kit namecards uniformly via custom_minimum_size only, then re-layout gaps.
	if _grid_scroll == null or _grid == null or not is_instance_valid(_grid_scroll) or not is_instance_valid(_grid):
		return
	var view_h := _grid_scroll.size.y
	if view_h < 48.0:
		_ensure_row_tries += 1
		if _ensure_row_tries < 8:
			call_deferred("_ensure_first_row_uncut")
		return
	_ensure_row_tries = 0
	# Reserve top/bottom pads so frame ornaments are not clipped by the scroll clip.
	var max_card_h := maxf(view_h - float(GRID_TOP_PAD + GRID_BOTTOM_PAD + 4), 140.0)
	var base := _kit_card_base_size()
	var target := base
	if base.y > max_card_h + 0.5:
		var scale := max_card_h / maxf(base.y, 1.0)
		target = Vector2(base.x * scale, max_card_h)
	var changed := false
	for c in _grid.get_children():
		if not _is_kit_namecard(c):
			continue
		var card := c as Control
		if absf(card.custom_minimum_size.x - target.x) > 0.5 or absf(card.custom_minimum_size.y - target.y) > 0.5:
			card.custom_minimum_size = target
			changed = true
	_layout_member_grid()
	if changed:
		call_deferred("_layout_member_grid")


func _layout_mid_split() -> void:
	## List ~62% / detail ~30% of content width; both fully inside the shell.
	clip_contents = true
	_pin_root_to_shell()
	var mid := find_child("FormationMid", true, false) as Control
	var detail := find_child("DetailColumn", true, false) as Control
	var members := find_child("MemberColumn", true, false) as Control
	if mid == null or detail == null:
		return
	# Prefer shell lock so rebuild/resize cannot inflate list width.
	var avail := _shell_lock.x if _shell_lock.x > 64.0 else size.x
	if avail < 64.0:
		call_deferred("_layout_mid_split")
		return
	var sep := 6.0
	var detail_w := _target_detail_w if _target_detail_w > 64.0 else avail * (_ratio_detail / (_ratio_list + _ratio_detail))
	# Reserve list width for the column count (4 on PC, 2 on ~844).
	var cols_for_list := _member_grid_columns()
	var min_list := (4.0 * 168.0 + 3.0 * float(GRID_H_SEP) + float(GRID_SIDE_PAD * 2)) if cols_for_list >= 4 else (2.0 * 148.0 + float(GRID_H_SEP) + float(GRID_SIDE_PAD * 2))
	detail_w = mini(detail_w, maxf(160.0, avail - min_list - sep))
	if _dense:
		detail_w = mini(detail_w, avail * 0.34)
	detail_w = clampf(detail_w, 160.0 if _dense else 220.0, avail * 0.34)
	var members_w := maxf(min_list if cols_for_list >= 4 else 160.0, avail - detail_w - sep)
	_members_lock_w = members_w
	detail.custom_minimum_size = Vector2(detail_w, 0)
	detail.size_flags_horizontal = Control.SIZE_SHRINK_END
	detail.size_flags_stretch_ratio = 0.0
	if members:
		# Lock intended list width so GridHost gutters stay stable across rebuild.
		members.custom_minimum_size = Vector2(members_w, 0)
		members.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		members.size_flags_stretch_ratio = 1.0
	mid.clip_contents = true
	mid.custom_minimum_size = Vector2(0, 0)
	if mid.size.x > avail + 1.0:
		mid.set_deferred("size", Vector2(avail, mid.size.y))
	call_deferred("_layout_member_grid")
	call_deferred("_ensure_first_row_uncut")


func _build_detail_column() -> Control:
	## Kit detail chrome. Width is assigned in `_layout_mid_split` (layout-only).
	## Control host + anchored panel so detail min-width cannot blow the mid HBox.
	var host := Control.new()
	host.name = "DetailColumn"
	var detail_w := 280.0 if not _dense else 180.0
	host.custom_minimum_size = Vector2(detail_w, 0)
	host.size_flags_horizontal = Control.SIZE_SHRINK_END
	host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host.clip_contents = true
	var layer := Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(layer)
	layer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var bg := TextureRect.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.texture = _tex(KIT_DETAIL_PANEL)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	layer.add_child(bg)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	# Inset past ornate rim so text does not sit on gold decoration.
	scroll.offset_left = 18 if not _dense else 12
	scroll.offset_top = 16 if not _dense else 12
	scroll.offset_right = -18 if not _dense else -12
	scroll.offset_bottom = -16 if not _dense else -12
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layer.add_child(scroll)
	_detail_box = VBoxContainer.new()
	_detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_box.add_theme_constant_override("separation", 6)
	scroll.add_child(_detail_box)
	_populate_detail()
	return host


func _build_party_strip() -> Control:
	## One horizontal panel: label + 5 slots + actions. Nothing clipped below the fold.
	var host := Control.new()
	host.name = "PartyStrip"
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.size_flags_vertical = Control.SIZE_SHRINK_END
	host.clip_contents = false
	host.custom_minimum_size = Vector2(0, 64 if _dense else 72)
	var panel := _make_stone_panel(false, true)
	host.add_child(panel)
	panel.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(row)
	var max_n: int = int(GameState.GUILD_PARTY_MAX.get(party_kind, 5))
	var title := UIStyle.label("선택 파티 (%d/%d)" % [_draft_ids.size(), max_n], 11 if not _dense else 10, METAL_GOLD_BRIGHT)
	title.name = "PartyTitle"
	row.add_child(title)
	_party_row = HBoxContainer.new()
	_party_row.name = "PartySlots"
	_party_row.add_theme_constant_override("separation", 4)
	_party_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_party_row)
	var clear_b := Button.new()
	clear_b.text = "비우기"
	clear_b.custom_minimum_size = Vector2(64, 28 if not _dense else 24)
	_apply_metal_button(clear_b)
	clear_b.pressed.connect(func():
		_draft_ids.clear()
		_refresh_lists_only()
	)
	row.add_child(clear_b)
	var save_b := Button.new()
	save_b.text = "편성 완료"
	save_b.custom_minimum_size = Vector2(88 if not _dense else 76, 28 if not _dense else 24)
	_apply_metal_button(save_b, true)
	save_b.pressed.connect(_on_confirm)
	row.add_child(save_b)
	_populate_party_strip()
	return host


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
		_grid.add_child(UIStyle.label("해당 직업 길드원이 없습니다.", 13, INK_DIM))
		return
	# Every member uses the same kit namecard size/structure.
	for m in list:
		_grid.add_child(_make_kit_namecard(m))
	# Defer until MemberColumn width is final (see _layout_mid_split).
	call_deferred("_layout_member_grid")


# ---------------------------------------------------------------------------
# Art-kit namecards — uniform grid (all members)
# ---------------------------------------------------------------------------

func _make_kit_namecard(m: Dictionary) -> Control:
	## Compact vertical kit card — UV locked to card_frame_default for all members.
	var mid := str(m.get("id", ""))
	var in_draft := _draft_ids.has(mid)
	var focused := mid == _focus_id
	var base := _kit_card_base_size()
	var card_w := base.x
	var card_h := base.y

	var card := Button.new()
	card.name = "KitNamecard_%s" % mid
	card.set_meta("kit_namecard", true)
	card.flat = true
	card.clip_contents = true
	card.custom_minimum_size = Vector2(card_w, card_h)
	card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	UIStyle.apply_button(card)
	var flat_sb := StyleBoxEmpty.new()
	card.add_theme_stylebox_override("normal", flat_sb)
	card.add_theme_stylebox_override("hover", flat_sb)
	card.add_theme_stylebox_override("pressed", flat_sb)
	card.add_theme_stylebox_override("focus", flat_sb)

	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_preset(PRESET_FULL_RECT)
	card.add_child(root)

	# Dark fill in portrait hole, then sharp pixel portrait (NEAREST, no COVER upscale mush).
	var hole_fill := ColorRect.new()
	hole_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hole_fill.color = Color(0.03, 0.025, 0.02, 1)
	_ornate_apply_uv(hole_fill, KIT_PORTRAIT_UV)
	root.add_child(hole_fill)
	var portrait_host := CenterContainer.new()
	portrait_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ornate_apply_uv(portrait_host, KIT_PORTRAIT_UV)
	root.add_child(portrait_host)
	var portrait := TextureRect.new()
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.texture = _card_portrait_for(str(m.get("job", "lord")))
	# Cap display size near source (96×96 atlas) — prefer sharp over huge blurry blow-up.
	var face_side := 80.0 if _dense else 96.0
	portrait.custom_minimum_size = Vector2(face_side, face_side)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait_host.add_child(portrait)

	# Always default frame for UV fidelity (selected PNG has different aspect/holes).
	var frame := TextureRect.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.texture = _tex(KIT_CARD_DEFAULT)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.set_anchors_preset(PRESET_FULL_RECT)
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	root.add_child(frame)
	if in_draft or focused:
		var rim := PanelContainer.new()
		rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rim.set_anchors_preset(PRESET_FULL_RECT)
		var rsb := StyleBoxFlat.new()
		rsb.bg_color = Color(0, 0, 0, 0)
		rsb.border_color = METAL_GOLD_BRIGHT if focused else UIStyle.OK
		rsb.set_border_width_all(2)
		rsb.set_corner_radius_all(6)
		rim.add_theme_stylebox_override("panel", rsb)
		root.add_child(rim)

	var name_host := Control.new()
	name_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_host.clip_contents = true
	_ornate_apply_uv(name_host, KIT_NAME_UV)
	root.add_child(name_host)
	var name_col := VBoxContainer.new()
	name_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_col.set_anchors_preset(PRESET_FULL_RECT)
	name_col.alignment = BoxContainer.ALIGNMENT_CENTER
	name_col.add_theme_constant_override("separation", 0)
	name_host.add_child(name_col)
	var name_row := HBoxContainer.new()
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	name_row.add_theme_constant_override("separation", 4)
	name_col.add_child(name_row)
	var name_l := UIStyle.label(str(m.get("name", "")), 13 if not _dense else 12, METAL_GOLD_BRIGHT)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_row.add_child(name_l)
	if in_draft:
		name_row.add_child(UIStyle.label("선택", 8, UIStyle.OK))
	elif focused:
		name_row.add_child(UIStyle.label("포커스", 8, METAL_GOLD))
	var job_l := UIStyle.label("%s · Lv.%d" % [
		UIStyle.job_name(str(m.get("job", ""))), int(m.get("level", 1))
	], 10 if not _dense else 9, INK)
	job_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_col.add_child(job_l)

	# Compact one-line stats — chip stacks do not fit the kit stats band (~0.078 UV).
	var stats_host := Control.new()
	stats_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_host.clip_contents = true
	_ornate_apply_uv(stats_host, KIT_STATS_UV)
	root.add_child(stats_host)
	var preview := GameState.compute_combat_preview(m)
	var stats_row := HBoxContainer.new()
	stats_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_row.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	stats_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_row.add_theme_constant_override("separation", 6 if not _dense else 4)
	stats_host.add_child(stats_row)
	for pair in [
		["HP", int(preview.get("hp", 0)), Color(1.0, 0.55, 0.5)],
		["ATK", int(preview.get("atk", 0)), Color(1.0, 0.85, 0.45)],
		["DEF", int(preview.get("def", 0)), Color(0.65, 0.8, 1.0)],
	]:
		var cell := VBoxContainer.new()
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.add_theme_constant_override("separation", 0)
		var lab := UIStyle.label(str(pair[0]), 8, INK_DIM)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.add_theme_color_override("font_color", pair[2])
		cell.add_child(lab)
		var val := UIStyle.label(str(pair[1]), 12 if not _dense else 11, METAL_GOLD_BRIGHT)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(val)
		stats_row.add_child(cell)

	var skills: Array = m.get("skills", [])
	for i in 3:
		var well := Control.new()
		well.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ornate_apply_uv(well, KIT_SKILL_UVS[i])
		root.add_child(well)
		var sk := str(skills[i]) if i < skills.size() else ""
		var cell2 := CenterContainer.new()
		cell2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell2.set_anchors_preset(PRESET_FULL_RECT)
		well.add_child(cell2)
		if sk != "":
			var tex := _skill_tex(sk)
			if tex:
				var ir := TextureRect.new()
				ir.texture = tex
				ir.custom_minimum_size = Vector2(22 if _dense else 26, 22 if _dense else 26)
				ir.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				ir.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				ir.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				ir.mouse_filter = Control.MOUSE_FILTER_IGNORE
				ir.tooltip_text = sk
				cell2.add_child(ir)
			else:
				var cap := UIStyle.label(sk.substr(0, 2), 9, INK)
				cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				cell2.add_child(cap)
		else:
			var empty := ColorRect.new()
			empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
			empty.color = Color(0.08, 0.06, 0.04, 0.55)
			empty.custom_minimum_size = Vector2(18, 18)
			cell2.add_child(empty)

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


func _ornate_apply_uv(node: Control, uv: Rect2) -> void:
	## uv is (x0,y0,w,h) in 0–1 frame space → anchors on parent.
	node.anchor_left = uv.position.x
	node.anchor_top = uv.position.y
	node.anchor_right = uv.position.x + uv.size.x
	node.anchor_bottom = uv.position.y + uv.size.y
	node.offset_left = 0
	node.offset_top = 0
	node.offset_right = 0
	node.offset_bottom = 0


# ---------------------------------------------------------------------------
# Namecards — portrait-forward 70/30 + equal 3-col skill icons
# ---------------------------------------------------------------------------

func _make_member_card(m: Dictionary) -> Control:
	## v3: character is the hero. Portrait COVER-fills the top well; stats as 3 chips;
	## skills locked to bottom ~30%. Dense uses 2-col readable cards (not crushed 3-col).
	var mid := str(m.get("id", ""))
	var in_draft := _draft_ids.has(mid)
	var focused := mid == _focus_id
	var selected := in_draft or focused
	# Content mins must fit inside the list viewport — custom_minimum_size alone
	# cannot shrink a card whose children demand more height.
	var card_w := 136.0 if _dense else 150.0
	var portrait_side := 48.0 if _dense else 64.0
	var skill_h := 28.0 if _dense else 42.0
	# portrait + name + job + stats(~28) + sep + skills + chrome(~12) + seps
	var card_h := portrait_side + skill_h + (72.0 if _dense else 82.0)
	var card := Button.new()
	card.flat = true
	card.clip_contents = true
	card.custom_minimum_size = Vector2(card_w, card_h)
	card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	UIStyle.apply_button(card)
	var flat_sb := StyleBoxEmpty.new()
	card.add_theme_stylebox_override("normal", flat_sb)
	card.add_theme_stylebox_override("hover", flat_sb)
	card.add_theme_stylebox_override("pressed", flat_sb)
	card.add_theme_stylebox_override("focus", flat_sb)

	var outer := PanelContainer.new()
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.set_anchors_preset(PRESET_FULL_RECT)
	outer.add_theme_stylebox_override("panel", _style_card_outer(selected))
	card.add_child(outer)
	var wrap := PanelContainer.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_theme_stylebox_override("panel", _style_card_inner(selected))
	outer.add_child(wrap)

	var root := VBoxContainer.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_constant_override("separation", 2)
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.add_child(root)

	# --- Top block (fixed portrait, no expand that steals skill space) ---
	var top := VBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 2)
	top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top.size_flags_stretch_ratio = 7.0
	root.add_child(top)

	var portrait_row := CenterContainer.new()
	portrait_row.name = "PortraitRow"
	portrait_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait_row.custom_minimum_size = Vector2(0, portrait_side)
	top.add_child(portrait_row)
	var portrait_well := PanelContainer.new()
	portrait_well.name = "PortraitWell"
	portrait_well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_well.custom_minimum_size = Vector2(portrait_side, portrait_side)
	var well_sb := _style_inset()
	well_sb.content_margin_left = 1
	well_sb.content_margin_right = 1
	well_sb.content_margin_top = 1
	well_sb.content_margin_bottom = 1
	well_sb.bg_color = Color(0.03, 0.025, 0.02, 1)
	portrait_well.add_theme_stylebox_override("panel", well_sb)
	portrait_row.add_child(portrait_well)
	var tr := TextureRect.new()
	tr.texture = _card_portrait_for(str(m.get("job", "dps")))
	tr.custom_minimum_size = Vector2(portrait_side - 4.0, portrait_side - 4.0)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_well.add_child(tr)

	var name_row := HBoxContainer.new()
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_theme_constant_override("separation", 4)
	top.add_child(name_row)
	var name_l := UIStyle.label(str(m.get("name", "")), 12 if not _dense else 11, METAL_GOLD_BRIGHT)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_l)
	if in_draft:
		var badge := PanelContainer.new()
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bsb := StyleBoxFlat.new()
		bsb.bg_color = Color(0.18, 0.32, 0.16, 0.95)
		bsb.border_color = UIStyle.OK
		bsb.set_border_width_all(1)
		bsb.set_corner_radius_all(3)
		bsb.content_margin_left = 3
		bsb.content_margin_right = 3
		bsb.content_margin_top = 0
		bsb.content_margin_bottom = 0
		badge.add_theme_stylebox_override("panel", bsb)
		badge.add_child(UIStyle.label("선택", 8, UIStyle.OK))
		name_row.add_child(badge)
	elif focused:
		name_row.add_child(UIStyle.label("포커스", 8, METAL_GOLD))

	top.add_child(UIStyle.label("%s · Lv.%d" % [
		UIStyle.job_name(str(m.get("job", ""))), int(m.get("level", 1))
	], 10 if not _dense else 9, INK))

	var preview := GameState.compute_combat_preview(m)
	top.add_child(_stat_chip_row(
		int(preview.get("hp", 0)),
		int(preview.get("atk", 0)),
		int(preview.get("def", 0))
	))

	var div := HSeparator.new()
	div.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(div)

	# --- Bottom skill row (must remain on first paint) ---
	var skill_zone := VBoxContainer.new()
	skill_zone.name = "SkillZone"
	skill_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skill_zone.size_flags_vertical = Control.SIZE_SHRINK_END
	skill_zone.custom_minimum_size = Vector2(0, skill_h)
	skill_zone.add_theme_constant_override("separation", 0)
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


func _stat_chip_row(hp: int, atk: int, defv: int) -> Control:
	## Three equal chips so HP/ATK/DEF read at a glance without eating portrait space.
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 4)
	row.add_child(_stat_chip("HP", hp, STAT_ICON_HP, Color(0.85, 0.35, 0.35)))
	row.add_child(_stat_chip("ATK", atk, STAT_ICON_ATK, Color(0.95, 0.75, 0.35)))
	row.add_child(_stat_chip("DEF", defv, STAT_ICON_DEF, Color(0.45, 0.65, 0.95)))
	return row


func _stat_chip(label: String, value: int, icon_paths: Array, accent: Color) -> Control:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0.06, 0.05, 0.04, 0.92)
	csb.border_color = Color(accent.r, accent.g, accent.b, 0.55)
	csb.set_border_width_all(1)
	csb.set_corner_radius_all(4)
	csb.content_margin_left = 3
	csb.content_margin_right = 3
	csb.content_margin_top = 2
	csb.content_margin_bottom = 2
	chip.add_theme_stylebox_override("panel", csb)
	var hb := HBoxContainer.new()
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_theme_constant_override("separation", 3)
	chip.add_child(hb)
	var icon_sz := 11.0 if _dense else 13.0
	var icon_tex := _first_tex(icon_paths)
	if icon_tex:
		var ir := TextureRect.new()
		ir.texture = icon_tex
		ir.custom_minimum_size = Vector2(icon_sz, icon_sz)
		ir.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ir.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ir.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ir.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(ir)
	else:
		var dot := ColorRect.new()
		dot.color = accent
		dot.custom_minimum_size = Vector2(icon_sz, icon_sz)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(dot)
	var meta := VBoxContainer.new()
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta.add_theme_constant_override("separation", 0)
	hb.add_child(meta)
	meta.add_child(UIStyle.label(label, 8 if _dense else 9, INK_DIM))
	meta.add_child(UIStyle.label(str(value), 10 if _dense else 11, INK))
	return chip


func _build_card_skill_grid(skills_raw: Variant) -> Control:
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

		var icon_sz := 16.0 if _dense else 18.0
		var frame := PanelContainer.new()
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.custom_minimum_size = Vector2(icon_sz + 2, icon_sz + 2)
		frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var fsb := StyleBoxFlat.new()
		fsb.set_corner_radius_all(3)
		fsb.content_margin_left = 1
		fsb.content_margin_right = 1
		fsb.content_margin_top = 1
		fsb.content_margin_bottom = 1

		var caption := Label.new()
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.clip_text = true
		caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		caption.visible = not _dense
		caption.add_theme_font_size_override("font_size", 8 if _dense else 9)
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		caption.custom_minimum_size = Vector2(0, 12)

		if i < skills.size() and str(skills[i]) != "":
			var sk := str(skills[i])
			fsb.bg_color = Color(0.14, 0.11, 0.07, 1)
			fsb.border_color = METAL_GOLD
			fsb.set_border_width_all(1)
			frame.add_theme_stylebox_override("panel", fsb)
			var tex := _skill_tex(sk)
			if tex:
				var ir := TextureRect.new()
				ir.texture = tex
				ir.custom_minimum_size = Vector2(icon_sz, icon_sz)
				ir.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				ir.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				ir.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				ir.mouse_filter = Control.MOUSE_FILTER_IGNORE
				frame.add_child(ir)
			else:
				frame.add_child(UIStyle.label(sk.substr(0, 1), 9, INK))
			caption.text = sk
			caption.add_theme_color_override("font_color", INK)
		else:
			# Empty slot: soft well, no gold rim — must not read as a skill icon.
			fsb.bg_color = Color(0.05, 0.045, 0.035, 0.55)
			fsb.border_color = Color(0.22, 0.18, 0.12, 0.45)
			fsb.set_border_width_all(1)
			frame.add_theme_stylebox_override("panel", fsb)
			caption.text = ""
			caption.add_theme_color_override("font_color", Color(0.35, 0.32, 0.28, 0.6))

		cell.add_child(frame)
		cell.add_child(caption)
		grid.add_child(cell)
	return grid


# ---------------------------------------------------------------------------
# Detail panel
# ---------------------------------------------------------------------------

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
		_detail_box.add_child(UIStyle.label("길드원을 선택하세요.", 13, INK_DIM))
		return

	_detail_box.add_child(UIStyle.label(str(m.get("name", "")), 17 if not _dense else 14, METAL_GOLD_BRIGHT))
	_detail_box.add_child(UIStyle.label("%s · Lv.%d" % [
		UIStyle.job_name(str(m.get("job", ""))), int(m.get("level", 1))
	], 12, INK))

	# Compact detail face (list card already shows the framed hero). Sharp NEAREST, not blown up.
	var stage := PanelContainer.new()
	stage.add_theme_stylebox_override("panel", _style_inset())
	stage.custom_minimum_size = Vector2(0, 72 if _dense else 88)
	_detail_box.add_child(stage)
	var stage_center := CenterContainer.new()
	stage_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.add_child(stage_center)
	var pface := TextureRect.new()
	pface.texture = _card_portrait_for(str(m.get("job", "dps")))
	pface.custom_minimum_size = Vector2(64 if _dense else 80, 64 if _dense else 80)
	pface.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pface.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pface.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stage_center.add_child(pface)

	var preview := GameState.compute_combat_preview(m)
	_detail_box.add_child(UIStyle.label("능력치", 12, METAL_GOLD))
	_detail_box.add_child(_bar_stat("HP", int(preview.get("hp", 0)), 300, Color(0.75, 0.28, 0.28)))
	_detail_box.add_child(_bar_stat("ATK", int(preview.get("atk", 0)), 80, Color(0.85, 0.65, 0.25)))
	_detail_box.add_child(_bar_stat("DEF", int(preview.get("def", 0)), 60, Color(0.35, 0.55, 0.85)))

	_detail_box.add_child(UIStyle.label("대표 스킬", 12, METAL_GOLD))
	var skills: Array = m.get("skills", [])
	if skills.is_empty():
		_detail_box.add_child(UIStyle.label("(등록된 스킬 없음)", 12, INK_DIM))
		_skill_desc = null
		_demo_host = null
		_demo_note = null
	else:
		var sk_row := HBoxContainer.new()
		sk_row.add_theme_constant_override("separation", 6)
		_detail_box.add_child(sk_row)
		if _selected_skill == "" or not skills.has(_selected_skill):
			_selected_skill = str(skills[0])
		for sk in skills:
			var sb := Button.new()
			sb.custom_minimum_size = Vector2(52 if _dense else 58, 46 if _dense else 52)
			_apply_metal_button(sb)
			if str(sk) == _selected_skill:
				sb.add_theme_stylebox_override("normal", UIStyle.button_pressed())
			var inner := VBoxContainer.new()
			inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
			inner.alignment = BoxContainer.ALIGNMENT_CENTER
			sb.add_child(inner)
			var tex := _skill_tex(str(sk))
			if tex:
				var ir := TextureRect.new()
				ir.texture = tex
				ir.custom_minimum_size = Vector2(20, 20)
				ir.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				ir.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				ir.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				ir.mouse_filter = Control.MOUSE_FILTER_IGNORE
				ir.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				inner.add_child(ir)
			var cap := UIStyle.label(str(sk), 9, INK)
			cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			inner.add_child(cap)
			var sk_name := str(sk)
			sb.pressed.connect(func():
				_selected_skill = sk_name
				_populate_detail()
			)
			sk_row.add_child(sb)

		_skill_desc = UIStyle.label("", 10, INK)
		_skill_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail_box.add_child(_skill_desc)
		_update_skill_desc()

		_demo_host = Control.new()
		_demo_host.custom_minimum_size = Vector2(0, 56 if _dense else 64)
		_demo_host.clip_contents = true
		var demo_bg := PanelContainer.new()
		demo_bg.set_anchors_preset(PRESET_FULL_RECT)
		demo_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		demo_bg.add_theme_stylebox_override("panel", _style_inset())
		_demo_host.add_child(demo_bg)
		_detail_box.add_child(_demo_host)
		_demo_note = UIStyle.label("미리보기 전용", 9, INK_DIM)
		_detail_box.add_child(_demo_note)
		var demo_btn := Button.new()
		demo_btn.text = "스킬 미리보기"
		demo_btn.custom_minimum_size = Vector2(0, 26)
		_apply_metal_button(demo_btn)
		demo_btn.pressed.connect(_play_skill_demo)
		_detail_box.add_child(demo_btn)


func _bar_stat(label: String, value: int, cap: int, fill: Color = Color(0.55, 0.72, 0.35)) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var head := HBoxContainer.new()
	head.add_child(UIStyle.label(label, 11, INK_DIM))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	head.add_child(UIStyle.label(str(value), 11, INK))
	row.add_child(head)
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = maxf(1.0, float(cap))
	bar.value = float(value)
	bar.custom_minimum_size = Vector2(0, 11)
	bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.12, 0.10, 0.08, 1)
	bg.set_corner_radius_all(3)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
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
	_demo_sprite.scale = Vector2(1.25, 1.25)
	_demo_sprite.position = Vector2(100, 95)
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


# ---------------------------------------------------------------------------
# Party strip — portrait slots
# ---------------------------------------------------------------------------

func _populate_party_strip() -> void:
	if _party_row == null:
		return
	for c in _party_row.get_children():
		c.free()
	# Refresh title text if present.
	var strip := find_child("PartyStrip", true, false)
	if strip:
		var title := strip.find_child("PartyTitle", true, false) as Label
		if title:
			var max_label_n: int = int(GameState.GUILD_PARTY_MAX.get(party_kind, 5))
			title.text = "선택 파티 (%d/%d)" % [_draft_ids.size(), max_label_n]
	var max_n: int = int(GameState.GUILD_PARTY_MAX.get(party_kind, 5))
	for i in max_n:
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(96 if not _dense else 78, 44 if not _dense else 40)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var outer_sb := _style_card_outer(i < _draft_ids.size())
		outer_sb.content_margin_left = 3
		outer_sb.content_margin_right = 3
		outer_sb.content_margin_top = 2
		outer_sb.content_margin_bottom = 2
		slot.add_theme_stylebox_override("panel", outer_sb)
		if i < _draft_ids.size():
			var mid := str(_draft_ids[i])
			var m := GameState.get_member_by_id(mid)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 3)
			slot.add_child(row)
			var tr := TextureRect.new()
			tr.texture = _card_portrait_for(str(m.get("job", "dps")))
			tr.custom_minimum_size = Vector2(28 if not _dense else 24, 28 if not _dense else 24)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			row.add_child(tr)
			var texts := VBoxContainer.new()
			texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			texts.add_theme_constant_override("separation", 0)
			row.add_child(texts)
			texts.add_child(UIStyle.label(str(m.get("name", mid)), 10 if not _dense else 9, METAL_GOLD_BRIGHT))
			texts.add_child(UIStyle.label(UIStyle.job_name(str(m.get("job", ""))), 8, INK_DIM))
			var xbtn := Button.new()
			xbtn.text = "×"
			xbtn.custom_minimum_size = Vector2(22, 22)
			_apply_metal_button(xbtn)
			var mid_copy := mid
			xbtn.pressed.connect(func():
				_draft_ids.erase(mid_copy)
				_refresh_lists_only()
			)
			row.add_child(xbtn)
		else:
			var empty := UIStyle.label("+", 14, INK_DIM)
			empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
			slot.add_child(empty)
		_party_row.add_child(slot)


# ---------------------------------------------------------------------------
# Actions / state
# ---------------------------------------------------------------------------

func _toggle_draft(member_id: String) -> void:
	var sid := str(member_id)
	if _draft_ids.has(sid):
		_draft_ids.erase(sid)
		return
	var max_n: int = int(GameState.GUILD_PARTY_MAX.get(party_kind, 5))
	if _draft_ids.size() >= max_n:
		GameState.emit_message("파티 인원이 가득 찼습니다. (최대 %d)" % max_n, true)
		return
	var other := GameState.member_party_kind(sid)
	if other != "" and other != party_kind and not _draft_ids.has(sid):
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
			_apply_metal_button(b)


func _style_kind_buttons() -> void:
	for kind in _kind_buttons.keys():
		var b: Button = _kind_buttons[kind]
		if not is_instance_valid(b):
			continue
		if str(kind) == party_kind:
			b.add_theme_stylebox_override("normal", UIStyle.button_pressed())
		else:
			_apply_metal_button(b)


## Content crops for 96×96 portraits (measured; trims empty margin without inventing art).
const PORTRAIT_CROP := {
	"lord": Rect2(0, 0, 65, 93),
	"tank": Rect2(0, 7, 96, 87),
	"dps": Rect2(0, 2, 96, 88),
	"healer": Rect2(0, 4, 96, 91),
	"mage": Rect2(0, 0, 96, 93),
}


func _card_portrait_for(job: String) -> Texture2D:
	## Square portraits only — combat_00 sheets have huge empty margins and look tiny in cards.
	var path := "res://assets/sprites/characters/portrait_%s.png" % job
	var base := _tex(path)
	if base == null:
		base = _tex("res://assets/sprites/characters/portrait_lord.png")
	if base == null:
		return null
	var cache_key := "atlas:%s" % job
	if _tex_cache.has(cache_key) and _tex_cache[cache_key] != null:
		return _tex_cache[cache_key]
	var crop: Rect2 = PORTRAIT_CROP.get(job, Rect2(0, 0, base.get_width(), base.get_height()))
	crop.size.x = mini(crop.size.x, float(base.get_width()) - crop.position.x)
	crop.size.y = mini(crop.size.y, float(base.get_height()) - crop.position.y)
	var atlas := AtlasTexture.new()
	atlas.atlas = base
	atlas.region = crop
	_tex_cache[cache_key] = atlas
	return atlas


func _portrait_for(job: String) -> Texture2D:
	## Same art family as namecards/detail (consistent character identity).
	return _card_portrait_for(job)
