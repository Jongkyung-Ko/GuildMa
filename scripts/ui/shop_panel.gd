extends RefCounted
class_name ShopPanel

## Full shop trade UI mounted into the facility main area.

const NPC_LINES := [
	"어서 오세요! 필요한 물건이 있나요?",
	"좋은 선택은 길드를 강하게 만듭니다.",
	"팔고 싶은 물건이 있으면 언제든 말씀하세요.",
]


static func mount(parent: Control, host: Node) -> void:
	for c in parent.get_children():
		c.free()
	var root := ShopPanelRoot.new()
	root.host = host
	parent.add_child(root)
	root.build()


class ShopPanelRoot extends Control:
	var host: Node
	var mode: String = "buy" # buy | sell
	var category: String = "weapon"
	var selected_id: String = ""
	var selected_enhance: int = 0
	var buy_qty: int = 1
	var _grid: GridContainer
	var _detail: VBoxContainer
	var _gold_chip: Label
	var _level_chip: Label
	var _dialogue: Label
	var _feedback: Label
	var _confirm: AcceptDialog
	var _compact: bool = false
	var _cat_buttons: Dictionary = {}
	var _mode_buy: Button
	var _mode_sell: Button

	func build() -> void:
		set_anchors_preset(PRESET_FULL_RECT)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_EXPAND_FILL
		_confirm = AcceptDialog.new()
		_confirm.title = "구매 확인"
		add_child(_confirm)
		GameState.state_changed.connect(_refresh)
		_rebuild_layout()
		resized.connect(_on_resized)
		_on_resized()

	func _on_resized() -> void:
		var compact := size.x > 0 and (size.x < 720 or size.y > size.x or size.y < 480)
		if compact != _compact:
			_compact = compact
			_rebuild_layout()

	func _rebuild_layout() -> void:
		for c in get_children():
			if c == _confirm:
				continue
			c.free()
		_cat_buttons.clear()
		var scroll := ScrollContainer.new()
		scroll.set_anchors_preset(PRESET_FULL_RECT)
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		add_child(scroll)

		var body: Control = VBoxContainer.new() if _compact else HBoxContainer.new()
		body.add_theme_constant_override("separation", 10)
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.add_child(body)

		body.add_child(_build_left_npc())
		body.add_child(_build_center_grid())
		body.add_child(_build_detail())
		_refresh()

	func _build_left_npc() -> Control:
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", ItemUI.deep_panel_style(false))
		panel.custom_minimum_size = Vector2(230 if not _compact else 0, 0)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL if _compact else Control.SIZE_FILL
		panel.size_flags_stretch_ratio = 0.95
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 8)
		panel.add_child(vb)

		vb.add_child(UIStyle.label("상점", 18, UIStyle.GOLD_BRIGHT))
		var portrait := TextureRect.new()
		portrait.texture = load("res://assets/backgrounds/shop_interior.png")
		portrait.custom_minimum_size = Vector2(0, 130 if _compact else 230)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		vb.add_child(portrait)

		_dialogue = UIStyle.label(NPC_LINES[0], 13, UIStyle.TEXT)
		_dialogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(_dialogue)

		vb.add_child(UIStyle.label("카테고리", 13, UIStyle.TEXT_DIM))
		for cat in ItemUI.CATEGORY_ORDER:
			var cat_str: String = str(cat)
			var b := Button.new()
			b.text = ItemUI.category_label(cat_str)
			b.custom_minimum_size = Vector2(0, 34 if _compact else 40)
			UIStyle.apply_button(b)
			var cat_id: String = cat_str
			b.pressed.connect(func():
				category = cat_id
				selected_id = ""
				_refresh()
			)
			_cat_buttons[cat_str] = b
			vb.add_child(b)

		var mode_row := HBoxContainer.new()
		mode_row.add_theme_constant_override("separation", 6)
		vb.add_child(mode_row)
		_mode_buy = Button.new()
		_mode_buy.text = "구매"
		_mode_buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UIStyle.apply_button(_mode_buy)
		_mode_buy.pressed.connect(func():
			mode = "buy"
			selected_id = ""
			_dialogue.text = NPC_LINES[0]
			_refresh()
		)
		mode_row.add_child(_mode_buy)
		_mode_sell = Button.new()
		_mode_sell.text = "판매"
		_mode_sell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UIStyle.apply_button(_mode_sell)
		_mode_sell.pressed.connect(func():
			mode = "sell"
			selected_id = ""
			_dialogue.text = NPC_LINES[2]
			_refresh()
		)
		mode_row.add_child(_mode_sell)
		return panel

	func _build_center_grid() -> Control:
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", ItemUI.deep_panel_style(false))
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		panel.size_flags_stretch_ratio = 1.55
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 8)
		panel.add_child(vb)

		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 12)
		vb.add_child(top)
		top.add_child(UIStyle.label("상품 목록", 18, UIStyle.GOLD_BRIGHT))
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(spacer)
		_gold_chip = UIStyle.label("", 14, UIStyle.GOLD_BRIGHT)
		top.add_child(_gold_chip)
		_level_chip = UIStyle.label("", 13, UIStyle.TEXT_DIM)
		top.add_child(_level_chip)

		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.custom_minimum_size = Vector2(0, 240)
		vb.add_child(scroll)
		_grid = GridContainer.new()
		_grid.columns = 3 if _compact else 4
		_grid.add_theme_constant_override("h_separation", 10)
		_grid.add_theme_constant_override("v_separation", 10)
		_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(_grid)

		_feedback = UIStyle.label("", 13, UIStyle.OK)
		_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(_feedback)
		return panel

	func _build_detail() -> Control:
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", ItemUI.deep_panel_style(true))
		panel.custom_minimum_size = Vector2(260 if not _compact else 0, 0)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL if _compact else Control.SIZE_FILL
		panel.size_flags_stretch_ratio = 1.05
		_detail = VBoxContainer.new()
		_detail.add_theme_constant_override("separation", 8)
		panel.add_child(_detail)
		return panel

	func _style_active_buttons() -> void:
		for cat in _cat_buttons.keys():
			var b: Button = _cat_buttons[cat]
			if str(cat) == category:
				b.add_theme_stylebox_override("normal", UIStyle.button_pressed())
			else:
				UIStyle.apply_button(b)
		if _mode_buy:
			if mode == "buy":
				_mode_buy.add_theme_stylebox_override("normal", UIStyle.button_pressed())
			else:
				UIStyle.apply_button(_mode_buy)
		if _mode_sell:
			if mode == "sell":
				_mode_sell.add_theme_stylebox_override("normal", UIStyle.button_pressed())
			else:
				UIStyle.apply_button(_mode_sell)

	func _refresh() -> void:
		if _gold_chip == null:
			return
		_gold_chip.text = "골드 %d G" % GameState.gold
		var lvl := 1
		if GameState.members.size() > 0:
			lvl = int(GameState.members[0].get("level", 1))
		_level_chip.text = "군주 Lv.%d" % lvl
		_style_active_buttons()
		_ensure_selection()
		_populate_grid()
		_populate_detail()

	func _ensure_selection() -> void:
		if selected_id != "" and GameState.get_item(selected_id):
			if mode == "buy":
				return
			if GameState.inventory_qty(selected_id, selected_enhance) > 0:
				return
		selected_id = ""
		selected_enhance = 0
		if mode == "buy":
			var list: Array = GameState.items_by_category(category)
			if list.size() > 0:
				selected_id = str(list[0].get("id", ""))
			return
		for e in GameState.inventory:
			var item := GameState.get_item(str(e.get("id", "")))
			if item.is_empty():
				continue
			if str(item.get("category", "")) != category:
				continue
			selected_id = str(item.get("id", ""))
			selected_enhance = int(e.get("enhance", 0))
			return

	func _populate_grid() -> void:
		for c in _grid.get_children():
			c.free()
		if mode == "buy":
			for item in GameState.items_by_category(category):
				_grid.add_child(_make_buy_card(item))
		else:
			var any := false
			for e in GameState.inventory:
				var item := GameState.get_item(str(e.get("id", "")))
				if item.is_empty():
					continue
				if str(item.get("category", "")) != category:
					continue
				any = true
				_grid.add_child(_make_sell_card(item, int(e.get("enhance", 0)), int(e.get("qty", 0))))
			if not any:
				_grid.add_child(UIStyle.label("이 분류의 보유 아이템이 없습니다.", 13, UIStyle.TEXT_DIM))

	func _make_buy_card(item: Dictionary) -> Control:
		var id := str(item.get("id", ""))
		var selected := selected_id == id and selected_enhance == 0
		var slot := str(item.get("slot", ""))
		var sub := "장착 가능" if slot != "" else ItemUI.category_label(str(item.get("category")))
		var cell := ItemUI.make_item_card(item, {
			"selected": selected,
			"price_text": "%d G" % int(item.get("price", 0)),
			"sub_text": sub,
			"icon_size": 64 if _compact else 76,
			"min_w": 108 if _compact else 124,
			"min_h": 138 if _compact else 156,
		})
		cell.pressed.connect(func():
			selected_id = id
			selected_enhance = 0
			buy_qty = 1
			_refresh()
		)
		return cell

	func _make_sell_card(item: Dictionary, enhance: int, qty: int) -> Control:
		var id := str(item.get("id", ""))
		var selected := selected_id == id and selected_enhance == enhance
		var unit := GameState.sell_price_of(id)
		if enhance > 0:
			unit = int(round(float(unit) * (1.0 + 0.08 * float(enhance))))
		var cell := ItemUI.make_item_card(item, {
			"enhance": enhance,
			"selected": selected,
			"price_text": "%d G" % unit,
			"sub_text": "보유 x%d" % qty,
			"icon_size": 64 if _compact else 76,
			"min_w": 108 if _compact else 124,
			"min_h": 138 if _compact else 156,
		})
		cell.pressed.connect(func():
			selected_id = id
			selected_enhance = enhance
			_refresh()
		)
		return cell

	func _populate_detail() -> void:
		for c in _detail.get_children():
			c.free()
		_detail.add_child(UIStyle.label("상세 정보", 17, UIStyle.GOLD_BRIGHT))
		if selected_id == "":
			_detail.add_child(UIStyle.label("아이템을 선택하세요.", 13, UIStyle.TEXT_DIM))
			return
		var item := GameState.get_item(selected_id)
		if item.is_empty():
			return
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		_detail.add_child(row)
		row.add_child(ItemUI.make_icon_frame(item, 96 if not _compact else 80, selected_enhance, true))
		var meta := VBoxContainer.new()
		row.add_child(meta)
		meta.add_child(UIStyle.label(str(item.get("name")), 18, UIStyle.GOLD_BRIGHT))
		meta.add_child(UIStyle.label("%s · %s" % [
			ItemUI.rarity_label(str(item.get("rarity", "common"))),
			ItemUI.category_label(str(item.get("category"))),
		], 13, ItemUI.rarity_color(str(item.get("rarity", "common")))))
		var sub := ItemUI.subcategory_label(str(item.get("subcategory", "")))
		if sub != "":
			meta.add_child(UIStyle.label("세부: %s" % sub, 12, UIStyle.TEXT_DIM))
		if selected_enhance > 0:
			meta.add_child(UIStyle.label("강화 +%d" % selected_enhance, 13, UIStyle.GOLD_BRIGHT))
		var slot := str(item.get("slot", ""))
		if slot != "":
			meta.add_child(UIStyle.label("장착 부위: %s" % slot, 12, UIStyle.TEXT_DIM))
		if str(item.get("balance_status", "")) == "proposed":
			meta.add_child(UIStyle.label("가격/스탯: 제안(미확정)", 11, Color(0.85, 0.7, 0.35)))

		var desc := UIStyle.label(str(item.get("desc", "")), 13, UIStyle.TEXT_DIM)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail.add_child(desc)
		for line in ItemUI.stats_lines(item, selected_enhance):
			_detail.add_child(UIStyle.label(line, 13, UIStyle.OK))

		if mode == "buy":
			var qty_row := HBoxContainer.new()
			qty_row.add_theme_constant_override("separation", 8)
			_detail.add_child(qty_row)
			var minus := Button.new()
			minus.text = "-"
			minus.custom_minimum_size = Vector2(44, 44)
			UIStyle.apply_button(minus)
			minus.pressed.connect(func():
				buy_qty = maxi(1, buy_qty - 1)
				_refresh()
			)
			qty_row.add_child(minus)
			qty_row.add_child(UIStyle.label("수량 %d" % buy_qty, 15))
			var plus := Button.new()
			plus.text = "+"
			plus.custom_minimum_size = Vector2(44, 44)
			UIStyle.apply_button(plus)
			plus.pressed.connect(func():
				buy_qty = mini(99, buy_qty + 1)
				_refresh()
			)
			qty_row.add_child(plus)

			var unit: int = int(item.get("price", 0))
			var total: int = unit * buy_qty
			_detail.add_child(UIStyle.label("단가 %d G · 합계 %d G" % [unit, total], 14, UIStyle.GOLD_BRIGHT))
			var can_buy := GameState.gold >= total
			var buy := Button.new()
			buy.text = "구매 (%d G)" % total
			buy.custom_minimum_size = Vector2(0, 50)
			buy.disabled = not can_buy
			UIStyle.apply_button(buy)
			buy.pressed.connect(_on_buy_pressed)
			_detail.add_child(buy)
			if not can_buy:
				var short: int = total - GameState.gold
				_detail.add_child(UIStyle.label("골드가 %d G 부족합니다." % short, 13, UIStyle.DANGER))
		else:
			var unit2 := GameState.sell_price_of(selected_id)
			if selected_enhance > 0:
				unit2 = int(round(float(unit2) * (1.0 + 0.08 * float(selected_enhance))))
			var own := GameState.inventory_qty(selected_id, selected_enhance)
			var sell := Button.new()
			sell.text = "판매 (%d G) · 보유 %d" % [unit2, own]
			sell.custom_minimum_size = Vector2(0, 50)
			sell.disabled = own <= 0
			UIStyle.apply_button(sell)
			sell.pressed.connect(_on_sell_pressed)
			_detail.add_child(sell)

	func _on_buy_pressed() -> void:
		var item := GameState.get_item(selected_id)
		_confirm.dialog_text = "%s x%d 을(를) %d G에 구매할까요?" % [
			item.get("name"), buy_qty, int(item.get("price", 0)) * buy_qty
		]
		if _confirm.confirmed.is_connected(_do_buy):
			_confirm.confirmed.disconnect(_do_buy)
		_confirm.confirmed.connect(_do_buy, CONNECT_ONE_SHOT)
		_confirm.popup_centered()

	func _do_buy() -> void:
		var ok := GameState.buy_item(selected_id, buy_qty)
		_feedback.text = "구매 완료!" if ok else "구매 실패"
		_feedback.add_theme_color_override("font_color", UIStyle.OK if ok else UIStyle.DANGER)
		_dialogue.text = NPC_LINES[1] if ok else "골드가 부족한 것 같아요…"
		_refresh()

	func _on_sell_pressed() -> void:
		var ok := GameState.sell_item(selected_id, 1, selected_enhance)
		_feedback.text = "판매 완료!" if ok else "판매 실패"
		_feedback.add_theme_color_override("font_color", UIStyle.OK if ok else UIStyle.DANGER)
		if ok and GameState.inventory_qty(selected_id, selected_enhance) <= 0:
			selected_id = ""
		_refresh()
