extends CharacterBody2D

# ==========================================
# ESTADOS DEL ENEMIGO
# ==========================================
enum State { WANDER, CHASE, ATTACK, HURT, DEAD }

var current_state: State = State.WANDER

# ==========================================
# PARÁMETROS DE MOVIMIENTO
# ==========================================
@export var wander_speed: float = 60.0
@export var chase_speed: float = 130.0
@export var wander_range: float = 150.0  # Distancia máxima desde punto de origen

# ==========================================
# PARÁMETROS DE COMBATE
# ==========================================
@export var max_health: int = 3         # Golpes que aguanta el enemigo
@export var attack_damage: int = 1      # Daño por golpe al jugador (muere a 5)
@export var attack_range: float = 12.0  # Margen extra horizontal sobre el contacto real de colisiones
@export var attack_vertical_tolerance: float = 24.0  # Margen extra vertical sobre el contacto real
@export var attack_cooldown: float = 1.2

# ==========================================
# REFERENCIAS A NODOS
# ==========================================
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea
@onready var attack_timer: Timer = $Timer
@onready var ray: RayCast2D = $RayCast2D

# ==========================================
# VARIABLES INTERNAS
# ==========================================
var health: int = max_health
var player: CharacterBody2D = null
var origin_position: Vector2 = Vector2.ZERO
var wander_target: Vector2 = Vector2.ZERO
var facing_direction: float = 1.0       # 1 = derecha, -1 = izquierda
var can_attack: bool = true
var is_dead: bool = false

# Referencia opcional al sistema de purificación (rama probability)
var purification_manager = null


# ==========================================
# INICIALIZACIÓN
# ==========================================
func _ready() -> void:
	origin_position = global_position
	wander_target = _pick_wander_target()

	# Configurar el timer de ataque
	attack_timer.wait_time = attack_cooldown
	attack_timer.one_shot = true
	attack_timer.timeout.connect(_on_attack_timer_timeout)

	# Conectar el área de detección
	detection_area.body_entered.connect(_on_detection_area_body_entered)
	detection_area.body_exited.connect(_on_detection_area_body_exited)

	# Buscar el PurificationManager si existe (sistema de probability)
	purification_manager = get_node_or_null("/root/PurificationManager")


# ==========================================
# BUCLE PRINCIPAL
# ==========================================
func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Gravedad
	if not is_on_floor():
		velocity += get_gravity() * delta

	match current_state:
		State.WANDER:
			_process_wander()
		State.CHASE:
			_process_chase()
		State.ATTACK:
			_process_attack()
		State.HURT:
			pass  # Espera a que termine la animación
		State.DEAD:
			pass

	move_and_slide()
	_update_sprite_direction()


# ==========================================
# ESTADO: WANDER (patrulla aleatoria)
# ==========================================
func _process_wander() -> void:
	# Si el jugador entró al área de detección, cambiar a CHASE
	if player != null:
		current_state = State.CHASE
		return

	var distance_to_target = global_position.distance_to(wander_target)

	if distance_to_target < 8.0:
		# Llegamos, elegir nuevo destino
		wander_target = _pick_wander_target()
		velocity.x = 0.0
		return

	# Verificar si hay borde de plataforma adelante con el RayCast
	ray.target_position = Vector2(facing_direction * 20.0, 20.0)
	ray.force_raycast_update()
	if not ray.is_colliding():
		# Borde detectado: dar vuelta
		wander_target = _pick_wander_target()

	# Mover hacia el target
	var dir = sign(wander_target.x - global_position.x)
	facing_direction = dir
	velocity.x = dir * wander_speed

	if sprite.animation != "default":
		sprite.play("default")


# ==========================================
# ESTADO: CHASE (perseguir al jugador)
# ==========================================
func _process_chase() -> void:
	if player == null or not is_instance_valid(player):
		current_state = State.WANDER
		wander_target = _pick_wander_target()
		return

	var dist = global_position.distance_to(player.global_position)

	# Si está cerca, atacar
	if _is_player_in_attack_range():
		current_state = State.ATTACK
		velocity.x = 0.0
		return

	# Perseguir
	var dir = sign(player.global_position.x - global_position.x)
	facing_direction = dir
	velocity.x = dir * chase_speed

	if sprite.animation != "default":
		sprite.play("default")


# ==========================================
# ESTADO: ATTACK (atacar al jugador)
# ==========================================
func _process_attack() -> void:
	if player == null or not is_instance_valid(player):
		current_state = State.WANDER
		return

	# Si el jugador se alejó, volver a perseguir
	if not _is_player_in_attack_range(1.5):
		current_state = State.CHASE
		return

	velocity.x = 0.0

	if can_attack:
		can_attack = false
		attack_timer.start()
		_deal_damage_to_player()


# ==========================================
# RECIBIR DAÑO (llamado por el jugador al lanzar un ladrillo)
# ==========================================
func take_damage(damage: int = 1) -> void:
	if is_dead:
		return

	health -= damage

	# Notificar al sistema de purificación (si existe)
	# Cuando el jugador golpea a un enemigo "pacifista-ish", sube la ira
	if purification_manager and purification_manager.has_method("ingest_game_signal"):
		purification_manager.ingest_game_signal("attacked_pacifist_enemy", {"intensity": 1.0})

	if health <= 0:
		_die()
	else:
		current_state = State.HURT
		velocity.x = 0.0
		# Pequeño knockback
		var knockback_dir = -sign(player.global_position.x - global_position.x) if player else 1.0
		velocity.x = knockback_dir * 120.0
		# Volver a CHASE después de 0.4 segundos
		await get_tree().create_timer(0.4).timeout
		if not is_dead:
			current_state = State.CHASE if player != null else State.WANDER


# ==========================================
# MUERTE
# ==========================================
func _die() -> void:
	is_dead = true
	current_state = State.DEAD
	velocity = Vector2.ZERO

	# Notificar al sistema de purificación — perdonar (no atacar) sería la acción buena
	# pero acá el jugador lo mató, así que es neutral/malo según el contexto
	# Puedes ajustar esto según la narrativa del juego
	if purification_manager and purification_manager.has_method("ingest_game_signal"):
		purification_manager.ingest_game_signal("limbo_enemy_killed", {"intensity": 1.0})

	# Desactivar colisiones
	$CollisionShape2D.set_deferred("disabled", true)
	detection_area.monitoring = false

	# Pequeña animación de muerte (se desvanece)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.8)
	tween.tween_callback(queue_free)


# ==========================================
# DAÑO AL JUGADOR
# ==========================================
func _deal_damage_to_player() -> void:
	if player == null or not is_instance_valid(player):
		return

	if not _is_player_in_attack_range():
		return

	# El jugador necesita tener un método "receive_damage" 
	# que maneje los 5 golpes antes de morir
	if player.has_method("receive_damage"):
		player.receive_damage(attack_damage)


# ==========================================
# SEÑALES DEL ÁREA DE DETECCIÓN
# ==========================================
func _on_detection_area_body_entered(body: Node2D) -> void:
	if _is_player_body(body):
		player = body
		# Permite atravesar al enemigo sin bloqueo físico.
		add_collision_exception_with(player)
		player.add_collision_exception_with(self)
		if current_state == State.WANDER:
			current_state = State.CHASE


func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == player:
		remove_collision_exception_with(player)
		player.remove_collision_exception_with(self)
		# El jugador salió del área de visión: volver a wander
		# (puedes cambiar esto para que persista la persecución más tiempo)
		player = null
		if current_state == State.CHASE or current_state == State.ATTACK:
			current_state = State.WANDER
			wander_target = _pick_wander_target()


func _on_attack_timer_timeout() -> void:
	can_attack = true


# ==========================================
# UTILIDADES
# ==========================================
func _pick_wander_target() -> Vector2:
	# Elegir un punto aleatorio dentro del rango de patrulla
	var offset = randf_range(-wander_range, wander_range)
	var target_x = clamp(origin_position.x + offset, origin_position.x - wander_range, origin_position.x + wander_range)
	return Vector2(target_x, global_position.y)


func _update_sprite_direction() -> void:
	if facing_direction > 0:
		sprite.flip_h = false
	else:
		sprite.flip_h = true


func _is_player_body(body: Node2D) -> bool:
	# Permite CharacterBody2D, CharacterBody2D2, etc.
	return body is CharacterBody2D and body.name.begins_with("CharacterBody2D")


func _is_player_in_attack_range(multiplier: float = 1.0) -> bool:
	if player == null or not is_instance_valid(player):
		return false

	var delta = player.global_position - global_position
	var enemy_half_extents = _get_body_half_extents(self)
	var player_half_extents = _get_body_half_extents(player)

	var allowed_x = (enemy_half_extents.x + player_half_extents.x + attack_range) * multiplier
	var allowed_y = (enemy_half_extents.y + player_half_extents.y + attack_vertical_tolerance) * multiplier

	var horizontal_ok = absf(delta.x) <= allowed_x
	var vertical_ok = absf(delta.y) <= allowed_y
	return horizontal_ok and vertical_ok


func _get_body_half_extents(body: CharacterBody2D) -> Vector2:
	var collider: CollisionShape2D = body.get_node_or_null("CollisionShape2D")
	if collider == null or collider.shape == null:
		return Vector2(16.0, 16.0)

	var half_extents := Vector2(16.0, 16.0)
	var shape = collider.shape

	if shape is RectangleShape2D:
		half_extents = shape.size * 0.5
	elif shape is CircleShape2D:
		half_extents = Vector2.ONE * shape.radius
	elif shape is CapsuleShape2D:
		half_extents = Vector2(shape.radius, shape.height * 0.5 + shape.radius)

	var scale_abs = body.global_scale.abs()
	return Vector2(half_extents.x * scale_abs.x, half_extents.y * scale_abs.y)
