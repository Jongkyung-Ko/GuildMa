extends Node

const TITLE := "res://scenes/title/title.tscn"
const TOWN := "res://scenes/town/town.tscn"
const SETTINGS := "res://scenes/title/settings.tscn"
const FACILITY := "res://scenes/facilities/facility.tscn"

var current_facility: String = ""


func go_title() -> void:
	current_facility = ""
	get_tree().change_scene_to_file(TITLE)


func go_town() -> void:
	current_facility = ""
	get_tree().change_scene_to_file(TOWN)


func go_settings(from_title: bool = true) -> void:
	# settings scene reads a flag via meta
	get_tree().root.set_meta("settings_from_title", from_title)
	get_tree().change_scene_to_file(SETTINGS)


func go_facility(facility_id: String) -> void:
	current_facility = facility_id
	get_tree().root.set_meta("facility_id", facility_id)
	get_tree().change_scene_to_file(FACILITY)
