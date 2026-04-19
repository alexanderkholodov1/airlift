extends StaticBody2D

# Agregamos la ruta del nodo con $
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D 

func _ready():
	if anim: # Una buena práctica para evitar errores
		anim.play("raise")
