extends Node

## Shared UI colors/styles + embedded Korean font + PC/mobile display adapt.
## PC keeps project default expand layout; mobile/web-narrow uses letterbox KEEP.

const GOLD := Color(0.82, 0.68, 0.32)
const GOLD_BRIGHT := Color(1.0, 0.88, 0.45)
const PANEL_BG := Color(0.11, 0.13, 0.2, 0.94)
const PANEL_BG_SOFT := Color(0.14, 0.16, 0.24, 0.9)
const TEXT := Color(0.95, 0.93, 0.88)
const TEXT_DIM := Color(0.72, 0.7, 0.64)
const DANGER := Color(0.9, 0.35, 0.35)
const OK := Color(0.45, 0.85, 0.5)

const FONT_PATH := "res://assets/fonts/NotoSansKR-Variable.ttf"

var ui_font: Font = null
var app_theme: Theme = null
var _mobile_like: bool = false


func _ready() -> void:
	_setup_embedded_font_theme()
	_apply_display_adapt()
	var win := get_window()
	if win:
		win.size_changed.connect(_apply_display_adapt)
	# Root viewport size changes (browser resize / rotate)
	get_tree().root.size_changed.connect(_apply_display_adapt)


func _setup_embedded_font_theme() -> void:
	if ResourceLoader.exists(FONT_PATH):
		ui_font = load(FONT_PATH) as Font
	else:
		push_warning("UIStyle: missing embedded font %s" % FONT_PATH)
		return

	app_theme = Theme.new()
	app_theme.default_font = ui_font
	app_theme.default_font_size = 16

	# Common control types used across title/town/facility/combat
	for type_name in ["Label", "Button", "LineEdit", "OptionButton", "CheckBox", "AcceptDialog", "Window", "PopupMenu"]:
		app_theme.set_font("font", type_name, ui_font)
		app_theme.set_font_size("font_size", type_name, 16)

	app_theme.set_font("normal_font", "RichTextLabel", ui_font)
	app_theme.set_font("bold_font", "RichTextLabel", ui_font)
	app_theme.set_font("italics_font", "RichTextLabel", ui_font)
	app_theme.set_font("bold_italics_font", "RichTextLabel", ui_font)
	app_theme.set_font("mono_font", "RichTextLabel", ui_font)
	app_theme.set_font_size("normal_font_size", "RichTextLabel", 14)

	# Slightly larger default button padding for readability
	var btn_style := button_normal()
	app_theme.set_stylebox("normal", "Button", btn_style)
	app_theme.set_stylebox("hover", "Button", button_hover())
	app_theme.set_stylebox("pressed", "Button", button_pressed())
	app_theme.set_stylebox("disabled", "Button", button_disabled())

	get_tree().root.theme = app_theme


func apply_font(control: Control, size: int = -1) -> void:
	if ui_font == null or control == null:
		return
	if control is RichTextLabel:
		var rtl := control as RichTextLabel
		rtl.add_theme_font_override("normal_font", ui_font)
		rtl.add_theme_font_override("bold_font", ui_font)
		if size > 0:
			rtl.add_theme_font_size_override("normal_font_size", size)
	else:
		control.add_theme_font_override("font", ui_font)
		if size > 0:
			control.add_theme_font_size_override("font_size", size)


func is_mobile_like() -> bool:
	return _mobile_like


func _detect_mobile_like() -> bool:
	if OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios"):
		return true
	var win := get_window()
	if win == null:
		return false
	var sz := win.size
	if sz.x <= 0 or sz.y <= 0:
		return false
	# Phone / narrow browser: portrait or short width. Laptops with touch stay PC if wide.
	var portrait := sz.y > sz.x
	var narrow := sz.x < 900
	if OS.has_feature("web") and (portrait or narrow):
		return true
	if DisplayServer.is_touchscreen_available() and (portrait or sz.x < 700):
		return true
	return false


func _apply_display_adapt() -> void:
	var win := get_window()
	if win == null:
		return
	_mobile_like = _detect_mobile_like()

	# Design resolution stays 1280x720 for both; only scale aspect differs.
	win.content_scale_size = Vector2i(1280, 720)
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS

	if _mobile_like:
		# Letterbox — no stretch distortion; PC default expand unchanged.
		win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		if app_theme:
			app_theme.default_font_size = 17
			app_theme.set_font_size("font_size", "Button", 17)
			app_theme.set_font_size("font_size", "Label", 16)
	else:
		# Match project.godot stretch/aspect=expand for desktop / Steam landscape.
		win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		if app_theme:
			app_theme.default_font_size = 16
			app_theme.set_font_size("font_size", "Button", 16)
			app_theme.set_font_size("font_size", "Label", 16)


static func panel_style(active: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = PANEL_BG if not active else Color(0.18, 0.16, 0.1, 0.95)
	s.border_color = GOLD_BRIGHT if active else GOLD
	s.set_border_width_all(2)
	s.set_corner_radius_all(6)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 4
	return s


static func button_normal() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.2, 0.16, 0.1, 1)
	s.border_color = GOLD
	s.set_border_width_all(2)
	s.set_corner_radius_all(5)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


static func button_hover() -> StyleBoxFlat:
	var s := button_normal()
	s.bg_color = Color(0.32, 0.26, 0.14, 1)
	s.border_color = GOLD_BRIGHT
	return s


static func button_pressed() -> StyleBoxFlat:
	var s := button_normal()
	s.bg_color = Color(0.45, 0.34, 0.14, 1)
	s.border_color = GOLD_BRIGHT
	return s


static func button_disabled() -> StyleBoxFlat:
	var s := button_normal()
	s.bg_color = Color(0.12, 0.12, 0.14, 1)
	s.border_color = Color(0.35, 0.33, 0.3)
	return s


static func apply_button(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", button_normal())
	btn.add_theme_stylebox_override("hover", button_hover())
	btn.add_theme_stylebox_override("pressed", button_pressed())
	btn.add_theme_stylebox_override("disabled", button_disabled())
	btn.add_theme_color_override("font_color", TEXT)
	btn.add_theme_color_override("font_hover_color", GOLD_BRIGHT)
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 0.85))
	btn.add_theme_color_override("font_disabled_color", TEXT_DIM)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# Autoload instance applies embedded font when available
	var style_node := _ui_style_autoload()
	if style_node:
		style_node.apply_font(btn)
		if style_node.is_mobile_like():
			btn.custom_minimum_size.y = maxf(btn.custom_minimum_size.y, 44.0)


static func label(text: String, size: int = 16, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	var style_node := _ui_style_autoload()
	if style_node:
		style_node.apply_font(l, size)
	return l


static func _ui_style_autoload() -> Node:
	# Prefer Engine singleton; safe during static helpers after boot
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("/root/UIStyle")


static func make_panel(active: bool = false) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style(active))
	return p


static func job_name(job: String) -> String:
	match job:
		"lord":
			return "군주"
		"tank":
			return "탱커"
		"dps":
			return "딜러"
		"healer":
			return "힐러"
		"mage":
			return "마법사"
		_:
			return job


static func facility_name(id: String) -> String:
	match id:
		"guild":
			return "길드 본부"
		"inn":
			return "여관"
		"shop":
			return "상점"
		"blacksmith":
			return "대장간"
		"training":
			return "훈련장"
		"warehouse":
			return "창고"
		"infirmary":
			return "의무실"
		"quest":
			return "의뢰 게시판"
		"gate":
			return "사냥터 출구"
		_:
			return id
