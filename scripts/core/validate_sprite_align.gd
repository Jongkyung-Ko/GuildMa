extends SceneTree

## Foot-pivot alignment check. Mage cast frames must stay within 2px of pivot.
## godot --headless --path . -s res://scripts/core/validate_sprite_align.gd

const PIVOT_PATH := "res://data/combat/sprite_pivots.json"
const MAX_IDLE_FOOT_ERR := 5.0
const MAX_IDLE_TORSO_ERR := 8.0
const MAX_MAGE_FOOT_ERR := 2.0
const JOBS := ["mage", "healer", "dps", "tank", "lord"]
const A_THRESH := 0.03


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed := 0
	# Bust pivot cache so this script always reads disk.
	SpriteFactory._pivot_cache = {}
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
			var foot := _foot_of_main(img)
			var torso := _torso_cx_main(img)
			if i == 0:
				idle_torso = torso
			var foot_err := Vector2(foot.x - px, foot.y - py)
			print("  %s[%d] foot=(%.2f,%.2f) foot_err=(%.2f,%.2f) torso_err=%.2f canvas=%dx%d" % [
				job, i, foot.x, foot.y, foot_err.x, foot_err.y, torso - px, img.get_width(), img.get_height()
			])
			if absf(foot_err.y) > MAX_IDLE_FOOT_ERR:
				print("FAIL: foot Y drift %s frame %d" % [job, i])
				failed += 1
			# Torso may lean during walk/cast once feet are pinned — only flag other jobs.
			if job != "mage" and i <= 3 and absf(torso - idle_torso) > MAX_IDLE_TORSO_ERR:
				print("FAIL: idle/walk torso drift %s frame %d (%.2f)" % [job, i, torso - idle_torso])
				failed += 1
			# Mage: every combat frame (incl. cast) must stay ≤2px from pivot.
			if job == "mage":
				if absf(foot_err.x) > MAX_MAGE_FOOT_ERR or absf(foot_err.y) > MAX_MAGE_FOOT_ERR:
					print("FAIL: mage foot err > %.1f on frame %d (%.2f,%.2f)" % [
						MAX_MAGE_FOOT_ERR, i, foot_err.x, foot_err.y
					])
					failed += 1
		if job == "mage" and entry.get("staff_tip_offset", null) == null:
			print("FAIL: mage missing staff_tip_offset")
			failed += 1
		elif job == "mage":
			print("  mage staff_tip_offset=", entry.get("staff_tip_offset"))
			print("  mage staff_tip_by_frame=", entry.get("staff_tip_by_frame", {}))
		if job == "healer" and entry.get("heal_origin_offset", null) == null:
			print("FAIL: healer missing heal_origin_offset")
			failed += 1
		elif job == "healer":
			print("  healer heal_origin_offset=", entry.get("heal_origin_offset"))

	for job in JOBS:
		var sf := SpriteFactory.ally_frames(job)
		var n := sf.get_frame_count("attack")
		var active := SpriteFactory.attack_active_frame(job)
		var sheets: Array = SpriteFactory.attack_sheet_indices(job)
		print("attack seq %s frames=%d active_idx=%d sheets=%s" % [job, n, active, str(sheets)])
		if active < 0 or active >= n:
			print("FAIL: active frame out of range for ", job)
			failed += 1
		if sheets.size() != n:
			print("FAIL: sheet index list size mismatch for ", job)
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


func _main_component(img: Image) -> Array:
	## Largest 4-connected opaque component (excludes fireball VFX blobs).
	var w := img.get_width()
	var h := img.get_height()
	var visited: Array = []
	visited.resize(w * h)
	for i in range(visited.size()):
		visited[i] = false
	var best: Array = []
	for y in range(h):
		for x in range(w):
			var idx := y * w + x
			if visited[idx]:
				continue
			if img.get_pixel(x, y).a <= A_THRESH:
				visited[idx] = true
				continue
			var q: Array = [[x, y]]
			visited[idx] = true
			var cells: Array = []
			while not q.is_empty():
				var p: Array = q.pop_back()
				var cx: int = int(p[0])
				var cy: int = int(p[1])
				cells.append(Vector2(cx, cy))
				for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
					var nx: int = cx + int(d[0])
					var ny: int = cy + int(d[1])
					if nx < 0 or ny < 0 or nx >= w or ny >= h:
						continue
					var nidx := ny * w + nx
					if visited[nidx]:
						continue
					visited[nidx] = true
					if img.get_pixel(nx, ny).a > A_THRESH:
						q.append([nx, ny])
			if cells.size() > best.size():
				best = cells
	return best


func _foot_of_main(img: Image) -> Vector2:
	var cells: Array = _main_component(img)
	if cells.is_empty():
		return Vector2(img.get_width() * 0.5, img.get_height() - 1.0)
	var minx := 99999
	var miny := 99999
	var maxx := -1
	var maxy := -1
	for c in cells:
		var v: Vector2 = c
		minx = mini(minx, int(v.x))
		miny = mini(miny, int(v.y))
		maxx = maxi(maxx, int(v.x))
		maxy = maxi(maxy, int(v.y))
	var band := maxi(6, int((maxy - miny + 1) * 0.18))
	var band_top := maxy - band + 1
	var sumx := 0.0
	var n := 0
	var foot_y := float(maxy)
	for c in cells:
		var v: Vector2 = c
		if int(v.y) >= band_top:
			sumx += v.x
			n += 1
			foot_y = maxf(foot_y, v.y)
	if n == 0:
		return Vector2((minx + maxx) * 0.5, float(maxy))
	return Vector2(sumx / float(n), foot_y)


func _torso_cx_main(img: Image) -> float:
	var cells: Array = _main_component(img)
	if cells.is_empty():
		return img.get_width() * 0.5
	var minx := 99999
	var miny := 99999
	var maxx := -1
	var maxy := -1
	for c in cells:
		var v: Vector2 = c
		minx = mini(minx, int(v.x))
		miny = mini(miny, int(v.y))
		maxx = maxi(maxx, int(v.x))
		maxy = maxi(maxy, int(v.y))
	var bh := maxy - miny + 1
	var y1 := miny + int(bh * 0.22)
	var y2 := miny + int(bh * 0.62)
	var xs: Array = []
	for c in cells:
		var v: Vector2 = c
		var yy := int(v.y)
		if yy >= y1 and yy <= y2:
			xs.append(int(v.x))
	if xs.is_empty():
		return (minx + maxx) * 0.5
	xs.sort()
	var lo := int(xs.size() * 0.18)
	var hi := maxi(lo + 1, int(xs.size() * 0.82))
	var sum := 0.0
	for i in range(lo, hi):
		sum += float(xs[i])
	return sum / float(hi - lo)
