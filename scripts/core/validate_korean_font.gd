extends SceneTree

## Headless: Noto Sans KR must back UIStyle.draw_font + Hangul string metrics.
## godot --headless --path . -s res://scripts/core/validate_korean_font.gd

var _failed := 0
var _passed := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== KOREAN FONT VALIDATION ===")
	var ui: Node = root.get_node_or_null("/root/UIStyle")
	if ui == null:
		_fail("UIStyle autoload missing")
		_finish()
		return

	if not ResourceLoader.exists("res://assets/fonts/NotoSansKR-Regular.otf"):
		_fail("NotoSansKR-Regular.otf missing")
	else:
		_pass("NotoSansKR-Regular.otf present")

	if not ResourceLoader.exists("res://assets/fonts/NotoSansKR-Bold.otf"):
		_fail("NotoSansKR-Bold.otf missing")
	else:
		_pass("NotoSansKR-Bold.otf present")

	var font: Font = null
	if ui.has_method("draw_font"):
		font = ui.draw_font()
	if font == null:
		_fail("draw_font returned null")
		_finish()
		return

	# Must not be bare fallback when Noto is loaded.
	var regular: Font = ui.get("ui_font") as Font
	if regular == null:
		_fail("ui_font not loaded")
	elif font != regular:
		_fail("draw_font is not ui_font")
	else:
		_pass("draw_font returns embedded Noto")

	var samples := [
		"미니맵",
		"현재 위치",
		"이동 가능",
		"클리어한 방",
		"보스 방",
		"연결된 출구",
		"출현 몬스터",
		"이동하기",
		"전투 중에는 이동할 수 없습니다.",
		"늑대",
		"슬라임",
		"고블린",
	]
	for s in samples:
		var sz: Vector2 = font.get_string_size(str(s), HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
		if sz.x < 8.0:
			_fail("glyph width too small for '%s' (%.1f) — missing Hangul?" % [s, sz.x])
		else:
			_pass("metrics ok '%s' w=%.1f" % [s, sz.x])

	# Theme default should be Noto.
	var theme: Theme = ui.get("app_theme") as Theme
	if theme == null or theme.default_font == null:
		_fail("app_theme.default_font missing")
	elif theme.default_font != regular:
		_fail("theme default_font is not Noto")
	else:
		_pass("root theme uses Noto")

	_finish()


func _pass(msg: String) -> void:
	_passed += 1
	print("PASS: ", msg)


func _fail(msg: String) -> void:
	_failed += 1
	print("FAIL: ", msg)


func _finish() -> void:
	print("=== KOREAN FONT RESULT: %s (%d pass / %d fail) ===" % [
		"PASS" if _failed == 0 else "FAIL", _passed, _failed
	])
	quit(0 if _failed == 0 else 1)
