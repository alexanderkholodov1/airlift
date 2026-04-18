extends RigidBody2D

var agarrado = false
var jugador = null

func _physics_process(_delta):
	if agarrado and jugador:
		# El objeto sigue al Marker2D que creaste en el personaje
		global_position = jugador.get_node("Marker2D").global_position
		rotation = 0

func ser_agarrado(entidad_jugador):
	agarrado = true
	jugador = entidad_jugador
	freeze = true # Detiene la gravedad
	# Desactivar colisión con el jugador para que no "vueles" al pisar el objeto
	$CollisionShape2D.disabled = true

func ser_soltado(impulso):
	agarrado = false
	jugador = null
	freeze = false # Devuelve la gravedad
	$CollisionShape2D.disabled = false
	apply_central_impulse(impulso)
