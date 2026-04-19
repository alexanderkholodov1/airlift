extends CharacterBody2D

# Estados del enemigo
var persiguiendo: bool = false
var objetivo = null

@export var velocidad: float = 70.0

func _physics_process(_delta):
	# Solo si el nivel nos dijo que persigamos y tenemos a quién
	if persiguiendo and objetivo:
		var direccion = (objetivo.global_position - global_position).normalized()
		velocity = direccion * velocidad
		
		# Control de animación
		if has_node("AnimatedSprite2D"):
			$AnimatedSprite2D.play("caminar")
			$AnimatedSprite2D.flip_h = direccion.x < 0
		
		move_and_slide()
	else:
		velocity = Vector2.ZERO
		if has_node("AnimatedSprite2D"):
			$AnimatedSprite2D.play("idle_arbol")

# Esta función la llamará el Area2D del nivel
func despertar(jugador_a_seguir):
	objetivo = jugador_a_seguir
	persiguiendo = true
