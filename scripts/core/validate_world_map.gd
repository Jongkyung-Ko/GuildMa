extends SceneTree

## Functional checks for world map markers + AudioManager BGM keys.
## godot4 --headless --path . -s res://scripts/core/validate_world_map.gd

const MARKERS := "res://data/world/world_map_markers.json"
const BG := "res://assets/backgrounds/world_map_background.jpg"
const EXPECT_VILLAGES := [
	"frostheim", "stoneguard", "gravehall",
	"elderwood", "moonshadow", "mistfall",
	"demonfall", "deadcrown", "abyssgate",
]
const EXPECT_CASTLES := ["icecrown", "eldria", "abysscal"]
const BGM_KEYS := {
	"world_map": "res://assets/audio/music/world_map_bgm.mp3",
	"hunt": "res://assets/audio/music/hunting_ground_bgm.mp3",
	"boss": "res://assets/audio/music/boss_battle_bgm.mp3",
	"combat_boss": "res://assets/audio/music/boss_battle_bgm.mp3",
	"credits": "res://assets/audio/music/ending_credits_bgm.mp3",
	"town": "res://assets/audio/music/morning_dew_on_stone.mp3",
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var failed := 0
	var passed := 0

	if not ResourceLoader.exists(BG) and not FileAccess.file_exists(BG):
		print("FAIL: missing world map background ", BG)
		failed += 1
	else:
		print("PASS: background jpg present")
		passed += 1

	var f := FileAccess.open(MARKERS, FileAccess.READ)
	if f == null:
		print("FAIL: cannot open markers JSON")
		quit(1)
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		print("FAIL: markers JSON not a dictionary")
		quit(1)
		return
	print("PASS: markers JSON parse")
	passed += 1

	var home := str(data.get("home_marker_id", ""))
	if home != "elderwood":
		print("FAIL: home_marker_id expected elderwood got ", home)
		failed += 1
	else:
		print("PASS: home marker elderwood")
		passed += 1

	var markers = data.get("markers", [])
	if typeof(markers) != TYPE_ARRAY:
		print("FAIL: markers not array")
		failed += 1
		markers = []
	var by_id := {}
	var villages := 0
	var castles := 0
	for m in markers:
		if typeof(m) != TYPE_DICTIONARY:
			continue
		var mid := str(m.get("id", ""))
		by_id[mid] = m
		var kind := str(m.get("kind", ""))
		if kind == "village":
			villages += 1
		elif kind == "castle":
			castles += 1
			var bosses = m.get("bosses", [])
			if typeof(bosses) != TYPE_ARRAY or bosses.size() != 3:
				print("FAIL: castle %s expected 3 bosses" % mid)
				failed += 1
			else:
				print("PASS: castle %s has 3 bosses" % mid)
				passed += 1

	if villages != 9:
		print("FAIL: expected 9 villages got ", villages)
		failed += 1
	else:
		print("PASS: 9 villages")
		passed += 1
	if castles != 3:
		print("FAIL: expected 3 castles got ", castles)
		failed += 1
	else:
		print("PASS: 3 castles")
		passed += 1

	for id in EXPECT_VILLAGES:
		if not by_id.has(id):
			print("FAIL: missing village ", id)
			failed += 1
		else:
			passed += 1
	for id in EXPECT_CASTLES:
		if not by_id.has(id):
			print("FAIL: missing castle ", id)
			failed += 1
		else:
			passed += 1

	# Region → castle boss sets
	var expect_boss := {
		"icecrown": ["fenrir", "behemoth", "bone_golem"],
		"eldria": ["gorgon", "lilith", "morgana"],
		"abysscal": ["malkav", "malachi", "vorak"],
	}
	for cid in expect_boss.keys():
		var m: Dictionary = by_id.get(cid, {})
		var got: Array = []
		for b in m.get("bosses", []):
			if typeof(b) == TYPE_DICTIONARY:
				got.append(str(b.get("id", "")))
		for bid in expect_boss[cid]:
			if bid not in got:
				print("FAIL: %s missing boss %s" % [cid, bid])
				failed += 1
			else:
				passed += 1

	var audio: Node = root.get_node_or_null("/root/AudioManager")
	if audio == null:
		print("FAIL: AudioManager missing")
		failed += 1
	else:
		var paths: Dictionary = audio.get("BGM_PATHS")
		for key in BGM_KEYS.keys():
			var want: String = BGM_KEYS[key]
			if not paths.has(key):
				print("FAIL: BGM_PATHS missing ", key)
				failed += 1
				continue
			if str(paths[key]) != want:
				print("FAIL: BGM_PATHS[%s]=%s want %s" % [key, str(paths[key]), want])
				failed += 1
				continue
			if not ResourceLoader.exists(want):
				print("FAIL: missing file ", want)
				failed += 1
				continue
			print("PASS: BGM %s → %s" % [key, want])
			passed += 1

		audio.call("unlock_audio")
		audio.call("on_enter_world_map")
		await process_frame
		if str(audio.call("get_current_bgm")) != "world_map":
			print("FAIL: on_enter_world_map got ", audio.call("get_current_bgm"))
			failed += 1
		else:
			print("PASS: on_enter_world_map → world_map")
			passed += 1

		# Credits hook exists but is NOT scene-wired.
		if not audio.has_method("on_enter_credits"):
			print("FAIL: on_enter_credits hook missing")
			failed += 1
		else:
			audio.call("on_enter_credits")
			await process_frame
			if str(audio.call("get_current_bgm")) != "credits":
				print("FAIL: on_enter_credits got ", audio.call("get_current_bgm"))
				failed += 1
			else:
				print("PASS: on_enter_credits hook plays credits (NOT scene-wired)")
				passed += 1

		audio.call("on_enter_town")
		await process_frame
		if str(audio.call("get_current_bgm")) != "town":
			print("FAIL: town BGM not restored got ", audio.call("get_current_bgm"))
			failed += 1
		else:
			print("PASS: town BGM preserved/restored")
			passed += 1

	var sr: Node = root.get_node_or_null("/root/SceneRouter")
	if sr == null or not sr.has_method("go_world_map"):
		print("FAIL: SceneRouter.go_world_map missing")
		failed += 1
	else:
		print("PASS: SceneRouter.go_world_map present")
		passed += 1

	if not ResourceLoader.exists("res://scenes/world_map/world_map.tscn"):
		print("FAIL: world_map.tscn missing")
		failed += 1
	else:
		print("PASS: world_map.tscn present")
		passed += 1

	print("=== validate_world_map: %d pass / %d fail ===" % [passed, failed])
	quit(0 if failed == 0 else 1)
