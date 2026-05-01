extends Node2D

@onready var dialogue_label = $CanvasLayer/DialogueBox/Label
@onready var character_sprite = $Character

const _DIALOGUES_ES: Array = [
	{"speaker": "...", "text": "Estás despierto.", "prompt": "Click derecho para saltar diálogos", "icon": "RMB"},
	{"speaker": "...", "text": "Tendrás que aprender a existir en este lugar. No es el mundo que conoces."},
	{"speaker": "...", "text": "Intenta moverte.", "action": "move", "prompt": "Mantén el botón izquierdo para caminar", "icon": "LMB"},
	{"speaker": "...", "text": "Así. Mientras mantengas presionado, irás a donde apuntes."},
	{"speaker": "...", "text": "Tu cuerpo no es el de antes. Este lugar tiene sus propias reglas, y tú aún no las conoces."},
	{"speaker": "Logan", "text": "¿Quién eres? ¿Dónde estoy?"},
	{"speaker": "...", "text": "Estás en el umbral. Y yo soy quien te conduce."},
	{"speaker": "Logan", "text": "¿Conducirme? ¿A dónde?"},
	{"speaker": "...", "text": "A lo que te pertenece."},
	{"speaker": "Logan", "text": "No entiendo nada. Espera- puedo..."},
	{"speaker": "...", "text": "Hay algo frente a ti. Tómalo.", "action": "pickup", "prompt": "Click derecho para tomar", "icon": "RMB"},
	{"speaker": "", "text": "", "action": "drop", "prompt": "Click derecho para soltar", "icon": "RMB"},
	{"speaker": "...", "text": "Recuérdalo. En lo que viene, necesitarás las manos."},
	{"speaker": "Logan", "text": "¿Qué es 'lo que viene'?"},
	{"speaker": "...", "text": "Tus obras. Una por una."},
	{"speaker": "Logan", "text": "No sé de qué hablas."},
	{"speaker": "...", "text": "Ya lo sabrás."},
	{"speaker": "...", "text": "Hemos llegado. A partir de aquí, vas solo."},
]

const _DIALOGUES_EN: Array = [
	{"speaker": "...", "text": "You're awake.", "prompt": "Right click to skip dialogue", "icon": "RMB"},
	{"speaker": "...", "text": "You'll need to learn to exist in this place. It is not the world you know."},
	{"speaker": "...", "text": "Try to move.", "action": "move", "prompt": "Hold left button to walk", "icon": "LMB"},
	{"speaker": "...", "text": "That's it. As long as you hold it down, you'll go wherever you point."},
	{"speaker": "...", "text": "Your body is no longer what it was. This place has its own rules, and you don't know them yet."},
	{"speaker": "Logan", "text": "Who are you? Where am I?"},
	{"speaker": "...", "text": "You are at the threshold. And I am the one who guides you."},
	{"speaker": "Logan", "text": "Guide me? To where?"},
	{"speaker": "...", "text": "To what belongs to you."},
	{"speaker": "Logan", "text": "I don't understand. Wait— I can..."},
	{"speaker": "...", "text": "There's something in front of you. Take it.", "action": "pickup", "prompt": "Right click to pick up", "icon": "RMB"},
	{"speaker": "", "text": "", "action": "drop", "prompt": "Right click to drop", "icon": "RMB"},
	{"speaker": "...", "text": "Remember this. In what is to come, you will need your hands."},
	{"speaker": "Logan", "text": "What is 'what is to come'?"},
	{"speaker": "...", "text": "Your works. One by one."},
	{"speaker": "Logan", "text": "I don't know what you're talking about."},
	{"speaker": "...", "text": "You will."},
	{"speaker": "...", "text": "We've arrived. From here on, you go alone."},
]

var dialogues: Array = []
var current_dialogue_index = 0
var char_index = 0
var typing_speed = 0.05
var timer = 0.0
var is_moving = true
var move_speed = 50

var _awaiting_action := false
var _current_action := ""
var _had_object := false
var _line_started_at_ms: int = 0
const _FAST_SKIP_THRESHOLD_MS: int = 1200

@onready var _action_prompt: Control = $CanvasLayer/ActionPrompt
@onready var _prompt_icon: Label = $CanvasLayer/ActionPrompt/HBox/Icon
@onready var _prompt_text: Label = $CanvasLayer/ActionPrompt/HBox/Text
@onready var _character: Node = $Character


func _ready():
	GameLocale.load_language()
	dialogues = _DIALOGUES_EN if GameLocale.language == "en" else _DIALOGUES_ES

	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	dialogue_label.clip_contents = true
	dialogue_label.scale = Vector2(1, 1)
	dialogue_label.add_theme_font_size_override("font_size", 32)
	_action_prompt.visible = false
	_action_prompt.modulate.a = 0.0
	if _character != null:
		_character.can_move = false
	start_dialogue()


func _process(delta):
	if current_dialogue_index >= dialogues.size():
		return

	var entry: Dictionary = dialogues[current_dialogue_index]
	var entry_text: String = str(entry.get("text", ""))

	if _awaiting_action:
		if _check_action_complete(_current_action):
			_end_action_wait()
			next_dialogue()
		return

	if entry_text.length() == 0 and entry.has("action"):
		_begin_action_wait(entry)
		return

	timer += delta
	if timer >= typing_speed:
		timer = 0.0
		if char_index < entry_text.length():
			char_index += 1
			var speaker: String = str(entry.get("speaker", ""))
			var text = entry_text.substr(0, char_index)
			dialogue_label.text = _format_dialogue_text(speaker, text)
		else:
			if entry.has("action"):
				_begin_action_wait(entry)


func _input(event):
	if _awaiting_action:
		return
	# No permitir skip en replicas con accion — el jugador debe completar la accion
	if current_dialogue_index < dialogues.size() and dialogues[current_dialogue_index].has("action"):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		next_dialogue()
		return
	if Input.is_action_just_pressed("skip"):
		next_dialogue()


func start_dialogue():
	current_dialogue_index = 0
	is_moving = true
	_enter_dialogue()


func next_dialogue():
	_register_skip_speed_for_purification()
	current_dialogue_index += 1

	if current_dialogue_index >= dialogues.size():
		get_tree().change_scene_to_file("res://scenes/limbo.tscn")
	else:
		_enter_dialogue()


func _register_skip_speed_for_purification() -> void:
	if _line_started_at_ms <= 0:
		return
	var elapsed := Time.get_ticks_msec() - _line_started_at_ms
	if elapsed >= _FAST_SKIP_THRESHOLD_MS:
		return
	var manager := get_node_or_null("/root/PurificationManager")
	if manager == null or not manager.has_method("ingest_game_signal"):
		return
	# Fast skip without listening -> Soberbia.
	var ratio := clampf(1.0 - float(elapsed) / float(_FAST_SKIP_THRESHOLD_MS), 0.2, 1.0)
	manager.call("ingest_game_signal", "ignored_shortcuts_or_defense", {"intensity": ratio})


func _enter_dialogue() -> void:
	char_index = 0
	timer = 0.0
	_line_started_at_ms = Time.get_ticks_msec()
	var entry: Dictionary = dialogues[current_dialogue_index]
	var speaker: String = str(entry.get("speaker", ""))
	var text: String = str(entry.get("text", ""))
	if entry.has("prompt") and not entry.has("action"):
		_prompt_icon.text = str(entry.get("icon", ""))
		_prompt_text.text = str(entry.get("prompt", ""))
		_show_prompt(true)
	elif _awaiting_action == false:
		_show_prompt(false)
	if text.is_empty():
		dialogue_label.text = ""
	else:
		dialogue_label.text = _format_dialogue_text(speaker, "")


func _format_dialogue_text(speaker: String, text: String) -> String:
	if speaker == "..." or speaker.is_empty():
		return text
	return speaker + ": " + text


func _begin_action_wait(entry: Dictionary) -> void:
	_awaiting_action = true
	_current_action = str(entry.get("action", ""))
	_had_object = _get_held_object() != null

	if _current_action == "move" and _character != null:
		_character.can_move = true

	_prompt_icon.text = str(entry.get("icon", ""))
	_prompt_text.text = str(entry.get("prompt", ""))
	_show_prompt(true)


func _end_action_wait() -> void:
	_awaiting_action = false
	_current_action = ""
	_show_prompt(false)


func is_pickup_allowed() -> bool:
	return _awaiting_action and _current_action == "pickup"


func _check_action_complete(action: String) -> bool:
	match action:
		"move":
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				var body: CharacterBody2D = _character as CharacterBody2D
				if body != null and body.velocity.length() > 0.1:
					return true
			return false
		"pickup":
			return _get_held_object() != null
		"drop":
			var held: Variant = _get_held_object()
			if _had_object and held == null:
				return true
			_had_object = held != null
			return false
		_:
			return true


func _get_held_object() -> Variant:
	if _character == null:
		return null
	return _character.get("objeto_en_mano")


func _show_prompt(visible: bool) -> void:
	_action_prompt.visible = true
	var target: float = 1.0 if visible else 0.0
	var tween: Tween = create_tween()
	tween.tween_property(_action_prompt, "modulate:a", target, 0.25)
	if not visible:
		tween.finished.connect(func(): _action_prompt.visible = false)
