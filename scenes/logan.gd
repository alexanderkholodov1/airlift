extends CharacterBody2D
	
@export var anim: AnimatedSprite2D

var speed: float = 100.0	
var jumpForce: float = -300.0;

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
	
	
