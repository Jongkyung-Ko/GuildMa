class_name FloatingText
extends Node2D

## World-space floating combat number (drawn, not a Control).

var _text: String = ""
var _color: Color = Color.WHITE
var _life: float = 0.0
var _duration: float = 0.75
var _font_size: int = 16
var _vy: float = -48.0


func setup(text: String, color: Color, font_size: int = 16) -> void:
	_text = text
	_color = color
	_font_size = font_size
	z_index = 90
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_life += delta
	position.y += _vy * delta
	position.x += sin(_life * 10.0) * 8.0 * delta
	_vy = lerpf(_vy, -12.0, 2.0 * delta)
	queue_redraw()
	if _life >= _duration:
		queue_free()


func _draw() -> void:
	var alpha := 1.0
	if _life > _duration * 0.55:
		alpha = 1.0 - ((_life - _duration * 0.55) / (_duration * 0.45))
	var col := Color(_color.r, _color.g, _color.b, alpha)
	var outline := Color(0.05, 0.05, 0.08, alpha * 0.95)
	var font: Font = ThemeDB.fallback_font
	# Outline
	for ox in [-1, 0, 1]:
		for oy in [-1, 0, 1]:
			if ox == 0 and oy == 0:
				continue
			draw_string(font, Vector2(-10 + ox, oy), _text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, outline)
	draw_string(font, Vector2(-10, 0), _text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, col)
