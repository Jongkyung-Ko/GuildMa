extends RefCounted
class_name ItemUI

## Shared item presentation helpers (rarity borders, icons, category labels).

const RARITY_COLORS := {
	"common": Color(0.62, 0.64, 0.68),
	"uncommon": Color(0.35, 0.78, 0.42),
	"rare": Color(0.35, 0.55, 0.95),
	"epic": Color(0.72, 0.38, 0.92),
	"legendary": Color(1.0, 0.78, 0.22),
}

const CATEGORY_LABELS := {
	"all": "전체",
	"weapon": "무기",
	"armor": "방어구",
	"accessory": "장신구",
	"consumable": "소모품",
	"material": "재료",
}

const CATEGORY_ORDER := ["weapon", "armor", "accessory", "consumable", "material"]


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


static func load_icon(item: Dictionary) -> Texture2D:
	var path := str(item.get("icon", ""))
	if path != "" and ResourceLoader.exists(path):
		return load(path) as Texture2D
	var fallback := "res://assets/sprites/items/%s.png" % str(item.get("id", ""))
	if ResourceLoader.exists(fallback):
		return load(fallback) as Texture2D
	if ResourceLoader.exists("res://assets/sprites/icons/shop.png"):
		return load("res://assets/sprites/icons/shop.png") as Texture2D
	return null


static func make_icon_frame(item: Dictionary, size: float = 56.0, enhance: int = 0, selected: bool = false) -> PanelContainer:
	var rarity := str(item.get("rarity", "common"))
	var border := rarity_color(rarity)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.06, 0.95)
	style.border_color = UIStyle.GOLD_BRIGHT if selected else border
	style.set_border_width_all(3 if selected else 2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(size, size)

	var stack := Control.new()
	stack.custom_minimum_size = Vector2(size - 8, size - 8)
	panel.add_child(stack)

	var tex := TextureRect.new()
	tex.texture = load_icon(item)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.add_child(tex)

	if enhance > 0:
		var badge := Label.new()
		badge.text = "+%d" % enhance
		badge.add_theme_font_size_override("font_size", 12)
		badge.add_theme_color_override("font_color", UIStyle.GOLD_BRIGHT)
		badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		badge.offset_left = -28
		badge.offset_top = 0
		badge.offset_right = -2
		badge.offset_bottom = 16
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stack.add_child(badge)
	return panel


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
