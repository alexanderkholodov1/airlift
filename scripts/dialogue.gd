extends Node2D

@onready var dialogue_label = $CanvasLayer/DialogueBox/Label
@onready var character_sprite = $Character

var dialogues = [
	{"speaker": "Logan", "text": "Eh… ¿dónde estoy? ¿Qué es este lugar?"},
	{"speaker": "Sr. Misterio", "text": "Estás yendo a un lugar en donde pagarás cada uno de los pecados que has hecho."},
	{"speaker": "Logan", "text": "¿Cómo? ¿Acaso es que estoy muerto?"},
	{"speaker": "Sr. Misterio", "text": "Así es…"},
	{"speaker": "Logan", "text": "No me puedes dejar aquí, debe haber un modo de salir."},
	{"speaker": "Sr. Misterio", "text": "Sí lo hay, deberías pasar por cada uno de los pecados que realizaste mientras estuviste en vida."},
	{"speaker": "Logan", "text": "¿Y cómo llego a eso y qué debo de hacer?"},
	{"speaker": "Sr. Misterio", "text": "Actualmente te estoy llevando a un lugar en donde tendrás que ir demostrando que los pecados que hiciste son suficiente para uno y salir ya."},
	{"speaker": "Tutorial", "text": "Tutorial: Usa el click izquierdo para hacer que Logan se mueva hacia esa posición."},
	{"speaker": "Tutorial", "text": "Tutorial: Haz click derecho cerca de un objeto para recogerlo. El objeto se agarrará en la mano de Logan."},
	{"speaker": "Tutorial", "text": "Tutorial: Mientras sostienes un objeto, haz click derecho nuevamente para lanzarlo desde la posición actual de Logan."}
]

var current_dialogue_index = 0
var char_index = 0
var typing_speed = 0.05  # seconds per character
var timer = 0.0
var is_moving = true
var move_speed = 50  # pixels per second

func _ready():
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	dialogue_label.clip_contents = true
	dialogue_label.scale = Vector2(1, 1)
	start_dialogue()

func _process(delta):
	
	if current_dialogue_index < dialogues.size():
		timer += delta
		if timer >= typing_speed:
			timer = 0.0
			if char_index < dialogues[current_dialogue_index]["text"].length():
				char_index += 1
				var speaker = dialogues[current_dialogue_index]["speaker"]
				var text = dialogues[current_dialogue_index]["text"].substr(0, char_index)
				dialogue_label.text = speaker + ": " + text
			else:
				# Dialogue finished, wait for input to continue
				pass

func _input(event):
	if Input.is_action_just_pressed("skip") and char_index >= dialogues[current_dialogue_index]["text"].length():
		next_dialogue()

func start_dialogue():
	current_dialogue_index = 0
	char_index = 0
	timer = 0.0
	is_moving = true
	dialogue_label.text = ""

func next_dialogue():
	current_dialogue_index += 1
	char_index = 0
	timer = 0.0
	if current_dialogue_index >= dialogues.size():
		# End of tutorial/dialogue sequence
		current_dialogue_index = dialogues.size() - 1
		char_index = dialogues[current_dialogue_index]["text"].length()
	else:
		var speaker = dialogues[current_dialogue_index]["speaker"]
		dialogue_label.text = speaker + ": "
