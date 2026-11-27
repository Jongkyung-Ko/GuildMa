extends Control

const FACILITY_ORDER := ["guild", "inn", "shop", "blacksmith", "training", "warehouse", "infirmary", "quest", "gate"]

const INTERIOR := {
	"guild": "res://assets/backgrounds/guild_interior.png",
	"inn": "res://assets/backgrounds/inn_interior.png",
	"shop": "res://assets/backgrounds/shop_interior.png",
	"blacksmith": "res://assets/backgrounds/smith_interior.png",
	"training": "res://assets/backgrounds/train_interior.png",
	"warehouse": "res://assets/backgrounds/warehouse_interior.png",
	"infirmary": "res://assets/backgrounds/med_interior.png",
	"quest": "res://assets/backgrounds/quest_interior.png",
	"gate": "res://assets/backgrounds/hunt_select.png",
}

var facility_id: String = "guild"
var _content: VBoxContainer
var _toast: Label
var _gold_label: Label
var _selected_member_id: String = ""
var _confirm: AcceptDialog


func _ready() -> void:
	facility_id = str(get_tree().root.get_meta("facility_id", "guild"))
	_build_shell()
	GameState.state_changed.connect(_rebuild_content)
	GameState.message_emitted.connect(_on_message)
	_rebuild_content()


func _build_shell() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.12)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	# Top HUD
	var top := UIStyle.make_panel()
	top.set_anchors_preset(PRESET_TOP_WIDE)
	top.offset_left = 8
	top.offset_right = -8
	top.offset_top = 6
	top.offset_bottom = 64
	add_child(top)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 16)
	top.add_child(top_row)
	top_row.add_child(UIStyle.label("GuildMaster", 20, UIStyle.GOLD_BRIGHT))
	top_row.add_child(UIStyle.label("길드: %s" % GameState.guild_name, 16))
	_gold_label = UIStyle.label("", 16, UIStyle.GOLD_BRIGHT)
	top_row.add_child(_gold_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer)
	var town_btn := Button.new()
	town_btn.text = "마을로 돌아가기"
	UIStyle.apply_button(town_btn)
	town_btn.pressed.connect(func(): SceneRouter.go_town())
	top_row.add_child(town_btn)

	# Left nav — stretch with EXPAND tall viewports (fixed 560 left a huge empty void).
	var nav := UIStyle.make_panel()
	nav.name = "FacilityNav"
	nav.anchor_left = 0.0
	nav.anchor_right = 0.0
	nav.anchor_top = 0.0
	nav.anchor_bottom = 1.0
	nav.offset_left = 8
	nav.offset_right = 188
	nav.offset_top = 76
	nav.offset_bottom = -40
	add_child(nav)
	var nav_box := VBoxContainer.new()
	nav_box.add_theme_constant_override("separation", 6)
	nav.add_child(nav_box)
	nav_box.add_child(UIStyle.label("시설", 16, UIStyle.TEXT_DIM))
	for fid in FACILITY_ORDER:
		var b := Button.new()
		b.text = UIStyle.facility_name(fid)
		b.custom_minimum_size = Vector2(0, 36)
		UIStyle.apply_button(b)
		if fid == facility_id:
			b.add_theme_stylebox_override("normal", UIStyle.button_pressed())
		b.pressed.connect(_make_nav_cb(fid))
		nav_box.add_child(b)

	# Main area — anchor to viewport so right-edge content stays visible
	var main := UIStyle.make_panel()
	main.anchor_left = 0.0
	main.anchor_right = 1.0
	main.anchor_top = 0.0
	main.anchor_bottom = 1.0
	main.offset_left = 200
	main.offset_right = -8
	main.offset_top = 76
	main.offset_bottom = -40
	add_child(main)
	var main_box := HBoxContainer.new()
	main_box.add_theme_constant_override("separation", 12)
	main_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(main_box)

	var left_visual := VBoxContainer.new()
	left_visual.custom_minimum_size = Vector2(340, 0)
	main_box.add_child(left_visual)
	var interior := TextureRect.new()
	interior.texture = load(INTERIOR.get(facility_id, INTERIOR["guild"]))
	interior.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	interior.custom_minimum_size = Vector2(340, 280)
	interior.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	left_visual.add_child(interior)
	left_visual.add_child(UIStyle.label(UIStyle.facility_name(facility_id), 22, UIStyle.GOLD_BRIGHT))
	left_visual.add_child(UIStyle.label(_facility_blurb(), 14, UIStyle.TEXT_DIM))

	var right := ScrollContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Keep gate/hunt buttons reachable without horizontal scroll at 1280x720.
	right.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_box.add_child(right)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	right.add_child(_content)

	_toast = UIStyle.label("", 14, UIStyle.TEXT)
	_toast.set_anchors_preset(PRESET_BOTTOM_WIDE)
	_toast.offset_left = 210
	_toast.offset_right = -20
	_toast.offset_top = -36
	_toast.offset_bottom = -8
	add_child(_toast)

	_confirm = AcceptDialog.new()
	_confirm.title = "확인"
	add_child(_confirm)

	_refresh_gold()


func _make_nav_cb(fid: String) -> Callable:
	return func(): SceneRouter.go_facility(fid)


func _facility_blurb() -> String:
	match facility_id:
		"guild":
			return "길드 정보와 길드원·파티를 관리합니다."
		"inn":
			return "방문 모험가를 확인하고 영입합니다."
		"shop":
			return "물품을 구매해 창고에 보관합니다."
		"blacksmith":
			return "장비를 확인하고 장착합니다. (강화는 추후)"
		"training":
			return "길드원을 훈련해 경험치를 얻습니다."
		"warehouse":
			return "보유 아이템을 확인합니다."
		"infirmary":
			return "부상 길드원을 회복합니다."
		"quest":
			return "의뢰를 수락합니다."
		"gate":
			return "사냥터로 이동합니다. (전투는 다음 단계)"
		_:
			return ""


func _refresh_gold() -> void:
	_gold_label.text = "골드 %d G  |  명성 %d  |  %s" % [GameState.gold, GameState.reputation, GameState.time_text()]


func _rebuild_content() -> void:
	_refresh_gold()
	for c in _content.get_children():
		c.free()
	match facility_id:
		"guild":
			_build_guild()
		"inn":
			_build_inn()
		"shop":
			_build_shop()
		"blacksmith":
			_build_blacksmith()
		"training":
			_build_training()
		"warehouse":
			_build_warehouse()
		"infirmary":
			_build_infirmary()
		"quest":
			_build_quest()
		"gate":
			_build_gate()
		_:
			_content.add_child(UIStyle.label("준비 중", 18))


func _build_guild() -> void:
	_content.add_child(UIStyle.label("길드 정보", 20, UIStyle.GOLD_BRIGHT))
	_content.add_child(UIStyle.label("이름: %s   레벨: %d   명성: %d   인원: %s" % [GameState.guild_name, GameState.guild_level, GameState.reputation, GameState.member_count_text()], 15))
	_content.add_child(UIStyle.label("재정: %d G (유지비 합계 추정 %d G/주기)" % [GameState.gold, _total_upkeep()], 15))

	_content.add_child(HSeparator.new())
	_content.add_child(UIStyle.label("길드원 관리", 18, UIStyle.GOLD_BRIGHT))
	for m in GameState.members:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var portrait := TextureRect.new()
		portrait.texture = _portrait_for(m.get("job"))
		portrait.custom_minimum_size = Vector2(40, 40)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		row.add_child(portrait)
		var info := "%s  |  %s  Lv.%d  EXP %d  %s" % [
			m.get("name"), UIStyle.job_name(m.get("job")), m.get("level"), m.get("exp", 0),
			"부상" if m.get("injured") else ("파티" if m.get("in_party") else "대기")
		]
		row.add_child(UIStyle.label(info, 14))
		_content.add_child(row)

	_content.add_child(HSeparator.new())
	_content.add_child(UIStyle.label("파티 구성 (군주 + 4)", 18, UIStyle.GOLD_BRIGHT))
	var party := HBoxContainer.new()
	for m in GameState.members:
		if m.get("in_party"):
			var slot := UIStyle.make_panel(true)
			var vb := VBoxContainer.new()
			slot.add_child(vb)
			vb.add_child(UIStyle.label(str(m.get("name")), 13, UIStyle.GOLD_BRIGHT))
			vb.add_child(UIStyle.label(UIStyle.job_name(m.get("job")), 12, UIStyle.TEXT_DIM))
			party.add_child(slot)
	_content.add_child(party)

	_content.add_child(HSeparator.new())
	_content.add_child(UIStyle.label("길드 활동 현황", 18, UIStyle.GOLD_BRIGHT))
	if GameState.message_log.is_empty():
		_content.add_child(UIStyle.label("아직 활동 기록이 없습니다.", 14, UIStyle.TEXT_DIM))
	else:
		for i in range(mini(5, GameState.message_log.size())):
			var e = GameState.message_log[i]
			_content.add_child(UIStyle.label("- %s" % e.get("text"), 13, UIStyle.TEXT_DIM))


func _build_inn() -> void:
	_content.add_child(UIStyle.label("방문 모험가", 20, UIStyle.GOLD_BRIGHT))
	_content.add_child(UIStyle.label("영입 시 계약금이 차감되며, 동일 모험가는 중복 영입되지 않습니다.", 13, UIStyle.TEXT_DIM))
	for adv in GameState.adventurer_pool:
		var already: bool = GameState.recruited_ids.has(adv.get("id"))
		var card := UIStyle.make_panel(already)
		var vb := VBoxContainer.new()
		card.add_child(vb)
		vb.add_child(UIStyle.label("%s  (%s / %s / Lv.%d)" % [adv.get("name"), UIStyle.job_name(adv.get("job")), adv.get("rarity"), adv.get("level")], 16, UIStyle.GOLD_BRIGHT))
		vb.add_child(UIStyle.label("능력 STR%d VIT%d AGI%d INT%d WIS%d" % [adv.get("str"), adv.get("vit"), adv.get("agi"), adv.get("int"), adv.get("wis")], 13))
		vb.add_child(UIStyle.label("스킬: %s   특성: %s" % [", ".join(adv.get("skills", [])), ", ".join(adv.get("traits", []))], 13, UIStyle.TEXT_DIM))
		vb.add_child(UIStyle.label("계약금 %d G  /  유지비 %d G" % [adv.get("contract"), adv.get("upkeep")], 13))
		var btn := Button.new()
		btn.text = "이미 영입됨" if already else "영입 (%d G)" % int(adv.get("contract"))
		btn.disabled = already
		UIStyle.apply_button(btn)
		var adv_copy: Dictionary = adv.duplicate(true)
		btn.pressed.connect(_make_recruit_cb(adv_copy))
		vb.add_child(btn)
		_content.add_child(card)


func _make_recruit_cb(adv: Dictionary) -> Callable:
	return func():
		_confirm.dialog_text = "%s 을(를) %d G에 영입할까요?" % [adv.get("name"), adv.get("contract")]
		if _confirm.confirmed.is_connected(_on_confirm_recruit):
			_confirm.confirmed.disconnect(_on_confirm_recruit)
		_confirm.set_meta("adv", adv)
		_confirm.confirmed.connect(_on_confirm_recruit, CONNECT_ONE_SHOT)
		_confirm.popup_centered()


func _on_confirm_recruit() -> void:
	var adv: Dictionary = _confirm.get_meta("adv", {})
	GameState.recruit_adventurer(adv)


func _build_shop() -> void:
	_content.add_child(UIStyle.label("상점 — 구매", 20, UIStyle.GOLD_BRIGHT))
	for item in GameState.catalog_items:
		var row := UIStyle.make_panel()
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 12)
		row.add_child(hb)
		var vb := VBoxContainer.new()
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(vb)
		vb.add_child(UIStyle.label("%s  (%s)  %d G" % [item.get("name"), item.get("category"), item.get("price")], 15, UIStyle.GOLD_BRIGHT))
		vb.add_child(UIStyle.label(str(item.get("desc")), 13, UIStyle.TEXT_DIM))
		var btn := Button.new()
		btn.text = "구매"
		UIStyle.apply_button(btn)
		var item_id := str(item.get("id"))
		btn.pressed.connect(_make_buy_cb(item_id, str(item.get("name")), int(item.get("price"))))
		hb.add_child(btn)
		_content.add_child(row)


func _make_buy_cb(item_id: String, item_name: String, price: int) -> Callable:
	return func():
		_confirm.dialog_text = "%s 을(를) %d G에 구매할까요?" % [item_name, price]
		if _confirm.confirmed.is_connected(_on_confirm_buy):
			_confirm.confirmed.disconnect(_on_confirm_buy)
		_confirm.set_meta("item_id", item_id)
		_confirm.confirmed.connect(_on_confirm_buy, CONNECT_ONE_SHOT)
		_confirm.popup_centered()


func _on_confirm_buy() -> void:
	GameState.buy_item(str(_confirm.get_meta("item_id", "")))


func _build_blacksmith() -> void:
	_content.add_child(UIStyle.label("대장간", 20, UIStyle.GOLD_BRIGHT))
	_content.add_child(UIStyle.label("탭: 장비 구매/장착  |  강화·제작은 이후 단계에서 활성화됩니다.", 13, UIStyle.TEXT_DIM))

	var enhance := Button.new()
	enhance.text = "강화 (준비 중)"
	enhance.disabled = true
	UIStyle.apply_button(enhance)
	_content.add_child(enhance)

	_content.add_child(HSeparator.new())
	_content.add_child(UIStyle.label("장비 목록", 18, UIStyle.GOLD_BRIGHT))
	for item in GameState.catalog_items:
		if str(item.get("slot", "")) == "":
			continue
		var owned := GameState.inventory_qty(item.get("id"))
		var row := HBoxContainer.new()
		row.add_child(UIStyle.label("%s  공격+%s 방어+%s  | 보유 %d  | %d G" % [
			item.get("name"), item.get("atk", "-"), item.get("def", "-"), owned, item.get("price")
		], 14))
		var buy := Button.new()
		buy.text = "구매"
		UIStyle.apply_button(buy)
		var iid := str(item.get("id"))
		buy.pressed.connect(func(): GameState.buy_item(iid))
		row.add_child(buy)
		_content.add_child(row)

	_content.add_child(HSeparator.new())
	_content.add_child(UIStyle.label("장착 — 길드원 선택 후 보유 장비 장착", 18, UIStyle.GOLD_BRIGHT))
	_selected_member_id = str(GameState.members[0].get("id")) if GameState.members.size() > 0 else ""
	var member_opt := OptionButton.new()
	for m in GameState.members:
		member_opt.add_item("%s (%s)" % [m.get("name"), UIStyle.job_name(m.get("job"))], member_opt.item_count)
		member_opt.set_item_metadata(member_opt.item_count - 1, m.get("id"))
	member_opt.item_selected.connect(func(i): _selected_member_id = str(member_opt.get_item_metadata(i)))
	_content.add_child(member_opt)

	for e in GameState.inventory:
		var item := GameState.get_item(e.get("id"))
		if str(item.get("slot", "")) == "":
			continue
		var btn := Button.new()
		btn.text = "%s 장착 (보유 %d)" % [item.get("name"), e.get("qty")]
		UIStyle.apply_button(btn)
		var iid2 := str(item.get("id"))
		btn.pressed.connect(func(): GameState.equip_item(_selected_member_id, iid2))
		_content.add_child(btn)


func _build_training() -> void:
	_content.add_child(UIStyle.label("훈련장", 20, UIStyle.GOLD_BRIGHT))
	_content.add_child(UIStyle.label("훈련 비용 %d G / 획득 경험치 %d" % [GameState.balance.get("train_gold_cost", 50), GameState.balance.get("train_exp_gain", 25)], 13, UIStyle.TEXT_DIM))
	for m in GameState.members:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.add_child(UIStyle.label("%s  %s  Lv.%d  EXP %d/100  %s" % [
			m.get("name"), UIStyle.job_name(m.get("job")), m.get("level"), m.get("exp", 0),
			"부상" if m.get("injured") else "훈련 가능"
		], 14))
		var btn := Button.new()
		btn.text = "훈련"
		btn.disabled = m.get("injured", false)
		UIStyle.apply_button(btn)
		var mid := str(m.get("id"))
		btn.pressed.connect(func(): GameState.train_member(mid))
		row.add_child(btn)
		_content.add_child(row)


func _build_warehouse() -> void:
	_content.add_child(UIStyle.label("창고", 20, UIStyle.GOLD_BRIGHT))
	if GameState.inventory.is_empty():
		_content.add_child(UIStyle.label("보관 중인 아이템이 없습니다. 상점에서 구매해 보세요.", 14, UIStyle.TEXT_DIM))
		return
	for e in GameState.inventory:
		var item := GameState.get_item(e.get("id"))
		_content.add_child(UIStyle.label("%s  x%d  [%s]  — %s" % [
			item.get("name", e.get("id")), e.get("qty"), item.get("category", "?"), item.get("desc", "")
		], 14))


func _build_infirmary() -> void:
	_content.add_child(UIStyle.label("의무실", 20, UIStyle.GOLD_BRIGHT))
	_content.add_child(UIStyle.label("회복 비용 %d G. 테스트용으로 부상을 지정할 수 있습니다." % GameState.balance.get("heal_gold_cost", 80), 13, UIStyle.TEXT_DIM))
	var injured_any := false
	for m in GameState.members:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(UIStyle.label("%s  %s  %s" % [m.get("name"), UIStyle.job_name(m.get("job")), "부상" if m.get("injured") else "건강"], 14))
		var mid := str(m.get("id"))
		if m.get("injured"):
			injured_any = true
			var heal := Button.new()
			heal.text = "회복"
			UIStyle.apply_button(heal)
			heal.pressed.connect(func(): GameState.heal_member(mid))
			row.add_child(heal)
		else:
			var injure := Button.new()
			injure.text = "테스트 부상"
			UIStyle.apply_button(injure)
			injure.pressed.connect(func():
				GameState.set_injured_for_test(mid, true)
				GameState.emit_message("%s 가 부상 상태가 되었습니다." % m.get("name"))
			)
			row.add_child(injure)
		_content.add_child(row)
	if not injured_any:
		_content.add_child(UIStyle.label("현재 부상 길드원이 없습니다.", 14, UIStyle.TEXT_DIM))


func _build_quest() -> void:
	_content.add_child(UIStyle.label("의뢰 게시판", 20, UIStyle.GOLD_BRIGHT))
	_content.add_child(UIStyle.label("진행 중 의뢰: %d" % GameState.active_quests.size(), 14, UIStyle.TEXT_DIM))
	for q in GameState.quest_catalog:
		var active := false
		for aq in GameState.active_quests:
			if aq.get("id") == q.get("id"):
				active = true
				break
		var card := UIStyle.make_panel(active)
		var vb := VBoxContainer.new()
		card.add_child(vb)
		vb.add_child(UIStyle.label("%s  (난이도 %d)" % [q.get("name"), q.get("difficulty")], 16, UIStyle.GOLD_BRIGHT))
		vb.add_child(UIStyle.label(str(q.get("desc")), 13, UIStyle.TEXT_DIM))
		vb.add_child(UIStyle.label("보상: %d G / 명성 %d" % [q.get("gold"), q.get("reputation")], 13))
		var btn := Button.new()
		btn.text = "진행 중" if active else "수락"
		btn.disabled = active
		UIStyle.apply_button(btn)
		var qid := str(q.get("id"))
		btn.pressed.connect(func(): GameState.accept_quest(qid))
		vb.add_child(btn)
		_content.add_child(card)


func _build_gate() -> void:
	_content.add_child(UIStyle.label("사냥터 · 던전", 20, UIStyle.GOLD_BRIGHT))
	var hint := UIStyle.label(
		"일반 사냥터는 미로형 연결 통로로만 이동합니다. 던전은 층 하강 방식입니다.",
		13, UIStyle.TEXT_DIM
	)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(hint)

	_content.add_child(UIStyle.label("일반 사냥터 (미로 탐험)", 15, UIStyle.GOLD_BRIGHT))
	for h in GameState.list_hunts():
		var hid := str(h.get("id", ""))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var al := UIStyle.label(
			"%s (Lv.%d–%d)" % [str(h.get("name")), int(h.get("rec_level", 1)), int(h.get("rec_level_max", 1))],
			14
		)
		al.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		al.clip_text = true
		row.add_child(al)
		var go := Button.new()
		go.text = "출정"
		go.custom_minimum_size = Vector2(64, 0)
		UIStyle.apply_button(go)
		var id_copy := hid
		go.pressed.connect(func(): SceneRouter.go_hunt(id_copy, false))
		row.add_child(go)
		var anew := Button.new()
		anew.text = "새 맵"
		anew.custom_minimum_size = Vector2(64, 0)
		UIStyle.apply_button(anew)
		anew.pressed.connect(func(): SceneRouter.go_hunt(id_copy, true))
		row.add_child(anew)
		_content.add_child(row)

	_content.add_child(UIStyle.label("던전 (수직 하강)", 15, UIStyle.GOLD_BRIGHT))
	var dun_row := HBoxContainer.new()
	dun_row.add_theme_constant_override("separation", 10)
	var dun_lbl := UIStyle.label("그림자 지하묘", 15, UIStyle.TEXT)
	dun_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dun_row.add_child(dun_lbl)
	var dun_btn := Button.new()
	dun_btn.text = "입장"
	dun_btn.custom_minimum_size = Vector2(80, 0)
	UIStyle.apply_button(dun_btn)
	dun_btn.pressed.connect(func(): SceneRouter.go_dungeon("shadow_crypt"))
	dun_row.add_child(dun_btn)
	_content.add_child(dun_row)

	var test_row := HBoxContainer.new()
	test_row.add_theme_constant_override("separation", 10)
	var test_lbl := UIStyle.label("전투 시험 (미로 없음)", 15, UIStyle.TEXT_DIM)
	test_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	test_row.add_child(test_lbl)
	var test_btn := Button.new()
	test_btn.text = "출정"
	test_btn.custom_minimum_size = Vector2(80, 0)
	UIStyle.apply_button(test_btn)
	test_btn.pressed.connect(func(): SceneRouter.go_combat("phase_2_1_test"))
	test_row.add_child(test_btn)
	_content.add_child(test_row)

	var back := Button.new()
	back.text = "마을로 돌아가기"
	UIStyle.apply_button(back)
	back.pressed.connect(func(): SceneRouter.go_town())
	_content.add_child(back)


func _portrait_for(job: String) -> Texture2D:
	var path := "res://assets/sprites/characters/portrait_%s.png" % job
	if ResourceLoader.exists(path):
		return load(path)
	return load("res://assets/sprites/characters/portrait_lord.png")


func _total_upkeep() -> int:
	var t := 0
	for m in GameState.members:
		t += int(m.get("upkeep", 0))
	return t


func _on_message(text: String, is_error: bool) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", UIStyle.DANGER if is_error else UIStyle.OK)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		SceneRouter.go_town()
