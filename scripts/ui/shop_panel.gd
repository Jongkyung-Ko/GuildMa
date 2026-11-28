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
	var _left_panel: PanelContainer
	var _left_host: Control
	var _cat_scroll: ScrollContainer
	## Staged catalog spawn — avoids one-frame 48-card/icon hitch (BGM underrun on web).
	const GRID_BATCH_SIZE := 4
	var _grid_gen: int = 0
	var _grid_queue: Array = []
	## Catalog identity — rebuild grid only when this changes (not on hover/qty/select).
	var _catalog_fp: String = ""
	var _cards_by_key: Dictionary = {}

	func build() -> void:
		set_anchors_preset(PRESET_FULL_RECT)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_EXPAND_FILL
		_confirm = AcceptDialog.new()
		_confirm.title = "구매 확인"
		add_child(_confirm)
		GameState.state_changed.connect(_on_state_changed)
		_rebuild_layout()
		resized.connect(_on_resized)
		if get_viewport():
			get_viewport().size_changed.connect(_on_resized)
		_on_resized()

	func _on_state_changed() -> void:
		## Gold/inventory may change from outside; refresh chrome + catalog when needed.
		_refresh(false)

	func _window_size() -> Vector2i:
		## Physical/window size — reliable for short mobile landscape under stretch modes.
		return DisplayServer.window_get_size()

	func _is_compact_for(sz: Vector2) -> bool:
		return sz.x > 0.0 and (sz.x < 720.0 or sz.y > sz.x or sz.y < 480.0)

	func _on_resized() -> void:
		# Prefer window size so short mobile landscape is detected even when
		# canvas stretch keeps a taller content viewport / content-driven min size.
		var win_sz: Vector2 = Vector2(_window_size())
		var compact := _is_compact_for(win_sz) or _is_compact_for(size)
		if compact != _compact:
			_compact = compact
			_rebuild_layout()
		else:
			_fit_left_panel_height()

	func _fit_left_panel_height() -> void:
		## Category column height = available column height (resize-safe).
		## compact: clamp via _left_host (min_size alone cannot cap VBox children).
		## Also cap compact width to the on-screen facility main area — the stacked
		## ScrollContainer body grows with card min-widths; SIZE_EXPAND_FILL on the
		## left host would match that overflow width and push Sell past the window.
		var win_sz: Vector2i = _window_size()
		# Facility main host ≈ window minus top HUD (76) and bottom pad (40).
		var host_h: int = maxi(160, win_sz.y - 76 - 40)
		if size.y > 1.0:
			host_h = mini(host_h, int(size.y))
		var avail: int = maxi(160, host_h - 4)
		if _compact and _left_host != null:
			# Facility main_host offsets: left 200, right 8 (see facility_screen.gd).
			var avail_w: int = maxi(220, win_sz.x - 200 - 8)
			_left_host.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			_left_host.custom_minimum_size = Vector2(avail_w, avail)
			_left_host.set_deferred("size", Vector2(float(avail_w), float(avail)))
			if _left_panel:
				_left_panel.clip_contents = true
		elif not _compact and _left_panel != null:
			_left_panel.custom_minimum_size = Vector2(230, 0)
			_left_panel.clip_contents = true

	func _rebuild_layout() -> void:
		for c in get_children():
			if c == _confirm:
				continue
			c.free()
		_cat_buttons.clear()

		# Desktop: no outer scroll — left/center/right each scroll independently.
		# Compact: outer scroll stacks panels for short landscape / portrait.
		if _compact:
			var outer := ScrollContainer.new()
			outer.set_anchors_preset(PRESET_FULL_RECT)
			outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
			outer.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			add_child(outer)
			var body := VBoxContainer.new()
			body.add_theme_constant_override("separation", 10)
			body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			body.size_flags_vertical = Control.SIZE_EXPAND_FILL
			outer.add_child(body)
			body.add_child(_build_left_npc())
			body.add_child(_build_center_grid())
			body.add_child(_build_detail())
		else:
			var body := HBoxContainer.new()
			body.set_anchors_preset(PRESET_FULL_RECT)
			body.add_theme_constant_override("separation", 10)
			body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			body.size_flags_vertical = Control.SIZE_EXPAND_FILL
			add_child(body)
			body.add_child(_build_left_npc())
			body.add_child(_build_center_grid())
			body.add_child(_build_detail())
		_fit_left_panel_height()
		_refresh()

	func _build_left_npc() -> Control:
		## Left column fills available height; only the category list scrolls.
		## Buy/sell stay pinned under the scroll so the panel bottom never clips them.
		## Do not change card/catalog/detail layout from here.
		var panel := PanelContainer.new()
		_left_panel = panel
		_left_host = null
		panel.add_theme_stylebox_override("panel", ItemUI.deep_panel_style(false))
		panel.custom_minimum_size = Vector2(230 if not _compact else 0, 0)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL if _compact else Control.SIZE_FILL
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		panel.size_flags_stretch_ratio = 0.95
		panel.clip_contents = true
		var root_vb := VBoxContainer.new()
		root_vb.add_theme_constant_override("separation", 8)
		root_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		root_vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
		panel.add_child(root_vb)

		root_vb.add_child(UIStyle.label("상점", 18, UIStyle.GOLD_BRIGHT))
		var portrait := TextureRect.new()
		# Compact short-landscape: keep atmosphere but leave room for pinned Buy/Sell
		# inside the height-clamped left host (110 + mins overflowed ~270px host).
		portrait.custom_minimum_size = Vector2(0, 90 if _compact else 150)
		portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		UIStyle.apply_cover_texture(portrait, load("res://assets/backgrounds/shop_interior.png") as Texture2D)
		root_vb.add_child(portrait)

		_dialogue = UIStyle.label(NPC_LINES[0], 13, UIStyle.TEXT)
		_dialogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_dialogue.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		root_vb.add_child(_dialogue)

		# Category list: take remaining height only (no large min that overflows short viewports).
		var cat_scroll := ScrollContainer.new()
		_cat_scroll = cat_scroll
		cat_scroll.name = "CategoryScroll"
		cat_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cat_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		# Always show track so short landscape makes scroll affordance obvious; content has right pad.
		cat_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
		# Small floor so the region exists; never force 160/220 which clips on short landscape.
		cat_scroll.custom_minimum_size = Vector2(0, 64)
		root_vb.add_child(cat_scroll)

		# Right margin so the vertical scrollbar does not cover category buttons.
		var pad := MarginContainer.new()
		pad.add_theme_constant_override("margin_right", 14)
		pad.add_theme_constant_override("margin_bottom", 6)
		pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cat_scroll.add_child(pad)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 8)
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pad.add_child(vb)

		vb.add_child(UIStyle.label("카테고리", 13, UIStyle.TEXT_DIM))
		for cat in ItemUI.CATEGORY_ORDER:
			var cat_str: String = str(cat)
			var b := Button.new()
			b.text = ItemUI.category_label(cat_str)
			b.custom_minimum_size = Vector2(0, 36 if _compact else 42)
			UIStyle.apply_button(b)
			var cat_id: String = cat_str
			b.pressed.connect(func():
				category = cat_id
				selected_id = ""
				_refresh(true)
			)
			_cat_buttons[cat_str] = b
			vb.add_child(b)

		# Pin buy/sell under the scroll so the panel bottom never clips the mode row.
		var mode_row := HBoxContainer.new()
		mode_row.add_theme_constant_override("separation", 6)
		mode_row.size_flags_vertical = Control.SIZE_SHRINK_END
		root_vb.add_child(mode_row)
		_mode_buy = Button.new()
		_mode_buy.text = "구매"
		_mode_buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_mode_buy.custom_minimum_size = Vector2(0, 40)
		UIStyle.apply_button(_mode_buy)
		_mode_buy.pressed.connect(func():
			mode = "buy"
			selected_id = ""
			_dialogue.text = NPC_LINES[0]
			_refresh(true)
		)
		mode_row.add_child(_mode_buy)
		_mode_sell = Button.new()
		_mode_sell.text = "판매"
		_mode_sell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_mode_sell.custom_minimum_size = Vector2(0, 40)
		UIStyle.apply_button(_mode_sell)
		_mode_sell.pressed.connect(func():
			mode = "sell"
			selected_id = ""
			_dialogue.text = NPC_LINES[2]
			_refresh(true)
		)
		mode_row.add_child(_mode_sell)

		if _compact:
			# Clamp to on-screen facility main area — do NOT EXPAND_FILL to the
			# card-driven ScrollContainer body width (that pushed Sell off-window).
			var host := Control.new()
			_left_host = host
			host.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			host.clip_contents = true
			var win_sz: Vector2i = _window_size()
			var avail_w: int = maxi(220, win_sz.x - 200 - 8)
			var avail_h: int = maxi(160, win_sz.y - 76 - 40 - 4)
			host.custom_minimum_size = Vector2(avail_w, avail_h)
			panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
			host.add_child(panel)
			return host
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

		# Catalog scrolls independently of left categories / right detail.
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.custom_minimum_size = Vector2(0, 220 if _compact else 360)
		vb.add_child(scroll)
		_grid = GridContainer.new()
		_grid.columns = 3 if _compact else 4
		_grid.add_theme_constant_override("h_separation", 12)
		_grid.add_theme_constant_override("v_separation", 14)
		_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(_grid)

		_feedback = UIStyle.label("", 13, UIStyle.OK)
		_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_feedback.custom_minimum_size = Vector2(0, 36)
		vb.add_child(_feedback)
		return panel

	func _build_detail() -> Control:
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", ItemUI.deep_panel_style(true))
		panel.custom_minimum_size = Vector2(260 if not _compact else 0, 0)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL if _compact else Control.SIZE_FILL
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		panel.size_flags_stretch_ratio = 1.05
		var scroll := ScrollContainer.new()
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		panel.add_child(scroll)
		_detail = VBoxContainer.new()
		_detail.add_theme_constant_override("separation", 8)
		_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(_detail)
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

	func _refresh(force_grid: bool = false) -> void:
		## force_grid: category/mode/trade changed. Selection/qty only patches chrome.
		if _gold_chip == null:
			return
		_gold_chip.text = "골드 %d G" % GameState.gold
		var lvl := 1
		if GameState.members.size() > 0:
			lvl = int(GameState.members[0].get("level", 1))
		_level_chip.text = "군주 Lv.%d" % lvl
		_style_active_buttons()
		_ensure_selection()
		var fp := _catalog_fingerprint()
		if force_grid or fp != _catalog_fp or _grid == null or _grid.get_child_count() == 0:
			_catalog_fp = fp
			_populate_grid()
		else:
			_patch_selection_chrome()
		_populate_detail()

	func _catalog_fingerprint() -> String:
		var parts: PackedStringArray = PackedStringArray()
		parts.append(mode)
		parts.append(category)
		if mode == "buy":
			for item in GameState.items_by_category(category):
				parts.append(str(item.get("id", "")))
		else:
			for e in GameState.inventory:
				var item := GameState.get_item(str(e.get("id", "")))
				if item.is_empty():
					continue
				if str(item.get("category", "")) != category:
					continue
				parts.append("%s#%d#%d" % [str(e.get("id", "")), int(e.get("enhance", 0)), int(e.get("qty", 0))])
		return "|".join(parts)

	func _card_key(id: String, enhance: int) -> String:
		return "%s#%d" % [id, enhance]

	func _patch_selection_chrome() -> void:
		for key in _cards_by_key.keys():
			var cell: Button = _cards_by_key[key] as Button
			if cell == null or not is_instance_valid(cell):
				continue
			var want := _card_key(selected_id, selected_enhance)
			ItemUI.set_card_selected(cell, str(key) == want)

	func _select_item(id: String, enhance: int = 0, reset_qty: bool = false) -> void:
		selected_id = id
		selected_enhance = enhance
		if reset_qty:
			buy_qty = 1
		_patch_selection_chrome()
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
		## Clear immediately, then spawn cards across frames so town BGM does not underrun.
		## First batch is deferred one frame so facility shell/layout cost does not stack.
		## Icons are cached in ItemUI — do not reload textures per refresh.
		if _grid == null:
			return
		for c in _grid.get_children():
			c.free()
		_cards_by_key.clear()
		_grid_gen += 1
		var gen := _grid_gen
		_grid_queue.clear()
		if mode == "buy":
			for item in GameState.items_by_category(category):
				_grid_queue.append({
					"kind": "buy",
					"item": item,
				})
		else:
			for e in GameState.inventory:
				var item := GameState.get_item(str(e.get("id", "")))
				if item.is_empty():
					continue
				if str(item.get("category", "")) != category:
					continue
				_grid_queue.append({
					"kind": "sell",
					"item": item,
					"enhance": int(e.get("enhance", 0)),
					"qty": int(e.get("qty", 0)),
				})
			if _grid_queue.is_empty():
				_grid.add_child(UIStyle.label("이 분류의 보유 아이템이 없습니다.", 13, UIStyle.TEXT_DIM))
				return
		_pump_grid(gen, true)

	func _pump_grid(gen: int, defer_first: bool = false) -> void:
		if gen != _grid_gen or _grid == null or not is_inside_tree():
			return
		if defer_first:
			await get_tree().process_frame
			if gen != _grid_gen or _grid == null or not is_inside_tree():
				return
		var n := 0
		while n < GRID_BATCH_SIZE and not _grid_queue.is_empty():
			var entry: Dictionary = _grid_queue.pop_front()
			if str(entry.get("kind", "")) == "buy":
				_grid.add_child(_make_buy_card(entry["item"]))
			else:
				_grid.add_child(_make_sell_card(
					entry["item"],
					int(entry.get("enhance", 0)),
					int(entry.get("qty", 0))
				))
			n += 1
		if _grid_queue.is_empty():
			return
		await get_tree().process_frame
		if gen != _grid_gen:
			return
		_pump_grid(gen, false)

	func _card_opts(extra: Dictionary) -> Dictionary:
		var opts := {
			"icon_size": 60 if _compact else 72,
			"min_w": 112 if _compact else 132,
			"min_h": 168 if _compact else 188,
		}
		for k in extra.keys():
			opts[k] = extra[k]
		return opts

	func _make_buy_card(item: Dictionary) -> Control:
		var id := str(item.get("id", ""))
		var selected := selected_id == id and selected_enhance == 0
		var slot := str(item.get("slot", ""))
		var sub := "장착 가능" if slot != "" else ItemUI.category_label(str(item.get("category")))
		var cell := ItemUI.make_item_card(item, _card_opts({
			"selected": selected,
			"price_text": "%d G" % int(item.get("price", 0)),
			"sub_text": sub,
		}))
		_cards_by_key[_card_key(id, 0)] = cell
		cell.pressed.connect(func():
			_select_item(id, 0, true)
		)
		return cell

	func _make_sell_card(item: Dictionary, enhance: int, qty: int) -> Control:
		var id := str(item.get("id", ""))
		var selected := selected_id == id and selected_enhance == enhance
		var unit := GameState.sell_price_of(id)
		if enhance > 0:
			unit = int(round(float(unit) * (1.0 + 0.08 * float(enhance))))
		var cell := ItemUI.make_item_card(item, _card_opts({
			"enhance": enhance,
			"selected": selected,
			"price_text": "%d G" % unit,
			"sub_text": "보유 x%d" % qty,
		}))
		_cards_by_key[_card_key(id, enhance)] = cell
		cell.pressed.connect(func():
			_select_item(id, enhance, false)
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
				_populate_detail()
			)
			qty_row.add_child(minus)
			qty_row.add_child(UIStyle.label("수량 %d" % buy_qty, 15))
			var plus := Button.new()
			plus.text = "+"
			plus.custom_minimum_size = Vector2(44, 44)
			UIStyle.apply_button(plus)
			plus.pressed.connect(func():
				buy_qty = mini(99, buy_qty + 1)
				_populate_detail()
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
		# Buy catalog identity unchanged — patch chrome/detail only (no grid flicker).
		_refresh(false)

	func _on_sell_pressed() -> void:
		var item := GameState.get_item(selected_id)
		var unit2 := GameState.sell_price_of(selected_id)
		if selected_enhance > 0:
			unit2 = int(round(float(unit2) * (1.0 + 0.08 * float(selected_enhance))))
		var sold_id := selected_id
		var sold_enh := selected_enhance
		var ok := GameState.sell_item(sold_id, 1, sold_enh)
		if ok:
			var remain := GameState.inventory_qty(sold_id, sold_enh)
			var enh_txt := (" +%d" % sold_enh) if sold_enh > 0 else ""
			_feedback.text = "판매 성공! %s%s +%d G · 남은 보유 %d · 현재 골드 %d G" % [
				item.get("name", sold_id), enh_txt, unit2, remain, GameState.gold
			]
			_feedback.add_theme_color_override("font_color", UIStyle.OK)
			_dialogue.text = "잘 팔렸어요! +%d G 획득했습니다." % unit2
			if remain <= 0:
				selected_id = ""
				selected_enhance = 0
		else:
			_feedback.text = "판매 실패"
			_feedback.add_theme_color_override("font_color", UIStyle.DANGER)
		_refresh(true)
