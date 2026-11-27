extends Control

## Large centered boss HP bar + phase / skill labels.

var _boss: Node = null
var _bar: ProgressBar
var _name_l: Label
var _phase_l: Label
var _skill_l: Label
var _hp_l: Label


func bind_boss(boss: Node) -> void:
	_boss = boss
	if _boss != null and _boss.has_signal("phase_changed") and not _boss.phase_changed.is_connected(_on_phase):
		_boss.phase_changed.connect(_on_phase)
	if _boss != null and _boss.has_signal("skill_used") and not _boss.skill_used.is_connected(_on_skill):
		_boss.skill_used.connect(_on_skill)
	visible = _boss != null
	_refresh()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	offset_top = 68
	offset_bottom = 118
	offset_left = 180
	offset_right = -280

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.1, 0.78)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	panel.add_child(col)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	_name_l = Label.new()
	_name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_l.add_theme_font_size_override("font_size", 16)
	_name_l.add_theme_color_override("font_color", Color(1.0, 0.82, 0.45))
	row.add_child(_name_l)
	_phase_l = Label.new()
	_phase_l.add_theme_font_size_override("font_size", 13)
	_phase_l.add_theme_color_override("font_color", Color(0.85, 0.75, 1.0))
	row.add_child(_phase_l)

	_bar = ProgressBar.new()
	_bar.min_value = 0
	_bar.max_value = 100
	_bar.value = 100
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 16)
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.12, 0.1, 0.12, 0.9)
	bg.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.85, 0.22, 0.28, 0.95)
	fill.set_corner_radius_all(3)
	_bar.add_theme_stylebox_override("background", bg)
	_bar.add_theme_stylebox_override("fill", fill)
	col.add_child(_bar)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	col.add_child(bottom)
	_hp_l = Label.new()
	_hp_l.add_theme_font_size_override("font_size", 12)
	_hp_l.add_theme_color_override("font_color", Color(0.9, 0.9, 0.88))
	bottom.add_child(_hp_l)
	_skill_l = Label.new()
	_skill_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skill_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_skill_l.add_theme_font_size_override("font_size", 12)
	_skill_l.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	bottom.add_child(_skill_l)

	var ui := Engine.get_main_loop().root.get_node_or_null("/root/UIStyle") if Engine.get_main_loop() else null
	if ui and ui.has_method("apply_font"):
		ui.apply_font(_name_l, 16)
		ui.apply_font(_phase_l, 13)
		ui.apply_font(_hp_l, 12)
		ui.apply_font(_skill_l, 12)


func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	if _boss == null or not is_instance_valid(_boss):
		visible = false
		return
	visible = true
	_name_l.text = str(_boss.display_name)
	_bar.max_value = float(_boss.hp_max)
	_bar.value = float(_boss.hp)
	_hp_l.text = "%d / %d" % [int(_boss.hp), int(_boss.hp_max)]
	if _boss.get("phase_label") != null:
		_phase_l.text = str(_boss.phase_label)
	if bool(_boss.is_dead):
		_skill_l.text = "처치됨"
		_bar.value = 0


func _on_phase(_pid: String, label: String) -> void:
	_phase_l.text = label


func _on_skill(_sid: String, sname: String) -> void:
	_skill_l.text = sname
