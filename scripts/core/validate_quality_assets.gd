extends SceneTree

## Godot mirror of quality asset/data gates (IDs, paths, counts, basic image props).
## Visual style is NEVER auto-approved.
## Run: godot4 --path . --headless -s res://scripts/core/validate_quality_assets.gd

const ITEMS_PATH := "res://data/items.json"
const MIN_ICON_PX := 256

var _failed := 0
var _soft := 0


func _init() -> void:
	call_deferred("_run")


func _fail(msg: String) -> void:
	printerr("FAIL: ", msg)
	_failed += 1


func _soft_fail(msg: String) -> void:
	print("SOFT: ", msg)
	_soft += 1


func _pass(msg: String) -> void:
	print("OK: ", msg)


func _run() -> void:
	print("=== validate_quality_assets (Godot) ===")
	print("NOTE: visual style is NEVER auto-approved by this script.")

	if not FileAccess.file_exists(ITEMS_PATH):
		_fail("missing %s" % ITEMS_PATH)
		_finish()
		return

	var txt := FileAccess.get_file_as_string(ITEMS_PATH)
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY and typeof(parsed) != TYPE_ARRAY:
		_fail("items.json parse failed")
		_finish()
		return

	var items: Array = []
	if typeof(parsed) == TYPE_DICTIONARY:
		items = parsed.get("items", [])
	else:
		items = parsed

	_pass("loaded items.json count=%d" % items.size())

	var seen := {}
	var dup := 0
	var cats := {}
	var missing := 0
	var bad_ref := 0
	var low_res := 0
	var hash_groups := {}  # content fingerprint -> Array[String]

	for it_v in items:
		if typeof(it_v) != TYPE_DICTIONARY:
			_fail("non-dict item entry")
			continue
		var it: Dictionary = it_v
		var iid := str(it.get("id", ""))
		if iid == "":
			_fail("item missing id")
			continue
		if seen.has(iid):
			dup += 1
			printerr("  duplicate id ", iid)
		seen[iid] = true
		var cat := str(it.get("category", ""))
		cats[cat] = int(cats.get(cat, 0)) + 1

		var icon := str(it.get("icon", ""))
		if icon == "":
			bad_ref += 1
			printerr("  empty icon for ", iid)
			continue
		if not icon.begins_with("res://"):
			bad_ref += 1
			printerr("  non-res icon for ", iid, " -> ", icon)
		if not ResourceLoader.exists(icon) and not FileAccess.file_exists(icon):
			missing += 1
			printerr("  missing icon for ", iid, " -> ", icon)
			continue

		var img := Image.new()
		var err := img.load(icon)
		if err != OK:
			bad_ref += 1
			printerr("  Image.load failed for ", iid, " err=", err)
			continue
		if img.get_width() < MIN_ICON_PX or img.get_height() < MIN_ICON_PX:
			low_res += 1
			printerr("  low-res ", iid, " ", img.get_width(), "x", img.get_height())
		# Alpha: convert and sample corners + sparse grid
		img.convert(Image.FORMAT_RGBA8)
		var transparent := 0
		var total := 0
		var step: int = maxi(1, mini(img.get_width(), img.get_height()) / 32)
		var y := 0
		while y < img.get_height():
			var x := 0
			while x < img.get_width():
				total += 1
				if img.get_pixel(x, y).a < 0.06:
					transparent += 1
				x += step
			y += step
		var corners := [
			img.get_pixel(0, 0).a,
			img.get_pixel(img.get_width() - 1, 0).a,
			img.get_pixel(0, img.get_height() - 1).a,
			img.get_pixel(img.get_width() - 1, img.get_height() - 1).a,
		]
		var min_c: float = corners[0]
		for c in corners:
			min_c = minf(min_c, float(c))
		var ratio: float = 0.0 if total == 0 else float(transparent) / float(total)
		if ratio < 0.005 and min_c > 0.98:
			_soft_fail("%s appears fully opaque (possible solid rect)" % iid)
		# content hash for identical-byte-ish collisions (pixel dump)
		var key := str(img.get_data().hex_encode().substr(0, 24))
		if not hash_groups.has(key):
			hash_groups[key] = []
		hash_groups[key].append(iid)

	if dup > 0:
		_fail("%d duplicate item ids" % dup)
	else:
		_pass("item ids unique")

	for k in cats.keys():
		_pass("category %s count=%d" % [k if str(k) != "" else "?", int(cats[k])])

	if missing > 0:
		_fail("%d missing icon paths" % missing)
	else:
		_pass("all item icons resolve")

	if bad_ref > 0:
		_fail("%d bad icon refs / load errors" % bad_ref)
	else:
		_pass("no bad icon refs")

	if low_res > 0:
		_fail("%d icons below %dpx" % [low_res, MIN_ICON_PX])
	else:
		_pass("linked icons >= %dpx" % MIN_ICON_PX)

	var identical := 0
	for k in hash_groups.keys():
		var group: Array = hash_groups[k]
		if group.size() > 1:
			identical += 1
			var names: PackedStringArray = PackedStringArray()
			for g in group:
				names.append(str(g))
			_soft_fail("identical pixel group: %s" % ", ".join(names))
	if identical == 0:
		_pass("no identical pixel collisions among linked icons")

	# Placeholder manifesto (declared list — honesty gate)
	var manifest_path := "res://docs/standards/placeholder_assets.manifest.json"
	if FileAccess.file_exists(manifest_path):
		var mtxt := FileAccess.get_file_as_string(manifest_path)
		var mparsed: Variant = JSON.parse_string(mtxt)
		var declared: Array = []
		if typeof(mparsed) == TYPE_DICTIONARY:
			declared = mparsed.get("declared_placeholders", [])
		if declared.size() > 0:
			_soft_fail("%d declared placeholders in manifest (not final art)" % declared.size())
		else:
			_pass("placeholder manifest has zero declared entries")
	else:
		_soft_fail("placeholder manifest missing")

	_finish()


func _finish() -> void:
	# Soft findings are honesty reports; they do not fail by default.
	# Python tool: --strict to fail on soft. Visual style is never auto-approved.
	if _soft > 0 and _failed == 0:
		print("NOTE: soft findings reported (%d); not failing (Godot default)" % _soft)
	print("=== RESULT: %s (%d fails, %d soft) ===" % [
		"PASS" if _failed == 0 else "FAIL",
		_failed,
		_soft
	])
	quit(0 if _failed == 0 else 1)
