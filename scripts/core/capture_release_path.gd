extends SceneTree

## Graphic release-path screenshots (X11/OpenGL via xvfb — NOT --headless).
## Uses SceneRouter scene loads of production scenes (not HTML emulator).
## This is NOT a substitute for full GUI click-tour verification.
##
##   xvfb-run -a /tmp/godot --path . -s res://scripts/core/capture_release_path.gd

const OUT := "Guild Hub Layout/internal/pr9-visual-verification"
const ART := "/opt/cursor/artifacts/pr9-visual-verification"
const DID := "shadow_crypt"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var ds := str(DisplayServer.get_name())
	print("=== RELEASE PATH CAPTURE ===")
	print("DisplayServer=", ds)
	print("Video=", OS.get_video_adapter_driver_info())
	if ds == "headless":
		printerr("ABORT headless")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + OUT))
	DirAccess.make_dir_recursive_absolute(ART)

	var gs: Node = root.get_node("/root/GameState")
	var sr: Node = root.get_node("/root/SceneRouter")
	gs.new_game()

	# 06 Title
	sr.go_title()
	await process_frame
	await process_frame
	await process_frame
	await _shot("06_title_screen.png")

	# 07 Town
	sr.go_town()
	await process_frame
	await process_frame
	await process_frame
	await _shot("07_town_screen.png")

	# 08 Gate facility — hunt + dungeon entry UI
	root.set_meta("facility_id", "gate")
	sr.go_facility("gate")
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	await _shot("08_dungeon_entry.png")

	# Dungeon hub
	sr.go_dungeon(DID)
	await process_frame
	await process_frame
	await process_frame
	# already have 01; keep floor transition evidence
	gs.mark_dungeon_floor_cleared(DID, 1)
	gs.dungeon_set_floor(DID, 1)
	# refresh hub
	sr.go_dungeon(DID)
	await process_frame
	await process_frame
	await process_frame
	# Move to floor 2 for transition shot
	if gs.dungeon_set_floor(DID, 2):
		sr.go_dungeon(DID)
		await process_frame
		await process_frame
		await process_frame
	await _shot("09_dungeon_floor_transition.png")

	# Mobile portrait of hub
	var win := root.get_window()
	if win:
		win.size = Vector2i(720, 1280)
		await process_frame
		await process_frame
		await process_frame
		await _shot("11_mobile_preview.png")
		win.size = Vector2i(1280, 720)
		await process_frame

	print("=== RELEASE PATH CAPTURE DONE ===")
	quit(0)


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	var tex: ViewportTexture = root.get_viewport().get_texture()
	if tex == null:
		printerr("FAIL no tex ", name)
		return
	var img: Image = tex.get_image()
	if img == null:
		printerr("FAIL no img ", name)
		return
	var p1 := ProjectSettings.globalize_path("res://" + OUT) + "/" + name
	img.save_png(p1)
	img.save_png(ART + "/" + name)
	print("SHOT ", name, " ", img.get_width(), "x", img.get_height())
