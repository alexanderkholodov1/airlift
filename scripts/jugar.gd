extends Control

const START_SCENE := "res://scenes/Tutorial.tscn"
const CREDITS_SCENE := "res://scenes/ui/menu_credits.tscn"
const SETTINGS_SCENE := "res://scenes/ui/settings_menu.tscn"

@onready var _jugar_button: Button = $VBoxContainer/Jugar
@onready var _credits_button: Button = $VBoxContainer/Creditos
@onready var _settings_button: Button = $VBoxContainer/Ajustes
@onready var _salir_button: Button = $VBoxContainer/Salir


func _ready() -> void:
	if get_tree() != null and get_tree().paused:
		get_tree().paused = false

	_jugar_button.pressed.connect(_on_jugar_pressed)
	_credits_button.pressed.connect(_on_credits_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_salir_button.pressed.connect(_on_salir_pressed)

	GameLocale.load_language()
	_jugar_button.text = GameLocale.t("menu.play")
	_credits_button.text = GameLocale.t("menu.credits")
	_settings_button.text = GameLocale.t("menu.settings")
	_salir_button.text = GameLocale.t("menu.exit")


func _on_jugar_pressed() -> void:
	if EndRunState != null:
		EndRunState.clear()
	_go_to_scene(START_SCENE)


func _on_credits_pressed() -> void:
	_go_to_scene(CREDITS_SCENE)


func _on_settings_pressed() -> void:
	_go_to_scene(SETTINGS_SCENE)


func _on_salir_pressed() -> void:
	get_tree().quit()


func _go_to_scene(scene_path: String) -> void:
	var flow := get_node_or_null("/root/GameFlow")
	if flow != null and flow.has_method("go_to_scene"):
		flow.call("go_to_scene", scene_path)
		return

	get_tree().change_scene_to_file(scene_path)
