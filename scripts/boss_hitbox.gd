extends CharacterBody2D


func take_damage(damage: int = 1) -> void:
	var current: Node = self
	while current != null:
		if current.has_method("take_damage") and current != self:
			current.call("take_damage", damage)
			return
		current = current.get_parent()
