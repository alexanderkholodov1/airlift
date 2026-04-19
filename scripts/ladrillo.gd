extends RigidBody2D

var agarrado = false
var jugador = null
var lanzamiento_activo: bool = false
var estado_muerto: bool = false
var rest_cooldown: float = 0.0

const AUTOAIM_RANGE: float = 900.0
const MIN_THROW_FORCE: float = 700.0
const REST_VELOCITY_THRESHOLD: float = 12.0
const BRICK_DEFAULT_LAYER: int = 2

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 8
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	body_entered.connect(_on_body_entered)

func _physics_process(_delta):
	if rest_cooldown > 0.0:
		rest_cooldown -= _delta

	if agarrado and jugador:
		# 1. Hacemos que el objeto siga al marcador del jugador
		# Usamos global_position para que no haya desfases
		var punto_agarre = jugador.get_node("Marker2D").global_position
		global_position = punto_agarre
		
		# 2. Anulamos la rotación para que no gire loco en la mano
		rotation = 0
		return

	# En reposo en el piso: sin empuje accidental al pisarlo.
	# Espera un poco tras lanzar para evitar congelarlo en el aire por contactos transitorios.
	if rest_cooldown <= 0.0 and not agarrado and linear_velocity.length() <= REST_VELOCITY_THRESHOLD and get_contact_count() > 0:
		lanzamiento_activo = false
		freeze = true
		linear_velocity = Vector2.ZERO
		angular_velocity = 0.0
		if collision != null:
			collision.disabled = true

func ser_agarrado(entidad_jugador):
	agarrado = true
	jugador = entidad_jugador
	lanzamiento_activo = false
	
	# 3. Importante: Desactivamos las físicas mientras se carga
	freeze = true 
	
	# 4. Desactivamos colisiones con el jugador para evitar bugs de empuje
	if collision != null:
		collision.disabled = true
	collision_layer = BRICK_DEFAULT_LAYER
	_set_vivo_visual()

func ser_soltado(impulso = Vector2.ZERO):
	agarrado = false
	jugador = null
	lanzamiento_activo = true
	rest_cooldown = 0.2
	
	# 5. Reactivamos físicas
	freeze = false
	if collision != null:
		collision.disabled = false
	collision_layer = BRICK_DEFAULT_LAYER

	var fuerza = maxf(impulso.length(), MIN_THROW_FORCE)
	var direccion = impulso.normalized() if impulso.length() > 0.001 else Vector2.RIGHT

	# Autoaim al enemigo más cercano dentro del rango.
	var enemy := _get_nearest_enemy_in_range(AUTOAIM_RANGE)
	if enemy != null:
		direccion = (enemy.global_position - global_position).normalized()
	
	# 6. Si queremos lanzarlo, aplicamos la fuerza
	apply_central_impulse(direccion * fuerza)


func _on_body_entered(body: Node) -> void:
	if not lanzamiento_activo:
		return

	var target := _resolve_damageable_target(body)
	if target != null:
		var enemy_node: Node2D = target
		var enemy_pos: Vector2 = enemy_node.global_position
		var enemy_feet_y: float = _get_enemy_feet_y(enemy_node)
		target.take_damage(9999)

		# El ladrillo queda donde murió el enemigo y pasa a estado reutilizable.
		_place_on_floor_near(enemy_pos.x, enemy_feet_y)
		_enter_dead_brick_state()
		return



func _resolve_damageable_target(body: Node) -> Node2D:
	var current: Node = body
	var depth := 0
	while current != null and depth < 4:
		if current is Node2D and current.has_method("take_damage"):
			return current
		current = current.get_parent()
		depth += 1
	return null


func _place_on_floor_near(x: float, y_hint: float) -> void:
	var start_y := minf(y_hint, global_position.y) - 220.0
	var end_y := start_y + 2200.0
	var space_state := get_world_2d().direct_space_state
	var probe_offsets := [0.0, -28.0, 28.0]
	var best_hit: Dictionary = {}

	for offset in probe_offsets:
		var from := Vector2(x + offset, start_y)
		var to := Vector2(x + offset, end_y)
		var query := PhysicsRayQueryParameters2D.create(from, to)
		query.exclude = [self]
		query.collide_with_areas = false
		query.collide_with_bodies = true
		var hit := space_state.intersect_ray(query)
		if hit.is_empty():
			continue
		# Preferimos el primer suelo más alto para no enterrarlo.
		if best_hit.is_empty() or hit.position.y < best_hit.position.y:
			best_hit = hit

	if best_hit.is_empty():
		# Fallback seguro: no lo movemos a coordenadas dudosas.
		return

	var floor_pos: Vector2 = best_hit.position
	var half_h := _get_brick_half_height()
	global_position = Vector2(x, floor_pos.y - half_h)


func _get_brick_half_height() -> float:
	if collision == null or collision.shape == null:
		return 8.0

	if collision.shape is RectangleShape2D:
		return collision.shape.size.y * 0.5 * absf(collision.global_scale.y)

	if collision.shape is CircleShape2D:
		return collision.shape.radius * absf(collision.global_scale.y)

	return 8.0


func _enter_dead_brick_state() -> void:
	estado_muerto = true
	lanzamiento_activo = false
	freeze = true
	sleeping = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	rotation = 0.0
	if collision != null:
		collision.disabled = true
	_set_muerto_visual()


func _set_muerto_visual() -> void:
	if sprite == null:
		return
	# "Sprite muerto": más oscuro y apenas aplastado, pero visible para volver a agarrarlo.
	sprite.modulate = Color(0.45, 0.35, 0.35, 1.0)
	sprite.scale = Vector2(2.6333542, 2.1)


func _set_vivo_visual() -> void:
	estado_muerto = false
	if sprite == null:
		return
	sprite.modulate = Color(1, 1, 1, 1)
	sprite.scale = Vector2(2.6333542, 2.6333542)


func _get_enemy_feet_y(enemy: Node2D) -> float:
	var enemy_collision: CollisionShape2D = enemy.get_node_or_null("CollisionShape2D")
	if enemy_collision == null or enemy_collision.shape == null:
		return enemy.global_position.y

	if enemy_collision.shape is RectangleShape2D:
		var half_h = enemy_collision.shape.size.y * 0.5 * absf(enemy.global_scale.y)
		return enemy.global_position.y + half_h

	if enemy_collision.shape is CircleShape2D:
		var r = enemy_collision.shape.radius * absf(enemy.global_scale.y)
		return enemy.global_position.y + r

	return enemy.global_position.y


func _get_nearest_enemy_in_range(max_range: float) -> CharacterBody2D:
	var root = get_tree().current_scene
	if root == null:
		return null

	var nearest: CharacterBody2D = null
	var nearest_dist: float = max_range
	var stack: Array = [root]

	while not stack.is_empty():
		var node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)

		if node is CharacterBody2D and node.has_method("take_damage"):
			var d = global_position.distance_to(node.global_position)
			if d <= nearest_dist:
				nearest = node
				nearest_dist = d

	return nearest
