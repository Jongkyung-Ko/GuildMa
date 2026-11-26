extends Control

## Cardinal travel buttons after hunt-room clear. Only real connections; never dungeon.

signal travel_dir(dir: String)

const DIRS := ["N", "E", "S", "W"]
const LABELS := {"N": "↑", "E": "→", "S": "↓", "W": "←"}
const NAMES := {"N": "북쪽", "E": "동쪽", "S": "남쪽", "W": "서쪽"}

var _buttons: Dictionary = {}  # dir -> Button
var _busy: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	visible = false


func _build() -> void:
	var mobile := UIStyle.is_mobile_like() if UIStyle else false
	var sz := Vector2(56, 56) if mobile else Vector2(48, 48)
	var positions := {
		"N": Vector2(0.5, 0.12),
		"S": Vector2(0.5, 0.78),
		"W": Vector2(0.08, 0.5),
		"E": Vector2(0.72, 0.5),
	}
	for d in DIRS:
		var b := Button.new()
		b.text = "%s\n%s" % [LABELS[d], NAMES[d]]
		b.custom_minimum_size = sz
		b.focus_mode = Control.FOCUS_NONE
		UIStyle.apply_button(b)
		UIStyle.apply_font(b, 13 if mobile else 12)
		b.set_anchors_preset(Control.PRESET_TOP_LEFT)
		b.anchor_left = positions[d].x
		b.anchor_right = positions[d].x
		b.anchor_top = positions[d].y
		b.anchor_bottom = positions[d].y
		b.offset_left = -sz.x * 0.5
		b.offset_right = sz.x * 0.5
		b.offset_top = -sz.y * 0.5
		b.offset_bottom = sz.y * 0.5
		# Keep clear of party HUD (right) and minimap (top-left).
		if d == "E":
			b.anchor_left = 0.62
			b.anchor_right = 0.62
		if d == "N":
			b.anchor_top = 0.18
			b.anchor_bottom = 0.18
		var dir_copy: String = str(d)
		b.pressed.connect(func(): _on_pressed(dir_copy))
		add_child(b)
		_buttons[d] = b
		b.visible = false


func refresh(show_pad: bool) -> void:
	_busy = false
	if not show_pad:
		visible = false
		for d in DIRS:
			(_buttons[d] as Button).visible = false
		return
	var room := GameState.get_current_hunt_room()
	if room.is_empty():
		visible = false
		return
	var cons: Dictionary = room.get("connected_rooms", {})
	var any := false
	for d in DIRS:
		var o = cons.get(d, null)
		var show := o != null and str(o) != ""
		var btn: Button = _buttons[d]
		btn.visible = show
		btn.disabled = false
		if show:
			any = true
			var oid := str(o)
			# Prefer can_move check so uncleared-current never enables mid-fight misuse.
			btn.disabled = not GameState.hunt_can_move_to(oid)
			btn.tooltip_text = NAMES[d]
	visible = any


func _on_pressed(dir: String) -> void:
	if _busy:
		return
	var room := GameState.get_current_hunt_room()
	if room.is_empty():
		return
	var cons: Dictionary = room.get("connected_rooms", {})
	var o = cons.get(dir, null)
	if o == null:
		return
	var oid := str(o)
	if not GameState.hunt_can_move_to(oid):
		return
	_busy = true
	for d in DIRS:
		(_buttons[d] as Button).disabled = true
	travel_dir.emit(dir)
