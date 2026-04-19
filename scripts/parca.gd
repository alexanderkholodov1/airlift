extends CharacterBody2D

@export var anim: AnimatedSprite2D

func _process(delta: float) -> void:
	anim.play("remo")
