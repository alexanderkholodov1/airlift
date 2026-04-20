extends Area2D

signal unplugged(plug: Area2D)

var _disconnected: bool = false
var _holder: Node2D = null
var _was_picked: bool = false


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	if _holder == null:
		return

	if _holder.has_node("Marker2D"):
		global_position = (_holder.get_node("Marker2D") as Node2D).global_position
	else:
		global_position = _holder.global_position


func ser_agarrado(player: Node2D) -> bool:
	if _disconnected:
		return false
	if player == null:
		return false

	_holder = player
	_was_picked = true
	monitoring = false
	monitorable = false
	modulate = Color(0.9, 0.95, 1.0, 1.0)
	return true


func ser_soltado(_impulse: Vector2 = Vector2.ZERO) -> void:
	if _holder == null:
		return

	if _holder.has_node("Marker2D"):
		global_position = (_holder.get_node("Marker2D") as Node2D).global_position
	else:
		global_position = _holder.global_position

	_holder = null
	if _was_picked:
		_mark_disconnected()


func try_disconnect(_player: Node) -> bool:
	if _disconnected:
		return false
	_mark_disconnected()
	return true


func _mark_disconnected() -> void:
	if _disconnected:
		return

	_disconnected = true
	monitoring = false
	monitorable = false
	modulate = Color(0.45, 0.45, 0.45, 1.0)
	emit_signal("unplugged", self)
	queue_free()


func is_disconnected() -> bool:
	return _disconnected
