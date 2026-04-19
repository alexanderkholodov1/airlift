extends CharacterBody2D

# Variables de estado
var persiguiendo: bool = false
var objetivo = null

# Velocidad exportada para poder cambiarla desde el Inspector
@export var velocidad: float = 70.0

func _ready():
	# Nos aseguramos de que empiece con la animación estática
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.play("Idle")

func _physics_process(_delta):
	if persiguiendo and objetivo:
		# Lógica de persecución
		var direccion = (objetivo.global_position - global_position).normalized()
		velocity = direccion * velocidad
		
		if has_node("AnimatedSprite2D"):
			$AnimatedSprite2D.play("Attack")
			# Voltea el sprite si el jugador está a la izquierda
			$AnimatedSprite2D.flip_h = direccion.x < 0
			
		move_and_slide()
	else:
		# Si no persigue, se queda quieto
		velocity = Vector2.ZERO
		if has_node("AnimatedSprite2D"):
			if $AnimatedSprite2D.animation != "Idle":
				$AnimatedSprite2D.play("Idle")

# Esta función la usaremos desde la escena del nivel
func despertar(jugador_a_seguir):
	objetivo = jugador_a_seguir
	persiguiendo = true
