extends Area2D


func _on_body_entered(body: Node2D) -> void:
	if body.name == "Logan":
		body.puede_trepar = true


func _on_body_exited(body: Node2D) -> void:
	if body.name == "Logan":
		body.puede_trepar = false
		body.trepando = false
