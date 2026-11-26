extends Control

## Compact hunting-ground minimap (top-left). Click opens expanded maze modal.
## Does NOT apply to dungeon vertical floors.

signal open_requested

const NODE := 10.0

var _btn: Button
var _hint: Label


func _ready() -> void:
	custom_minimum_size = Vector2(132, 132)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_btn = Button.new()
	_btn.flat = true
	_btn.focus_mode = Control.FOCUS_NONE
	_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_btn.pressed.connect(func(): open_requested.emit())
	add_child(_btn)
	_hint = Label.new()
	_hint.text = "미니맵"
	_hint.add_theme_font_size_override("font_size", 11)
	_hint.add_theme_color_override("font_color", UIStyle.GOLD)
	_hint.position = Vector2(8, 4)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)
	var ui := get_node_or_null("/root/UIStyle")
	if ui and ui.has_method("apply_font"):
		ui.apply_font(_hint, 11)
	queue_redraw()


func refresh() -> void:
	queue_redraw()


func _font() -> Font:
	var ui := get_node_or_null("/root/UIStyle")
	if ui and ui.has_method("draw_font"):
		return ui.draw_font()
	return ThemeDB.fallback_font


func _draw() -> void:
	var panel := Rect2(Vector2.ZERO, size)
	draw_rect(panel, Color(0.07, 0.08, 0.12, 0.78), true)
	draw_rect(panel, UIStyle.GOLD, false, 1.5)

	var map := GameState.get_active_hunt_map()
	if map.is_empty():
		draw_string(_font(), Vector2(10, 70), "—", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UIStyle.TEXT_DIM)
		return

	var rooms: Dictionary = map.get("rooms", {})
	var cur := str(map.get("current_room_id", ""))
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
		var x := int(p[0])
		var y := int(p[1])
		min_x = mini(min_x, x)
		min_y = mini(min_y, y)
		max_x = maxi(max_x, x)
		max_y = maxi(max_y, y)
		visible.append(r)
	if visible.is_empty():
		return

	var cols := maxi(1, max_x - min_x + 1)
	var rows := maxi(1, max_y - min_y + 1)
	var pad := 16.0
	var usable_w := size.x - pad * 2.0
	var usable_h := size.y - pad * 2.0 - 10.0
	var cell := minf(usable_w / float(cols), usable_h / float(rows))
	cell = clampf(cell, 12.0, 22.0)
	var ox := pad + (usable_w - cell * cols) * 0.5
	var oy := pad + 12.0 + (usable_h - cell * rows) * 0.5

	for r in visible:
		var p: Array = r.get("position", [0, 0])
		var ax := ox + (float(int(p[0]) - min_x) + 0.5) * cell
		var ay := oy + (float(int(p[1]) - min_y) + 0.5) * cell
		var cons: Dictionary = r.get("connected_rooms", {})
		for d in ["N", "E", "S", "W"]:
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
			draw_line(Vector2(ax, ay), Vector2(bx, by), Color(0.55, 0.48, 0.32, 0.85), 2.0)

	for r in visible:
		var p: Array = r.get("position", [0, 0])
		var cx := ox + (float(int(p[0]) - min_x) + 0.5) * cell
		var cy := oy + (float(int(p[1]) - min_y) + 0.5) * cell
		var rid := str(r.get("room_id"))
		var cleared := bool(r.get("cleared", false))
		var boss := bool(r.get("boss_flag", false))
		var is_cur := rid == cur
		var col := Color(0.25, 0.28, 0.35, 0.95)
		var border := Color(0.55, 0.55, 0.6, 0.9)
		if boss:
			col = Color(0.45, 0.12, 0.12, 0.95)
			border = Color(0.95, 0.35, 0.35, 1.0)
		elif cleared:
			col = Color(0.18, 0.22, 0.18, 0.95)
			border = Color(0.45, 0.7, 0.45, 0.9)
		if is_cur:
			border = UIStyle.GOLD_BRIGHT
			col = Color(0.35, 0.28, 0.12, 0.98)
		var half := NODE * 0.5
		var rect := Rect2(cx - half, cy - half, NODE, NODE)
		draw_rect(rect, col, true)
		draw_rect(rect, border, false, 1.4 if is_cur else 1.0)
		# Geometric icons — avoid unsupported unicode glyphs (✓/☠) on web.
		if cleared and not is_cur:
			draw_line(Vector2(cx - 3, cy), Vector2(cx - 1, cy + 3), Color(0.6, 0.9, 0.6), 1.4)
			draw_line(Vector2(cx - 1, cy + 3), Vector2(cx + 3, cy - 3), Color(0.6, 0.9, 0.6), 1.4)
		if boss:
			draw_circle(Vector2(cx, cy), 2.2, Color(1, 0.55, 0.55))

	draw_circle(Vector2(size.x - 14, size.y - 14), 7.0, Color(0.12, 0.12, 0.16, 0.9))
	draw_arc(Vector2(size.x - 14, size.y - 14), 5.0, 0, TAU, 16, UIStyle.GOLD, 1.2)
