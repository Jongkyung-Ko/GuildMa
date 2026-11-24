extends SceneTree

# Run: godot4 --headless --path . -s res://scripts/core/smoke_test.gd


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok := true
	print("=== GuildMaster smoke test ===")

	# Prefer autoload if present, otherwise instance.
	var gs: Node = root.get_node_or_null("/root/GameState")
	if gs == null:
		gs = load("res://scripts/core/game_state.gd").new()
		root.add_child(gs)
		gs._ready()

	gs.new_game()
	if gs.members.size() != 5:
		printerr("FAIL starting party size")
		ok = false
	else:
		print("OK starting party: ", gs.members.size())

	var gold0: int = gs.gold
	if not gs.buy_item("potion_hp_s", 1):
		printerr("FAIL buy potion")
		ok = false
	elif gs.gold != gold0 - 150:
		printerr("FAIL gold deduct")
		ok = false
	else:
		print("OK shop purchase / gold")

	var adv: Dictionary = gs.adventurer_pool[0]
	var before: int = gs.members.size()
	if not gs.recruit_adventurer(adv):
		printerr("FAIL recruit")
		ok = false
	elif gs.members.size() != before + 1:
		printerr("FAIL member add")
		ok = false
	elif gs.recruit_adventurer(adv):
		printerr("FAIL duplicate recruit allowed")
		ok = false
	else:
		print("OK recruit + duplicate block")

	var mid: String = str(gs.members[1].get("id"))
	if not gs.train_member(mid):
		printerr("FAIL train")
		ok = false
	else:
		print("OK training")

	gs.set_injured_for_test(mid, true)
	if not gs.heal_member(mid):
		printerr("FAIL heal")
		ok = false
	else:
		print("OK infirmary heal")

	if not gs.accept_quest("q_wolf"):
		printerr("FAIL quest")
		ok = false
	elif gs.accept_quest("q_wolf"):
		printerr("FAIL duplicate quest")
		ok = false
	else:
		print("OK quest accept")

	gs.save_game()
	var gold_saved: int = gs.gold
	gs.gold = 0
	if not gs.load_game():
		printerr("FAIL load")
		ok = false
	elif gs.gold != gold_saved:
		printerr("FAIL save/load gold")
		ok = false
	else:
		print("OK save/load")

	print("=== RESULT: ", "PASS" if ok else "FAIL", " ===")
	quit(0 if ok else 1)
