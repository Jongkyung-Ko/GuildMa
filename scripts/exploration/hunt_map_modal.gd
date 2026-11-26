extends CanvasLayer

## Expanded hunting maze map. Move only along real connections; blocked while fighting.

signal closed
signal travel_requested(room_id: String)

var _root: Control
var _map_view: Control
var _detail: VBoxContainer
var _move_btn: Button
var _msg: Label
var _selected: String = ""
var _combat_active: bool = true
var _node_rects: Dictionary = {}  # room_id -> Rect2 in map_view local


func setup(combat_active: bool) -> void:
	_combat_active = combat_active
	_build()
	_selected = str(GameState.get_active_hunt_map().get("current_room_id", ""))
	_refresh_detail()
	if _map_view:
		_map_view.queue_redraw()


func set_combat_active(active: bool) -> void:
	_combat_active = active
	_refresh_detail()


func _build() -> void:
	layer = 40
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	dim.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_close()
	)
	_root.add_child(dim)

	var mobile := UIStyle.is_mobile_like() if UIStyle else false
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	var pw := 920.0 if not mobile else 640.0
	var ph := 560.0 if not mobile else 480.0
	panel.offset_left = -pw * 0.5
	panel.offset_right = pw * 0.5
	panel.offset_top = -ph * 0.5
	panel.offset_bottom = ph * 0.5
	panel.add_theme_stylebox_override("panel", UIStyle.panel_style())
	_root.add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	panel.add_child(outer)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	outer.add_child(head)
	var title := UIStyle.label("미니맵", 20, UIStyle.GOLD_BRIGHT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close_btn := Button.new()
	close_btn.text = "닫기"
	UIStyle.apply_button(close_btn)
	close_btn.pressed.connect(_close)
	head.add_child(close_btn)

	var map := GameState.get_active_hunt_map()
	var sub := UIStyle.label(
		"%s — 이동할 방을 선택하세요" % str(map.get("hunt_name", "사냥터")),
		13, UIStyle.TEXT_DIM
	)
	outer.add_child(sub)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	outer.add_child(body)

	_map_view = Control.new()
	_map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map_view.custom_minimum_size = Vector2(420, 280)
	_map_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_map_view.draw.connect(_draw_map)
	_map_view.gui_input.connect(_on_map_input)
	body.add_child(_map_view)

	var legend := VBoxContainer.new()
	legend.custom_minimum_size.x = 150
	legend.add_theme_constant_override("separation", 6)
	body.add_child(legend)
	legend.add_child(UIStyle.label("범례", 14, UIStyle.GOLD))
	legend.add_child(_legend_row(UIStyle.GOLD_BRIGHT, "현재 위치"))
	legend.add_child(_legend_row(Color(0.45, 0.7, 0.45), "클리어한 방"))
	legend.add_child(_legend_row(Color(0.35, 0.65, 0.95), "이동 가능"))
	legend.add_child(_legend_row(Color(0.45, 0.45, 0.5), "발견·미클리어"))
	legend.add_child(_legend_row(Color(0.95, 0.35, 0.35), "보스 방"))

	var foot := PanelContainer.new()
	foot.add_theme_stylebox_override("panel", UIStyle.panel_style())
	outer.add_child(foot)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 4)
	foot.add_child(_detail)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	outer.add_child(actions)
	_msg = UIStyle.label("", 12, UIStyle.TEXT_DIM)
	_msg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(_msg)
	_move_btn = Button.new()
	_move_btn.text = "이동하기"
	_move_btn.custom_minimum_size = Vector2(140, 36)
	UIStyle.apply_button(_move_btn)
	_move_btn.pressed.connect(_on_move)
	actions.add_child(_move_btn)


func _legend_row(c: Color, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var sw := ColorRect.new()
	sw.custom_minimum_size = Vector2(14, 14)
	sw.color = c
	row.add_child(sw)
	row.add_child(UIStyle.label(text, 12, UIStyle.TEXT))
	return row


func _draw_map() -> void:
	_node_rects.clear()
	var map := GameState.get_active_hunt_map()
	var rooms: Dictionary = map.get("rooms", {})
	var cur := str(map.get("current_room_id", ""))
	var sz := _map_view.size
	_map_view.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.08, 0.09, 0.13, 0.95), true)
	_map_view.draw_rect(Rect2(Vector2.ZERO, sz), UIStyle.GOLD, false, 1.2)

	var min_x := 999
	var min_y := 999
	var max_x := -999
	var max_y := -999
	var visible: Array = []
	for rid in rooms.keys():
		var r: Dictionary = rooms[rid]
		if not bool(r.get("discovered", false)):
			continue
		var p: Array = r.get("position", [0, 0])
		min_x = mini(min_x, int(p[0]))
		min_y = mini(min_y, int(p[1]))
		max_x = maxi(max_x, int(p[0]))
		max_y = maxi(max_y, int(p[1]))
		visible.append(r)
	if visible.is_empty():
		return

	var cols := maxi(1, max_x - min_x + 1)
	var rows := maxi(1, max_y - min_y + 1)
	var pad := 28.0
	var cell := minf((sz.x - pad * 2.0) / float(cols), (sz.y - pad * 2.0) / float(rows))
	cell = clampf(cell, 36.0, 64.0)
	var ox := pad + (sz.x - pad * 2.0 - cell * cols) * 0.5
	var oy := pad + (sz.y - pad * 2.0 - cell * rows) * 0.5

	for r in visible:
		var p: Array = r.get("position", [0, 0])
		var ax := ox + (float(int(p[0]) - min_x) + 0.5) * cell
		var ay := oy + (float(int(p[1]) - min_y) + 0.5) * cell
		var cons: Dictionary = r.get("connected_rooms", {})
		for d in MazeGenerator.DIRS:
			var o = cons.get(d, null)
			if o == null:
				continue
			var oid := str(o)
			if not rooms.has(oid) or not bool(rooms[oid].get("discovered", false)):
				continue
			if oid < str(r.get("room_id")):
				continue
			var op: Array = rooms[oid].get("position", [0, 0])
			var bx := ox + (float(int(op[0]) - min_x) + 0.5) * cell
			var by := oy + (float(int(op[1]) - min_y) + 0.5) * cell
			_map_view.draw_line(Vector2(ax, ay), Vector2(bx, by), Color(0.62, 0.55, 0.35, 0.9), 3.0)

	for r in visible:
		var p: Array = r.get("position", [0, 0])
		var cx := ox + (float(int(p[0]) - min_x) + 0.5) * cell
		var cy := oy + (float(int(p[1]) - min_y) + 0.5) * cell
		var rid := str(r.get("room_id"))
		var cleared := bool(r.get("cleared", false))
		var boss := bool(r.get("boss_flag", false))
		var is_cur := rid == cur
		var can_move := (not _combat_active) and GameState.hunt_can_move_to(rid)
		var col := Color(0.22, 0.24, 0.3, 0.95)
		var border := Color(0.5, 0.5, 0.55)
		if boss:
			col = Color(0.42, 0.12, 0.12, 0.95)
			border = Color(0.95, 0.35, 0.35)
		elif cleared:
			col = Color(0.16, 0.22, 0.16, 0.95)
			border = Color(0.45, 0.75, 0.45)
		elif not cleared:
			border = Color(0.55, 0.55, 0.6)
		if can_move:
			border = Color(0.35, 0.7, 0.95)
			col = Color(0.15, 0.22, 0.32, 0.95)
		if is_cur:
			border = UIStyle.GOLD_BRIGHT
			col = Color(0.35, 0.28, 0.1, 0.98)
		if rid == _selected:
			border = Color(0.4, 0.85, 1.0)
		var ns := 22.0
		var rect := Rect2(cx - ns * 0.5, cy - ns * 0.5, ns, ns)
		_map_view.draw_rect(rect, col, true)
		_map_view.draw_rect(rect, border, false, 2.0 if rid == _selected or is_cur else 1.2)
		_node_rects[rid] = rect
		if cleared:
			_map_view.draw_string(ThemeDB.fallback_font, Vector2(cx - 4, cy + 4), "✓", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.7, 1.0, 0.7))
		elif boss:
			_map_view.draw_string(ThemeDB.fallback_font, Vector2(cx - 5, cy + 4), "☠", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.6, 0.6))


func _on_map_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var local: Vector2 = ev.position
		for rid in _node_rects.keys():
			var r: Rect2 = _node_rects[rid]
			if r.grow(6.0).has_point(local):
				_selected = str(rid)
				_refresh_detail()
				_map_view.queue_redraw()
				return


func _refresh_detail() -> void:
	while _detail.get_child_count() > 0:
		var c := _detail.get_child(0)
		_detail.remove_child(c)
		c.queue_free()
	var map := GameState.get_active_hunt_map()
	var rooms: Dictionary = map.get("rooms", {})
	if _selected == "" or not rooms.has(_selected):
		_detail.add_child(UIStyle.label("방을 선택하세요", 14, UIStyle.TEXT_DIM))
		_move_btn.disabled = true
		return
	var r: Dictionary = rooms[_selected]
	_detail.add_child(UIStyle.label(str(r.get("name", _selected)), 16, UIStyle.GOLD_BRIGHT))
	_detail.add_child(UIStyle.label("유형: %s" % str(r.get("area_type", r.get("room_type", ""))), 13, UIStyle.TEXT))
	_detail.add_child(UIStyle.label("권장 레벨: Lv.%d" % int(r.get("rec_level", 1)), 13, UIStyle.TEXT))
	var mons: Array = r.get("monsters", [])
	var mparts: PackedStringArray = PackedStringArray()
	for m in mons:
		mparts.append(str(m))
	var mtxt := ", ".join(mparts) if mparts.size() > 0 else "—"
	_detail.add_child(UIStyle.label("출현 몬스터: %s" % mtxt, 13, UIStyle.TEXT_DIM))
	if bool(r.get("boss_flag", false)):
		_detail.add_child(UIStyle.label("보스 방", 13, UIStyle.DANGER))
	var cons: Dictionary = r.get("connected_rooms", {})
	var exits: Array = []
	for d in MazeGenerator.DIRS:
		if cons.get(d, null) != null:
			exits.append(d)
	_detail.add_child(UIStyle.label("연결된 출구: %s" % (", ".join(PackedStringArray(exits)) if exits.size() > 0 else "없음"), 12, UIStyle.TEXT_DIM))

	var cur := str(map.get("current_room_id", ""))
	var can := GameState.hunt_can_move_to(_selected)
	if _combat_active:
		_move_btn.disabled = true
		_msg.text = "전투 중에는 이동할 수 없습니다. 전투 종료 후 이동하세요."
		_msg.add_theme_color_override("font_color", UIStyle.DANGER)
	elif _selected == cur:
		_move_btn.disabled = true
		_msg.text = "현재 위치입니다."
		_msg.add_theme_color_override("font_color", UIStyle.TEXT_DIM)
	elif can:
		_move_btn.disabled = false
		_msg.text = "이 방으로 이동할 수 있습니다."
		_msg.add_theme_color_override("font_color", UIStyle.OK)
	else:
		_move_btn.disabled = true
		_msg.text = "직접 연결되지 않은 방입니다."
		_msg.add_theme_color_override("font_color", UIStyle.TEXT_DIM)


func _on_move() -> void:
	if _combat_active:
		_msg.text = "전투 종료 후 이동 가능합니다."
		_msg.add_theme_color_override("font_color", UIStyle.DANGER)
		return
	if not GameState.hunt_can_move_to(_selected):
		_refresh_detail()
		return
	travel_requested.emit(_selected)


func _close() -> void:
	closed.emit()
	queue_free()
