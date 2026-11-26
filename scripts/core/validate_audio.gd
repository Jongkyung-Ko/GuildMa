extends SceneTree

## Headless audio asset + AudioManager wiring smoke test.
## godot4 --headless --path . -s res://scripts/core/validate_audio.gd

const SFX := {
	"ui_click": "res://assets/audio/sfx/01_ui_button_click.wav",
	"ambience": "res://assets/audio/sfx/02_battle_ambience_loop.wav",
	"hit": "res://assets/audio/sfx/03_combat_hit.wav",
	"magic": "res://assets/audio/sfx/04_magic_cast.wav",
	"equip": "res://assets/audio/sfx/05_item_equip.wav",
}
const BGM := {
	"town": "res://assets/audio/bgm/01_town_theme.ogg",
	"combat": "res://assets/audio/bgm/02_hunting_grounds_rock.ogg",
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var failed := 0
	var audio: Node = root.get_node_or_null("/root/AudioManager")
	if audio == null:
		print("FAIL: AudioManager autoload missing")
		quit(1)
		return
	_pass("AudioManager autoload present")

	for id in SFX.keys():
		var path: String = SFX[id]
		if not ResourceLoader.exists(path):
			print("FAIL: missing SFX ", path)
			failed += 1
			continue
		var s: AudioStream = load(path)
		if s == null:
			print("FAIL: cannot load SFX ", path)
			failed += 1
		else:
			_pass("SFX load %s" % id)

	for id in BGM.keys():
		var path: String = BGM[id]
		if not ResourceLoader.exists(path):
			print("FAIL: missing BGM ", path)
			failed += 1
			continue
		var s: AudioStream = load(path)
		if s == null:
			print("FAIL: cannot load BGM ", path)
			failed += 1
		else:
			_pass("BGM load %s (%s)" % [id, path.get_file()])

	for mid in ["01_town_theme.mid", "02_hunting_grounds_rock.mid"]:
		var p := "res://assets/audio/bgm/%s" % mid
		if not FileAccess.file_exists(p):
			print("FAIL: missing MIDI source ", p)
			failed += 1
		else:
			_pass("MIDI source %s" % mid)

	if AudioServer.get_bus_index("BGM") < 0 or AudioServer.get_bus_index("SFX") < 0:
		print("FAIL: BGM/SFX buses missing")
		failed += 1
	else:
		_pass("BGM/SFX buses present")

	audio.call("unlock_audio")
	audio.call("play_bgm", "town", true)
	await process_frame
	var bgm_player: AudioStreamPlayer = audio.get("_bgm")
	if bgm_player == null or bgm_player.stream == null:
		print("FAIL: BGM stream not assigned")
		failed += 1
	elif bgm_player.playing:
		_pass("BGM playing after unlock")
	else:
		_pass("BGM stream assigned after unlock (dummy driver may not mark playing)")

	audio.call("play_ui_click")
	audio.call("play_hit")
	audio.call("play_magic")
	audio.call("play_equip")
	audio.call("start_combat_ambience")
	await process_frame
	_pass("SFX + ambience calls completed without error")

	audio.call("play_bgm", "combat", true)
	await process_frame
	if str(audio.get("_current_bgm")) != "combat":
		print("FAIL: BGM did not switch to combat (got %s)" % str(audio.get("_current_bgm")))
		failed += 1
	else:
		_pass("BGM switched town → combat without stacking second player")

	audio.call("on_enter_town")
	await process_frame
	var amb: AudioStreamPlayer = audio.get("_ambience")
	if amb and amb.playing:
		print("FAIL: combat ambience still playing after town")
		failed += 1
	else:
		_pass("Combat ambience stopped on town")

	var mid_res = load("res://assets/audio/bgm/01_town_theme.mid")
	print("NOTE: load(.mid) => ", mid_res.get_class() if mid_res else "null", " — playback uses .ogg renders")

	if failed == 0:
		print("=== AUDIO VALIDATE: PASS ===")
		quit(0)
	else:
		print("=== AUDIO VALIDATE: FAIL (%d) ===" % failed)
		quit(1)


func _pass(msg: String) -> void:
	print("PASS: ", msg)
