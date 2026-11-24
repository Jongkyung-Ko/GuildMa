extends Node

const GOLD := Color(0.82, 0.68, 0.32)
const GOLD_BRIGHT := Color(1.0, 0.88, 0.45)
const PANEL_BG := Color(0.11, 0.13, 0.2, 0.94)
const PANEL_BG_SOFT := Color(0.14, 0.16, 0.24, 0.9)
const TEXT := Color(0.95, 0.93, 0.88)
const TEXT_DIM := Color(0.72, 0.7, 0.64)
const DANGER := Color(0.9, 0.35, 0.35)
const OK := Color(0.45, 0.85, 0.5)


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


static func label(text: String, size: int = 16, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


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
