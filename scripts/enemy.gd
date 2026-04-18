extends CharacterBody2D

@export var speed = 80.0
@export var chase_speed = 120.0
@export var wander_range = 150.0

enum State { WANDER, CHASE, IDLE }
var current_state = State.IDLE

var target_position = Vector2.ZERO
var start_position = Vector2.ZERO
var player = null # Aquí guardaremos a Logan

@onready var timer = $Timer
@onready var wall_detector = $WallDetector
@onready var detection_area = $DetectionArea

func _ready():
	start_position = global_position
	current_state = State.IDLE
	timer.start(randf_range(1, 3))

func _physics_process(delta):
	# Aplicar gravedad siempre
	if not is_on_floor():
		velocity.y += get_gravity().y * delta

	match current_state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0, speed)
		State.WANDER:
			move_towards_target(speed)
		State.CHASE:
			if player:
				target_position = player.global_position
				move_towards_target(chase_speed)

	# Lógica para subir un escalón
	if is_on_floor() and wall_detector.is_colliding():
		var collider = wall_detector.get_collider()
		# Si choca con algo y hay espacio arriba, "salta" un poco
		velocity.y = -250 # Fuerza suficiente para subir 1 bloque

	move_and_slide()

func move_towards_target(move_speed):
	var direction = sign(target_position.x - global_position.x)
	
	# Girar el RayCast según la dirección
	if direction != 0:
		velocity.x = direction * move_speed
		wall_detector.target_position.x = direction * 20 
	
	# Si llega al destino en modo Wander
	if current_state == State.WANDER and abs(global_position.x - target_position.x) < 10:
		change_to_idle()

func change_to_idle():
	current_state = State.IDLE
	timer.start(randf_range(1, 3))

func _on_timer_timeout():
	if current_state == State.IDLE:
		current_state = State.WANDER
		var sector = [-1, 1].pick_random()
		target_position.x = start_position.x + (sector * randf_range(50, wander_range))

# --- DETECCIÓN DE LOGAN ---

func _on_detection_area_body_entered(body):
	if body.name == "Logan" or body.is_in_group("player"):
		player = body
		current_state = State.CHASE

func _on_detection_area_body_exited(body):
	if body == player:
		player = null
		start_position = global_position # Resetear centro de vagabundeo
		change_to_idle()
