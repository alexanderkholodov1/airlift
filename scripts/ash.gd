extends RigidBody2D

var agarrado = false
var jugador = null

const MIN_THROW_FORCE: float = 700.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

var _original_sprite_scale: Vector2 = Vector2.ONE


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	if sprite != null:
		_original_sprite_scale = sprite.scale


func _physics_process(_delta: float) -> void:
	if agarrado and jugador:
		global_position = jugador.get_node("Marker2D").global_position
		rotation = 0


func ser_agarrado(entidad_jugador: Node) -> void:
	agarrado = true
	jugador = entidad_jugador
	freeze = true
	collision_layer = 0
	collision_mask = 0
	if collision != null:
		collision.disabled = true
	_restaurar_visual()


func ser_soltado(impulso: Vector2 = Vector2.ZERO) -> void:
	agarrado = false
	jugador = null
	freeze = false
	collision_layer = 2
	# mask 0 = no choca con Bote ni con nada, sale volando libremente
	collision_mask = 0
	if collision != null:
		collision.disabled = false

	var fuerza := maxf(impulso.length(), MIN_THROW_FORCE)
	var direccion := impulso.normalized() if impulso.length() > 0.001 else Vector2.RIGHT
	apply_central_impulse(direccion * fuerza)


func _restaurar_visual() -> void:
	if sprite == null:
		return
	sprite.modulate = Color(1, 1, 1, 1)
	sprite.scale = _original_sprite_scale
