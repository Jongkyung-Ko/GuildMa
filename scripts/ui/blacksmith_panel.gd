extends RefCounted
class_name BlacksmithPanel

const NPC_LINES := [
	"무엇을 강화하러 왔나?",
	"망치가 울리면 강함이 깃든다!",
	"실패해도 낙담 말게. 다시 벼리면 된다.",
]


static func mount(parent: Control, host: Node) -> void:
	for c in parent.get_children():
		c.free()
	var root := BlacksmithPanelRoot.new()
	root.host = host
	parent.add_child(root)
	root.build()


class BlacksmithPanelRoot extends Control:
	var host: Node
	var selected_id: String = ""
	var selected_enhance: int = 0
	var _equip_grid: GridContainer
	var _detail: VBoxContainer
	var _dialogue: Label
	var _feedback: Label
	var _furnace_glow: ColorRect
	var _spark_layer: Control
	var _hammer: Label
	var _compact: bool = false
	var _busy: bool = false
	var _glow_tween: Tween

	func build() -> void:
		set_anchors_preset(PRESET_FULL_RECT)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_EXPAND_FILL
		GameState.state_changed.connect(_refresh)
		tree_exiting.connect(_stop_glow)
		_rebuild_layout()
		resized.connect(_on_resized)
		_on_resized()

	func _stop_glow() -> void:
		if _glow_tween and _glow_tween.is_valid():
			_glow_tween.kill()
			_glow_tween = null

	func _on_resized() -> void:
		var compact := size.x > 0 and (size.x < 720 or size.y > size.x or size.y < 480)
		if compact != _compact:
			_compact = compact
			_rebuild_layout()

	func _rebuild_layout() -> void:
		for c in get_children():
			c.free()
		var scroll := ScrollContainer.new()
		scroll.set_anchors_preset(PRESET_FULL_RECT)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		add_child(scroll)
		var body: Control = VBoxContainer.new() if _compact else HBoxContainer.new()
		body.add_theme_constant_override("separation", 10)
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.add_child(body)
		body.add_child(_build_npc())
		body.add_child(_build_enhance_stage())
		body.add_child(_build_inventory())
		_refresh()

	func _build_npc() -> Control:
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", ItemUI.deep_panel_style(false))
		panel.custom_minimum_size = Vector2(220 if not _compact else 0, 0)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL if _compact else Control.SIZE_FILL
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 8)
		panel.add_child(vb)
		vb.add_child(UIStyle.label("대장간", 18, UIStyle.GOLD_BRIGHT))

		var stage := Control.new()
		stage.custom_minimum_size = Vector2(0, 130 if _compact else 230)
		stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.add_child(stage)

		var bg := TextureRect.new()
		bg.texture = load("res://assets/backgrounds/smith_interior.png")
		bg.set_anchors_preset(PRESET_FULL_RECT)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		stage.add_child(bg)

		_furnace_glow = ColorRect.new()
		_furnace_glow.color = Color(1.0, 0.45, 0.1, 0.0)
		_furnace_glow.set_anchors_preset(PRESET_FULL_RECT)
		_furnace_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(_furnace_glow)

		_spark_layer = Control.new()
		_spark_layer.set_anchors_preset(PRESET_FULL_RECT)
		_spark_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(_spark_layer)

		_hammer = UIStyle.label("타격!", 22, UIStyle.GOLD_BRIGHT)
		_hammer.visible = false
		_hammer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_hammer.set_anchors_preset(PRESET_CENTER)
		_hammer.offset_left = -40
		_hammer.offset_top = -18
		_hammer.offset_right = 40
		_hammer.offset_bottom = 18
		stage.add_child(_hammer)

		if _glow_tween and _glow_tween.is_valid():
			_glow_tween.kill()
		_glow_tween = create_tween()
		_glow_tween.set_loops(40)
		_glow_tween.tween_property(_furnace_glow, "color:a", 0.28, 1.0)
		_glow_tween.tween_property(_furnace_glow, "color:a", 0.08, 1.0)

		_dialogue = UIStyle.label(NPC_LINES[0], 13, UIStyle.TEXT)
		_dialogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(_dialogue)
		var guide := UIStyle.label(
			"무기·방어구를 선택해 +0~+%d까지 강화합니다.\n재료와 골드를 소모하며, 실패 시 규칙은 [%s]입니다." % [
				GameState.enhance_max_level(),
				str(GameState.enhance_cfg().get("failure_rule", "keep")),
			],
			12, UIStyle.TEXT_DIM
		)
		guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(guide)
		return panel

	func _build_enhance_stage() -> Control:
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", ItemUI.deep_panel_style(false))
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		panel.size_flags_stretch_ratio = 1.4
		_detail = VBoxContainer.new()
		_detail.add_theme_constant_override("separation", 8)
		panel.add_child(_detail)
		return panel

	func _build_inventory() -> Control:
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", ItemUI.deep_panel_style(true))
		panel.custom_minimum_size = Vector2(240 if not _compact else 0, 0)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL if _compact else Control.SIZE_FILL
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 8)
		panel.add_child(vb)
		vb.add_child(UIStyle.label("강화 가능 장비", 16, UIStyle.GOLD_BRIGHT))
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.custom_minimum_size = Vector2(0, 250)
		vb.add_child(scroll)
		_equip_grid = GridContainer.new()
		_equip_grid.columns = 2 if _compact else 2
		_equip_grid.add_theme_constant_override("h_separation", 8)
		_equip_grid.add_theme_constant_override("v_separation", 8)
		scroll.add_child(_equip_grid)
		_feedback = UIStyle.label("", 13, UIStyle.OK)
		_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(_feedback)
		return panel

	func _refresh() -> void:
		if _equip_grid == null:
			return
		_ensure_selection()
		_populate_inventory()
		_populate_detail()

	func _ensure_selection() -> void:
		if selected_id != "" and GameState.inventory_qty(selected_id, selected_enhance) > 0:
			return
		selected_id = ""
		selected_enhance = 0
		for e in GameState.inventory:
			var iid := str(e.get("id", ""))
			if GameState.can_enhance_item(iid):
				selected_id = iid
				selected_enhance = int(e.get("enhance", 0))
				return

	func _populate_inventory() -> void:
		for c in _equip_grid.get_children():
			c.free()
		var any := false
		for e in GameState.inventory:
			var iid := str(e.get("id", ""))
			if not GameState.can_enhance_item(iid):
				continue
			var item := GameState.get_item(iid)
			if item.is_empty():
				continue
			any = true
			var enh := int(e.get("enhance", 0))
			var selected := selected_id == iid and selected_enhance == enh
			var cell := ItemUI.make_item_card(item, {
				"enhance": enh,
				"selected": selected,
				"price_text": "+%d" % enh,
				"sub_text": "x%d" % int(e.get("qty", 0)),
				"icon_size": 60 if _compact else 68,
				"min_w": 100,
				"min_h": 132,
			})
			var id_copy := iid
			var enh_copy := enh
			cell.pressed.connect(func():
				selected_id = id_copy
				selected_enhance = enh_copy
				_refresh()
			)
			_equip_grid.add_child(cell)
		if not any:
			_equip_grid.add_child(UIStyle.label("강화할 무기/방어구를 상점에서 구매하세요.", 12, UIStyle.TEXT_DIM))

	func _populate_detail() -> void:
		for c in _detail.get_children():
			c.free()
		_detail.add_child(UIStyle.label("장비 강화", 20, UIStyle.GOLD_BRIGHT))
		if selected_id == "":
			_detail.add_child(UIStyle.label("오른쪽에서 장비를 선택하세요.", 13, UIStyle.TEXT_DIM))
			return
		var item := GameState.get_item(selected_id)
		if item.is_empty():
			return
		var cur := selected_enhance
		var nxt := mini(cur + 1, GameState.enhance_max_level())
		var maxed := cur >= GameState.enhance_max_level()

		var compare := HBoxContainer.new()
		compare.alignment = BoxContainer.ALIGNMENT_CENTER
		compare.add_theme_constant_override("separation", 16)
		_detail.add_child(compare)
		var left := VBoxContainer.new()
		left.add_child(ItemUI.make_icon_frame(item, 88 if not _compact else 72, cur, true))
		left.add_child(UIStyle.label("현재 +%d" % cur, 15, UIStyle.GOLD_BRIGHT))
		compare.add_child(left)
		compare.add_child(UIStyle.label(">>>", 24, UIStyle.GOLD_BRIGHT))
		var right := VBoxContainer.new()
		right.add_child(ItemUI.make_icon_frame(item, 88 if not _compact else 72, nxt, false))
		right.add_child(UIStyle.label("강화 +%d" % nxt, 15, Color(1.0, 0.55, 0.2)))
		compare.add_child(right)

		_detail.add_child(UIStyle.label(str(item.get("name")), 16, UIStyle.GOLD_BRIGHT))
		_detail.add_child(UIStyle.label("%s · %s" % [
			ItemUI.rarity_label(str(item.get("rarity", "common"))),
			ItemUI.category_label(str(item.get("category"))),
		], 12, ItemUI.rarity_color(str(item.get("rarity", "common")))))
		var sub := ItemUI.subcategory_label(str(item.get("subcategory", "")))
		if sub != "":
			_detail.add_child(UIStyle.label("세부: %s" % sub, 12, UIStyle.TEXT_DIM))

		if maxed:
			_detail.add_child(UIStyle.label("최대 강화에 도달했습니다.", 14, UIStyle.GOLD_BRIGHT))
			return

		_detail.add_child(UIStyle.label("능력치 변화", 14, UIStyle.TEXT_DIM))
		for entry in ItemUI.stat_delta_lines(item, cur, nxt):
			var col := UIStyle.OK if bool(entry.get("positive", true)) else UIStyle.DANGER
			_detail.add_child(UIStyle.label(str(entry.get("text")), 14, col))

		var gold_cost := GameState.enhance_gold_cost(cur)
		var rate := GameState.enhance_success_rate(cur)
		var cost_panel := PanelContainer.new()
		cost_panel.add_theme_stylebox_override("panel", ItemUI.deep_panel_style(false, Color(0.55, 0.4, 0.18)))
		var cost_vb := VBoxContainer.new()
		cost_vb.add_theme_constant_override("separation", 6)
		cost_panel.add_child(cost_vb)
		cost_vb.add_child(UIStyle.label("성공 확률  %d%%" % rate, 16, UIStyle.GOLD_BRIGHT))
		cost_vb.add_child(UIStyle.label("강화 비용  %d G" % gold_cost, 14))
		var mats := GameState.enhance_materials_for(cur)
		for m in mats:
			var mid := str(m.get("id", ""))
			var need: int = int(m.get("qty", 1))
			var have := GameState.inventory_qty(mid)
			var mat_item := GameState.get_item(mid)
			var label_txt := "%s  %d / %d" % [mat_item.get("name", mid), have, need]
			var col2 := UIStyle.OK if have >= need else UIStyle.DANGER
			if have < need and m.has("alt_id"):
				var alt := str(m.get("alt_id"))
				var alt_need := int(m.get("alt_qty", need))
				var alt_have := GameState.inventory_qty(alt)
				var alt_item := GameState.get_item(alt)
				label_txt += "  (또는 %s %d/%d)" % [alt_item.get("name", alt), alt_have, alt_need]
				if alt_have >= alt_need:
					col2 = UIStyle.OK
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			row.add_child(ItemUI.make_icon_frame(mat_item if not mat_item.is_empty() else {"id": mid, "rarity": "common"}, 40))
			row.add_child(UIStyle.label(label_txt, 13, col2))
			cost_vb.add_child(row)
		_detail.add_child(cost_panel)

		var btn := Button.new()
		btn.text = "강화 실행  (+%d → +%d)" % [cur, nxt]
		btn.custom_minimum_size = Vector2(0, 54)
		btn.disabled = _busy
		UIStyle.apply_button(btn)
		btn.pressed.connect(_on_enhance_pressed)
		_detail.add_child(btn)

	func _on_enhance_pressed() -> void:
		if _busy or selected_id == "":
			return
		_busy = true
		await _play_enhance_vfx()
		var result: Dictionary = GameState.enhance_item(selected_id, selected_enhance)
		_busy = false
		if bool(result.get("ok", false)):
			selected_enhance = int(result.get("new_enhance", selected_enhance))
			if bool(result.get("success", false)):
				_feedback.text = str(result.get("message", "성공"))
				_feedback.add_theme_color_override("font_color", UIStyle.GOLD_BRIGHT)
				_dialogue.text = NPC_LINES[1]
				await _flash_result(Color(1.0, 0.85, 0.2, 0.55))
			else:
				_feedback.text = str(result.get("message", "실패"))
				_feedback.add_theme_color_override("font_color", UIStyle.DANGER)
				_dialogue.text = NPC_LINES[2]
				await _flash_result(Color(0.9, 0.2, 0.15, 0.55))
		else:
			_feedback.text = str(result.get("message", "실패"))
			_feedback.add_theme_color_override("font_color", UIStyle.DANGER)
		_refresh()

	func _play_enhance_vfx() -> void:
		_hammer.visible = true
		_hammer.rotation = -0.4
		var tw := create_tween()
		tw.tween_property(_furnace_glow, "color:a", 0.55, 0.15)
		tw.parallel().tween_property(_hammer, "rotation", 0.55, 0.18)
		tw.tween_property(_hammer, "rotation", -0.2, 0.12)
		await tw.finished
		_spawn_sparks()
		await get_tree().create_timer(0.25).timeout
		_hammer.visible = false

	func _spawn_sparks() -> void:
		if _spark_layer == null:
			return
		for i in 12:
			var spark := ColorRect.new()
			spark.color = Color(1.0, 0.75 + randf() * 0.2, 0.2, 1.0)
			spark.size = Vector2(4, 4)
			spark.position = Vector2(80 + randf() * 60, 90 + randf() * 40)
			_spark_layer.add_child(spark)
			var tw := create_tween()
			var dest := spark.position + Vector2(randf_range(-40, 40), randf_range(-70, -20))
			tw.tween_property(spark, "position", dest, 0.35)
			tw.parallel().tween_property(spark, "color:a", 0.0, 0.35)
			tw.tween_callback(spark.queue_free)

	func _flash_result(color: Color) -> void:
		var flash := ColorRect.new()
		flash.color = color
		flash.set_anchors_preset(PRESET_FULL_RECT)
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(flash)
		var tw := create_tween()
		tw.tween_property(flash, "color:a", 0.0, 0.45)
		tw.tween_callback(flash.queue_free)
		await tw.finished
