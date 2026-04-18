extends RigidBody2D

var agarrado = false
var jugador = null

func _physics_process(_delta):
	if agarrado and jugador:
		# 1. Hacemos que el objeto siga al marcador del jugador
		# Usamos global_position para que no haya desfases
		var punto_agarre = jugador.get_node("Marker2D").global_position
		global_position = punto_agarre
		
		# 2. Anulamos la rotación para que no gire loco en la mano
		rotation = 0

func ser_agarrado(entidad_jugador):
	agarrado = true
	jugador = entidad_jugador
	
	# 3. Importante: Desactivamos las físicas mientras se carga
	freeze = true 
	
	# 4. Desactivamos colisiones con el jugador para evitar bugs de empuje
	$CollisionShape2D.disabled = true

func ser_soltado(impulso = Vector2.ZERO):
	agarrado = false
	jugador = null
	
	# 5. Reactivamos físicas
	freeze = false
	$CollisionShape2D.disabled = false
	
	# 6. Si queremos lanzarlo, aplicamos la fuerza
	apply_central_impulse(impulso)
