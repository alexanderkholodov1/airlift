extends Control

@onready var _title_label: Label = $Root/Panel/Margin/VBox/Title
@onready var _credits_label: RichTextLabel = $Root/Panel/Margin/VBox/CreditsText
@onready var _back_button: Button = $Root/Panel/Margin/VBox/BackButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameLocale.load_language()
	_title_label.text = "CRÉDITOS" if GameLocale.language == "es" else "CREDITS"
	_back_button.text = GameLocale.t("settings.back")
	_credits_label.text = _build_credits_text()
	_back_button.pressed.connect(_on_back_pressed)


func _on_back_pressed() -> void:
	var flow := get_node_or_null("/root/GameFlow")
	if flow != null and flow.has_method("go_to_main_menu"):
		flow.call("go_to_main_menu")
		return

	get_tree().change_scene_to_file("res://scenes/Main_Scene.tscn")


func _build_credits_text() -> String:
	var en := GameLocale.language == "en"
	var lines: Array[String] = []

	lines.append("[center][b]BOLAIKO INTERACTIVE[/b][/center]")
	lines.append("")

	if en:
		lines.append("[center]" + tr_italic("Made in 32 hours for the") + "[/center]")
		lines.append("[center][b]Interact2Hack 2026[/b] — " + tr_italic("Game Development Challenge") + "[/center]")
	else:
		lines.append("[center]" + tr_italic("Hecho en 32 horas para la") + "[/center]")
		lines.append("[center][b]Interact2Hack 2026[/b] — " + tr_italic("Reto de Videojuegos") + "[/center]")

	lines.append("")
	lines.append("[center]— — —[/center]")
	lines.append("")

	if en:
		lines.append("[b]Art Director, Original Assets & Music[/b]")
	else:
		lines.append("[b]Director de Arte, Assets Originales & Música[/b]")
	lines.append("Maximiliano Carlosama")
	lines.append("")

	if en:
		lines.append("[b]Karma System & Game Mechanics[/b]")
	else:
		lines.append("[b]Sistema de Karma & Mecánicas de Juego[/b]")
	lines.append("Felipe Bohórquez")
	lines.append("")

	if en:
		lines.append("[b]Physics, Level Design & Dialogue System[/b]")
	else:
		lines.append("[b]Física, Diseño de Niveles & Sistema de Diálogo[/b]")
	lines.append("Jhoan Laica")
	lines.append("")

	if en:
		lines.append("[b]Level Building, Mechanics & Narrative[/b]")
	else:
		lines.append("[b]Construcción de Niveles, Mecánicas & Narrativa[/b]")
	lines.append("Alexander Kholodov")
	lines.append("")

	lines.append("[center]— — —[/center]")
	lines.append("")

	if en:
		lines.append("[b]Music[/b]")
	else:
		lines.append("[b]Música[/b]")
	lines.append("Kevin MacLeod — Heart of the Beast")
	lines.append("Kevin MacLeod — Penumbra")

	return "\n".join(lines)


func tr_italic(text: String) -> String:
	return "[i]" + text + "[/i]"
