extends Node

const TITLE := "res://scenes/title/title.tscn"
const TOWN := "res://scenes/town/town.tscn"
const SETTINGS := "res://scenes/title/settings.tscn"
const FACILITY := "res://scenes/facilities/facility.tscn"
const COMBAT := "res://scenes/combat/combat.tscn"

var current_facility: String = ""


func go_title() -> void:
	current_facility = ""
	_play_bgm("title")
	get_tree().change_scene_to_file(TITLE)


func go_town() -> void:
	current_facility = ""
	_play_bgm("town")
	get_tree().change_scene_to_file(TOWN)


func go_settings(from_title: bool = true) -> void:
	# settings scene reads a flag via meta; keep whatever BGM is already playing
	get_tree().root.set_meta("settings_from_title", from_title)
	get_tree().change_scene_to_file(SETTINGS)


func go_facility(facility_id: String) -> void:
	current_facility = facility_id
	_play_bgm("town")
	get_tree().root.set_meta("facility_id", facility_id)
	get_tree().change_scene_to_file(FACILITY)


## Phase 2-1: enter combat prototype directly (HuntSelect comes in a later phase).
func go_combat(_hunt_id: String = "phase_2_1_test") -> void:
	current_facility = ""
	_play_bgm("combat")
	get_tree().root.set_meta("combat_hunt_id", _hunt_id)
	get_tree().change_scene_to_file(COMBAT)


func _play_bgm(key: String) -> void:
	var mm := get_node_or_null("/root/MusicManager")
	if mm and mm.has_method("play"):
		mm.play(key)
