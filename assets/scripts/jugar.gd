extends Button

@export var main_scene: PackedScene

func _ready() -> void:
	pressed.connect(_jugar, 4)
	
func _jugar():
	get_tree().change_scene_to_file("res://scenes/limbo.tscn")
