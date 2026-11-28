extends Node

## Shared UI colors/styles + embedded Korean font + PC/mobile display adapt.
## Landscape-only game. Design size stays 1280×720 (town hotspots / facility shell
## assume that width). Aspect EXPAND fills landscape windows without letterboxing;
## portrait is out of scope (no dedicated portrait layout).
## Fonts are static OTFs shipped in the project (no OS / variable-font reliance).

const GOLD := Color(0.82, 0.68, 0.32)
const GOLD_BRIGHT := Color(1.0, 0.88, 0.45)
const PANEL_BG := Color(0.11, 0.13, 0.2, 0.94)
const PANEL_BG_SOFT := Color(0.14, 0.16, 0.24, 0.9)
const TEXT := Color(0.95, 0.93, 0.88)
const TEXT_DIM := Color(0.72, 0.7, 0.64)
const DANGER := Color(0.9, 0.35, 0.35)
const OK := Color(0.45, 0.85, 0.5)

const FONT_REGULAR_PATH := "res://assets/fonts/NotoSansKR-Regular.otf"
const FONT_BOLD_PATH := "res://assets/fonts/NotoSansKR-Bold.otf"

## Sample used to force glyph rasterization for Hangul + UI ASCII on web.
const FONT_WARMUP := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789" \
	+ "가나다라마바사아자차카타파하한글길드마스터상점대장간여관훈련창고의무의뢰사냥전투" \
	+ "공격방어체력경험치골드명성파티적새게임이어하기설정마을시설구매장착강화부상출정" \
	+ "미니맵현재위치이동가능클리어한방보스방연결된출구출현몬스터이동하기북쪽남쪽동쪽서쪽" \
	+ "전투중에는이동할수없습니다화살표탐험승리패배자동" \
	+ "세계지도출발마을성채프로스트하임엘더우드어비스칼아이스크라운엘드리아" \
	+ "—·/()[]{}.,!?:+-%"

var ui_font: Font = null
var ui_font_bold: Font = null
var app_theme: Theme = null
var _mobile_like: bool = false


func _ready() -> void:
	_setup_embedded_font_theme()
	_apply_display_adapt()
	var win := get_window()
	if win and not win.size_changed.is_connected(_apply_display_adapt):
		win.size_changed.connect(_apply_display_adapt)
	var root_vp := get_tree().root
	if root_vp and not root_vp.size_changed.is_connected(_apply_display_adapt):
		root_vp.size_changed.connect(_apply_display_adapt)


func _setup_embedded_font_theme() -> void:
	if ResourceLoader.exists(FONT_REGULAR_PATH):
		ui_font = load(FONT_REGULAR_PATH) as Font
	else:
		push_warning("UIStyle: missing embedded font %s" % FONT_REGULAR_PATH)
		return

	if ResourceLoader.exists(FONT_BOLD_PATH):
		ui_font_bold = load(FONT_BOLD_PATH) as Font
	else:
		ui_font_bold = ui_font

	_warm_font_cache()

	app_theme = Theme.new()
	app_theme.default_font = ui_font
	app_theme.default_font_size = 16

	for type_name in [
		"Label", "Button", "LineEdit", "OptionButton", "CheckBox",
		"AcceptDialog", "Window", "PopupMenu", "ItemList", "Tree",
		"TextEdit", "CodeEdit", "TooltipLabel"
	]:
		app_theme.set_font("font", type_name, ui_font)
		app_theme.set_font_size("font_size", type_name, 16)

	# Buttons prefer bold for readability
	app_theme.set_font("font", "Button", ui_font_bold)
	app_theme.set_font_size("font_size", "Button", 16)

	app_theme.set_font("normal_font", "RichTextLabel", ui_font)
	app_theme.set_font("bold_font", "RichTextLabel", ui_font_bold)
	app_theme.set_font("italics_font", "RichTextLabel", ui_font)
	app_theme.set_font("bold_italics_font", "RichTextLabel", ui_font_bold)
	app_theme.set_font("mono_font", "RichTextLabel", ui_font)
	app_theme.set_font_size("normal_font_size", "RichTextLabel", 14)
	app_theme.set_font_size("bold_font_size", "RichTextLabel", 14)

	app_theme.set_stylebox("normal", "Button", button_normal())
	app_theme.set_stylebox("hover", "Button", button_hover())
	app_theme.set_stylebox("pressed", "Button", button_pressed())
	app_theme.set_stylebox("disabled", "Button", button_disabled())

	# Apply as early as possible so every subsequent Control inherits Korean glyphs.
	get_tree().root.theme = app_theme


func _warm_font_cache() -> void:
	if ui_font == null:
		return
	for size in [11, 13, 14, 15, 16, 17, 18, 20, 22, 28, 56]:
		ui_font.get_string_size(FONT_WARMUP, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
		if ui_font_bold != null and ui_font_bold != ui_font:
			ui_font_bold.get_string_size(FONT_WARMUP, HORIZONTAL_ALIGNMENT_LEFT, -1, size)


func apply_font(control: Control, size: int = -1) -> void:
	if ui_font == null or control == null:
		return
	if control is RichTextLabel:
		var rtl := control as RichTextLabel
		rtl.add_theme_font_override("normal_font", ui_font)
		rtl.add_theme_font_override("bold_font", ui_font_bold if ui_font_bold else ui_font)
		if size > 0:
			rtl.add_theme_font_size_override("normal_font_size", size)
			rtl.add_theme_font_size_override("bold_font_size", size)
	elif control is Button:
		control.add_theme_font_override("font", ui_font_bold if ui_font_bold else ui_font)
		if size > 0:
			control.add_theme_font_size_override("font_size", size)
	else:
		control.add_theme_font_override("font", ui_font)
		if size > 0:
			control.add_theme_font_size_override("font_size", size)


func is_mobile_like() -> bool:
	return _mobile_like


func draw_font() -> Font:
	## Prefer embedded Noto Sans KR for CanvasItem.draw_string (maps / custom draw).
	if ui_font != null:
		return ui_font
	return ThemeDB.fallback_font


func _detect_mobile_like() -> bool:
	if OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios"):
		return true
	var win := get_window()
	if win == null:
		return false
	var sz := win.size
	if sz.x <= 0 or sz.y <= 0:
		return false
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

	# Keep 1280×720 design size globally — absolute town/facility layouts depend on it.
	# EXPAND: landscape phones (e.g. 844×390) fill the screen without side letterboxing.
	win.content_scale_size = Vector2i(1280, 720)
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	if _mobile_like:
		if app_theme:
			app_theme.default_font_size = 18
			app_theme.set_font_size("font_size", "Button", 18)
			app_theme.set_font_size("font_size", "Label", 17)
			app_theme.set_font_size("normal_font_size", "RichTextLabel", 15)
	else:
		if app_theme:
			app_theme.default_font_size = 16
			app_theme.set_font_size("font_size", "Button", 16)
			app_theme.set_font_size("font_size", "Label", 16)
			app_theme.set_font_size("normal_font_size", "RichTextLabel", 14)


static func panel_style(active: bool = false) -> StyleBoxFlat:
	# Painted collage crops are unreliable as 9-slice sources; keep coherent flat panels.
	var s := StyleBoxFlat.new()
	s.bg_color = PANEL_BG if not active else Color(0.18, 0.16, 0.1, 0.95)
	s.border_color = GOLD_BRIGHT if active else GOLD
	s.set_border_width_all(2)
	s.set_corner_radius_all(6)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 6
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
	var style_node := _ui_style_autoload()
	if style_node:
		style_node.apply_font(btn)
		if style_node.is_mobile_like():
			btn.custom_minimum_size.y = maxf(btn.custom_minimum_size.y, 48.0)
	# UI click SFX once per button (audio wiring only — no layout change).
	if not btn.has_meta("_gm_click_sfx"):
		btn.set_meta("_gm_click_sfx", true)
		btn.pressed.connect(_play_ui_click_sfx)


static func _play_ui_click_sfx() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var audio := tree.root.get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_ui_click"):
		audio.play_ui_click()


static func label(text: String, size: int = 16, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	var style_node := _ui_style_autoload()
	if style_node:
		# On mobile, bump small HUD labels a bit without changing PC sizes.
		var final_size := size
		if style_node.is_mobile_like() and size <= 16:
			final_size = size + 1
		style_node.apply_font(l, final_size)
	return l


static func _ui_style_autoload() -> Node:
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


static func apply_cover_texture(tex_rect: TextureRect, tex: Texture2D = null) -> void:
	## Aspect-safe cover fill. Godot centers KEEP_ASPECT_COVERED — no bottom-only crop.
	if tex_rect == null:
		return
	if tex != null:
		tex_rect.texture = tex
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


static func fit_texture_cover_centered(
	tex_rect: TextureRect,
	area: Vector2,
	aspect: float = 0.0,
	zoom: float = 1.0
) -> void:
	## Manual cover with true center alignment (X and Y). Prefer over bottom-pin.
	if tex_rect == null or area.x < 8.0 or area.y < 8.0:
		return
	var a := aspect
	if a <= 0.0:
		var t := tex_rect.texture
		if t != null and t.get_height() > 0:
			a = float(t.get_width()) / float(t.get_height())
		else:
			a = 16.0 / 9.0
	var z := maxf(0.01, zoom)
	var w := area.x * z
	var h := w / a
	if h < area.y * z:
		h = area.y * z
		w = h * a
	tex_rect.anchor_left = 0.0
	tex_rect.anchor_top = 0.0
	tex_rect.anchor_right = 0.0
	tex_rect.anchor_bottom = 0.0
	tex_rect.position = Vector2((area.x - w) * 0.5, (area.y - h) * 0.5)
	tex_rect.size = Vector2(w, h)
