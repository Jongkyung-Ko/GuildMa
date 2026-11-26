extends Node


func _ready() -> void:
	call_deferred("_boot")


func _boot() -> void:
	# First boot: title theme (Sovereign of the Keep) starts with the title scene.
	SceneRouter.go_title()
