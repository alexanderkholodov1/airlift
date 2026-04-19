extends CharacterBody2D

# ==========================================
# MOVIMIENTO
# ==========================================
const SPEED = 300.0
const JUMP_VELOCITY = -400.0

# ==========================================
# SISTEMA DE SALUD (5 golpes = muerte)
# ==========================================
const MAX_HEALTH: int = 5
var health: int = MAX_HEALTH
var is_invincible: bool = false          # Frames de invulnerabilidad tras recibir daño
const INVINCIBILITY_TIME: float = 1.0   # Segundos de invulnerabilidad
var is_dead: bool = false

# ==========================================
# REFERENCIAS (ajusta según tu escena)
# ==========================================
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

# Señal para actualizar la UI de salud
signal health_changed(current_health: int, max_health: int)
signal player_died


# ==========================================
# FÍSICA Y MOVIMIENTO
# ==========================================
func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Gravedad
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Salto
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Movimiento horizontal
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
		if sprite:
			sprite.flip_h = direction > 0
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

	# Animaciones
	_update_animation()


func _update_animation() -> void:
	if sprite == null:
		return
	if not is_on_floor():
		sprite.play("Jump")
	elif abs(velocity.x) > 10:
		sprite.play("Run")
	else:
		sprite.play("IDLE")


# ==========================================
# SISTEMA DE DAÑO
# ==========================================
func receive_damage(damage: int = 1) -> void:
	if is_dead or is_invincible:
		return

	health -= damage
	health = max(health, 0)

	health_changed.emit(health, MAX_HEALTH)

	if health <= 0:
		_die()
		return

	# Activar invulnerabilidad temporal
	is_invincible = true
	_flash_damage()
	await get_tree().create_timer(INVINCIBILITY_TIME).timeout
	is_invincible = false
	if sprite:
		sprite.modulate = Color.WHITE


func _flash_damage() -> void:
	# Parpadeo rojo para indicar daño
	if sprite == null:
		return
	var tween = create_tween()
	tween.set_loops(3)
	tween.tween_property(sprite, "modulate", Color(1.0, 0.3, 0.3, 1.0), 0.1)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)


func _die() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	player_died.emit()

	# Fade out y reinicio de escena
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.8)
	tween.tween_callback(func():
		# Recargar la escena actual
		get_tree().reload_current_scene()
	)


# ==========================================
# UTILIDAD: obtener salud actual (para la UI)
# ==========================================
func get_health() -> int:
	return health
