extends Control

var _toast: Label


func _ready() -> void:
	_build()
	GameState.message_emitted.connect(_on_message)


func _build() -> void:
	var bg := TextureRect.new()
	bg.texture = load("res://assets/backgrounds/title_bg.png")
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(bg)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_preset(PRESET_FULL_RECT)
	add_child(dim)

	var center := VBoxContainer.new()
	center.set_anchors_preset(PRESET_CENTER)
	center.position = Vector2(440, 120)
	center.custom_minimum_size = Vector2(400, 480)
	center.add_theme_constant_override("separation", 14)
	add_child(center)

	var brand := UIStyle.label("GuildMaster", 56, UIStyle.GOLD_BRIGHT)
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(brand)

	var sub := UIStyle.label("길드마스터 — 마을 허브", 20, UIStyle.TEXT_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(sub)

	center.add_child(Control.new()) # spacer

	var panel := UIStyle.make_panel()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	box.add_child(_menu_btn("새 게임", _on_new_game))
	var cont := _menu_btn("이어하기", _on_continue)
	cont.disabled = not GameState.has_save
	box.add_child(cont)
	box.add_child(_menu_btn("설정", func(): SceneRouter.go_settings(true)))
	box.add_child(_menu_btn("게임 종료", func(): get_tree().quit()))

	_toast = UIStyle.label("", 14, UIStyle.TEXT)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center.add_child(_toast)


func _menu_btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	UIStyle.apply_button(b)
	b.pressed.connect(cb)
	return b


func _on_new_game() -> void:
	GameState.new_game()
	SceneRouter.go_town()


func _on_continue() -> void:
	if GameState.load_game():
		SceneRouter.go_town()
	else:
		_toast.text = "저장 데이터가 없습니다."
		_toast.add_theme_color_override("font_color", UIStyle.DANGER)


func _on_message(text: String, is_error: bool) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", UIStyle.DANGER if is_error else UIStyle.OK)
