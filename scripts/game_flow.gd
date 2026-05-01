extends Node
class_name GameFlow

const MAIN_MENU_SCENE := "res://scenes/Main_Scene.tscn"
const ENDING_CREDITS_SCENE := "res://scenes/credits.tscn"
const MENU_CREDITS_SCENE := "res://scenes/ui/menu_credits.tscn"
const SETTINGS_SCENE := "res://scenes/ui/settings_menu.tscn"
const PAUSE_MENU_SCENE := preload("res://scenes/ui/pause_menu.tscn")
const PAUSE_BUTTON_SCENE := preload("res://scenes/ui/pause_button.tscn")

const NON_GAME_SCENES := {
	MAIN_MENU_SCENE: true,
	ENDING_CREDITS_SCENE: true,
	MENU_CREDITS_SCENE: true,
	SETTINGS_SCENE: true,
}

var _pause_menu: CanvasLayer = null
var _pause_button: CanvasLayer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if get_tree() != null and get_tree().paused:
		get_tree().paused = false

	# Botón de pausa como hijo permanente del autoload: sobrevive a cualquier cambio de escena.
	_pause_button = PAUSE_BUTTON_SCENE.instantiate() as CanvasLayer
	if _pause_button != null:
		_pause_button.visible = false
		add_child(_pause_button)

	get_tree().root.child_entered_tree.connect(_on_root_child_entered)


func _on_root_child_entered(_node: Node) -> void:
	call_deferred("_refresh_pause_button_visibility")


func _refresh_pause_button_visibility() -> void:
	if _pause_button == null or not is_instance_valid(_pause_button):
		return
	_pause_button.visible = _can_pause_current_scene()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause_game"):
		return

	if not _can_pause_current_scene():
		return

	if is_pause_menu_open():
		close_pause_menu()
	else:
		open_pause_menu()

	get_viewport().set_input_as_handled()


func is_pause_menu_open() -> bool:
	return _pause_menu != null and is_instance_valid(_pause_menu)


func open_pause_menu() -> bool:
	if is_pause_menu_open() or not _can_pause_current_scene():
		return false

	var current_scene := get_tree().current_scene
	if current_scene == null:
		return false

	_pause_menu = PAUSE_MENU_SCENE.instantiate() as CanvasLayer
	if _pause_menu == null:
		return false

	current_scene.add_child(_pause_menu)
	get_tree().paused = true
	return true


func close_pause_menu() -> void:
	if is_pause_menu_open():
		_pause_menu.queue_free()
	_pause_menu = null
	if get_tree() != null:
		get_tree().paused = false


func restart_current_level() -> bool:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return false
	var scene_path := current_scene.scene_file_path
	if scene_path.is_empty():
		return false
	_prepare_for_scene_change()
	return _change_scene(scene_path)


func go_to_main_menu() -> bool:
	EndRunState.clear()
	_prepare_for_scene_change()
	return _change_scene(MAIN_MENU_SCENE)


func go_to_scene(scene_path: String) -> bool:
	if scene_path.is_empty():
		return false
	_prepare_for_scene_change()
	return _change_scene(scene_path)


func quit_game() -> void:
	_prepare_for_scene_change()
	get_tree().quit()


func _prepare_for_scene_change() -> void:
	close_pause_menu()
	if get_tree() != null:
		get_tree().paused = false


func _change_scene(scene_path: String) -> bool:
	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_error("GameFlow: no se pudo cambiar a '%s'" % scene_path)
		return false
	return true


func _can_pause_current_scene() -> bool:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return false
	var scene_path := current_scene.scene_file_path
	if scene_path.is_empty():
		return false
	return not NON_GAME_SCENES.has(scene_path)
