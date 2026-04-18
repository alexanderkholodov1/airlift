extends CharacterBody2D

# ==========================================
# VARIABLES DE MOVIMIENTO Y ANIMACIÓN
# ==========================================
@export var anim: AnimatedSprite2D
var speed: float = 140.0	
var jumpForce: float = -300.0

# ==========================================
# VARIABLES DE INTERACCIÓN (OBJETOS)
# ==========================================
var objeto_en_mano = null
@onready var zona_deteccion = $Area2D # El área de alcance de tus brazos
@onready var punto_agarre = $Marker2D # El punto donde sostendrá la caja

# ==========================================
# FÍSICAS Y MOVIMIENTO CONSTANTE
# ==========================================
func _physics_process(delta):
	# 1. Aplicar Gravedad (Godot 4.3+)
	velocity += get_gravity() * delta
	
	# 2. Salto (Con la barra espaciadora / ui_accept)
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jumpForce
	
	# 3. Movimiento horizontal siguiendo al mouse
	var direccion_mouse = get_local_mouse_position().x
	
	# Si el mouse está a más de 10 píxeles a la derecha
	if direccion_mouse > 10:
		velocity.x = speed
		anim.flip_h = true # Cambia esto a false si tu personaje camina de espaldas
	# Si está a la izquierda
	elif direccion_mouse < -10:
		velocity.x = -speed
		anim.flip_h = false # Cambia esto a true si tu personaje camina de espaldas
	else:
		velocity.x = 0
		
	# 4. Aplicar el movimiento
	move_and_slide()
	
	# 5. Control de animaciones
	if velocity.x != 0:
		anim.play("Run")
	else:
		anim.play("IDLE")

# ==========================================
# DETECCIÓN DE CLICKS (AGARRAR / LANZAR)
# ==========================================
func _input(event):
	# Detectar solo Click Derecho
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed: # Justo al presionar
			if objeto_en_mano == null:
				intentar_agarrar_objeto()
			else:
				lanzar_objeto()

func intentar_agarrar_objeto():
	# print("Intentando agarrar...")
	var cuerpos = zona_deteccion.get_overlapping_bodies()
	
	for cuerpo in cuerpos:
		# Verificamos si el objeto tiene nuestro código para ser agarrado
		if cuerpo.has_method("ser_agarrado"):
			objeto_en_mano = cuerpo
			# Le pasamos "self" para que el objeto sepa quién es el jugador
			objeto_en_mano.ser_agarrado(self) 
			# print("¡Objeto agarrado con éxito!")
			break

func lanzar_objeto():
	if objeto_en_mano:
		# Calculamos dirección desde el personaje hacia el mouse
		var direccion = (get_global_mouse_position() - global_position).normalized()
		var fuerza_lanzamiento = 700.0
		
		# Le damos la orden al objeto de soltarse y salir volando
		objeto_en_mano.ser_soltado(direccion * fuerza_lanzamiento)
		objeto_en_mano = null
