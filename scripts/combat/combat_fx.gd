class_name CombatFx
extends RefCounted

## Floating numbers, white-flash helpers, camera shake, brief hit-stop.


static func spawn_number(parent: Node, world_pos: Vector2, amount: int, kind: String = "damage") -> void:
	if parent == null:
		return
	var color := Color(1.0, 0.96, 0.92, 1)
	var size := 16
	var text := str(amount)
	match kind:
		"heal":
			color = Color(0.35, 0.95, 0.45, 1)
			text = "+%d" % amount
			size = 17
		"crit":
			color = Color(1.0, 0.88, 0.25, 1)
			size = 22
		"heavy":
			color = Color(1.0, 0.55, 0.2, 1)
			size = 19
		_:
			pass
	var ft := FloatingText.new()
	parent.add_child(ft)
	ft.global_position = world_pos + Vector2(randf_range(-6, 6), -52)
	ft.setup(text, color, size)


static func white_flash(sprite: CanvasItem, duration: float = 0.1) -> void:
	if sprite == null:
		return
	sprite.modulate = Color(2.4, 2.4, 2.4, 1.0)
	var tw := sprite.create_tween()
	tw.tween_property(sprite, "modulate", Color(1, 1, 1, 1), duration)


static func shake_sprite(node: Node2D, strength: float = 4.0, pulses: int = 3) -> void:
	if node == null:
		return
	var base := node.position
	var tw := node.create_tween()
	for i in range(pulses):
		var off := Vector2(randf_range(-strength, strength), randf_range(-strength * 0.6, strength * 0.6))
		tw.tween_property(node, "position", base + off, 0.03)
	tw.tween_property(node, "position", base, 0.04)


static func hit_stop(manager: Node, duration: float = 0.05) -> void:
	if manager == null or duration <= 0.0:
		return
	if manager.has_method("request_hit_stop"):
		manager.request_hit_stop(duration)
