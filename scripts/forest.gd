extends Node2D

@onready var arbol_bloqueo = $ArbolBloqueo
@onready var arbol_atras = $ArbolAparicion

func _ready():
	# Nos aseguramos de que el árbol sorpresa empiece apagado
	arbol_atras.hide()
	arbol_atras.get_node("CollisionShape2D").disabled = true

func _on_area_regreso_body_entered(body):
	if body.is_in_group("Logan"):
		# El jugador tocó esta zona al volver, aparece el árbol
		arbol_atras.show()
		arbol_atras.get_node("CollisionShape2D").set_deferred("disabled", false)


func _on_area_susto_body_entered(body):
	if body.is_in_group("Logan"):
		# El jugador está en el centro, ¡ambos atacan!
		arbol_bloqueo.despertar(body)
		arbol_atras.despertar(body)
