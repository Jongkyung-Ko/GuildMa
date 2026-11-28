extends Node

const TITLE := "res://scenes/title/title.tscn"
const TOWN := "res://scenes/town/town.tscn"
const WORLD_MAP := "res://scenes/world_map/world_map.tscn"
const SETTINGS := "res://scenes/title/settings.tscn"
const FACILITY := "res://scenes/facilities/facility.tscn"
const GUILD_HALL := "res://scenes/facilities/guild_hall.tscn"
const COMBAT := "res://scenes/combat/combat.tscn"
const DUNGEON_HUB := "res://scenes/dungeon/dungeon_hub.tscn"

var current_facility: String = ""


func go_title() -> void:
	current_facility = ""
	if GameState and GameState.active_hunt_id != "":
		GameState.leave_hunt_session()
	if AudioManager:
		AudioManager.on_enter_title()
	get_tree().change_scene_to_file(TITLE)


func go_town() -> void:
	current_facility = ""
	# If a hunt session is still marked active (edge paths), clear re-entry spawn.
	if GameState and GameState.active_hunt_id != "":
		GameState.leave_hunt_session()
	if AudioManager:
		AudioManager.on_enter_town()
	get_tree().change_scene_to_file(TOWN)


func go_world_map() -> void:
	current_facility = ""
	if GameState and GameState.active_hunt_id != "":
		GameState.leave_hunt_session()
	if AudioManager:
		AudioManager.on_enter_world_map()
	get_tree().change_scene_to_file(WORLD_MAP)


func go_settings(from_title: bool = true) -> void:
	# Keep whatever BGM is already playing.
	get_tree().root.set_meta("settings_from_title", from_title)
	get_tree().change_scene_to_file(SETTINGS)


func go_facility(facility_id: String) -> void:
	current_facility = facility_id
	get_tree().root.set_meta("facility_id", facility_id)
	if AudioManager:
		AudioManager.on_enter_facility()
	# Guild HQ uses dedicated Guild Hall scene; other facilities keep shared shell.
	if facility_id == "guild":
		get_tree().change_scene_to_file(GUILD_HALL)
	else:
		get_tree().change_scene_to_file(FACILITY)


## Legacy / test combat (no maze). Hunting maze uses go_hunt().
func go_combat(_hunt_id: String = "phase_2_1_test") -> void:
	current_facility = ""
	get_tree().root.set_meta("combat_hunt_id", _hunt_id)
	get_tree().root.set_meta("hunt_id", "")
	get_tree().root.set_meta("dungeon_id", "")
	get_tree().root.set_meta("dungeon_floor", 0)
	get_tree().root.set_meta("special_encounter_id", "")
	if AudioManager:
		AudioManager.on_enter_combat(true)
	get_tree().change_scene_to_file(COMBAT)


## Hunting-ground maze expedition (node graph). Separate from dungeon floors.
func go_hunt(hunt_id: String = "beginner_forest", force_new: bool = false) -> void:
	current_facility = ""
	get_tree().root.set_meta("hunt_id", hunt_id)
	get_tree().root.set_meta("hunt_force_new", force_new)
	# Town→hunt / re-entry: always spawn at entrance (internal travel never uses go_hunt).
	get_tree().root.set_meta("hunt_spawn_at_start", true)
	get_tree().root.set_meta("combat_hunt_id", hunt_id)
	get_tree().root.set_meta("dungeon_id", "")
	get_tree().root.set_meta("dungeon_floor", 0)
	get_tree().root.set_meta("special_encounter_id", "")
	# Fresh town→hunt (or re-entry): restart hunt MP3 from the beginning.
	if AudioManager:
		AudioManager.on_enter_combat(true)
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
	get_tree().root.set_meta("hunt_id", "")
	get_tree().root.set_meta("special_encounter_id", "")
	get_tree().root.set_meta("combat_hunt_id", "dungeon_%s_f%d" % [dungeon_id, floor])
	if AudioManager:
		AudioManager.on_enter_combat(true)
	get_tree().change_scene_to_file(COMBAT)


## Named special boss encounter (Vorak / Morgana). Not a hunt maze room and not a dungeon floor.
func go_special_encounter(encounter_id: String) -> void:
	current_facility = ""
	get_tree().root.set_meta("special_encounter_id", encounter_id)
	get_tree().root.set_meta("hunt_id", "")
	get_tree().root.set_meta("dungeon_id", "")
	get_tree().root.set_meta("dungeon_floor", 0)
	get_tree().root.set_meta("combat_hunt_id", "special_%s" % encounter_id)
	if AudioManager:
		AudioManager.on_enter_combat(true)
	get_tree().change_scene_to_file(COMBAT)
