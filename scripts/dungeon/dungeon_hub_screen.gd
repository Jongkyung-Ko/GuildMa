extends Control

## Dungeon lobby: floor info, vertical minimap, enter / next / prev / town.
## Hunting-ground N/S/E/W exploration is intentionally separate and untouched.

const MINIMAP_SCRIPT := preload("res://scripts/dungeon/dungeon_minimap.gd")

var dungeon_id: String = "shadow_crypt"
var _name_l: Label
var _floor_l: Label
var _status_l: Label
var _diff_l: Label
var _blurb_l: Label
var _toast: Label
var _enter_btn: Button
var _next_btn: Button
var _prev_btn: Button
var _minimap: Control


func _ready() -> void:
	dungeon_id = str(get_tree().root.get_meta("dungeon_id", "shadow_crypt"))
	if GameState.get_dungeon_def(dungeon_id).is_empty():
		dungeon_id = "shadow_crypt"
	GameState.ensure_dungeon_progress(dungeon_id)
	GameState.dungeon_set_floor(dungeon_id, GameState.dungeon_current_floor(dungeon_id))
	_build()
	_refresh()
	if AudioManager:
		AudioManager.on_enter_facility()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.055, 0.08, 1)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	# Soft vignette atmosphere (no layout cards in hero sense — functional panels)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.04, 0.35)
	dim.set_anchors_preset(PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_minimap = MINIMAP_SCRIPT.new()
	_minimap.position = Vector2(16, 16)
	_minimap.size = Vector2(140, 240)
	_minimap.custom_minimum_size = Vector2(140, 240)
	add_child(_minimap)
	_minimap.setup(dungeon_id)

	var panel := UIStyle.make_panel()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -300
	panel.offset_right = 300
	panel.offset_top = -220
	panel.offset_bottom = 220
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	_name_l = UIStyle.label("던전", 26, UIStyle.GOLD_BRIGHT)
	box.add_child(_name_l)
	_floor_l = UIStyle.label("1층", 20, UIStyle.GOLD)
	box.add_child(_floor_l)
	_status_l = UIStyle.label("상태", 15, UIStyle.TEXT)
	box.add_child(_status_l)
	_diff_l = UIStyle.label("난이도", 15, UIStyle.TEXT_DIM)
	box.add_child(_diff_l)
	_blurb_l = UIStyle.label("", 13, UIStyle.TEXT_DIM)
	_blurb_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_blurb_l.custom_minimum_size = Vector2(500, 0)
	box.add_child(_blurb_l)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)

	_prev_btn = Button.new()
	_prev_btn.text = "이전 층"
	UIStyle.apply_button(_prev_btn)
	_prev_btn.pressed.connect(_on_prev)
	row.add_child(_prev_btn)

	_enter_btn = Button.new()
	_enter_btn.text = "이 층 전투"
	_enter_btn.custom_minimum_size = Vector2(140, 0)
	UIStyle.apply_button(_enter_btn)
	_enter_btn.pressed.connect(_on_enter)
	row.add_child(_enter_btn)

	_next_btn = Button.new()
	_next_btn.text = "다음 층"
	UIStyle.apply_button(_next_btn)
	_next_btn.pressed.connect(_on_next)
	row.add_child(_next_btn)

	var town := Button.new()
	town.text = "마을로 돌아가기"
	UIStyle.apply_button(town)
	town.pressed.connect(func(): SceneRouter.go_town())
	box.add_child(town)

	_toast = UIStyle.label("", 13, UIStyle.TEXT)
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_toast)

	GameState.message_emitted.connect(_on_message)


func _refresh() -> void:
	var def := GameState.get_dungeon_def(dungeon_id)
	var prog := GameState.ensure_dungeon_progress(dungeon_id)
	var floor := int(prog.get("current_floor", 1))
	var fdef := GameState.get_dungeon_floor_def(dungeon_id, floor)
	_name_l.text = str(def.get("name", dungeon_id))
	_floor_l.text = "%d층 — %s" % [floor, str(fdef.get("name", ""))]
	var cleared := GameState.dungeon_is_floor_cleared(dungeon_id, floor)
	var boss := str(fdef.get("boss", ""))
	var status := "클리어" if cleared else "미클리어 (적 잔존)"
	if boss == "mid":
		status += " · 중층 보스"
	elif boss == "final":
		status += " · 최종 보스"
	_status_l.text = "상태: %s" % status
	_status_l.add_theme_color_override("font_color", UIStyle.OK if cleared else UIStyle.DANGER)
	_diff_l.text = "난이도: %s / 최심부 %d층" % [str(fdef.get("difficulty", "?")), int(prog.get("deepest_floor", 1))]
	_blurb_l.text = str(def.get("blurb", ""))

	_prev_btn.disabled = floor <= 1
	_next_btn.disabled = not GameState.dungeon_can_go_next(dungeon_id)
	if cleared:
		_enter_btn.text = "재도전"
	else:
		_enter_btn.text = "이 층 전투"

	if _minimap and _minimap.has_method("refresh"):
		_minimap.refresh()


func _on_enter() -> void:
	var floor := GameState.dungeon_current_floor(dungeon_id)
	SceneRouter.go_dungeon_combat(dungeon_id, floor)


func _on_next() -> void:
	if not GameState.dungeon_can_go_next(dungeon_id):
		_toast.text = "이 층의 적을 모두 처치해야 다음 층으로 갈 수 있습니다."
		_toast.add_theme_color_override("font_color", UIStyle.DANGER)
		return
	var cur := GameState.dungeon_current_floor(dungeon_id)
	if GameState.dungeon_set_floor(dungeon_id, cur + 1):
		_refresh()


func _on_prev() -> void:
	var cur := GameState.dungeon_current_floor(dungeon_id)
	if cur <= 1:
		return
	if GameState.dungeon_set_floor(dungeon_id, cur - 1):
		_refresh()


func _on_message(text: String, is_error: bool) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", UIStyle.DANGER if is_error else UIStyle.OK)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		SceneRouter.go_town()
