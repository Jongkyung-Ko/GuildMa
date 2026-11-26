extends Control

## Vertical dungeon minimap: window of ±window_radius floors around current.
## Current = gold; cleared = dark gold; locked = dim; boss floors = icon mark.

const WINDOW_RADIUS := 3

var dungeon_id: String = ""
var _title: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(132, 220)
	_title = Label.new()
	_title.text = "층"
	_title.add_theme_font_size_override("font_size", 12)
	_title.add_theme_color_override("font_color", UIStyle.GOLD)
	_title.position = Vector2(8, 6)
	add_child(_title)
	var ui := get_node_or_null("/root/UIStyle")
	if ui and ui.has_method("apply_font"):
		ui.apply_font(_title, 12)


func setup(id: String) -> void:
	dungeon_id = id
	queue_redraw()


func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	if dungeon_id == "":
		return
	var def: Dictionary = GameState.get_dungeon_def(dungeon_id)
	if def.is_empty():
		return
	var prog: Dictionary = GameState.ensure_dungeon_progress(dungeon_id)
	var cur := int(prog.get("current_floor", 1))
	var max_f := int(def.get("max_floor", 1))
	var boss_floors: Dictionary = def.get("boss_floors", {})

	var panel := Rect2(Vector2.ZERO, size)
	draw_rect(panel, Color(0.06, 0.07, 0.1, 0.72), true)
	draw_rect(panel, UIStyle.GOLD, false, 1.5)

	var top := maxi(1, cur - WINDOW_RADIUS)
	var bottom := mini(max_f, cur + WINDOW_RADIUS)
	# Prefer a full window when near ends
	if bottom - top < WINDOW_RADIUS * 2:
		if top == 1:
			bottom = mini(max_f, top + WINDOW_RADIUS * 2)
		elif bottom == max_f:
			top = maxi(1, bottom - WINDOW_RADIUS * 2)

	var row_h := 22.0
	var y0 := 28.0
	var floors: Array = []
	for f in range(bottom, top - 1, -1):
		floors.append(f)

	for i in floors.size():
		var f: int = int(floors[i])
		var y := y0 + float(i) * row_h
		var cleared := GameState.dungeon_is_floor_cleared(dungeon_id, f)
		var unlocked := GameState.dungeon_is_floor_unlocked(dungeon_id, f)
		var is_cur := f == cur
		var boss_info = boss_floors.get(str(f), null)

		var bg := Color(0.12, 0.12, 0.16, 0.85)
		var border := Color(0.35, 0.32, 0.28, 0.9)
		var text_c := UIStyle.TEXT_DIM
		if not unlocked:
			bg = Color(0.08, 0.08, 0.1, 0.55)
			border = Color(0.22, 0.2, 0.18, 0.5)
			text_c = Color(0.4, 0.38, 0.35, 0.7)
		elif is_cur:
			bg = Color(0.28, 0.22, 0.1, 0.92)
			border = UIStyle.GOLD_BRIGHT
			text_c = UIStyle.GOLD_BRIGHT
		elif cleared:
			bg = Color(0.2, 0.16, 0.08, 0.88)
			border = UIStyle.GOLD
			text_c = UIStyle.GOLD

		var r := Rect2(8, y, size.x - 16, row_h - 3)
		draw_rect(r, bg, true)
		draw_rect(r, border, false, 1.0 if not is_cur else 1.6)

		var label := "%dF" % f
		if boss_info != null:
			var btype := str(boss_info.get("type", ""))
			label += " ◆" if btype == "final" else " ▲"
		draw_string(ThemeDB.fallback_font, Vector2(r.position.x + 8, r.position.y + 14), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, text_c)
