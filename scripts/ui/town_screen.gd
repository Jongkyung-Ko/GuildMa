extends Control

const BUILDINGS := [
	{"id": "blacksmith", "tex": "res://assets/sprites/buildings/blacksmith.png", "pos": Vector2(180, 280), "label_off": Vector2(0, -28)},
	{"id": "shop", "tex": "res://assets/sprites/buildings/shop.png", "pos": Vector2(160, 420), "label_off": Vector2(0, -28)},
	{"id": "inn", "tex": "res://assets/sprites/buildings/inn.png", "pos": Vector2(220, 540), "label_off": Vector2(0, -28)},
	{"id": "guild", "tex": "res://assets/sprites/buildings/guild_hq.png", "pos": Vector2(560, 250), "label_off": Vector2(0, -32)},
	{"id": "training", "tex": "res://assets/sprites/buildings/training.png", "pos": Vector2(920, 280), "label_off": Vector2(0, -28)},
	{"id": "warehouse", "tex": "res://assets/sprites/buildings/warehouse.png", "pos": Vector2(960, 420), "label_off": Vector2(0, -28)},
	{"id": "quest", "tex": "res://assets/sprites/buildings/quest_board.png", "pos": Vector2(780, 470), "label_off": Vector2(0, -28)},
	{"id": "infirmary", "tex": "res://assets/sprites/buildings/infirmary.png", "pos": Vector2(720, 330), "label_off": Vector2(0, -28)},
	{"id": "gate", "tex": "res://assets/sprites/buildings/gate.png", "pos": Vector2(1040, 560), "label_off": Vector2(0, -28)},
]

var _toast: Label
var _hud_gold: Label
var _hud_rep: Label
var _hud_time: Label
var _hud_members: Label
var _hud_guild: Label


func _ready() -> void:
	_build_world()
	_build_hud()
	GameState.state_changed.connect(_refresh_hud)
	GameState.message_emitted.connect(_on_message)
	_refresh_hud()


func _build_world() -> void:
	var bg := TextureRect.new()
	bg.texture = load("res://assets/backgrounds/town_bg.png")
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	for b in BUILDINGS:
		_add_building(b)


func _add_building(b: Dictionary) -> void:
	var root := Control.new()
	root.position = b["pos"]
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var tex: Texture2D = load(b["tex"])
	var sprite := TextureRect.new()
	sprite.texture = tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.custom_minimum_size = tex.get_size()
	sprite.size = tex.get_size()
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sprite)
	root.custom_minimum_size = tex.get_size()
	root.size = tex.get_size()

	var label := UIStyle.label(UIStyle.facility_name(b["id"]), 14, UIStyle.GOLD_BRIGHT)
	label.position = b["label_off"] + Vector2(tex.get_width() * 0.5 - 40, 0)
	label.visible = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(label)

	var hover := ColorRect.new()
	hover.color = Color(1, 0.9, 0.4, 0.0)
	hover.size = tex.get_size()
	hover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hover)

	var btn := Button.new()
	btn.flat = true
	btn.size = tex.get_size()
	btn.modulate = Color(1, 1, 1, 0)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.tooltip_text = UIStyle.facility_name(b["id"])
	root.add_child(btn)

	btn.mouse_entered.connect(func():
		label.visible = true
		hover.color = Color(1, 0.85, 0.3, 0.18)
		sprite.modulate = Color(1.15, 1.1, 0.95)
	)
	btn.mouse_exited.connect(func():
		label.visible = false
		hover.color = Color(1, 0.9, 0.4, 0.0)
		sprite.modulate = Color(1, 1, 1)
	)
	btn.pressed.connect(func(): SceneRouter.go_facility(b["id"]))


func _build_hud() -> void:
	var top := UIStyle.make_panel()
	top.set_anchors_preset(PRESET_TOP_WIDE)
	top.offset_left = 12
	top.offset_right = -12
	top.offset_top = 8
	top.offset_bottom = 70
	add_child(top)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	top.add_child(row)

	_hud_guild = UIStyle.label("", 18, UIStyle.GOLD_BRIGHT)
	row.add_child(_hud_guild)
	_hud_rep = UIStyle.label("", 16, UIStyle.TEXT)
	row.add_child(_hud_rep)
	_hud_gold = UIStyle.label("", 16, UIStyle.GOLD_BRIGHT)
	row.add_child(_hud_gold)
	_hud_members = UIStyle.label("", 16, UIStyle.TEXT)
	row.add_child(_hud_members)
	_hud_time = UIStyle.label("", 16, UIStyle.TEXT)
	row.add_child(_hud_time)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var save_btn := Button.new()
	save_btn.text = "저장"
	UIStyle.apply_button(save_btn)
	save_btn.pressed.connect(func():
		GameState.save_game()
		GameState.emit_message("게임을 저장했습니다.")
	)
	row.add_child(save_btn)

	var settings_btn := Button.new()
	settings_btn.text = "설정"
	UIStyle.apply_button(settings_btn)
	settings_btn.pressed.connect(func(): SceneRouter.go_settings(false))
	row.add_child(settings_btn)

	var title_btn := Button.new()
	title_btn.text = "타이틀"
	UIStyle.apply_button(title_btn)
	title_btn.pressed.connect(func():
		GameState.save_game()
		GameState.is_playing = false
		SceneRouter.go_title()
	)
	row.add_child(title_btn)

	_toast = UIStyle.label("건물을 클릭해 시설로 이동하세요.", 15, UIStyle.TEXT)
	_toast.set_anchors_preset(PRESET_BOTTOM_WIDE)
	_toast.offset_left = 20
	_toast.offset_right = -20
	_toast.offset_top = -48
	_toast.offset_bottom = -16
	add_child(_toast)


func _refresh_hud() -> void:
	_hud_guild.text = "길드: %s  Lv.%d" % [GameState.guild_name, GameState.guild_level]
	_hud_rep.text = "명성 %d" % GameState.reputation
	_hud_gold.text = "골드 %s G" % _format_num(GameState.gold)
	_hud_members.text = "길드원 %s" % GameState.member_count_text()
	_hud_time.text = GameState.time_text()


func _on_message(text: String, is_error: bool) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", UIStyle.DANGER if is_error else UIStyle.OK)


func _format_num(n: int) -> String:
	var s := str(n)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c == 3 and i != 0:
			out = "," + out
			c = 0
	return out
