extends SceneTree

## Foot-pivot + torso stability check. Idle/walk frames must stay tight.
## godot --headless --path . -s res://scripts/core/validate_sprite_align.gd

const PIVOT_PATH := "res://data/combat/sprite_pivots.json"
const MAX_IDLE_FOOT_ERR := 5.0
const MAX_IDLE_TORSO_ERR := 8.0
const JOBS := ["mage", "healer", "dps", "tank", "lord"]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed := 0
	if not FileAccess.file_exists(PIVOT_PATH):
		print("FAIL: missing ", PIVOT_PATH)
		quit(1)
		return
	var f := FileAccess.open(PIVOT_PATH, FileAccess.READ)
	var meta = JSON.parse_string(f.get_as_text())
	if typeof(meta) != TYPE_DICTIONARY:
		print("FAIL: bad pivot json")
		quit(1)
		return
	var jobs: Dictionary = meta.get("jobs", {})
	for job in JOBS:
		if not jobs.has(job):
			print("FAIL: no pivot meta for ", job)
			failed += 1
			continue
		var entry: Dictionary = jobs[job]
		var piv: Array = entry.get("pivot", [])
		if piv.size() < 2:
			print("FAIL: incomplete pivot for ", job)
			failed += 1
			continue
		var px := float(piv[0])
		var py := float(piv[1])
		var idle_torso := 0.0
		for i in range(8):
			var path := "res://assets/sprites/characters/%s/combat_%02d.png" % [job, i]
			var abs_path := ProjectSettings.globalize_path(path)
			var img := Image.new()
			var load_err := img.load(abs_path)
			if load_err != OK:
				print("FAIL: cannot load ", abs_path)
				failed += 1
				continue
			var foot := _foot_of(img)
			var torso := _torso_cx(img)
			if i == 0:
				idle_torso = torso
			var foot_err := Vector2(foot.x - px, foot.y - py)
			var torso_err := torso - px
			print("  %s[%d] foot_err=(%.2f,%.2f) torso_err=%.2f canvas=%dx%d" % [
				job, i, foot_err.x, foot_err.y, torso_err, img.get_width(), img.get_height()
			])
			# Vertical foot pin must stay tight on every frame
			if absf(foot_err.y) > MAX_IDLE_FOOT_ERR:
				print("FAIL: foot Y drift %s frame %d" % [job, i])
				failed += 1
			# Idle/walk (0-3): torso stable vs idle — horizontal jump detector
			if i <= 3 and absf(torso - idle_torso) > MAX_IDLE_TORSO_ERR:
				print("FAIL: idle/walk torso drift %s frame %d (%.2f)" % [job, i, torso - idle_torso])
				failed += 1
		if job == "mage" and entry.get("staff_tip_offset", null) == null:
			print("FAIL: mage missing staff_tip_offset")
			failed += 1
		elif job == "mage":
			print("  mage staff_tip_offset=", entry.get("staff_tip_offset"))
		if job == "healer" and entry.get("heal_origin_offset", null) == null:
			print("FAIL: healer missing heal_origin_offset")
			failed += 1
		elif job == "healer":
			print("  healer heal_origin_offset=", entry.get("heal_origin_offset"))

	for job in JOBS:
		var sf := SpriteFactory.ally_frames(job)
		var n := sf.get_frame_count("attack")
		var active := SpriteFactory.attack_active_frame(job)
		print("attack seq %s frames=%d active_idx=%d" % [job, n, active])
		if active < 0 or active >= n:
			print("FAIL: active frame out of range for ", job)
			failed += 1
		if job == "mage" and n < 5:
			print("FAIL: mage attack sequence too short")
			failed += 1

	if failed == 0:
		print("=== SPRITE ALIGN RESULT: PASS ===")
		quit(0)
	else:
		print("=== SPRITE ALIGN RESULT: FAIL (%d) ===" % failed)
		quit(1)


func _foot_of(img: Image) -> Vector2:
	var w := img.get_width()
	var h := img.get_height()
	var minx := w
	var miny := h
	var maxx := -1
	var maxy := -1
	for y in range(h):
		for x in range(w):
			if img.get_pixel(x, y).a > 0.1:
				minx = mini(minx, x)
				miny = mini(miny, y)
				maxx = maxi(maxx, x)
				maxy = maxi(maxy, y)
	if maxx < 0:
		return Vector2(w * 0.5, h - 1.0)
	var xs: Array = []
	for y in range(maxi(0, maxy - 5), maxy + 1):
		for x in range(minx, maxx + 1):
			if img.get_pixel(x, y).a > 0.1:
				xs.append(x)
	xs.sort()
	var lo := int(xs.size() * 0.25)
	var hi := maxi(lo + 1, int(xs.size() * 0.75))
	var sum := 0.0
	for i in range(lo, hi):
		sum += float(xs[i])
	return Vector2(sum / float(hi - lo), float(maxy))


func _torso_cx(img: Image) -> float:
	var w := img.get_width()
	var h := img.get_height()
	var minx := w
	var miny := h
	var maxx := -1
	var maxy := -1
	for y in range(h):
		for x in range(w):
			if img.get_pixel(x, y).a > 0.1:
				minx = mini(minx, x)
				miny = mini(miny, y)
				maxx = maxi(maxx, x)
				maxy = maxi(maxy, y)
	if maxx < 0:
		return w * 0.5
	var bh := maxy - miny + 1
	var y1 := miny + int(bh * 0.22)
	var y2 := miny + int(bh * 0.62)
	var xs: Array = []
	for y in range(y1, y2 + 1):
		for x in range(minx, maxx + 1):
			if img.get_pixel(x, y).a > 0.1:
				xs.append(x)
	if xs.is_empty():
		return (minx + maxx) * 0.5
	xs.sort()
	var lo := int(xs.size() * 0.18)
	var hi := maxi(lo + 1, int(xs.size() * 0.82))
	var sum := 0.0
	for i in range(lo, hi):
		sum += float(xs[i])
	return sum / float(hi - lo)
