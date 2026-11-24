extends Control

var _from_title: bool = true
var _window_option: OptionButton
var _volume: HSlider
var _info: Label


func _ready() -> void:
	_from_title = bool(get_tree().root.get_meta("settings_from_title", true))
	_build()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.14)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	var panel := UIStyle.make_panel()
	panel.set_anchors_preset(PRESET_CENTER)
	panel.position = Vector2(340, 80)
	panel.custom_minimum_size = Vector2(600, 520)
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	box.add_child(UIStyle.label("설정", 28, UIStyle.GOLD_BRIGHT))

	box.add_child(UIStyle.label("화면 모드", 16, UIStyle.TEXT_DIM))
	_window_option = OptionButton.new()
	_window_option.add_item("창 모드", 0)
	_window_option.add_item("전체 화면", 1)
	_window_option.selected = 1 if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else 0
	_window_option.item_selected.connect(_on_window_mode)
	box.add_child(_window_option)

	box.add_child(UIStyle.label("마스터 볼륨 (UI 미리보기)", 16, UIStyle.TEXT_DIM))
	_volume = HSlider.new()
	_volume.min_value = 0
	_volume.max_value = 100
	_volume.value = 80
	_volume.value_changed.connect(func(v): _info.text = "볼륨: %d%% (사운드 에셋 추가 시 적용)" % int(v))
	box.add_child(_volume)

	box.add_child(UIStyle.label("조작 안내", 16, UIStyle.TEXT_DIM))
	var help := UIStyle.label("마우스: 건물/버튼 클릭, 호버로 강조\nEsc / 취소: 일부 화면에서 뒤로 가기\n키보드: UI 포커스 이동 가능", 15, UIStyle.TEXT)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(help)

	_info = UIStyle.label("실제로 동작하는 설정만 표시합니다.", 14, UIStyle.OK)
	box.add_child(_info)

	var back := Button.new()
	back.text = "뒤로 가기"
	UIStyle.apply_button(back)
	back.pressed.connect(_on_back)
	box.add_child(back)


func _on_window_mode(idx: int) -> void:
	if idx == 1:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_info.text = "전체 화면으로 변경했습니다."
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1280, 720))
		_info.text = "창 모드로 변경했습니다."


func _on_back() -> void:
	if _from_title:
		SceneRouter.go_title()
	else:
		SceneRouter.go_town()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
