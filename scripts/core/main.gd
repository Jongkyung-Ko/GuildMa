extends Node


func _ready() -> void:
	call_deferred("_boot")


func _boot() -> void:
	SceneRouter.go_title()
