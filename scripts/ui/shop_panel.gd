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
		# Portrait OR short landscape (844×390): stack / denser packing.
		var compact := size.x > 0 and (size.x < 720 or size.y > size.x or size.y < 480)
		if compact != _compact:
			_compact = compact
			_rebuild_layout()

	func _rebuild_layout() -> void:
		for c in get_children():
			if c == _confirm:
				continue
			c.free()
		var scroll := ScrollContainer.new()
		scroll.set_anchors_preset(PRESET_FULL_RECT)
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		add_child(scroll)

		var body: Control
		if _compact:
			body = VBoxContainer.new()
		else:
			body = HBoxContainer.new()
		body.add_theme_constant_override("separation", 10)
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.add_child(body)

		body.add_child(_build_left_npc())
		body.add_child(_build_center_grid())
		body.add_child(_build_detail())
		_refresh()

	func _build_left_npc() -> Control:
		var panel := UIStyle.make_panel()
		panel.custom_minimum_size = Vector2(220 if not _compact else 0, 0)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL if _compact else Control.SIZE_FILL
		panel.size_flags_stretch_ratio = 0.9 if _compact else 1.0
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 8)
		panel.add_child(vb)

		var title := UIStyle.label("상점 주인", 16, UIStyle.GOLD_BRIGHT)
		vb.add_child(title)
		var portrait := TextureRect.new()
		portrait.texture = load("res://assets/backgrounds/shop_interior.png")
		portrait.custom_minimum_size = Vector2(0, 110 if _compact else 200)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		vb.add_child(portrait)

		_dialogue = UIStyle.label(NPC_LINES[0], 13, UIStyle.TEXT)
		_dialogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(_dialogue)

		vb.add_child(UIStyle.label("카테고리", 14, UIStyle.TEXT_DIM))
		for cat in ItemUI.CATEGORY_ORDER:
			var cat_str: String = str(cat)
			var b := Button.new()
			b.text = ItemUI.category_label(cat_str)
			b.custom_minimum_size = Vector2(0, 32 if _compact else 40)
			UIStyle.apply_button(b)
			var cat_id: String = cat_str
			b.pressed.connect(func():
				category = cat_id
				selected_id = ""
				_refresh()
			)
			vb.add_child(b)

		var mode_row := HBoxContainer.new()
		mode_row.add_theme_constant_override("separation", 6)
		vb.add_child(mode_row)
		var buy_btn := Button.new()
		buy_btn.text = "구매"
		buy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UIStyle.apply_button(buy_btn)
		buy_btn.pressed.connect(func():
			mode = "buy"
			selected_id = ""
			_dialogue.text = NPC_LINES[0]
			_refresh()
		)
		mode_row.add_child(buy_btn)
		var sell_btn := Button.new()
		sell_btn.text = "판매"
		sell_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UIStyle.apply_button(sell_btn)
		sell_btn.pressed.connect(func():
			mode = "sell"
			selected_id = ""
			_dialogue.text = NPC_LINES[2]
			_refresh()
		)
		mode_row.add_child(sell_btn)
		return panel

	func _build_center_grid() -> Control:
		var panel := UIStyle.make_panel()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		panel.size_flags_stretch_ratio = 1.4
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 8)
		panel.add_child(vb)

		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 12)
		vb.add_child(top)
		top.add_child(UIStyle.label("상점", 20, UIStyle.GOLD_BRIGHT))
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(spacer)
		_gold_chip = UIStyle.label("", 15, UIStyle.GOLD_BRIGHT)
		top.add_child(_gold_chip)
		_level_chip = UIStyle.label("", 14, UIStyle.TEXT_DIM)
		top.add_child(_level_chip)

		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.custom_minimum_size = Vector2(0, 220)
		vb.add_child(scroll)
		_grid = GridContainer.new()
		_grid.columns = 4 if not _compact else 3
		_grid.add_theme_constant_override("h_separation", 8)
		_grid.add_theme_constant_override("v_separation", 8)
		_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(_grid)

		_feedback = UIStyle.label("", 13, UIStyle.OK)
		_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(_feedback)
		return panel

	func _build_detail() -> Control:
		var panel := UIStyle.make_panel(true)
		panel.custom_minimum_size = Vector2(240 if not _compact else 0, 0)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL if _compact else Control.SIZE_FILL
		panel.size_flags_stretch_ratio = 1.0
		_detail = VBoxContainer.new()
		_detail.add_theme_constant_override("separation", 8)
		panel.add_child(_detail)
		return panel

	func _refresh() -> void:
		if _gold_chip == null:
			return
		_gold_chip.text = "골드 %d G" % GameState.gold
		var lvl := 1
		if GameState.members.size() > 0:
			lvl = int(GameState.members[0].get("level", 1))
		_level_chip.text = "군주 Lv.%d" % lvl
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
				_grid.add_child(_make_item_cell(item, 0, false))
		else:
			var any := false
			for e in GameState.inventory:
				var item := GameState.get_item(str(e.get("id", "")))
				if item.is_empty():
					continue
				if str(item.get("category", "")) != category:
					continue
				any = true
				_grid.add_child(_make_item_cell(item, int(e.get("enhance", 0)), true, int(e.get("qty", 0))))
			if not any:
				_grid.add_child(UIStyle.label("이 분류의 보유 아이템이 없습니다.", 13, UIStyle.TEXT_DIM))

	func _make_item_cell(item: Dictionary, enhance: int, owned: bool, qty: int = 0) -> Control:
		var id := str(item.get("id", ""))
		var selected := selected_id == id and selected_enhance == enhance
		var cell := Button.new()
		cell.custom_minimum_size = Vector2(88, 100)
		cell.flat = true
		UIStyle.apply_button(cell)
		var vb := VBoxContainer.new()
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_theme_constant_override("separation", 2)
		cell.add_child(vb)
		vb.add_child(ItemUI.make_icon_frame(item, 56, enhance, selected))
		var name_l := UIStyle.label(str(item.get("name")), 11, UIStyle.TEXT)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_l.clip_text = true
		name_l.custom_minimum_size = Vector2(80, 0)
		vb.add_child(name_l)
		var price := int(item.get("price", 0)) if not owned else GameState.sell_price_of(id)
		if owned and enhance > 0:
			price = int(round(float(price) * (1.0 + 0.08 * float(enhance))))
		var price_l := UIStyle.label(("%d G" % price) if not owned else ("x%d · %d G" % [qty, price]), 11, UIStyle.GOLD_BRIGHT)
		price_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(price_l)
		cell.pressed.connect(func():
			selected_id = id
			selected_enhance = enhance
			buy_qty = 1
			_refresh()
		)
		return cell

	func _populate_detail() -> void:
		for c in _detail.get_children():
			c.free()
		_detail.add_child(UIStyle.label("상세 정보", 16, UIStyle.GOLD_BRIGHT))
		if selected_id == "":
			_detail.add_child(UIStyle.label("아이템을 선택하세요.", 13, UIStyle.TEXT_DIM))
			return
		var item := GameState.get_item(selected_id)
		if item.is_empty():
			return
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_detail.add_child(row)
		row.add_child(ItemUI.make_icon_frame(item, 72, selected_enhance, true))
		var meta := VBoxContainer.new()
		row.add_child(meta)
		meta.add_child(UIStyle.label(str(item.get("name")), 18, UIStyle.GOLD_BRIGHT))
		meta.add_child(UIStyle.label("%s · %s" % [ItemUI.rarity_label(str(item.get("rarity", "common"))), ItemUI.category_label(str(item.get("category")))], 13, ItemUI.rarity_color(str(item.get("rarity", "common")))))
		if selected_enhance > 0:
			meta.add_child(UIStyle.label("강화 +%d" % selected_enhance, 13, UIStyle.GOLD_BRIGHT))

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

			var total: int = int(item.get("price", 0)) * buy_qty
			var can_buy := GameState.gold >= total
			var buy := Button.new()
			buy.text = "구매 (%d G)" % total
			buy.custom_minimum_size = Vector2(0, 48)
			buy.disabled = not can_buy
			UIStyle.apply_button(buy)
			buy.pressed.connect(_on_buy_pressed)
			_detail.add_child(buy)
			if not can_buy:
				_detail.add_child(UIStyle.label("골드가 부족합니다.", 13, UIStyle.DANGER))
		else:
			var unit := GameState.sell_price_of(selected_id)
			if selected_enhance > 0:
				unit = int(round(float(unit) * (1.0 + 0.08 * float(selected_enhance))))
			var own := GameState.inventory_qty(selected_id, selected_enhance)
			var sell := Button.new()
			sell.text = "판매 (%d G) · 보유 %d" % [unit, own]
			sell.custom_minimum_size = Vector2(0, 48)
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
