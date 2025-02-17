@tool
extends EditorPlugin

func _enter_tree() -> void:
    add_autoload_singleton("ECS", "res://addons/warp-ecs/ecs.gd")

func _exit_tree() -> void:
    remove_autoload_singleton("ECS")
