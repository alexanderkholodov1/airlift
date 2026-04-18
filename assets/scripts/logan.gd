extends CharacterBody2D
	
@export var anim: AnimatedSprite2D

var speed: float = 140.0	
var jumpForce: float = -300.0;

var objeto_en_mano = null
@onready var zona_deteccion = $Area2D # El área para detectar objetos cercanos

func _input(event):
	# Detectar Click Derecho
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed: # Al presionar el click
			if objeto_en_mano == null:
				intentar_agarrar_objeto()
			else:
				lanzar_objeto()

func intentar_agarrar_objeto():
	var cuerpos = zona_deteccion.get_overlapping_bodies()
	for cuerpo in cuerpos:
		# Verificamos que sea un objeto agarrable
		if cuerpo.has_method("ser_agarrado"):
			objeto_en_mano = cuerpo
			objeto_en_mano.ser_agarrado(self)
			break

func lanzar_objeto():
	if objeto_en_mano:
		# Calculamos fuerza hacia el mouse
		var direccion = (get_global_mouse_position() - global_position).normalized()
		var fuerza = 700.0
		
		objeto_en_mano.ser_soltado(direccion * fuerza)
		objeto_en_mano = null

func _physics_process(delta):
	
	velocity += get_gravity() * delta
	
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jumpForce
	
	
	# Obtenemos la posición del mouse relativa al personaje
	var direccion_mouse = get_local_mouse_position().x
	
	# Si el mouse está a más de 10 píxeles de distancia a la derecha
	if direccion_mouse > 10:
		velocity.x = speed
		anim.flip_h = true
	# Si está a la izquierda
	elif direccion_mouse < -10:
		velocity.x = -speed
		anim.flip_h = false
	else:
		velocity.x = 0
		
	move_and_slide()
	
	if velocity.x != 0:
		anim.play("Run")
	else:
		anim.play("IDLE")
	
	
