extends RefCounted
class_name ItemUI

## Shared item presentation helpers (rarity borders, icons, category labels).

const RARITY_COLORS := {
	"common": Color(0.62, 0.64, 0.68),
	"uncommon": Color(0.35, 0.78, 0.42),
	"rare": Color(0.35, 0.55, 0.95),
	"epic": Color(0.72, 0.38, 0.92),
	"legendary": Color(1.0, 0.72, 0.18),
}

const CATEGORY_LABELS := {
	"all": "전체",
	"weapon": "무기",
	"armor": "방어구",
	"accessory": "장신구",
	"consumable": "소모품",
	"material": "재료",
}

## Shop top-level filters stay these five; subcategory is display/data only.
const CATEGORY_ORDER := ["weapon", "armor", "accessory", "consumable", "material"]

const SUBCATEGORY_LABELS := {
	"weapon_1h": "한손 무기",
	"weapon_2h": "양손 무기",
	"weapon_ranged": "원거리",
	"weapon_magic": "마법 무기",
	"body": "갑옷",
	"shield": "방패",
	"helm": "투구",
	"gloves": "장갑",
	"boots": "신발",
	"ring": "반지",
	"amulet": "부적",
	"belt": "벨트",
	"cloak": "망토",
	"potion": "물약",
	"elixir": "영약",
	"food": "음식",
	"scroll": "주문서",
	"ore": "광석",
	"crystal": "결정",
	"hide": "가죽/천",
	"part": "부품",
	"special": "특수",
}

const CARD_BG := Color(0.09, 0.08, 0.1, 0.96)
const CARD_BG_DEEP := Color(0.07, 0.06, 0.08, 0.98)
const SLOT_BG := Color(0.05, 0.045, 0.055, 1.0)


static func rarity_color(rarity: String) -> Color:
	return RARITY_COLORS.get(rarity, RARITY_COLORS["common"])


static func rarity_label(rarity: String) -> String:
	match rarity:
		"common":
			return "일반"
		"uncommon":
			return "고급"
		"rare":
			return "희귀"
		"epic":
			return "영웅"
		"legendary":
			return "전설"
		_:
			return rarity


static func category_label(category: String) -> String:
	return CATEGORY_LABELS.get(category, category)


static func subcategory_label(subcategory: String) -> String:
	if subcategory == "":
		return ""
	return SUBCATEGORY_LABELS.get(subcategory, subcategory)


## Path → Texture2D. Avoids repeat ResourceLoader work across shop category toggles.
static var _icon_cache: Dictionary = {}
static var _placeholder_icon: Texture2D = null


static func _tex_area(tex: Texture2D) -> int:
	if tex == null:
		return 0
	return int(tex.get_width()) * int(tex.get_height())


static func _load_cached(path: String) -> Texture2D:
	if path == "":
		return null
	if _icon_cache.has(path):
		return _icon_cache[path] as Texture2D
	if not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path) as Texture2D
	if tex:
		_icon_cache[path] = tex
	return tex


static func placeholder_icon() -> Texture2D:
	## Neutral missing-art tile — never substitute another item's icon.
	if _placeholder_icon != null:
		return _placeholder_icon
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.12, 0.11, 0.14, 1.0))
	for y in range(64):
		for x in range(64):
			if x < 2 or y < 2 or x >= 62 or y >= 62:
				img.set_pixel(x, y, Color(0.55, 0.48, 0.28, 1.0))
			elif (x + y) % 8 < 2:
				img.set_pixel(x, y, Color(0.18, 0.16, 0.2, 1.0))
	_placeholder_icon = ImageTexture.create_from_image(img)
	_icon_cache["__placeholder__"] = _placeholder_icon
	return _placeholder_icon


static func load_icon(item: Dictionary) -> Texture2D:
	## Prefer the highest-resolution existing source. No fake upscale; placeholder if none.
	var candidates: Array = []
	var path := str(item.get("icon", ""))
	if path != "":
		candidates.append(path)
	var iid := str(item.get("id", ""))
	if iid != "":
		candidates.append("res://assets/items/%s.png" % iid)
		candidates.append("res://assets/sprites/items/%s.png" % iid)
	var best: Texture2D = null
	var best_area := 0
	var seen: Dictionary = {}
	for raw in candidates:
		var p := str(raw)
		if p == "" or seen.has(p):
			continue
		seen[p] = true
		var tex := _load_cached(p)
		if tex == null:
			continue
		var area := _tex_area(tex)
		if area > best_area:
			best = tex
			best_area = area
	if best != null:
		return best
	return placeholder_icon()


static func deep_panel_style(active: bool = false, border: Color = UIStyle.GOLD) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = CARD_BG if not active else Color(0.14, 0.11, 0.07, 0.97)
	s.border_color = UIStyle.GOLD_BRIGHT if active else border
	s.set_border_width_all(3 if active else 2)
	s.set_corner_radius_all(8)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	s.shadow_color = Color(0, 0, 0, 0.5)
	s.shadow_size = 5
	return s


static func make_icon_frame(item: Dictionary, size: float = 72.0, enhance: int = 0, selected: bool = false) -> PanelContainer:
	var rarity := str(item.get("rarity", "common"))
	var border := rarity_color(rarity)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = SLOT_BG
	style.border_color = UIStyle.GOLD_BRIGHT if selected else border
	style.set_border_width_all(4 if selected else 3)
	style.set_corner_radius_all(8)
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(size, size)

	var stack := Control.new()
	stack.custom_minimum_size = Vector2(size - 10, size - 10)
	panel.add_child(stack)

	var tex := TextureRect.new()
	tex.texture = load_icon(item)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# Keep native aspect inside the square frame — never stretch-distort.
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Crisp pixel presentation; LINEAR mipmaps looked like soft fake-upscale.
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.add_child(tex)

	if enhance > 0:
		var badge := Label.new()
		badge.text = "+%d" % enhance
		badge.add_theme_font_size_override("font_size", 13)
		badge.add_theme_color_override("font_color", UIStyle.GOLD_BRIGHT)
		badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		badge.offset_left = -34
		badge.offset_top = 0
		badge.offset_right = -2
		badge.offset_bottom = 18
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stack.add_child(badge)
	return panel


static func make_item_card(item: Dictionary, opts: Dictionary = {}) -> Button:
	## Shop/blacksmith selectable card: icon + name + rarity + price/qty.
	## Taller defaults + autowrap so subtype/status lines are not clipped.
	var enhance: int = int(opts.get("enhance", 0))
	var selected: bool = bool(opts.get("selected", false))
	var price_text: String = str(opts.get("price_text", ""))
	var sub_text: String = str(opts.get("sub_text", ""))
	var subtype_text: String = str(opts.get("subtype_text", ""))
	if subtype_text == "":
		subtype_text = subcategory_label(str(item.get("subcategory", "")))
	var icon_size: float = float(opts.get("icon_size", 72))
	var min_w: float = float(opts.get("min_w", 128))
	var min_h: float = float(opts.get("min_h", 178))

	var cell := Button.new()
	cell.flat = true
	cell.custom_minimum_size = Vector2(min_w, min_h)
	cell.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	UIStyle.apply_button(cell)
	cell.set_meta("item_id", str(item.get("id", "")))
	cell.set_meta("item_enhance", enhance)
	cell.set_meta("item_rarity", str(item.get("rarity", "common")))
	var wrap := PanelContainer.new()
	wrap.name = "CardWrap"
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_theme_stylebox_override("panel", deep_panel_style(selected, rarity_color(str(item.get("rarity", "common")))))
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	cell.add_child(wrap)
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 5)
	wrap.add_child(vb)
	var icon_row := CenterContainer.new()
	icon_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_row.add_child(make_icon_frame(item, icon_size, enhance, selected))
	vb.add_child(icon_row)
	var name_l := UIStyle.label(str(item.get("name")), 12, UIStyle.TEXT)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.custom_minimum_size = Vector2(min_w - 18, 28)
	vb.add_child(name_l)
	var rar := UIStyle.label(rarity_label(str(item.get("rarity", "common"))), 11, rarity_color(str(item.get("rarity", "common"))))
	rar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(rar)
	if subtype_text != "":
		var st := UIStyle.label(subtype_text, 11, UIStyle.TEXT_DIM)
		st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		st.custom_minimum_size = Vector2(min_w - 18, 16)
		vb.add_child(st)
	if price_text != "":
		var pl := UIStyle.label(price_text, 12, UIStyle.GOLD_BRIGHT)
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(pl)
	if sub_text != "":
		var sl := UIStyle.label(sub_text, 11, UIStyle.TEXT_DIM)
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sl.custom_minimum_size = Vector2(min_w - 18, 16)
		vb.add_child(sl)
	return cell


static func set_card_selected(cell: Button, selected: bool) -> void:
	## In-place chrome update — avoids tearing down TextureRects (shop flicker root).
	if cell == null or not is_instance_valid(cell):
		return
	var wrap := cell.get_node_or_null("CardWrap") as PanelContainer
	if wrap == null:
		return
	var rarity := str(cell.get_meta("item_rarity", "common"))
	wrap.add_theme_stylebox_override("panel", deep_panel_style(selected, rarity_color(rarity)))
	# Sync icon frame border if present.
	for n in wrap.find_children("*", "PanelContainer", true, false):
		var p := n as PanelContainer
		if p == null or p == wrap:
			continue
		if p.custom_minimum_size.x < 40.0:
			continue
		var style := p.get_theme_stylebox("panel") as StyleBoxFlat
		if style == null:
			continue
		var next := style.duplicate() as StyleBoxFlat
		next.border_color = Color(1.0, 0.88, 0.45) if selected else rarity_color(rarity)
		next.set_border_width_all(4 if selected else 3)
		p.add_theme_stylebox_override("panel", next)
		break


static func stats_lines(item: Dictionary, enhance: int = 0) -> Array:
	var lines: Array = []
	var keys := [
		["atk", "공격력"], ["matk", "마법 공격"], ["def", "방어력"],
		["acc", "명중"], ["crit", "치명타"], ["heal", "HP 회복"],
		["heal_mp", "MP 회복"], ["buff_atk", "일시 공격"],
		["str", "STR"], ["vit", "VIT"], ["agi", "AGI"],
	]
	for pair in keys:
		var k: String = str(pair[0])
		var label: String = str(pair[1])
		if not item.has(k):
			continue
		var base: int = int(item.get(k, 0))
		var shown: int = base
		if enhance > 0 and k in ["atk", "matk", "def", "acc", "crit"]:
			shown = GameState.enhanced_stat_value(base, enhance)
		var delta: String = ""
		if enhance > 0 and shown != base:
			delta = " (+%d)" % (shown - base)
		lines.append("%s +%d%s" % [label, shown, delta])
	var req := int(item.get("req_level", 0))
	if req > 0:
		lines.append("요구 레벨 Lv.%d" % req)
	return lines


static func stat_delta_lines(item: Dictionary, from_enhance: int, to_enhance: int) -> Array:
	## Returns {text, positive} dicts for before→after display.
	var out: Array = []
	var keys := [["atk", "공격력"], ["matk", "마법 공격"], ["def", "방어력"], ["acc", "명중"], ["crit", "치명타"]]
	for pair in keys:
		var k: String = str(pair[0])
		if not item.has(k):
			continue
		var base: int = int(item.get(k, 0))
		var a: int = GameState.enhanced_stat_value(base, from_enhance) if from_enhance > 0 else base
		if from_enhance == 0:
			a = base
		var b: int = GameState.enhanced_stat_value(base, to_enhance)
		var diff: int = b - a
		var col_positive := diff >= 0
		var text := "%s  %d → %d" % [str(pair[1]), a, b]
		if diff != 0:
			text += " (%s%d)" % ["+" if diff > 0 else "", diff]
		out.append({"text": text, "positive": col_positive, "diff": diff})
	return out
