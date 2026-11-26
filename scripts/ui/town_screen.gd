extends Control

## Town hub: premium environment art + facility hotspots.
## Building sprites are used as hover markers; the painted town_bg carries the world detail.

const BUILDINGS := [
	{"id": "blacksmith", "tex": "res://assets/sprites/buildings/blacksmith.png", "pos": Vector2(150, 210), "hit": Vector2(120, 130)},
	{"id": "shop", "tex": "res://assets/sprites/buildings/shop.png", "pos": Vector2(110, 400), "hit": Vector2(120, 120)},
	{"id": "inn", "tex": "res://assets/sprites/buildings/inn.png", "pos": Vector2(200, 520), "hit": Vector2(120, 120)},
	{"id": "guild", "tex": "res://assets/sprites/buildings/guild_hq.png", "pos": Vector2(520, 150), "hit": Vector2(170, 170)},
	{"id": "training", "tex": "res://assets/sprites/buildings/training.png", "pos": Vector2(900, 170), "hit": Vector2(140, 130)},
	{"id": "warehouse", "tex": "res://assets/sprites/buildings/warehouse.png", "pos": Vector2(980, 380), "hit": Vector2(130, 130)},
	{"id": "quest", "tex": "res://assets/sprites/buildings/quest_board.png", "pos": Vector2(700, 430), "hit": Vector2(110, 110)},
	{"id": "infirmary", "tex": "res://assets/sprites/buildings/infirmary.png", "pos": Vector2(740, 280), "hit": Vector2(120, 120)},
	{"id": "gate", "tex": "res://assets/sprites/buildings/gate.png", "pos": Vector2(1020, 520), "hit": Vector2(150, 140)},
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
	var hit: Vector2 = b.get("hit", Vector2(120, 120))
	var root := Control.new()
	root.position = b["pos"]
	root.custom_minimum_size = hit
	root.size = hit
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	# Soft ground plate so clickable facilities remain readable on busy art.
	var plate := ColorRect.new()
	plate.color = Color(0.05, 0.07, 0.12, 0.0)
	plate.size = hit
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(plate)

	var tex: Texture2D = load(b["tex"])
	var sprite := TextureRect.new()
	sprite.texture = tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.size = hit
	# Start mostly transparent — town_bg already paints architecture; sprite appears on hover.
	sprite.modulate = Color(1, 1, 1, 0.15)
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sprite)

	var label := UIStyle.label(UIStyle.facility_name(b["id"]), 14, UIStyle.GOLD_BRIGHT)
	label.position = Vector2(8, -22)
	label.visible = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(label)

	var btn := Button.new()
	btn.flat = true
	btn.size = hit
	btn.modulate = Color(1, 1, 1, 0)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.tooltip_text = UIStyle.facility_name(b["id"])
	root.add_child(btn)

	btn.mouse_entered.connect(func():
		label.visible = true
		plate.color = Color(0.95, 0.82, 0.35, 0.18)
		sprite.modulate = Color(1.1, 1.05, 0.95, 0.92)
	)
	btn.mouse_exited.connect(func():
		label.visible = false
		plate.color = Color(0.05, 0.07, 0.12, 0.0)
		sprite.modulate = Color(1, 1, 1, 0.15)
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
	_toast.offset_top = -40
	_toast.offset_bottom = -12
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
