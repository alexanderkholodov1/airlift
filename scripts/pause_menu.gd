extends CanvasLayer

@onready var _resume_button: Button = $Root/Panel/Margin/VBox/ResumeButton
@onready var _restart_button: Button = $Root/Panel/Margin/VBox/RestartButton
@onready var _menu_button: Button = $Root/Panel/Margin/VBox/MenuButton
@onready var _exit_button: Button = $Root/Panel/Margin/VBox/ExitButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_resume_button.pressed.connect(_on_resume_pressed)
	_restart_button.pressed.connect(_on_restart_pressed)
	_menu_button.pressed.connect(_on_menu_pressed)
	_exit_button.pressed.connect(_on_exit_pressed)


func _on_resume_pressed() -> void:
	_close_pause_menu()


func _on_restart_pressed() -> void:
	var flow := get_node_or_null("/root/GameFlow")
	if flow != null and flow.has_method("restart_current_level"):
		flow.call("restart_current_level")


func _on_menu_pressed() -> void:
	var flow := get_node_or_null("/root/GameFlow")
	if flow != null and flow.has_method("go_to_main_menu"):
		flow.call("go_to_main_menu")


func _on_exit_pressed() -> void:
	var flow := get_node_or_null("/root/GameFlow")
	if flow != null and flow.has_method("quit_game"):
		flow.call("quit_game")
		return

	get_tree().paused = false
	get_tree().quit()


func _close_pause_menu() -> void:
	var flow := get_node_or_null("/root/GameFlow")
	if flow != null and flow.has_method("close_pause_menu"):
		flow.call("close_pause_menu")
		return

	get_tree().paused = false
	queue_free()
