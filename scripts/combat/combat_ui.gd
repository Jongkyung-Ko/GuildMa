extends CanvasLayer

## Combat HUD: status, party/enemy HP, log, pause / return.
## Hunting: small maze minimap (top-left) + expanded modal.
## Dungeon: compact vertical floor minimap (top-left) — no maze travel.

const HUNT_MINIMAP := preload("res://scripts/exploration/hunt_minimap.gd")
const HUNT_MODAL := preload("res://scripts/exploration/hunt_map_modal.gd")
const HUNT_DIR_PAD := preload("res://scripts/exploration/hunt_direction_pad.gd")
const DUNGEON_MINIMAP := preload("res://scripts/dungeon/dungeon_minimap.gd")

var _manager: Node = null
var _root: Control
var _status: Label
var _party_box: VBoxContainer
var _enemy_box: VBoxContainer
var _log: RichTextLabel
var _pause_btn: Button
var _town_btn: Button
var _auto_label: Label
var _hunt_mini: Control = null
var _dungeon_mini: Control = null
var _modal: CanvasLayer = null
var _dir_pad: Control = null


func setup(manager: Node) -> void:
	_manager = manager
	_build()
	refresh()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.anchor_left = 0.0
	top.anchor_right = 1.0
	top.offset_left = 12
	top.offset_right = -12
	top.offset_top = 8
	top.offset_bottom = 64
	top.add_theme_stylebox_override("panel", UIStyle.panel_style())
	_root.add_child(top)

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
	_town_btn.text = "던전으로" if (_manager and _manager.has_method("is_dungeon_combat") and _manager.is_dungeon_combat()) else "마을로"
	UIStyle.apply_button(_town_btn)
	_town_btn.pressed.connect(_on_town)
	top_row.add_child(_town_btn)

	# Right status panel
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
	_root.add_child(right)

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

	# Bottom log
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
	_root.add_child(bottom)

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

	_attach_minimap()


func _attach_minimap() -> void:
	var mobile := UIStyle.is_mobile_like() if UIStyle else false
	var mini_size := Vector2(112, 112) if mobile else Vector2(132, 132)
	if _manager and _manager.has_method("is_dungeon_combat") and _manager.is_dungeon_combat():
		_dungeon_mini = DUNGEON_MINIMAP.new()
		_dungeon_mini.position = Vector2(14, 72)
		_dungeon_mini.size = Vector2(120 if mobile else 132, 200 if mobile else 220)
		_dungeon_mini.custom_minimum_size = _dungeon_mini.size
		_dungeon_mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(_dungeon_mini)
		_dungeon_mini.setup(str(_manager.dungeon_id))
	elif _manager and _manager.has_method("is_hunt_combat") and _manager.is_hunt_combat():
		_hunt_mini = HUNT_MINIMAP.new()
		_hunt_mini.position = Vector2(14, 72)
		_hunt_mini.size = mini_size
		_hunt_mini.custom_minimum_size = mini_size
		_root.add_child(_hunt_mini)
		_hunt_mini.open_requested.connect(_open_hunt_modal)
		_hunt_mini.refresh()
		_dir_pad = HUNT_DIR_PAD.new()
		_root.add_child(_dir_pad)
		_dir_pad.travel_dir.connect(_on_dir_travel)


func _open_hunt_modal() -> void:
	if _modal != null and is_instance_valid(_modal):
		return
	_modal = HUNT_MODAL.new()
	add_child(_modal)
	var fighting := _manager != null and str(_manager.get_phase_name()) == "fighting"
	_modal.setup(fighting)
	_modal.closed.connect(func():
		_modal = null
		if _hunt_mini:
			_hunt_mini.refresh()
		refresh()
	)
	_modal.travel_requested.connect(func(rid: String):
		if _manager and _manager.has_method("travel_hunt_room"):
			_manager.travel_hunt_room(rid)
		if _modal and is_instance_valid(_modal):
			_modal.queue_free()
			_modal = null
		if _hunt_mini:
			_hunt_mini.refresh()
		refresh()
	)


func refresh() -> void:
	if _manager == null:
		return
	var pname: String = _manager.get_phase_name()
	match pname:
		"fighting":
			if _manager.has_method("is_dungeon_combat") and _manager.is_dungeon_combat():
				_status.text = "던전 전투 — %d층" % int(_manager.dungeon_floor)
			elif _manager.has_method("is_hunt_combat") and _manager.is_hunt_combat():
				var room: Dictionary = GameState.get_current_hunt_room()
				_status.text = "사냥 — %s" % str(room.get("name", "탐험"))
			else:
				_status.text = "전투 중 — Phase 2-2"
			_status.add_theme_color_override("font_color", UIStyle.GOLD_BRIGHT)
			_pause_btn.disabled = false
			_pause_btn.text = "일시정지 (Esc)"
		"paused":
			_status.text = "일시정지"
			_status.add_theme_color_override("font_color", UIStyle.TEXT)
			_pause_btn.disabled = false
			_pause_btn.text = "재개 (Esc)"
		"victory":
			if _manager.has_method("is_dungeon_combat") and _manager.is_dungeon_combat():
				_status.text = "승리! — 층 클리어"
			elif _manager.has_method("is_hunt_combat") and _manager.is_hunt_combat():
				_status.text = "승리! — 방 클리어 (화살표로 이동)"
			else:
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
	if _hunt_mini and _hunt_mini.has_method("refresh"):
		_hunt_mini.refresh()
	if _dungeon_mini and _dungeon_mini.has_method("refresh"):
		_dungeon_mini.refresh()
	if _modal != null and is_instance_valid(_modal) and _modal.has_method("set_combat_active"):
		_modal.set_combat_active(pname == "fighting")
	_refresh_dir_pad(pname)


func _refresh_dir_pad(pname: String) -> void:
	if _dir_pad == null or not is_instance_valid(_dir_pad):
		return
	# Hunt victory / cleared-room idle only — never during fight or dungeon.
	var hunt: bool = _manager != null and _manager.has_method("is_hunt_combat") and bool(_manager.is_hunt_combat())
	var show: bool = hunt and pname == "victory"
	if _dir_pad.has_method("refresh"):
		_dir_pad.refresh(show)


func _on_dir_travel(dir: String) -> void:
	if _manager and _manager.has_method("travel_hunt_direction"):
		_manager.travel_hunt_direction(dir)
	refresh()


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
