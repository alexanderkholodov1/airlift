extends Area2D

@export_enum("WHEEL_UP", "WHEEL_DOWN") var scroll_direction: String = "WHEEL_UP"

var player_inside: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _input(event: InputEvent) -> void:
	if not player_inside:
		return

	if event is InputEventMouseButton and event.pressed:
		var correct_scroll = (
			event.button_index == MOUSE_BUTTON_WHEEL_UP and scroll_direction == "WHEEL_UP"
		) or (
			event.button_index == MOUSE_BUTTON_WHEEL_DOWN and scroll_direction == "WHEEL_DOWN"
		)
		if correct_scroll:
			SceneTransition.go_to_next()

func _on_body_entered(body: Node2D) -> void:
	if body.name == "CharacterBody2D":
		player_inside = true


func _on_body_exited(body: Node2D) -> void:
	if body.name == "CharacterBody2D":
		player_inside = false
