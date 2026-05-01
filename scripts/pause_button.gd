extends CanvasLayer

@onready var _button: Button = $Root/PauseButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_button.pressed.connect(_on_pause_button_pressed)


func _on_pause_button_pressed() -> void:
	var flow := get_node_or_null("/root/GameFlow")
	if flow != null and flow.has_method("open_pause_menu"):
		flow.call("open_pause_menu")
