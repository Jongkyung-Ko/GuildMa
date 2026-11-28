extends Control

## World map: painted continent + data-driven village/castle markers.
## Villages link to bosses via data/world/village_boss_links.json.
## Only open villages (Elderwood→Gorgon) launch real expeditions; others stay data-ready.

const MARKERS_PATH := "res://data/world/world_map_markers.json"
const BG_PATH := "res://assets/backgrounds/world_map_background.jpg"
## Design plate matches map art aspect (1024×576) scaled into 1280×720 shell.
const MAP_DESIGN := Vector2(1280, 720)

var _markers: Array = []
var _home_id: String = "elderwood"
var _selected_id: String = ""
var _map_host: Control
var _bg: TextureRect
var _panel: PanelContainer
var _panel_title: Label
var _panel_region: Label
var _panel_kind: Label
var _panel_body: Label
var _panel_bosses: Label
var _travel_btn: Button
var _expedition_btn: Button
var _status_label: Label
var _marker_buttons: Dictionary = {}


func _ready() -> void:
	_load_markers()
	_build_ui()
	resized.connect(_layout_map)
	call_deferred("_layout_map")
	# BGM is started by SceneRouter.go_world_map() → AudioManager.on_enter_world_map().


func _load_markers() -> void:
	_markers.clear()
	if not ResourceLoader.exists(MARKERS_PATH) and not FileAccess.file_exists(MARKERS_PATH):
		push_warning("WorldMap: missing markers JSON")
		return
	var f := FileAccess.open(MARKERS_PATH, FileAccess.READ)
	if f == null:
		push_warning("WorldMap: cannot open markers JSON")
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	_home_id = str(data.get("home_marker_id", "elderwood"))
	var list = data.get("markers", [])
	if typeof(list) == TYPE_ARRAY:
		_markers = list


func _build_ui() -> void:
	var under := ColorRect.new()
	under.color = Color(0.04, 0.05, 0.08)
	under.set_anchors_preset(PRESET_FULL_RECT)
	under.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(under)

	_map_host = Control.new()
	_map_host.name = "MapHost"
	_map_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_host.custom_minimum_size = MAP_DESIGN
	_map_host.size = MAP_DESIGN
	add_child(_map_host)

	_bg = TextureRect.new()
	_bg.name = "WorldMapBg"
	if ResourceLoader.exists(BG_PATH):
		_bg.texture = load(BG_PATH)
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.set_anchors_preset(PRESET_FULL_RECT)
	_bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_host.add_child(_bg)

	for m in _markers:
		if typeof(m) != TYPE_DICTIONARY:
			continue
		_add_marker(_map_host, m)

	_build_top_bar()
	_build_select_panel()
	_select_marker(_home_id)


func _build_top_bar() -> void:
	var top := UIStyle.make_panel()
	top.set_anchors_preset(PRESET_TOP_WIDE)
	top.offset_left = 10
	top.offset_right = -10
	top.offset_top = 8
	top.offset_bottom = 64
	add_child(top)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	top.add_child(row)

	row.add_child(UIStyle.label("세계 지도", 20, UIStyle.GOLD_BRIGHT))
	row.add_child(UIStyle.label("마을·성채를 선택하세요", 14, UIStyle.TEXT_DIM))

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var home_btn := Button.new()
	home_btn.text = "출발 마을로"
	UIStyle.apply_button(home_btn)
	home_btn.pressed.connect(_return_home)
	row.add_child(home_btn)

	var back_btn := Button.new()
	back_btn.text = "마을로 돌아가기"
	UIStyle.apply_button(back_btn)
	back_btn.pressed.connect(_return_home)
	row.add_child(back_btn)


func _build_select_panel() -> void:
	_panel = UIStyle.make_panel()
	_panel.name = "SelectPanel"
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -320
	_panel.offset_right = -12
	_panel.offset_top = 76
	_panel.offset_bottom = -16
	add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_panel.add_child(box)

	box.add_child(UIStyle.label("선택 정보", 14, UIStyle.TEXT_DIM))
	_panel_title = UIStyle.label("—", 22, UIStyle.GOLD_BRIGHT)
	box.add_child(_panel_title)
	_panel_region = UIStyle.label("", 14, UIStyle.TEXT)
	box.add_child(_panel_region)
	_panel_kind = UIStyle.label("", 13, UIStyle.TEXT_DIM)
	box.add_child(_panel_kind)

	var sep := ColorRect.new()
	sep.color = Color(0.82, 0.68, 0.32, 0.35)
	sep.custom_minimum_size = Vector2(0, 2)
	box.add_child(sep)

	_panel_body = UIStyle.label("", 14, UIStyle.TEXT)
	_panel_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_panel_body)

	_panel_bosses = UIStyle.label("", 14, UIStyle.GOLD_BRIGHT)
	_panel_bosses.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_panel_bosses)

	_status_label = UIStyle.label(
		"마을을 선택하면 연계 보스·사냥터가 표시됩니다. 개방된 거점만 출정할 수 있습니다.",
		12,
		UIStyle.TEXT_DIM
	)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status_label)

	_expedition_btn = Button.new()
	_expedition_btn.text = "사냥 출정"
	_expedition_btn.custom_minimum_size = Vector2(0, 42)
	UIStyle.apply_button(_expedition_btn)
	_expedition_btn.pressed.connect(_start_expedition)
	box.add_child(_expedition_btn)

	_travel_btn = Button.new()
	_travel_btn.text = "출발 마을로 돌아가기"
	_travel_btn.custom_minimum_size = Vector2(0, 42)
	UIStyle.apply_button(_travel_btn)
	_travel_btn.pressed.connect(_return_home)
	box.add_child(_travel_btn)


func _add_marker(host: Node, m: Dictionary) -> void:
	var mid := str(m.get("id", ""))
	if mid == "":
		return
	var kind := str(m.get("kind", "village"))
	var is_castle := kind == "castle"
	var is_home := bool(m.get("is_home", false)) or mid == _home_id
	var hit := Vector2(56, 56) if is_castle else Vector2(44, 44)

	var root := Control.new()
	root.name = "Marker_%s" % mid
	root.custom_minimum_size = hit
	root.size = hit
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	host.add_child(root)

	var plate := Panel.new()
	plate.set_anchors_preset(PRESET_FULL_RECT)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	if is_castle:
		style.bg_color = Color(0.55, 0.18, 0.16, 0.88)
		style.border_color = Color(1.0, 0.72, 0.35)
	elif is_home:
		style.bg_color = Color(0.18, 0.42, 0.28, 0.9)
		style.border_color = UIStyle.GOLD_BRIGHT
	else:
		style.bg_color = Color(0.14, 0.18, 0.28, 0.88)
		style.border_color = UIStyle.GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(hit.x * 0.5 if not is_castle else 8)
	plate.add_theme_stylebox_override("panel", style)
	root.add_child(plate)

	var glyph := Label.new()
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glyph.set_anchors_preset(PRESET_FULL_RECT)
	glyph.text = "성" if is_castle else ("홈" if is_home else "촌")
	glyph.add_theme_color_override("font_color", Color(1, 0.96, 0.88))
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.apply_font(glyph, 13 if is_castle else 12)
	root.add_child(glyph)

	var name_ko := str(m.get("name_ko", m.get("name", mid)))
	var tag := UIStyle.label(name_ko, 12, UIStyle.GOLD_BRIGHT)
	tag.position = Vector2(-10, -18)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tag)

	var btn := Button.new()
	btn.flat = true
	btn.set_anchors_preset(PRESET_FULL_RECT)
	btn.modulate = Color(1, 1, 1, 0)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.tooltip_text = name_ko
	root.add_child(btn)

	var id_copy := mid
	btn.pressed.connect(func():
		if AudioManager:
			AudioManager.play_ui_click()
		_select_marker(id_copy)
	)
	btn.mouse_entered.connect(func():
		plate.modulate = Color(1.15, 1.1, 0.95, 1)
	)
	btn.mouse_exited.connect(func():
		plate.modulate = Color(1, 1, 1, 1)
	)

	_marker_buttons[mid] = root
	# Stash normalized pos for layout.
	root.set_meta("norm_pos", _norm_pos(m.get("pos", [0.5, 0.5])))
	root.set_meta("hit", hit)


func _norm_pos(raw) -> Vector2:
	if typeof(raw) == TYPE_ARRAY and raw.size() >= 2:
		return Vector2(clampf(float(raw[0]), 0.0, 1.0), clampf(float(raw[1]), 0.0, 1.0))
	if typeof(raw) == TYPE_VECTOR2:
		return raw
	return Vector2(0.5, 0.5)


func _layout_map() -> void:
	if _map_host == null:
		return
	var view := size
	if view.x < 32.0 or view.y < 32.0:
		view = MAP_DESIGN
	# Fit map plate; leave top bar / right panel readable.
	var usable := Vector2(maxf(200.0, view.x - 340.0), maxf(160.0, view.y - 88.0))
	var scale := minf(usable.x / MAP_DESIGN.x, usable.y / MAP_DESIGN.y)
	var plate := MAP_DESIGN * scale
	_map_host.size = plate
	_map_host.custom_minimum_size = plate
	_map_host.position = Vector2(
		maxf(8.0, (usable.x - plate.x) * 0.5 + 8.0),
		76.0 + maxf(0.0, (usable.y - plate.y) * 0.5)
	)
	for mid in _marker_buttons.keys():
		var root: Control = _marker_buttons[mid]
		var np: Vector2 = root.get_meta("norm_pos", Vector2(0.5, 0.5))
		var hit: Vector2 = root.get_meta("hit", Vector2(44, 44))
		root.position = Vector2(np.x * plate.x - hit.x * 0.5, np.y * plate.y - hit.y * 0.5)
		root.size = hit


func _find_marker(mid: String) -> Dictionary:
	for m in _markers:
		if typeof(m) == TYPE_DICTIONARY and str(m.get("id", "")) == mid:
			return m
	return {}


func _select_marker(mid: String) -> void:
	_selected_id = mid
	var m := _find_marker(mid)
	if m.is_empty():
		_panel_title.text = "—"
		_panel_region.text = ""
		_panel_kind.text = ""
		_panel_body.text = "마커 데이터를 찾을 수 없습니다."
		_panel_bosses.text = ""
		return

	var name_ko := str(m.get("name_ko", m.get("name", mid)))
	var name_en := str(m.get("name", mid))
	_panel_title.text = "%s  (%s)" % [name_ko, name_en]
	_panel_region.text = str(m.get("region_name_ko", m.get("region_name", "")))
	var kind := str(m.get("kind", "village"))
	var is_home := bool(m.get("is_home", false)) or mid == _home_id
	if kind == "castle":
		_panel_kind.text = "성채 · Castle"
	elif is_home:
		_panel_kind.text = "출발 마을 · Home Town"
	else:
		_panel_kind.text = "마을 · Village"
	_panel_body.text = str(m.get("blurb", ""))

	var bosses = m.get("bosses", [])
	var link: Dictionary = {}
	if GameState:
		link = GameState.get_village_boss_link(mid)
	if typeof(bosses) == TYPE_ARRAY and bosses.size() > 0:
		var lines: PackedStringArray = PackedStringArray()
		lines.append("관련 보스")
		for b in bosses:
			if typeof(b) != TYPE_DICTIONARY:
				continue
			lines.append("· %s (%s)" % [str(b.get("name_ko", "")), str(b.get("name", ""))])
		_panel_bosses.text = "\n".join(lines)
	elif not link.is_empty():
		var bid := str(link.get("boss_id", ""))
		var bdef: Dictionary = GameState.get_boss_def(bid) if GameState else {}
		var bname := str(bdef.get("name", bid))
		_panel_bosses.text = "연계 보스 · %s\n%s" % [bname, str(link.get("label_ko", ""))]
	else:
		_panel_bosses.text = ""

	_travel_btn.text = "출발 마을로 돌아가기"
	_travel_btn.disabled = false

	if kind == "village" and not link.is_empty() and bool(link.get("open", false)):
		_expedition_btn.visible = true
		_expedition_btn.disabled = false
		_expedition_btn.text = "출정 — %s" % str(link.get("label_ko", "사냥터"))
		_status_label.text = "개방된 거점입니다. 출정 시 실제 보스 전투로 이어집니다."
	elif kind == "village" and not link.is_empty():
		_expedition_btn.visible = true
		_expedition_btn.disabled = true
		_expedition_btn.text = "미개방 — %s" % str(link.get("label_ko", "연계 준비됨"))
		_status_label.text = "데이터는 준비되어 있으나 아직 출정할 수 없습니다. (가짜 개방 없음)"
	else:
		_expedition_btn.visible = kind == "village"
		_expedition_btn.disabled = true
		_expedition_btn.text = "연계 정보 없음" if kind == "village" else "성채는 정보 표시만"
		_status_label.text = (
			"성채는 보스 목록만 표시합니다."
			if kind == "castle"
			else "마을을 선택하세요."
		)

	# Selection chrome on markers.
	for idk in _marker_buttons.keys():
		var root: Control = _marker_buttons[idk]
		var plate := root.get_child(0) as Panel
		if plate == null:
			continue
		if idk == mid:
			plate.modulate = Color(1.25, 1.15, 0.85, 1)
		else:
			plate.modulate = Color(1, 1, 1, 1)


func _return_home() -> void:
	if AudioManager:
		AudioManager.play_ui_click()
	SceneRouter.go_town()


func _start_expedition() -> void:
	if AudioManager:
		AudioManager.play_ui_click()
	if _selected_id == "":
		return
	var result: Dictionary = SceneRouter.go_village_expedition(_selected_id, true)
	if not bool(result.get("ok", false)):
		if GameState:
			GameState.emit_message(str(result.get("reason", "출정할 수 없습니다.")), true)
		_status_label.text = str(result.get("reason", "출정 실패"))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_return_home()
		get_viewport().set_input_as_handled()
