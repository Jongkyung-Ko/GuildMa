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
		var panel := UIStyle.make_panel()
		panel.custom_minimum_size = Vector2(210 if not _compact else 0, 0)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL if _compact else Control.SIZE_FILL
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 8)
		panel.add_child(vb)
		vb.add_child(UIStyle.label("대장장이", 16, UIStyle.GOLD_BRIGHT))

		var stage := Control.new()
		stage.custom_minimum_size = Vector2(0, 120 if _compact else 220)
		stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.add_child(stage)

		var bg := TextureRect.new()
		bg.texture = load("res://assets/backgrounds/smith_interior.png")
		bg.set_anchors_preset(PRESET_FULL_RECT)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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

		# Soft furnace pulse (finite loops — avoid infinite tween on scene swap)
		if _glow_tween and _glow_tween.is_valid():
			_glow_tween.kill()
		_glow_tween = create_tween()
		_glow_tween.set_loops(40)
		_glow_tween.tween_property(_furnace_glow, "color:a", 0.22, 1.1)
		_glow_tween.tween_property(_furnace_glow, "color:a", 0.06, 1.1)

		_dialogue = UIStyle.label(NPC_LINES[0], 13, UIStyle.TEXT)
		_dialogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(_dialogue)
		vb.add_child(UIStyle.label("강화 +0 ~ +%d · 실패 규칙: %s" % [
			GameState.enhance_max_level(),
			str(GameState.enhance_cfg().get("failure_rule", "keep")),
		], 12, UIStyle.TEXT_DIM))
		return panel

	func _build_enhance_stage() -> Control:
		var panel := UIStyle.make_panel()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		panel.size_flags_stretch_ratio = 1.35
		_detail = VBoxContainer.new()
		_detail.add_theme_constant_override("separation", 8)
		panel.add_child(_detail)
		return panel

	func _build_inventory() -> Control:
		var panel := UIStyle.make_panel(true)
		panel.custom_minimum_size = Vector2(230 if not _compact else 0, 0)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL if _compact else Control.SIZE_FILL
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 8)
		panel.add_child(vb)
		vb.add_child(UIStyle.label("강화 가능 장비", 16, UIStyle.GOLD_BRIGHT))
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.custom_minimum_size = Vector2(0, 240)
		vb.add_child(scroll)
		_equip_grid = GridContainer.new()
		_equip_grid.columns = 3 if _compact else 2
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
			any = true
			var item := GameState.get_item(iid)
			var enh := int(e.get("enhance", 0))
			var selected := selected_id == iid and selected_enhance == enh
			var cell := Button.new()
			cell.custom_minimum_size = Vector2(84, 96)
			cell.flat = true
			UIStyle.apply_button(cell)
			var vb := VBoxContainer.new()
			vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_child(vb)
			vb.add_child(ItemUI.make_icon_frame(item, 56, enh, selected))
			var nm := UIStyle.label(str(item.get("name")), 11)
			nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			nm.clip_text = true
			nm.custom_minimum_size = Vector2(76, 0)
			vb.add_child(nm)
			vb.add_child(UIStyle.label("x%d" % int(e.get("qty", 0)), 11, UIStyle.TEXT_DIM))
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
		compare.add_theme_constant_override("separation", 12)
		_detail.add_child(compare)
		var left := VBoxContainer.new()
		left.add_child(ItemUI.make_icon_frame(item, 72, cur, true))
		left.add_child(UIStyle.label("+%d" % cur, 16, UIStyle.GOLD_BRIGHT))
		compare.add_child(left)
		compare.add_child(UIStyle.label(">>>", 22, UIStyle.GOLD_BRIGHT))
		var right := VBoxContainer.new()
		right.add_child(ItemUI.make_icon_frame(item, 72, nxt, false))
		right.add_child(UIStyle.label("+%d" % nxt, 16, Color(1.0, 0.55, 0.2)))
		compare.add_child(right)

		_detail.add_child(UIStyle.label(str(item.get("name")), 16, UIStyle.GOLD_BRIGHT))
		for line in ItemUI.stats_lines(item, cur):
			_detail.add_child(UIStyle.label("현재  %s" % line, 13, UIStyle.TEXT))
		if not maxed:
			for line2 in ItemUI.stats_lines(item, nxt):
				_detail.add_child(UIStyle.label("다음  %s" % line2, 13, UIStyle.OK))

		if maxed:
			_detail.add_child(UIStyle.label("최대 강화에 도달했습니다.", 14, UIStyle.GOLD_BRIGHT))
			return

		var gold_cost := GameState.enhance_gold_cost(cur)
		var rate := GameState.enhance_success_rate(cur)
		_detail.add_child(UIStyle.label("성공 확률 %d%%" % rate, 15, UIStyle.GOLD_BRIGHT))
		_detail.add_child(UIStyle.label("비용 %d G" % gold_cost, 14))

		var mats := GameState.enhance_materials_for(cur)
		for m in mats:
			var mid := str(m.get("id", ""))
			var need: int = int(m.get("qty", 1))
			var have := GameState.inventory_qty(mid)
			var mat_item := GameState.get_item(mid)
			var label_txt := "%s  %d / %d" % [mat_item.get("name", mid), have, need]
			var col := UIStyle.OK if have >= need else UIStyle.DANGER
			if have < need and m.has("alt_id"):
				var alt := str(m.get("alt_id"))
				var alt_need := int(m.get("alt_qty", need))
				var alt_have := GameState.inventory_qty(alt)
				var alt_item := GameState.get_item(alt)
				label_txt += "  (또는 %s %d/%d)" % [alt_item.get("name", alt), alt_have, alt_need]
				if alt_have >= alt_need:
					col = UIStyle.OK
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			row.add_child(ItemUI.make_icon_frame(mat_item if not mat_item.is_empty() else {"id": mid, "rarity": "common"}, 36))
			row.add_child(UIStyle.label(label_txt, 13, col))
			_detail.add_child(row)

		var btn := Button.new()
		btn.text = "강화 실행"
		btn.custom_minimum_size = Vector2(0, 52)
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
