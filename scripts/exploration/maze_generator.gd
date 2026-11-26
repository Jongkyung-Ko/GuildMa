class_name MazeGenerator
extends RefCounted

## Builds a maze-like room graph for hunting grounds (NOT dungeon floors).
## Connections are bidirectional and direction-consistent (N↔S, E↔W).

const DIRS := ["N", "E", "S", "W"]
const OPPOSITE := {"N": "S", "S": "N", "E": "W", "W": "E"}
const DELTA := {
	"N": Vector2i(0, -1),
	"S": Vector2i(0, 1),
	"E": Vector2i(1, 0),
	"W": Vector2i(-1, 0),
}


static func generate(hunt: Dictionary, seed_override: int = -1) -> Dictionary:
	var gw := int(hunt.get("grid", [5, 5])[0])
	var gh := int(hunt.get("grid", [5, 5])[1])
	var want := int(hunt.get("room_count", 12))
	want = clampi(want, 6, gw * gh)
	var loops := int(hunt.get("loop_edges", 2))
	var seed_v := seed_override if seed_override >= 0 else int(hunt.get("seed", 1))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v

	# Pick cells via randomized growing tree
	var start := Vector2i(rng.randi_range(0, gw - 1), gh - 1)  # south edge start
	var cells: Array[Vector2i] = [start]
	var cell_set := {}
	cell_set[start] = true
	var frontier: Array[Vector2i] = [start]
	while cells.size() < want and not frontier.is_empty():
		var idx := rng.randi_range(0, frontier.size() - 1)
		var cur: Vector2i = frontier[idx]
		var opts: Array[Vector2i] = []
		for d in DIRS:
			var n: Vector2i = cur + DELTA[d]
			if n.x < 0 or n.y < 0 or n.x >= gw or n.y >= gh:
				continue
			if cell_set.has(n):
				continue
			opts.append(n)
		if opts.is_empty():
			frontier.remove_at(idx)
			continue
		var nxt: Vector2i = opts[rng.randi_range(0, opts.size() - 1)]
		cells.append(nxt)
		cell_set[nxt] = true
		frontier.append(nxt)

	# Perfect spanning tree via randomized Prim on selected cells
	var edges: Array = []  # {a:Vector2i, b:Vector2i, dir:String}
	var in_tree := {}
	in_tree[start] = true
	var tree_frontier: Array = []
	_add_frontier_edges(start, cell_set, in_tree, tree_frontier, gw, gh)
	while not tree_frontier.is_empty() and in_tree.size() < cells.size():
		var ei := rng.randi_range(0, tree_frontier.size() - 1)
		var e: Dictionary = tree_frontier[ei]
		tree_frontier.remove_at(ei)
		var b: Vector2i = e["b"]
		if in_tree.has(b):
			continue
		edges.append(e)
		in_tree[b] = true
		_add_frontier_edges(b, cell_set, in_tree, tree_frontier, gw, gh)

	# Extra loops (reconnections)
	var candidates: Array = []
	for c in cells:
		for d in DIRS:
			var n: Vector2i = c + DELTA[d]
			if not cell_set.has(n):
				continue
			if _has_edge(edges, c, n):
				continue
			# store undirected once
			if c.x < n.x or (c.x == n.x and c.y < n.y):
				candidates.append({"a": c, "b": n, "dir": d})
	candidates.shuffle()
	# RandomNumberGenerator has no shuffle for Array — manual
	for i in range(candidates.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp
	var added := 0
	for e in candidates:
		if added >= loops:
			break
		edges.append(e)
		added += 1

	# Build room dicts
	var rooms := {}
	var name_pool: Array = hunt.get("room_names", {}).get("normal", ["숲길"]).duplicate()
	var elite_names: Array = hunt.get("room_names", {}).get("elite", ["정예 구역"]).duplicate()
	var treasure_names: Array = hunt.get("room_names", {}).get("treasure", ["보물터"]).duplicate()
	for i in range(name_pool.size() - 1, 0, -1):
		var j2 := rng.randi_range(0, i)
		var t = name_pool[i]
		name_pool[i] = name_pool[j2]
		name_pool[j2] = t

	var farthest := start
	var far_d := -1
	for c in cells:
		var d := absi(c.x - start.x) + absi(c.y - start.y)
		if d > far_d:
			far_d = d
			farthest = c

	var dead_ends: Array[Vector2i] = []
	for c in cells:
		if c == start or c == farthest:
			continue
		var deg := 0
		for d in DIRS:
			var n: Vector2i = c + DELTA[d]
			if _has_edge(edges, c, n):
				deg += 1
		if deg == 1:
			dead_ends.append(c)

	var treasure_cell = dead_ends[0] if dead_ends.size() > 0 else null
	var elite_cell = dead_ends[1] if dead_ends.size() > 1 else null
	if elite_cell == null:
		for c in cells:
			if c != start and c != farthest and c != treasure_cell:
				elite_cell = c
				break

	var ni := 0
	for c in cells:
		var rid := _rid(c)
		var rtype := "normal"
		var rname := ""
		var boss := false
		if c == start:
			rtype = "start"
			rname = str(hunt.get("room_names", {}).get("start", "입구"))
		elif c == farthest:
			rtype = "boss"
			rname = str(hunt.get("room_names", {}).get("boss", "보스 방"))
			boss = true
		elif treasure_cell != null and c == treasure_cell:
			rtype = "treasure"
			rname = str(treasure_names[0] if treasure_names.size() > 0 else "보물 방")
		elif elite_cell != null and c == elite_cell:
			rtype = "elite"
			rname = str(elite_names[0] if elite_names.size() > 0 else "정예 방")
		else:
			rtype = "normal"
			rname = str(name_pool[ni % maxi(1, name_pool.size())]) if name_pool.size() > 0 else "숲길"
			ni += 1
		rooms[rid] = {
			"room_id": rid,
			"room_type": rtype,
			"name": rname,
			"position": [c.x, c.y],
			"connected_rooms": {"N": null, "E": null, "S": null, "W": null},
			"discovered": c == start,
			"cleared": false,
			"monsters": _monsters_for(hunt, rtype, rng),
			"reward": {"gold": 10 if rtype == "normal" else (40 if rtype == "treasure" else 25)},
			"boss_flag": boss,
			"rec_level": int(hunt.get("rec_level", 1)),
			"area_type": _area_type_label(rtype),
		}

	for e in edges:
		var a: Vector2i = e["a"]
		var b: Vector2i = e["b"]
		var dir: String = str(e["dir"])
		# Ensure dir points a→b
		var expect: Vector2i = a + DELTA[dir]
		if expect != b:
			dir = _dir_between(a, b)
		var ra: Dictionary = rooms[_rid(a)]
		var rb: Dictionary = rooms[_rid(b)]
		ra["connected_rooms"][dir] = rb["room_id"]
		rb["connected_rooms"][OPPOSITE[dir]] = ra["room_id"]

	var map := {
		"hunt_id": str(hunt.get("id", "")),
		"hunt_name": str(hunt.get("name", "")),
		"region": str(hunt.get("region", "")),
		"seed": seed_v,
		"grid": [gw, gh],
		"current_room_id": _rid(start),
		"rooms": rooms,
		"path": [_rid(start)],
	}
	var err := validate(map)
	if err != "":
		push_error("MazeGenerator validation failed: %s" % err)
	# Discover neighbors of start
	_discover_adjacent(map, _rid(start))
	return map


static func validate(map: Dictionary) -> String:
	var rooms: Dictionary = map.get("rooms", {})
	if rooms.is_empty():
		return "no rooms"
	for rid in rooms.keys():
		var r: Dictionary = rooms[rid]
		var cons: Dictionary = r.get("connected_rooms", {})
		for d in DIRS:
			var other = cons.get(d, null)
			if other == null:
				continue
			if typeof(other) != TYPE_STRING and typeof(other) != TYPE_STRING_NAME:
				return "bad link type %s.%s" % [rid, d]
			var oid := str(other)
			if not rooms.has(oid):
				return "missing room %s from %s.%s" % [oid, rid, d]
			var back: Dictionary = rooms[oid].get("connected_rooms", {})
			var opp: String = str(OPPOSITE[d])
			if str(back.get(opp, "")) != rid:
				return "asymmetric %s -%s-> %s (back %s)" % [rid, d, oid, str(back.get(opp))]
			var pa: Array = r.get("position", [0, 0])
			var pb: Array = rooms[oid].get("position", [0, 0])
			var a := Vector2i(int(pa[0]), int(pa[1]))
			var b := Vector2i(int(pb[0]), int(pb[1]))
			if a + DELTA[d] != b:
				return "dir/pos mismatch %s %s %s" % [rid, d, oid]
	# connectivity
	var start_id := str(map.get("current_room_id", ""))
	if not rooms.has(start_id):
		return "bad start"
	var seen := {}
	var q: Array = [start_id]
	seen[start_id] = true
	while not q.is_empty():
		var cur: String = str(q.pop_front())
		var cons2: Dictionary = rooms[cur].get("connected_rooms", {})
		for d in DIRS:
			var o = cons2.get(d, null)
			if o == null:
				continue
			var oid2 := str(o)
			if not seen.has(oid2):
				seen[oid2] = true
				q.append(oid2)
	if seen.size() != rooms.size():
		return "not fully connected (%d/%d)" % [seen.size(), rooms.size()]
	return ""


static func _discover_adjacent(map: Dictionary, room_id: String) -> void:
	var rooms: Dictionary = map.get("rooms", {})
	if not rooms.has(room_id):
		return
	var cons: Dictionary = rooms[room_id].get("connected_rooms", {})
	for d in DIRS:
		var o = cons.get(d, null)
		if o == null:
			continue
		var oid := str(o)
		if rooms.has(oid):
			rooms[oid]["discovered"] = true


static func _monsters_for(hunt: Dictionary, rtype: String, rng: RandomNumberGenerator) -> Array:
	var pool: Array = hunt.get("monster_pool", ["wolf"]).duplicate()
	var elite: Array = hunt.get("elite_pool", pool).duplicate()
	match rtype:
		"start":
			return [str(pool[0])]
		"boss":
			return [str(hunt.get("boss_enemy", pool[0]))]
		"elite":
			var a := str(elite[rng.randi_range(0, elite.size() - 1)])
			var b := str(elite[rng.randi_range(0, elite.size() - 1)])
			return [a, b, a]
		"treasure":
			return [str(pool[rng.randi_range(0, pool.size() - 1)])]
		_:
			var n := rng.randi_range(2, 3)
			var out: Array = []
			for _i in n:
				out.append(str(pool[rng.randi_range(0, pool.size() - 1)]))
			return out


static func _area_type_label(rtype: String) -> String:
	match rtype:
		"start":
			return "입구"
		"boss":
			return "보스 지역"
		"elite":
			return "정예 지역"
		"treasure":
			return "보물 지역"
		_:
			return "일반 지역"


static func _rid(c: Vector2i) -> String:
	return "r_%d_%d" % [c.x, c.y]


static func _dir_between(a: Vector2i, b: Vector2i) -> String:
	var d := b - a
	for k in DIRS:
		if DELTA[k] == d:
			return k
	return "N"


static func _has_edge(edges: Array, a: Vector2i, b: Vector2i) -> bool:
	for e in edges:
		var ea: Vector2i = e["a"]
		var eb: Vector2i = e["b"]
		if (ea == a and eb == b) or (ea == b and eb == a):
			return true
	return false


static func _add_frontier_edges(
	cell: Vector2i,
	cell_set: Dictionary,
	in_tree: Dictionary,
	frontier: Array,
	_gw: int,
	_gh: int
) -> void:
	for d in DIRS:
		var n: Vector2i = cell + DELTA[d]
		if not cell_set.has(n):
			continue
		if in_tree.has(n):
			continue
		frontier.append({"a": cell, "b": n, "dir": d})
