extends CanvasLayer

## Phase 2-1 combat HUD: status, party/enemy HP, log, pause / return.
## No tactics buttons, no WASD pad.

var _manager: Node = null
var _status: Label
var _party_box: VBoxContainer
var _enemy_box: VBoxContainer
var _log: Label
var _pause_btn: Button
var _town_btn: Button
var _auto_label: Label


func setup(manager: Node) -> void:
	_manager = manager
	_build()
	refresh()


func _build() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 12
	top.offset_right = -12
	top.offset_top = 8
	top.offset_bottom = 64
	top.add_theme_stylebox_override("panel", UIStyle.panel_style())
	root.add_child(top)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 16)
	top.add_child(top_row)

	_status = UIStyle.label("전투 중", 20, UIStyle.GOLD_BRIGHT)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(_status)

	_auto_label = UIStyle.label("자동전투", 16, UIStyle.OK)
	top_row.add_child(_auto_label)

	_pause_btn = Button.new()
	_pause_btn.text = "일시정지 (Esc)"
	UIStyle.apply_button(_pause_btn)
	_pause_btn.pressed.connect(_on_pause)
	top_row.add_child(_pause_btn)

	_town_btn = Button.new()
	_town_btn.text = "마을로"
	UIStyle.apply_button(_town_btn)
	_town_btn.pressed.connect(_on_town)
	top_row.add_child(_town_btn)

	var right := PanelContainer.new()
	right.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	right.offset_left = -260
	right.offset_right = -12
	right.offset_top = 76
	right.offset_bottom = -140
	right.add_theme_stylebox_override("panel", UIStyle.panel_style())
	root.add_child(right)

	var right_col := VBoxContainer.new()
	right_col.add_theme_constant_override("separation", 8)
	right.add_child(right_col)
	right_col.add_child(UIStyle.label("파티", 16, UIStyle.GOLD_BRIGHT))
	_party_box = VBoxContainer.new()
	_party_box.add_theme_constant_override("separation", 4)
	right_col.add_child(_party_box)
	right_col.add_child(UIStyle.label("적", 16, UIStyle.DANGER))
	_enemy_box = VBoxContainer.new()
	_enemy_box.add_theme_constant_override("separation", 4)
	right_col.add_child(_enemy_box)

	var bottom := PanelContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 12
	bottom.offset_right = -280
	bottom.offset_top = -128
	bottom.offset_bottom = -12
	bottom.add_theme_stylebox_override("panel", UIStyle.panel_style())
	root.add_child(bottom)
	_log = UIStyle.label("", 13, UIStyle.TEXT_DIM)
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom.add_child(_log)


func refresh() -> void:
	if _manager == null:
		return
	var pname: String = _manager.get_phase_name()
	match pname:
		"fighting":
			_status.text = "전투 중 — Phase 2-1"
			_status.add_theme_color_override("font_color", UIStyle.GOLD_BRIGHT)
			_pause_btn.disabled = false
			_pause_btn.text = "일시정지 (Esc)"
		"paused":
			_status.text = "일시정지"
			_status.add_theme_color_override("font_color", UIStyle.TEXT)
			_pause_btn.disabled = false
			_pause_btn.text = "재개 (Esc)"
		"victory":
			_status.text = "승리! (보상은 후속 Phase)"
			_status.add_theme_color_override("font_color", UIStyle.OK)
			_pause_btn.disabled = true
		"defeat":
			_status.text = "패배 (보상은 후속 Phase)"
			_status.add_theme_color_override("font_color", UIStyle.DANGER)
			_pause_btn.disabled = true

	_fill_list(_party_box, _manager.get_allies(), true)
	_fill_list(_enemy_box, _manager.get_enemies(), false)
	_log.text = _manager.get_log_text()


func _fill_list(box: VBoxContainer, units: Array, is_ally: bool) -> void:
	while box.get_child_count() > 0:
		var c := box.get_child(0)
		box.remove_child(c)
		c.queue_free()
	for u in units:
		if u == null or not is_instance_valid(u):
			continue
		var dead: bool = bool(u.is_dead)
		var dname: String = str(u.display_name)
		var row := HBoxContainer.new()
		var name_l := UIStyle.label(dname, 13, UIStyle.TEXT if not dead else UIStyle.TEXT_DIM)
		name_l.custom_minimum_size.x = 72
		row.add_child(name_l)
		var bar := ProgressBar.new()
		bar.min_value = 0
		bar.max_value = float(u.hp_max)
		bar.value = float(u.hp)
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(100, 14)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(bar)
		var hp_l := UIStyle.label("%d/%d" % [int(u.hp), int(u.hp_max)], 12, UIStyle.TEXT_DIM)
		row.add_child(hp_l)
		if not is_ally and dead:
			name_l.text = dname + " (처치)"
		elif is_ally and dead:
			name_l.text = dname + " (불능)"
		box.add_child(row)


func _on_pause() -> void:
	if _manager:
		_manager.toggle_pause()
		refresh()


func _on_town() -> void:
	if _manager:
		_manager.return_to_town()
