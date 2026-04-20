extends Area2D

@export var speed: float = 460.0
@export var damage: int = 1
@export var life_time: float = 6.0
@export var radius: float = 10.0
@export var color: Color = Color(0.9, 0.95, 1.0, 1.0)

var _velocity: Vector2 = Vector2.ZERO


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	set_physics_process(true)


func setup(direction: Vector2, projectile_speed: float, projectile_damage: int) -> void:
	_velocity = direction.normalized() * maxf(0.0, projectile_speed)
	speed = projectile_speed
	damage = projectile_damage


func _physics_process(delta: float) -> void:
	global_position += _velocity * delta
	life_time -= delta
	if life_time <= 0.0:
		queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)
	draw_circle(Vector2.ZERO, radius * 0.4, Color(1, 1, 1, 0.85))


func _on_body_entered(body: Node) -> void:
	if body != null and body.has_method("receive_damage"):
		body.call("receive_damage", damage)
		queue_free()
