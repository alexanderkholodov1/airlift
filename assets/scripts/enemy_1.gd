extends CharacterBody2D

@export var velocidad: float = 120.0
var jugador = null

func _ready():
	# Buscamos al jugador en el grupo que creamos
	var nodos_jugador = get_tree().get_nodes_in_group("Logan")
	if nodos_jugador.size() > 0:
		jugador = nodos_jugador[0]

func _physics_process(_delta):
	if jugador:
		# Calculamos la dirección: (Destino - Origen).normalized()
		var direccion = (jugador.global_position - global_position).normalized()
		
		# Aplicamos la velocidad
		velocity = direccion * velocidad
		
		# Opcional: Girar el sprite para mirar al jugador
		if direccion.x > 0:
			$Sprite2D.flip_h = false
		elif direccion.x < 0:
			$Sprite2D.flip_h = true
			
		move_and_slide()
