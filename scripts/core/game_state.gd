extends Node

signal state_changed
signal message_emitted(text: String, is_error: bool)

const SAVE_PATH := "user://guildmaster_save.json"

var balance: Dictionary = {}
var catalog_items: Array = []
var adventurer_pool: Array = []
var quest_catalog: Array = []
var dungeon_catalog: Dictionary = {}
var hunt_catalog: Dictionary = {}

var gold: int = 0
var reputation: int = 0
var guild_name: String = "라이온하트"
var guild_level: int = 1
var day: int = 1
var season: String = "봄"
var hour: int = 8
var minute: int = 0
var members: Array = []
var inventory: Array = [] # {id, qty}
var active_quests: Array = []
var recruited_ids: Array = []
## Separate from hunting-ground exploration. Keyed by dungeon id.
var dungeon_progress: Dictionary = {}
## Hunting-ground maze runs. Keyed by hunt id. Separate from dungeon floors.
var hunt_progress: Dictionary = {}
## Active run map snapshot (also mirrored under hunt_progress[hunt_id].map).
var active_hunt_id: String = ""
## Guild Hall mission parties — member id lists only (not full copies).
## hunt syncs to member.in_party for combat spawn (max 5).
## Exclusive: a member may belong to at most one of hunt / train / defend.
var guild_parties: Dictionary = {"hunt": [], "train": [], "defend": []}
var selected_guild_member_id: String = ""
const GUILD_PARTY_KINDS := ["hunt", "train", "defend"]
const GUILD_PARTY_MAX := {"hunt": 5, "train": 5, "defend": 5}
var _combat_balance: Dictionary = {}
var has_save: bool = false
var is_playing: bool = false
var message_log: Array = []
var _time_accum: float = 0.0


func _ready() -> void:
	_load_static_data()
	has_save = FileAccess.file_exists(SAVE_PATH)


func _process(delta: float) -> void:
	if not is_playing:
		return
	var rate: float = float(balance.get("minutes_per_real_second", 2))
	_time_accum += delta * rate
	while _time_accum >= 1.0:
		_time_accum -= 1.0
		minute += 1
		if minute >= 60:
			minute = 0
			hour += 1
			if hour >= 24:
				hour = 0
				day += 1
				if day > 30:
					day = 1
					season = _next_season(season)
		state_changed.emit()


func _load_static_data() -> void:
	balance = _read_json("res://data/balance.json")
	catalog_items = _read_json("res://data/items.json").get("items", [])
	adventurer_pool = _read_json("res://data/adventurers.json").get("pool", [])
	quest_catalog = _read_json("res://data/quests.json").get("quests", [])
	dungeon_catalog = _read_json("res://data/combat/dungeons.json")
	hunt_catalog = _read_json("res://data/combat/hunts.json")
	_combat_balance = _read_json("res://data/combat/balance_combat.json")


func _read_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Failed to read %s" % path)
		return {}
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	return data


func new_game() -> void:
	gold = int(balance.get("starting_gold", 5000))
	reputation = int(balance.get("starting_reputation", 10))
	guild_name = str(balance.get("guild_name_default", "라이온하트"))
	guild_level = 1
	day = int(balance.get("starting_day", 1))
	season = str(balance.get("starting_season", "봄"))
	hour = int(balance.get("starting_hour", 8))
	minute = int(balance.get("starting_minute", 0))
	inventory = []
	active_quests = []
	recruited_ids = []
	dungeon_progress = {}
	hunt_progress = {}
	active_hunt_id = ""
	message_log = []
	members = _create_starting_party()
	guild_parties = {"hunt": [], "train": [], "defend": []}
	for m in members:
		if bool(m.get("in_party", false)):
			guild_parties["hunt"].append(str(m.get("id")))
	selected_guild_member_id = str(members[0].get("id", "")) if not members.is_empty() else ""
	is_playing = true
	save_game()
	emit_message("새 게임을 시작합니다. 마을에 오신 것을 환영합니다.")
	state_changed.emit()


func _create_starting_party() -> Array:
	return [
		_member("m_lord", "아렌", "lord", 1, {"str": 7, "vit": 7, "agi": 6, "int": 6, "wis": 6}, ["지휘"], false),
		_member("m_tank", "가렌", "tank", 1, {"str": 8, "vit": 10, "agi": 4, "int": 2, "wis": 3}, ["방패 막기"], false),
		_member("m_dps", "리사", "dps", 1, {"str": 9, "vit": 5, "agi": 10, "int": 3, "wis": 2}, ["연속 베기"], false),
		_member("m_healer", "세이라", "healer", 1, {"str": 3, "vit": 6, "agi": 5, "int": 6, "wis": 11}, ["치유"], false),
		_member("m_mage", "카이", "mage", 1, {"str": 2, "vit": 4, "agi": 5, "int": 11, "wis": 8}, ["마력탄"], false),
	]


func _member(id: String, name: String, job: String, level: int, stats: Dictionary, skills: Array, injured: bool) -> Dictionary:
	return {
		"id": id,
		"name": name,
		"job": job,
		"level": level,
		"exp": 0,
		"stats": stats.duplicate(true),
		"skills": skills.duplicate(),
		"traits": [],
		"upkeep": 20 if job != "lord" else 0,
		"injured": injured,
		"equipment": {"weapon": "", "armor": "", "accessory": ""},
		"in_party": true,
	}


func time_text() -> String:
	return "%s %d일 %02d:%02d" % [season, day, hour, minute]


func member_count_text() -> String:
	return "%d / %d" % [members.size(), int(balance.get("max_members", 50))]


func get_item(item_id: String) -> Dictionary:
	for it in catalog_items:
		if it.get("id") == item_id:
			return it
	return {}


func inventory_qty(item_id: String) -> int:
	for e in inventory:
		if e.get("id") == item_id:
			return int(e.get("qty", 0))
	return 0


func add_item(item_id: String, qty: int = 1) -> void:
	for e in inventory:
		if e.get("id") == item_id:
			e["qty"] = int(e.get("qty", 0)) + qty
			state_changed.emit()
			return
	inventory.append({"id": item_id, "qty": qty})
	state_changed.emit()


func spend_gold(amount: int) -> bool:
	if gold < amount:
		emit_message("골드가 부족합니다.", true)
		return false
	gold -= amount
	state_changed.emit()
	return true


func add_gold(amount: int) -> void:
	gold += amount
	state_changed.emit()


func can_recruit(adv_id: String) -> bool:
	return not recruited_ids.has(adv_id)


func recruit_adventurer(adv: Dictionary) -> bool:
	var adv_id: String = str(adv.get("id", ""))
	if recruited_ids.has(adv_id):
		emit_message("이미 영입한 모험가입니다.", true)
		return false
	if members.size() >= int(balance.get("max_members", 50)):
		emit_message("길드 인원이 가득 찼습니다.", true)
		return false
	var fee: int = int(adv.get("contract", 0))
	if not spend_gold(fee):
		return false
	var m := _member(
		adv_id,
		str(adv.get("name")),
		str(adv.get("job")),
		int(adv.get("level", 1)),
		{
			"str": int(adv.get("str", 5)),
			"vit": int(adv.get("vit", 5)),
			"agi": int(adv.get("agi", 5)),
			"int": int(adv.get("int", 5)),
			"wis": int(adv.get("wis", 5)),
		},
		adv.get("skills", []),
		false
	)
	m["traits"] = adv.get("traits", []).duplicate()
	m["upkeep"] = int(adv.get("upkeep", 40))
	m["in_party"] = false
	members.append(m)
	recruited_ids.append(adv_id)
	emit_message("%s 을(를) 길드에 영입했습니다." % m["name"])
	save_game()
	return true


func buy_item(item_id: String, qty: int = 1) -> bool:
	var item := get_item(item_id)
	if item.is_empty():
		emit_message("존재하지 않는 아이템입니다.", true)
		return false
	var price: int = int(item.get("price", 0)) * qty
	if not spend_gold(price):
		return false
	add_item(item_id, qty)
	emit_message("%s x%d 구매 완료 (−%d G)" % [item.get("name"), qty, price])
	save_game()
	return true


func equip_item(member_id: String, item_id: String) -> bool:
	var item := get_item(item_id)
	var slot: String = str(item.get("slot", ""))
	if slot == "":
		emit_message("장착할 수 없는 아이템입니다.", true)
		return false
	if inventory_qty(item_id) <= 0:
		emit_message("보유하지 않은 장비입니다.", true)
		return false
	for m in members:
		if m.get("id") == member_id:
			m["equipment"][slot] = item_id
			emit_message("%s 에게 %s 장착" % [m.get("name"), item.get("name")])
			var audio := get_node_or_null("/root/AudioManager")
			if audio and audio.has_method("play_equip"):
				audio.play_equip()
			state_changed.emit()
			save_game()
			return true
	emit_message("길드원을 찾을 수 없습니다.", true)
	return false


func train_member(member_id: String) -> bool:
	var cost: int = int(balance.get("train_gold_cost", 50))
	var exp_gain: int = int(balance.get("train_exp_gain", 25))
	if not spend_gold(cost):
		return false
	for m in members:
		if m.get("id") == member_id:
			if m.get("injured", false):
				emit_message("부상 중인 길드원은 훈련할 수 없습니다.", true)
				gold += cost
				return false
			m["exp"] = int(m.get("exp", 0)) + exp_gain
			while int(m["exp"]) >= 100:
				m["exp"] = int(m["exp"]) - 100
				m["level"] = int(m["level"]) + 1
				emit_message("%s 레벨 업! (Lv.%d)" % [m["name"], m["level"]])
			emit_message("%s 훈련 완료 (+%d EXP)" % [m["name"], exp_gain])
			state_changed.emit()
			save_game()
			return true
	gold += cost
	emit_message("길드원을 찾을 수 없습니다.", true)
	return false


func heal_member(member_id: String) -> bool:
	var cost: int = int(balance.get("heal_gold_cost", 80))
	for m in members:
		if m.get("id") == member_id:
			if not m.get("injured", false):
				emit_message("회복이 필요한 상태가 아닙니다.", true)
				return false
			if not spend_gold(cost):
				return false
			m["injured"] = false
			emit_message("%s 가 회복되었습니다." % m["name"])
			save_game()
			return true
	emit_message("길드원을 찾을 수 없습니다.", true)
	return false


func accept_quest(quest_id: String) -> bool:
	for q in active_quests:
		if q.get("id") == quest_id:
			emit_message("이미 수락한 의뢰입니다.", true)
			return false
	for q in quest_catalog:
		if q.get("id") == quest_id:
			var aq: Dictionary = q.duplicate(true)
			aq["status"] = "active"
			active_quests.append(aq)
			emit_message("의뢰 수락: %s" % q.get("name"))
			# Phase1: no combat — mark ready for later completion pipeline
			state_changed.emit()
			save_game()
			return true
	emit_message("의뢰를 찾을 수 없습니다.", true)
	return false


func set_injured_for_test(member_id: String, value: bool = true) -> void:
	for m in members:
		if m.get("id") == member_id:
			m["injured"] = value
			state_changed.emit()
			return


func emit_message(text: String, is_error: bool = false) -> void:
	message_log.push_front({"text": text, "error": is_error, "time": time_text()})
	if message_log.size() > 40:
		message_log.resize(40)
	message_emitted.emit(text, is_error)


func save_game() -> void:
	var data := {
		"gold": gold,
		"reputation": reputation,
		"guild_name": guild_name,
		"guild_level": guild_level,
		"day": day,
		"season": season,
		"hour": hour,
		"minute": minute,
		"members": members,
		"inventory": inventory,
		"active_quests": active_quests,
		"recruited_ids": recruited_ids,
		"dungeon_progress": dungeon_progress,
		"hunt_progress": hunt_progress,
		"active_hunt_id": active_hunt_id,
		"guild_parties": guild_parties,
		"selected_guild_member_id": selected_guild_member_id,
		"message_log": message_log,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("Save failed")
		return
	f.store_string(JSON.stringify(data, "\t"))
	has_save = true


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		emit_message("저장 데이터가 없습니다.", true)
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		emit_message("저장 파일이 손상되었습니다.", true)
		return false
	gold = int(data.get("gold", 0))
	reputation = int(data.get("reputation", 0))
	guild_name = str(data.get("guild_name", "라이온하트"))
	guild_level = int(data.get("guild_level", 1))
	day = int(data.get("day", 1))
	season = str(data.get("season", "봄"))
	hour = int(data.get("hour", 8))
	minute = int(data.get("minute", 0))
	members = data.get("members", [])
	inventory = data.get("inventory", [])
	active_quests = data.get("active_quests", [])
	recruited_ids = data.get("recruited_ids", [])
	dungeon_progress = data.get("dungeon_progress", {})
	if typeof(dungeon_progress) != TYPE_DICTIONARY:
		dungeon_progress = {}
	hunt_progress = data.get("hunt_progress", {})
	if typeof(hunt_progress) != TYPE_DICTIONARY:
		hunt_progress = {}
	active_hunt_id = str(data.get("active_hunt_id", ""))
	message_log = data.get("message_log", [])
	selected_guild_member_id = str(data.get("selected_guild_member_id", ""))
	_load_guild_parties(data.get("guild_parties", null))
	is_playing = true
	emit_message("게임을 불러왔습니다.")
	state_changed.emit()
	return true


# --- Guild Hall parties (id references only) ---

func get_member_by_id(member_id: String) -> Dictionary:
	for m in members:
		if str(m.get("id", "")) == member_id:
			return m
	return {}


func get_guild_party(kind: String) -> Array:
	_ensure_guild_parties()
	var arr = guild_parties.get(kind, [])
	return arr if typeof(arr) == TYPE_ARRAY else []


func guild_party_label(kind: String) -> String:
	match kind:
		"hunt":
			return "사냥 파티"
		"train":
			return "훈련 파티"
		"defend":
			return "수비 파티"
		_:
			return kind


func guild_party_purpose(kind: String) -> String:
	match kind:
		"hunt":
			return "사냥터 탐험 · 몬스터 토벌 · 재료 · 경험치"
		"train":
			return "전투 훈련 · 기술 숙련 · 성장 준비"
		"defend":
			return "길드 성 · 마을 방어 · 위기 대응"
		_:
			return ""


func member_party_kind(member_id: String) -> String:
	_ensure_guild_parties()
	for kind in GUILD_PARTY_KINDS:
		for mid in get_guild_party(kind):
			if str(mid) == member_id:
				return kind
	return ""


func set_guild_party(kind: String, ids: Array) -> bool:
	if not GUILD_PARTY_KINDS.has(kind):
		emit_message("알 수 없는 파티 유형입니다.", true)
		return false
	_ensure_guild_parties()
	var max_n: int = int(GUILD_PARTY_MAX.get(kind, 5))
	var cleaned: Array = []
	var seen := {}
	for raw in ids:
		var mid := str(raw)
		if mid == "" or seen.has(mid):
			continue
		if get_member_by_id(mid).is_empty():
			continue
		seen[mid] = true
		cleaned.append(mid)
		if cleaned.size() >= max_n:
			break
	# Exclusive: remove these members from other mission parties.
	for other in GUILD_PARTY_KINDS:
		if other == kind:
			continue
		var kept: Array = []
		for mid2 in get_guild_party(other):
			if not cleaned.has(str(mid2)):
				kept.append(str(mid2))
		guild_parties[other] = kept
	guild_parties[kind] = cleaned
	_sync_hunt_in_party_flags()
	save_game()
	state_changed.emit()
	emit_message("%s 편성을 저장했습니다. (%d명)" % [guild_party_label(kind), cleaned.size()])
	return true


func toggle_member_in_party(kind: String, member_id: String) -> bool:
	_ensure_guild_parties()
	if not GUILD_PARTY_KINDS.has(kind):
		return false
	if get_member_by_id(member_id).is_empty():
		return false
	var current: Array = get_guild_party(kind).duplicate()
	var sid := str(member_id)
	if current.has(sid):
		current.erase(sid)
	else:
		var max_n: int = int(GUILD_PARTY_MAX.get(kind, 5))
		if current.size() >= max_n:
			emit_message("파티 인원이 가득 찼습니다. (최대 %d)" % max_n, true)
			return false
		current.append(sid)
	return set_guild_party(kind, current)


## Combat-derived preview — same formulas as CombatCharacter.setup_from_member.
## Does not invent DEX/LUK; uses only stored str/vit/agi/int/wis + level.
func compute_combat_preview(member: Dictionary) -> Dictionary:
	if member.is_empty():
		return {}
	var bal := _combat_balance if not _combat_balance.is_empty() else _read_json("res://data/combat/balance_combat.json")
	var level: int = int(member.get("level", 1))
	var stats: Dictionary = member.get("stats", {})
	var vit: float = float(stats.get("vit", 5))
	var stre: float = float(stats.get("str", 5))
	var agi: float = float(stats.get("agi", 5))
	var job := str(member.get("job", "dps"))
	var hp_max: float = float(bal.get("hp_base", 80)) + vit * float(bal.get("hp_vit", 12)) + level * float(bal.get("hp_level", 8))
	if job == "lord":
		hp_max += float(bal.get("hp_lord_bonus", 20))
	var atk: float = float(bal.get("atk_base", 5)) + stre * float(bal.get("atk_str", 2)) + level * float(bal.get("atk_level", 1))
	var defense: float = float(bal.get("def_base", 2)) + vit * float(bal.get("def_vit", 1)) + level / float(bal.get("def_level_div", 2))
	var move_speed: float = minf(float(bal.get("move_cap", 220)), float(bal.get("move_base", 115)) + agi * float(bal.get("move_agi", 2.5)))
	return {
		"hp": int(round(hp_max)),
		"atk": int(round(atk)),
		"def": int(round(defense)),
		"spd": int(round(move_speed)),
	}


func select_guild_member(member_id: String) -> void:
	if get_member_by_id(member_id).is_empty():
		return
	selected_guild_member_id = member_id
	save_game()
	state_changed.emit()


func _ensure_guild_parties() -> void:
	if typeof(guild_parties) != TYPE_DICTIONARY:
		guild_parties = {}
	for kind in GUILD_PARTY_KINDS:
		if not guild_parties.has(kind) or typeof(guild_parties[kind]) != TYPE_ARRAY:
			guild_parties[kind] = []


func _load_guild_parties(raw) -> void:
	guild_parties = {"hunt": [], "train": [], "defend": []}
	if typeof(raw) == TYPE_DICTIONARY:
		for kind in GUILD_PARTY_KINDS:
			var src = raw.get(kind, [])
			if typeof(src) != TYPE_ARRAY:
				continue
			for mid in src:
				var sid := str(mid)
				if not get_member_by_id(sid).is_empty() and not guild_parties[kind].has(sid):
					# Skip if already claimed by earlier kind (exclusive migrate).
					var claimed := false
					for other in GUILD_PARTY_KINDS:
						if other == kind:
							break
						if guild_parties[other].has(sid):
							claimed = true
							break
					if not claimed:
						guild_parties[kind].append(sid)
	# Legacy saves: no guild_parties → seed hunt from in_party.
	if get_guild_party("hunt").is_empty() and get_guild_party("train").is_empty() and get_guild_party("defend").is_empty():
		for m in members:
			if bool(m.get("in_party", false)):
				guild_parties["hunt"].append(str(m.get("id")))
	_sync_hunt_in_party_flags()
	if selected_guild_member_id == "" or get_member_by_id(selected_guild_member_id).is_empty():
		if not members.is_empty():
			selected_guild_member_id = str(members[0].get("id", ""))


func _sync_hunt_in_party_flags() -> void:
	_ensure_guild_parties()
	var hunt_set := {}
	for mid in get_guild_party("hunt"):
		hunt_set[str(mid)] = true
	for m in members:
		m["in_party"] = hunt_set.has(str(m.get("id", "")))


# --- Dungeon vertical progression (separate from hunting-ground exploration) ---

func get_dungeon_def(dungeon_id: String) -> Dictionary:
	for d in dungeon_catalog.get("dungeons", []):
		if str(d.get("id", "")) == dungeon_id:
			return d
	return {}


func ensure_dungeon_progress(dungeon_id: String) -> Dictionary:
	if dungeon_progress.has(dungeon_id) and typeof(dungeon_progress[dungeon_id]) == TYPE_DICTIONARY:
		return dungeon_progress[dungeon_id]
	var fresh := {
		"current_floor": 1,
		"deepest_floor": 1,
		"visited": [1],
		"cleared": [],
		"floors": {},
		"mid_boss_defeated": false,
		"final_boss_defeated": false,
	}
	dungeon_progress[dungeon_id] = fresh
	return fresh


func get_dungeon_floor_def(dungeon_id: String, floor: int) -> Dictionary:
	var def := get_dungeon_def(dungeon_id)
	var floors: Dictionary = def.get("floors", {})
	return floors.get(str(floor), {})


func dungeon_current_floor(dungeon_id: String) -> int:
	return int(ensure_dungeon_progress(dungeon_id).get("current_floor", 1))


func dungeon_is_floor_cleared(dungeon_id: String, floor: int) -> bool:
	var prog := ensure_dungeon_progress(dungeon_id)
	var cleared: Array = prog.get("cleared", [])
	return cleared.has(floor) or cleared.has(float(floor)) or cleared.has(str(floor))


func dungeon_is_floor_unlocked(dungeon_id: String, floor: int) -> bool:
	if floor <= 1:
		return true
	# Next floor unlocks only after previous is cleared.
	return dungeon_is_floor_cleared(dungeon_id, floor - 1)


func dungeon_can_go_next(dungeon_id: String) -> bool:
	var prog := ensure_dungeon_progress(dungeon_id)
	var cur := int(prog.get("current_floor", 1))
	var def := get_dungeon_def(dungeon_id)
	var max_f := int(def.get("max_floor", 1))
	if cur >= max_f:
		return false
	if not dungeon_is_floor_cleared(dungeon_id, cur):
		return false
	return dungeon_is_floor_unlocked(dungeon_id, cur + 1)


func dungeon_set_floor(dungeon_id: String, floor: int) -> bool:
	var def := get_dungeon_def(dungeon_id)
	if def.is_empty():
		return false
	var max_f := int(def.get("max_floor", 1))
	floor = clampi(floor, 1, max_f)
	if not dungeon_is_floor_unlocked(dungeon_id, floor):
		emit_message("%d층은 아직 잠겨 있습니다." % floor, true)
		return false
	var prog := ensure_dungeon_progress(dungeon_id)
	prog["current_floor"] = floor
	var visited: Array = prog.get("visited", [])
	if not (visited.has(floor) or visited.has(float(floor)) or visited.has(str(floor))):
		visited.append(floor)
	prog["visited"] = visited
	prog["deepest_floor"] = maxi(int(prog.get("deepest_floor", 1)), floor)
	var floors: Dictionary = prog.get("floors", {})
	if not floors.has(str(floor)):
		floors[str(floor)] = {"cleared": false, "kills": 0}
	prog["floors"] = floors
	dungeon_progress[dungeon_id] = prog
	save_game()
	state_changed.emit()
	return true


func mark_dungeon_floor_cleared(dungeon_id: String, floor: int, kills: int = 0) -> void:
	var prog := ensure_dungeon_progress(dungeon_id)
	var cleared: Array = prog.get("cleared", [])
	if not (cleared.has(floor) or cleared.has(float(floor)) or cleared.has(str(floor))):
		cleared.append(floor)
	prog["cleared"] = cleared
	var floors: Dictionary = prog.get("floors", {})
	var entry: Dictionary = floors.get(str(floor), {"cleared": false, "kills": 0})
	entry["cleared"] = true
	entry["kills"] = maxi(int(entry.get("kills", 0)), kills)
	floors[str(floor)] = entry
	prog["floors"] = floors
	prog["deepest_floor"] = maxi(int(prog.get("deepest_floor", 1)), floor)
	var floor_def := get_dungeon_floor_def(dungeon_id, floor)
	var boss := str(floor_def.get("boss", ""))
	if boss == "mid":
		prog["mid_boss_defeated"] = true
	elif boss == "final":
		prog["final_boss_defeated"] = true
	dungeon_progress[dungeon_id] = prog
	save_game()
	state_changed.emit()
	emit_message("%s %d층 클리어" % [str(get_dungeon_def(dungeon_id).get("name", dungeon_id)), floor])


# --- Hunting-ground maze exploration (separate from dungeon vertical floors) ---

func get_hunt_def(hunt_id: String) -> Dictionary:
	for h in hunt_catalog.get("hunts", []):
		if str(h.get("id", "")) == hunt_id:
			return h
	return {}


func list_hunts() -> Array:
	return hunt_catalog.get("hunts", [])


func get_active_hunt_map() -> Dictionary:
	if active_hunt_id == "":
		return {}
	var prog = hunt_progress.get(active_hunt_id, {})
	if typeof(prog) != TYPE_DICTIONARY:
		return {}
	var m = prog.get("map", {})
	return m if typeof(m) == TYPE_DICTIONARY else {}


func start_hunt_run(hunt_id: String, force_new: bool = false, spawn_at_start: bool = false) -> Dictionary:
	## force_new=true ("새 맵"): replace run with a fresh random-seed maze.
	## force_new=false + existing map: resume layout/clears.
	## spawn_at_start=true: town→hunt re-entry — force entrance room (not mid-maze).
	## Mid-hunt room travel must NOT call this with spawn_at_start.
	var def := get_hunt_def(hunt_id)
	if def.is_empty():
		emit_message("사냥터 정보를 찾을 수 없습니다.", true)
		return {}
	active_hunt_id = hunt_id
	var prog: Dictionary = hunt_progress.get(hunt_id, {}) if typeof(hunt_progress.get(hunt_id, null)) == TYPE_DICTIONARY else {}
	var has_map := prog.has("map") and typeof(prog.get("map")) == TYPE_DICTIONARY and not (prog.get("map") as Dictionary).is_empty()
	if force_new or not has_map:
		var seed_v: int = MazeGenerator.fresh_seed()
		var map: Dictionary = MazeGenerator.generate(def, seed_v)
		prog = {
			"map": map,
			"seed": seed_v,
			"runs": int(prog.get("runs", 0)) + 1,
			## Hunt maze goal boss only — never touches dungeon mid/final flags.
			"goal_boss_cleared": false,
			"pending_spawn_at_start": false,
		}
		hunt_progress[hunt_id] = prog
		save_game()
		state_changed.emit()
		emit_message("%s 탐험을 시작합니다. (seed %d)" % [str(def.get("name", hunt_id)), seed_v])
		return map
	# Resume existing map (cleared rooms + layout kept).
	var map_resume: Dictionary = prog.get("map", {})
	var need_start := spawn_at_start or bool(prog.get("pending_spawn_at_start", false))
	if need_start:
		_reset_map_to_start_room(map_resume)
		prog["map"] = map_resume
		prog["pending_spawn_at_start"] = false
		hunt_progress[hunt_id] = prog
		save_game()
		emit_message("%s 입구에서 탐험을 시작합니다." % str(def.get("name", hunt_id)))
	else:
		emit_message("%s 탐험을 이어갑니다." % str(def.get("name", hunt_id)))
	state_changed.emit()
	return map_resume


func get_hunt_start_room_id(map: Dictionary = {}) -> String:
	var m := map if not map.is_empty() else get_active_hunt_map()
	if m.is_empty():
		return ""
	var rooms: Dictionary = m.get("rooms", {})
	for rid in rooms.keys():
		if str(rooms[rid].get("room_type", "")) == "start":
			return str(rid)
	# Fallback: original path head or current.
	var path: Array = m.get("path", [])
	if path.size() > 0:
		return str(path[0])
	return str(m.get("current_room_id", ""))


func _reset_map_to_start_room(map: Dictionary) -> void:
	if map.is_empty():
		return
	var start_id := get_hunt_start_room_id(map)
	if start_id == "":
		return
	map["current_room_id"] = start_id
	map["path"] = [start_id]
	var rooms: Dictionary = map.get("rooms", {})
	if rooms.has(start_id):
		rooms[start_id]["discovered"] = true
	MazeGenerator._discover_adjacent(map, start_id)


## Call when fully leaving the hunt (town / title). Keeps maze progress; clears session spawn.
## hunt_id_override: use combat-local hunt_id when active_hunt_id was already cleared.
func leave_hunt_session(hunt_id_override: String = "") -> void:
	var hid := hunt_id_override if hunt_id_override != "" else active_hunt_id
	if hid == "" and hunt_progress.is_empty():
		active_hunt_id = ""
		return
	if hid != "":
		var prog: Dictionary = hunt_progress.get(hid, {})
		if typeof(prog) != TYPE_DICTIONARY:
			prog = {}
		if prog.has("map") and typeof(prog.get("map")) == TYPE_DICTIONARY:
			var map: Dictionary = prog.get("map", {})
			if not map.is_empty():
				_reset_map_to_start_room(map)
				prog["map"] = map
		# Belt-and-suspenders for next start_hunt_run even if reset was skipped.
		prog["pending_spawn_at_start"] = true
		hunt_progress[hid] = prog
	active_hunt_id = ""
	save_game()
	state_changed.emit()


func _store_active_map(map: Dictionary) -> void:
	if active_hunt_id == "":
		return
	var prog: Dictionary = hunt_progress.get(active_hunt_id, {})
	if typeof(prog) != TYPE_DICTIONARY:
		prog = {}
	prog["map"] = map
	hunt_progress[active_hunt_id] = prog
	save_game()
	state_changed.emit()


func get_current_hunt_room() -> Dictionary:
	var map := get_active_hunt_map()
	if map.is_empty():
		return {}
	var rid := str(map.get("current_room_id", ""))
	var rooms: Dictionary = map.get("rooms", {})
	return rooms.get(rid, {})


func mark_hunt_room_cleared(room_id: String = "") -> void:
	var map := get_active_hunt_map()
	if map.is_empty():
		return
	var rid := room_id if room_id != "" else str(map.get("current_room_id", ""))
	var rooms: Dictionary = map.get("rooms", {})
	if not rooms.has(rid):
		return
	rooms[rid]["cleared"] = true
	rooms[rid]["discovered"] = true
	MazeGenerator._discover_adjacent(map, rid)
	# Maze goal boss clear stays on hunt_progress only (not dungeon_progress).
	var kind := str(rooms[rid].get("boss_kind", ""))
	if bool(rooms[rid].get("boss_flag", false)) or kind == MazeGenerator.BOSS_KIND_HUNT_GOAL:
		var prog: Dictionary = hunt_progress.get(active_hunt_id, {})
		if typeof(prog) != TYPE_DICTIONARY:
			prog = {}
		prog["goal_boss_cleared"] = true
		prog["map"] = map
		hunt_progress[active_hunt_id] = prog
		emit_message("%s 클리어 (미로 목표 보스)" % str(rooms[rid].get("name", rid)))
	else:
		emit_message("%s 클리어" % str(rooms[rid].get("name", rid)))
	_store_active_map(map)


func hunt_connected_room_ids(room_id: String = "") -> Array:
	var map := get_active_hunt_map()
	if map.is_empty():
		return []
	var rid := room_id if room_id != "" else str(map.get("current_room_id", ""))
	var rooms: Dictionary = map.get("rooms", {})
	if not rooms.has(rid):
		return []
	var out: Array = []
	var cons: Dictionary = rooms[rid].get("connected_rooms", {})
	for d in MazeGenerator.DIRS:
		var o = cons.get(d, null)
		if o != null and str(o) != "":
			out.append(str(o))
	return out


func hunt_can_move_to(target_id: String) -> bool:
	var map := get_active_hunt_map()
	if map.is_empty():
		return false
	var cur := str(map.get("current_room_id", ""))
	if target_id == cur:
		return false
	var rooms: Dictionary = map.get("rooms", {})
	if not rooms.has(target_id) or not rooms.has(cur):
		return false
	# Must clear current room before leaving (revisit already-cleared is OK).
	if not bool(rooms[cur].get("cleared", false)):
		return false
	# Must be directly connected to current
	if not hunt_connected_room_ids(cur).has(target_id):
		return false
	# Destination must be discovered (adjacent after clear, or already visited)
	return bool(rooms[target_id].get("discovered", false))


func hunt_move_to(target_id: String) -> bool:
	if not hunt_can_move_to(target_id):
		emit_message("그 방으로는 이동할 수 없습니다.", true)
		return false
	var map := get_active_hunt_map()
	var rooms: Dictionary = map.get("rooms", {})
	map["current_room_id"] = target_id
	rooms[target_id]["discovered"] = true
	var path: Array = map.get("path", [])
	path.append(target_id)
	if path.size() > 64:
		path = path.slice(path.size() - 64)
	map["path"] = path
	MazeGenerator._discover_adjacent(map, target_id)
	_store_active_map(map)
	emit_message("%s 로 이동" % str(rooms[target_id].get("name", target_id)))
	return true


func _next_season(s: String) -> String:
	match s:
		"봄":
			return "여름"
		"여름":
			return "가을"
		"가을":
			return "겨울"
		_:
			return "봄"
