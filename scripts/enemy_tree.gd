extends CharacterBody2D

enum State { WANDER, CHASE, ATTACK, HURT, DEAD }

@export var wander_speed: float = 45.0
@export var chase_speed: float = 70.0
@export var wander_range: float = 120.0
@export var max_health: int = 3
@export var attack_damage: int = 1
@export var attack_range: float = 12.0
@export var attack_vertical_tolerance: float = 24.0
@export var attack_cooldown: float = 1.2

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var current_state: State = State.WANDER
var health: int = max_health
var player: CharacterBody2D = null
var origin_position: Vector2 = Vector2.ZERO
var wander_target: Vector2 = Vector2.ZERO
var facing_direction: float = 1.0
var can_attack: bool = true
var is_dead: bool = false

var _attack_timer: Timer
var _awakened: bool = false
var _player_collision_ignored: bool = false
var purification_manager = null


func _ready() -> void:
	origin_position = global_position
	wander_target = _pick_wander_target()

	_attack_timer = Timer.new()
	_attack_timer.one_shot = true
	_attack_timer.wait_time = attack_cooldown
	add_child(_attack_timer)
	_attack_timer.timeout.connect(_on_attack_timer_timeout)

	purification_manager = get_node_or_null("/root/PurificationManager")
	_play_idle_animation()


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_ensure_player_pass_through()

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
			pass
		State.DEAD:
			pass

	move_and_slide()
	_update_sprite_direction()


func despertar(jugador_a_seguir: Node) -> void:
	if jugador_a_seguir is CharacterBody2D:
		player = jugador_a_seguir as CharacterBody2D
		_player_collision_ignored = false
		_awakened = true
		if current_state == State.WANDER:
			current_state = State.CHASE


func take_damage(damage: int = 1) -> void:
	if is_dead:
		return

	health -= damage
	if purification_manager and purification_manager.has_method("ingest_game_signal"):
		purification_manager.ingest_game_signal("attacked_pacifist_enemy", {"intensity": 1.0})

	if health <= 0:
		_die()
		return

	current_state = State.HURT
	velocity.x = 0.0
	var knockback_dir = -sign(player.global_position.x - global_position.x) if player else 1.0
	velocity.x = knockback_dir * 120.0
	await get_tree().create_timer(0.4).timeout
	if not is_dead:
		current_state = State.CHASE if player != null else State.WANDER


func _process_wander() -> void:
	if _awakened and player != null and is_instance_valid(player):
		current_state = State.CHASE
		return

	var distance_to_target = global_position.distance_to(wander_target)
	if distance_to_target < 8.0:
		wander_target = _pick_wander_target()
		velocity.x = 0.0
		_play_idle_animation()
		return

	var dir = sign(wander_target.x - global_position.x)
	if dir == 0.0:
		dir = facing_direction
	facing_direction = dir
	velocity.x = dir * wander_speed
	_play_attack_animation()


func _process_chase() -> void:
	if player == null or not is_instance_valid(player):
		current_state = State.WANDER
		wander_target = _pick_wander_target()
		return

	if _is_player_in_attack_range():
		current_state = State.ATTACK
		velocity.x = 0.0
		return

	var dir = sign(player.global_position.x - global_position.x)
	if dir == 0.0:
		dir = facing_direction
	facing_direction = dir
	velocity.x = dir * chase_speed
	_play_attack_animation()


func _process_attack() -> void:
	if player == null or not is_instance_valid(player):
		current_state = State.WANDER
		return

	if not _is_player_in_attack_range(1.5):
		current_state = State.CHASE
		return

	velocity.x = 0.0
	_play_attack_animation()

	if can_attack:
		can_attack = false
		_attack_timer.start()
		_deal_damage_to_player()


func _deal_damage_to_player() -> void:
	if player == null or not is_instance_valid(player):
		return
	if not _is_player_in_attack_range():
		return

	if player.has_method("receive_damage"):
		player.receive_damage(attack_damage)


func _die() -> void:
	is_dead = true
	current_state = State.DEAD
	velocity = Vector2.ZERO

	if player != null and is_instance_valid(player):
		remove_collision_exception_with(player)
		player.remove_collision_exception_with(self)
	_player_collision_ignored = false

	$CollisionShape2D.set_deferred("disabled", true)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.8)
	tween.tween_callback(queue_free)


func _on_attack_timer_timeout() -> void:
	can_attack = true


func _pick_wander_target() -> Vector2:
	var offset = randf_range(-wander_range, wander_range)
	var target_x = clamp(origin_position.x + offset, origin_position.x - wander_range, origin_position.x + wander_range)
	return Vector2(target_x, global_position.y)


func _update_sprite_direction() -> void:
	sprite.flip_h = facing_direction < 0.0


func _is_player_in_attack_range(multiplier: float = 1.0) -> bool:
	if player == null or not is_instance_valid(player):
		return false

	var delta = player.global_position - global_position
	var enemy_half_extents = _get_body_half_extents(self)
	var player_half_extents = _get_body_half_extents(player)

	var allowed_x = (enemy_half_extents.x + player_half_extents.x + attack_range) * multiplier
	var allowed_y = (enemy_half_extents.y + player_half_extents.y + attack_vertical_tolerance) * multiplier
	return absf(delta.x) <= allowed_x and absf(delta.y) <= allowed_y


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


func _play_idle_animation() -> void:
	if sprite.animation != "Idle":
		sprite.play("Idle")


func _play_attack_animation() -> void:
	if sprite.animation != "Attack":
		sprite.play("Attack")


func _ensure_player_pass_through() -> void:
	if _player_collision_ignored:
		return
	if player == null or not is_instance_valid(player):
		return

	add_collision_exception_with(player)
	player.add_collision_exception_with(self)
	_player_collision_ignored = true
