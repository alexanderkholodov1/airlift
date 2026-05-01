extends Control

const SETTINGS_PATH := "user://display_settings.cfg"
const SECTION := "display"
const KEY_FULLSCREEN := "fullscreen"

@onready var _title: Label = $Root/Panel/Margin/VBox/Title
@onready var _description: Label = $Root/Panel/Margin/VBox/Description
@onready var _fullscreen_toggle: CheckButton = $Root/Panel/Margin/VBox/FullscreenToggle
@onready var _language_button: Button = $Root/Panel/Margin/VBox/LanguageButton
@onready var _back_button: Button = $Root/Panel/Margin/VBox/BackButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameLocale.load_language()
	_fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
	_language_button.pressed.connect(_on_language_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	_load_settings()
	_refresh_ui_text()


func _refresh_ui_text() -> void:
	_title.text = GameLocale.t("settings.title")
	_description.text = GameLocale.t("settings.subtitle")
	_fullscreen_toggle.text = GameLocale.t("settings.fullscreen")
	_language_button.text = GameLocale.t("settings.language")
	_back_button.text = GameLocale.t("settings.back")


func _load_settings() -> void:
	var config := ConfigFile.new()
	var fullscreen := false
	if config.load(SETTINGS_PATH) == OK:
		fullscreen = bool(config.get_value(SECTION, KEY_FULLSCREEN, fullscreen))

	_fullscreen_toggle.set_pressed_no_signal(fullscreen)


func _on_fullscreen_toggled(button_pressed: bool) -> void:
	_apply_fullscreen(button_pressed, true)


func _on_language_pressed() -> void:
	var new_lang := "en" if GameLocale.language == "es" else "es"
	GameLocale.save_language(new_lang)
	_refresh_ui_text()


func _on_back_pressed() -> void:
	_save_settings(_fullscreen_toggle.button_pressed)
	var flow := get_node_or_null("/root/GameFlow")
	if flow != null and flow.has_method("go_to_main_menu"):
		flow.call("go_to_main_menu")
		return

	get_tree().change_scene_to_file("res://scenes/Main_Scene.tscn")


func _apply_fullscreen(enabled: bool, save_setting: bool) -> void:
	if _is_window_embedded():
		push_warning("Pantalla completa no disponible en la ventana embebida del editor.")
		_fullscreen_toggle.set_pressed_no_signal(false)
		return

	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	if save_setting:
		_save_settings(enabled)


func _save_settings(fullscreen: bool) -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)  # preservar claves existentes (ej. idioma)
	config.set_value(SECTION, KEY_FULLSCREEN, fullscreen)
	config.save(SETTINGS_PATH)


func _is_window_embedded() -> bool:
	if not OS.has_feature("editor"):
		return false

	var window := get_window()
	if window == null:
		return false

	var window_name := window.get_name().to_lower()
	return "sub_window" in window_name
