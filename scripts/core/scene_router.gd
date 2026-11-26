extends Node

const TITLE := "res://scenes/title/title.tscn"
const TOWN := "res://scenes/town/town.tscn"
const SETTINGS := "res://scenes/title/settings.tscn"
const FACILITY := "res://scenes/facilities/facility.tscn"
const COMBAT := "res://scenes/combat/combat.tscn"
const DUNGEON_HUB := "res://scenes/dungeon/dungeon_hub.tscn"

var current_facility: String = ""


func go_title() -> void:
	current_facility = ""
	if AudioManager:
		AudioManager.on_enter_title()
	get_tree().change_scene_to_file(TITLE)


func go_town() -> void:
	current_facility = ""
	if AudioManager:
		AudioManager.on_enter_town()
	get_tree().change_scene_to_file(TOWN)


func go_settings(from_title: bool = true) -> void:
	# settings scene reads a flag via meta
	get_tree().root.set_meta("settings_from_title", from_title)
	get_tree().change_scene_to_file(SETTINGS)


func go_facility(facility_id: String) -> void:
	current_facility = facility_id
	get_tree().root.set_meta("facility_id", facility_id)
	if AudioManager:
		AudioManager.on_enter_facility()
	get_tree().change_scene_to_file(FACILITY)


## Phase 2-1: enter combat prototype directly (HuntSelect comes in a later phase).
## Hunting-ground exploration (N/S/E/W) is separate — do not overload this path.
func go_combat(_hunt_id: String = "phase_2_1_test") -> void:
	current_facility = ""
	get_tree().root.set_meta("combat_hunt_id", _hunt_id)
	get_tree().root.set_meta("dungeon_id", "")
	get_tree().root.set_meta("dungeon_floor", 0)
	if AudioManager:
		AudioManager.on_enter_combat()
	get_tree().change_scene_to_file(COMBAT)


func go_dungeon(dungeon_id: String = "shadow_crypt") -> void:
	current_facility = ""
	GameState.ensure_dungeon_progress(dungeon_id)
	get_tree().root.set_meta("dungeon_id", dungeon_id)
	if AudioManager:
		AudioManager.on_enter_facility()
	get_tree().change_scene_to_file(DUNGEON_HUB)


func go_dungeon_hub(dungeon_id: String = "shadow_crypt") -> void:
	go_dungeon(dungeon_id)


func go_dungeon_combat(dungeon_id: String, floor: int) -> void:
	current_facility = ""
	get_tree().root.set_meta("dungeon_id", dungeon_id)
	get_tree().root.set_meta("dungeon_floor", floor)
	get_tree().root.set_meta("combat_hunt_id", "dungeon_%s_f%d" % [dungeon_id, floor])
	if AudioManager:
		AudioManager.on_enter_combat()
	get_tree().change_scene_to_file(COMBAT)
