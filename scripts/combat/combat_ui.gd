extends CanvasLayer

## Phase 2-1 combat HUD: status, party/enemy HP, log, pause / return.
## No tactics buttons, no WASD pad.

var _manager: Node = null
var _status: Label
var _party_box: VBoxContainer
var _enemy_box: VBoxContainer
var _log: RichTextLabel
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
	top.anchor_left = 0.0
	top.anchor_right = 1.0
	top.offset_left = 12
	top.offset_right = -12
	top.offset_top = 8
	top.offset_bottom = 64
	top.add_theme_stylebox_override("panel", UIStyle.panel_style())
	root.add_child(top)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 12)
	top.add_child(top_row)

	_status = UIStyle.label("전투 중", 18, UIStyle.GOLD_BRIGHT)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.clip_text = true
	top_row.add_child(_status)

	_auto_label = UIStyle.label("자동전투", 15, UIStyle.OK)
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

	# Right status panel — fixed width, stays on-screen at 1280x720
	var right := PanelContainer.new()
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.anchor_top = 0.0
	right.anchor_bottom = 1.0
	right.offset_left = -268
	right.offset_right = -10
	right.offset_top = 72
	right.offset_bottom = -118
	right.add_theme_stylebox_override("panel", UIStyle.panel_style())
	root.add_child(right)

	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(right_scroll)

	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.add_theme_constant_override("separation", 6)
	right_scroll.add_child(right_col)
	right_col.add_child(UIStyle.label("파티", 15, UIStyle.GOLD_BRIGHT))
	_party_box = VBoxContainer.new()
	_party_box.add_theme_constant_override("separation", 4)
	_party_box.custom_minimum_size.x = 220
	right_col.add_child(_party_box)
	right_col.add_child(UIStyle.label("적", 15, UIStyle.DANGER))
	_enemy_box = VBoxContainer.new()
	_enemy_box.add_theme_constant_override("separation", 4)
	_enemy_box.custom_minimum_size.x = 220
	right_col.add_child(_enemy_box)

	# Bottom log — keep fully above window bottom
	var bottom := PanelContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.anchor_left = 0.0
	bottom.anchor_right = 1.0
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_left = 12
	bottom.offset_right = -278
	bottom.offset_top = -110
	bottom.offset_bottom = -10
	bottom.add_theme_stylebox_override("panel", UIStyle.panel_style())
	root.add_child(bottom)

	_log = RichTextLabel.new()
	_log.fit_content = false
	_log.scroll_active = true
	_log.scroll_following = true
	_log.bbcode_enabled = false
	_log.custom_minimum_size = Vector2(0, 70)
	_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.add_theme_font_size_override("normal_font_size", 13)
	_log.add_theme_color_override("default_color", UIStyle.TEXT_DIM)
	UIStyle.apply_font(_log, 13)
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
	if _log:
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
		if not is_ally and dead:
			dname += " (처치)"
		elif is_ally and dead:
			dname += " (불능)"

		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 1)
		var name_l := UIStyle.label(dname, 12, UIStyle.TEXT if not dead else UIStyle.TEXT_DIM)
		name_l.clip_text = true
		col.add_child(name_l)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var bar := ProgressBar.new()
		bar.min_value = 0
		bar.max_value = float(u.hp_max)
		bar.value = float(u.hp)
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(120, 12)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(bar)
		var hp_l := UIStyle.label("%d/%d" % [int(u.hp), int(u.hp_max)], 11, UIStyle.TEXT_DIM)
		hp_l.custom_minimum_size.x = 64
		row.add_child(hp_l)
		col.add_child(row)
		box.add_child(col)


func _on_pause() -> void:
	if _manager:
		_manager.toggle_pause()
		refresh()


func _on_town() -> void:
	if _manager:
		_manager.return_to_town()
