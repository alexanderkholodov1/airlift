extends CharacterBody2D

# ==========================================
# VARIABLES DE MOVIMIENTO Y ANIMACIÓN
# ==========================================
@export var anim: AnimatedSprite2D
var speed: float = 300.0	

var puede_trepar: bool = false
var trepando: bool = false
var climb_speed: float = 120.0

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
	
	# 1. VERIFICAR SI ESTAMOS TREPANDO
	# Nos enganchamos a la liana si podemos trepar y mantenemos el click derecho
	if puede_trepar and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		trepando = true
		
	# Si salimos del área de la liana, dejamos de trepar
	if not puede_trepar:
		trepando = false

	# ==========================================
	# ESTADO: TREPANDO (Sin gravedad, sube con arrastre de click derecho)
	# ==========================================
	if trepando:
		velocity.x = 0 # No nos movemos hacia los lados en la liana
		
		# Leer posición vertical del mouse MIENTRAS mantenemos click derecho
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			var direccion_mouse_y = get_local_mouse_position().y
			
			if direccion_mouse_y < -10: # Mouse arriba del personaje
				velocity.y = -climb_speed
			elif direccion_mouse_y > 10: # Mouse abajo del personaje
				velocity.y = climb_speed
			else:
				velocity.y = 0
		else:
			# Si soltamos el click derecho, nos quedamos quietos colgando
			velocity.y = 0
			
		# MECÁNICA DE SALIDA: Nos soltamos de la liana con el click izquierdo (caminar)
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			trepando = false
			if velocity.y < 0:
				velocity.y = 0

	# ==========================================
	# ESTADO: NORMAL (Gravedad + Caminar con click izquierdo)
	# ==========================================
	else:
		# APLICAR GRAVEDAD
		if not is_on_floor():
			velocity += get_gravity() * delta
			
		# Caminar arrastrando el mouse con el click izquierdo
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			var direccion_mouse = get_local_mouse_position().x
			
			if direccion_mouse > 10:
				velocity.x = speed
				anim.flip_h = true # Mirar a la derecha
			elif direccion_mouse < -10:
				velocity.x = -speed
				anim.flip_h = false  # Mirar a la izquierda
			else:
				velocity.x = 0
		else:
			velocity.x = 0
			
	# 2. APLICAR EL MOVIMIENTO FINAL
	move_and_slide()
	
	# 3. CONTROL DE ANIMACIONES
	if trepando:
		pass
	elif velocity.x != 0:
		anim.play("Run")
	else:
		anim.play("IDLE")

# ==========================================
# DETECCIÓN DE CLICKS 
# ==========================================
func _input(event):
	# Detectar Click Derecho PARA OBJETOS
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			# IMPORTANTE: Solo agarramos o lanzamos cosas si NO estamos en una liana
			if not puede_trepar:
				if objeto_en_mano == null:
					intentar_agarrar_objeto()
				else:
					lanzar_objeto()

# ==========================================
# FUNCIONES DE OBJETOS
# ==========================================
func intentar_agarrar_objeto():
	var cuerpos = zona_deteccion.get_overlapping_bodies()
	
	for cuerpo in cuerpos:
		if cuerpo.has_method("ser_agarrado"):
			objeto_en_mano = cuerpo
			objeto_en_mano.ser_agarrado(self) 
			break

func lanzar_objeto():
	if objeto_en_mano:
		var direccion = (get_global_mouse_position() - global_position).normalized()
		var fuerza_lanzamiento = 400.0
		
		objeto_en_mano.ser_soltado(direccion * fuerza_lanzamiento)
		objeto_en_mano = null


func _on_liana_detector_body_entered(body: Node2D) -> void:
	puede_trepar = true


func _on_liana_detector_body_exited(body: Node2D) -> void:
	puede_trepar = false
	trepando = false # Nos soltamos obligatoriamente
