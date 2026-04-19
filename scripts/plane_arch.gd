extends Area2D

@export_enum("TO_FOREGROUND", "TO_MAIN", "TOGGLE") var plane_mode: String = "TOGGLE"
@export_enum("ACTION", "RIGHT_CLICK", "WHEEL_UP", "WHEEL_DOWN", "WHEEL_ANY") var interaction_type: String = "ACTION"
@export var interaction_action: StringName = &"ui_accept"

# Ajusta estos bits a los TileMap con los que debe colisionar el jugador en cada plano.
@export_flags_2d_physics var main_collision_mask: int = 1
@export_flags_2d_physics var foreground_collision_mask: int = 2
@export_flags_2d_physics var main_collision_layer: int = 1
@export_flags_2d_physics var foreground_collision_layer: int = 1

# Mantiene al personaje visible, pero puedes enviarlo delante/detras segun tu escena.
@export var main_z_index: int = 0
@export var foreground_z_index: int = 0

# Marcadores opcionales para ubicar al jugador al cambiar de plano.
@export var snap_marker_main: NodePath
@export var snap_marker_foreground: NodePath
@export var auto_snap_if_no_marker: bool = true
@export var extra_snap_padding: float = 24.0
@export var proximity_activation_radius: float = 180.0
@export var use_collision_shape_as_origin: bool = false

@export var switch_cooldown: float = 0.2

var player_inside: bool = false
var current_player: CharacterBody2D = null
var can_switch: bool = true
var is_handling_input: bool = false


func _ready() -> void:
	_apply_name_based_defaults()
	monitoring = true
	monitorable = true
	set_process_input(true)
	set_process_unhandled_input(true)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _input(event: InputEvent) -> void:
	_try_handle_interaction_event(event)


func _unhandled_input(event: InputEvent) -> void:
	_try_handle_interaction_event(event)


func _try_handle_interaction_event(event: InputEvent) -> void:
	if is_handling_input:
		return

	if not can_switch:
		return

	if not _matches_interaction(event):
		return

	is_handling_input = true

	var player := _resolve_player_for_interaction()
	if player == null:
		is_handling_input = false
		return
	current_player = player

	var switched := _switch_player_plane()
	_play_interaction_feedback(player, switched)
	is_handling_input = false


func _matches_interaction(event: InputEvent) -> bool:
	match interaction_type:
		"ACTION":
			return event.is_action_pressed(interaction_action)
		"RIGHT_CLICK":
			return event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT
		"WHEEL_UP":
			return event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP
		"WHEEL_DOWN":
			return event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN
		"WHEEL_ANY":
			return event is InputEventMouseButton and event.pressed and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN)

	return false


func try_interact_with_player(player: CharacterBody2D, wheel_button: int) -> bool:
	if player == null or not is_instance_valid(player):
		return false

	var dist := _distance_to_player(player)
	if dist > proximity_activation_radius:
		return false

	if not can_switch:
		_play_interaction_feedback(player, false)
		return false

	if not _matches_wheel_button(wheel_button):
		_play_interaction_feedback(player, false)
		return false

	current_player = player
	player_inside = true
	var switched := _switch_player_plane()
	_play_interaction_feedback(player, switched)
	return switched


func _matches_wheel_button(wheel_button: int) -> bool:
	if interaction_type == "WHEEL_UP":
		return wheel_button == MOUSE_BUTTON_WHEEL_UP
	if interaction_type == "WHEEL_DOWN":
		return wheel_button == MOUSE_BUTTON_WHEEL_DOWN
	if interaction_type == "WHEEL_ANY":
		return wheel_button == MOUSE_BUTTON_WHEEL_UP or wheel_button == MOUSE_BUTTON_WHEEL_DOWN
	return false


func _switch_player_plane() -> bool:
	if current_player == null or not is_instance_valid(current_player):
		return false

	var current_plane: String = str(current_player.get_meta("world_plane", "main"))
	var target_plane: String = _resolve_target_plane(current_plane)

	if target_plane == current_plane:
		return false

	var snap_position: Vector2 = _get_snap_position_for(target_plane, current_player)

	current_player.collision_mask = foreground_collision_mask if target_plane == "foreground" else main_collision_mask
	current_player.collision_layer = foreground_collision_layer if target_plane == "foreground" else main_collision_layer
	current_player.z_index = foreground_z_index if target_plane == "foreground" else main_z_index
	current_player.set_meta("world_plane", target_plane)
	_apply_player_plane_visual(current_player, target_plane)

	if snap_position != Vector2.INF:
		current_player.global_position = snap_position

	can_switch = false
	var timer := get_tree().create_timer(switch_cooldown)
	timer.timeout.connect(_on_switch_cooldown_timeout)
	return true


func _on_switch_cooldown_timeout() -> void:
	can_switch = true


func _resolve_target_plane(current_plane: String) -> String:
	match plane_mode:
		"TO_FOREGROUND":
			return "foreground"
		"TO_MAIN":
			return "main"
		"TOGGLE":
			return "main" if current_plane == "foreground" else "foreground"

	return current_plane


func _get_snap_position_for(target_plane: String, player: CharacterBody2D) -> Vector2:
	var marker_path := snap_marker_foreground if target_plane == "foreground" else snap_marker_main
	if marker_path == NodePath(""):
		if auto_snap_if_no_marker:
			return _compute_auto_snap_position(target_plane, player)
		return Vector2.INF

	var marker := get_node_or_null(marker_path)
	if marker is Node2D:
		return marker.global_position

	if auto_snap_if_no_marker:
		return _compute_auto_snap_position(target_plane, player)

	return Vector2.INF


func _compute_auto_snap_position(target_plane: String, player: CharacterBody2D) -> Vector2:
	var origin := _interaction_origin()
	var dir_x := 1.0 if target_plane == "foreground" else -1.0

	# Si el jugador ya esta a un lado del arco, lo cruzamos al lado opuesto real.
	if player.global_position.x >= origin.x:
		dir_x = -1.0 if dir_x > 0.0 else 1.0

	var offset := _get_arch_half_width() + extra_snap_padding
	return Vector2(origin.x + dir_x * offset, player.global_position.y)


func _get_arch_half_width() -> float:
	var cs: CollisionShape2D = get_node_or_null("CollisionShape2D")
	if cs == null or cs.shape == null:
		return 48.0

	if cs.shape is RectangleShape2D:
		return cs.shape.size.x * 0.5 * absf(cs.global_scale.x)

	if cs.shape is CircleShape2D:
		return cs.shape.radius * absf(cs.global_scale.x)

	return 48.0


func _on_body_entered(body: Node2D) -> void:
	if _is_player(body):
		player_inside = true
		current_player = body


func _on_body_exited(body: Node2D) -> void:
	if body == current_player:
		player_inside = false
		current_player = null


func _is_player(body: Node2D) -> bool:
	return body is CharacterBody2D and body.name.begins_with("CharacterBody2D")


func _find_player_nearby() -> CharacterBody2D:
	var root := get_tree().current_scene
	if root == null:
		return null

	var nearest: CharacterBody2D = null
	var nearest_dist := proximity_activation_radius
	var stack: Array = [root]

	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)

		if node is CharacterBody2D and node.name.begins_with("CharacterBody2D"):
			var d = _distance_to_position(node.global_position)
			if d <= nearest_dist:
				nearest = node
				nearest_dist = d

	return nearest


func _resolve_player_for_interaction() -> CharacterBody2D:
	# 1) Prioridad: cuerpos realmente dentro del Area2D (más confiable).
	for body in get_overlapping_bodies():
		if body is Node2D and _is_player(body):
			player_inside = true
			return body

	# 2) Si ya teníamos referencia válida, aceptarla solo si está cerca.
	if current_player != null and is_instance_valid(current_player):
		var current_dist := _distance_to_player(current_player)
		if player_inside or current_dist <= proximity_activation_radius:
			return current_player

	# 3) Fallback por proximidad cuando el CollisionShape del arco está desalineado.
	var nearby := _find_player_nearby()
	if nearby != null:
		var d := _distance_to_player(nearby)
		if d <= proximity_activation_radius:
			return nearby

	return null


func _interaction_origin() -> Vector2:
	if not use_collision_shape_as_origin:
		return global_position

	var cs: CollisionShape2D = get_node_or_null("CollisionShape2D")
	if cs != null:
		return cs.global_position
	return global_position


func _distance_to_player(player: CharacterBody2D) -> float:
	return _distance_to_position(player.global_position)


func _distance_to_position(pos: Vector2) -> float:
	var node_dist := global_position.distance_to(pos)
	var cs: CollisionShape2D = get_node_or_null("CollisionShape2D")
	if cs == null:
		return node_dist

	var shape_dist := cs.global_position.distance_to(pos)
	return minf(node_dist, shape_dist)


func _play_interaction_feedback(player: CharacterBody2D, switched: bool) -> void:
	if player == null or not is_instance_valid(player):
		return

	var tint := Color(0.45, 0.9, 1.0, 1.0) if switched else Color(1.0, 0.35, 0.35, 1.0)
	var target := Color(0.82, 0.82, 0.82, 1.0) if str(player.get_meta("world_plane", "main")) == "foreground" else Color(1, 1, 1, 1)
	var original_scale := player.scale
	var tween := create_tween()
	tween.tween_property(player, "modulate", tint, 0.1)
	tween.parallel().tween_property(player, "scale", original_scale * 1.12, 0.1)
	tween.tween_property(player, "modulate", target, 0.2)
	tween.parallel().tween_property(player, "scale", original_scale, 0.2)


func _apply_player_plane_visual(player: CharacterBody2D, target_plane: String) -> void:
	if target_plane == "foreground":
		player.modulate = Color(0.82, 0.82, 0.82, 1.0)
	else:
		player.modulate = Color(1, 1, 1, 1)


func _apply_name_based_defaults() -> void:
	# Si el nodo ya está configurado en inspector, respetamos esos valores.
	if interaction_type != "ACTION":
		return

	if name == "ArchEntrance":
		plane_mode = "TOGGLE"
		interaction_type = "WHEEL_ANY"
		main_collision_mask = 1
		foreground_collision_mask = 2
		main_collision_layer = 1
		foreground_collision_layer = 1
		main_z_index = 0
		foreground_z_index = 0
		switch_cooldown = 0.3
		proximity_activation_radius = maxf(proximity_activation_radius, 260.0)
		return

	if name == "ArchExit":
		plane_mode = "TO_MAIN"
		interaction_type = "WHEEL_DOWN"
		main_collision_mask = 1
		foreground_collision_mask = 2
		main_collision_layer = 1
		foreground_collision_layer = 1
		main_z_index = 0
		foreground_z_index = 0
		switch_cooldown = 0.3
		proximity_activation_radius = maxf(proximity_activation_radius, 260.0)
