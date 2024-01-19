@tool
extends EditorPlugin


func _enter_tree() -> void:
	add_custom_type("Terrain", "Node3D", preload("terrain.gd"), preload("icons/terrain.svg"))

func _exit_tree() -> void:
	remove_custom_type("Terrain")
