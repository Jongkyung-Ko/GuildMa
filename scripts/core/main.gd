extends Node


func _ready() -> void:
	call_deferred("_boot")


func _boot() -> void:
	# First boot → title BGM (Sovereign of the Keep) via AudioManager.on_enter_title().
	SceneRouter.go_title()
