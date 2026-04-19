extends CharacterBody2D

enum SpiderMode {
	CHASE,
	DESCEND,
}

@export var chase_speed: float = 175.0
@export var chase_acceleration: float = 1050.0
@export var idle_speed_factor: float = 0.38
@export var moving_target_trail_distance: float = 104.0
@export var trail_tolerance: float = 10.0
@export var moving_target_speed_threshold: float = 12.0

@export var descend_speed: float = 220.0
@export var descend_cleanup_y: float = 1400.0
@export var emerge_duration: float = 0.30
@export var emerge_offset: Vector2 = Vector2(10.0, -4.0)

@export var target_path: NodePath

var target: Node2D
var _wander_time := 0.0
var _mode: SpiderMode = SpiderMode.CHASE
var _emerge_time := 0.0
var _emerge_start := Vector2.ZERO
var _emerge_end := Vector2.ZERO


func _ready() -> void:
	if target == null and target_path != NodePath():
		target = get_node_or_null(target_path) as Node2D

	collision_layer = 0
	collision_mask = 0
	set_physics_process(true)
	_reset_emerge_track()


func set_target(node: Node2D) -> void:
	target = node
	if _mode != SpiderMode.DESCEND:
		_mode = SpiderMode.CHASE


func configure_as_chaser(node: Node2D, speed_override: float = -1.0) -> void:
	target = node
	if speed_override > 0.0:
		chase_speed = speed_override
	_mode = SpiderMode.CHASE
	velocity = Vector2.ZERO


func configure_as_descender(new_descend_speed: float = -1.0, cleanup_y: float = INF) -> void:
	if new_descend_speed > 0.0:
		descend_speed = new_descend_speed
	if cleanup_y < INF:
		descend_cleanup_y = cleanup_y

	_mode = SpiderMode.DESCEND
	target = null
	velocity = Vector2.ZERO
	_reset_emerge_track()


func _physics_process(delta: float) -> void:
	if _mode == SpiderMode.DESCEND:
		_update_descend_mode(delta)
		queue_redraw()
		return

	var desired: Vector2 = Vector2.ZERO

	if target != null and is_instance_valid(target):
		var to_target := target.global_position - global_position
		var distance_to_target: float = to_target.length()
		var target_speed: float = _get_target_speed()

		if target_speed > moving_target_speed_threshold:
			var min_dist: float = maxf(8.0, moving_target_trail_distance - trail_tolerance)
			var max_dist: float = moving_target_trail_distance + trail_tolerance

			if distance_to_target > max_dist:
				desired = to_target.normalized() * chase_speed
			elif distance_to_target < min_dist and distance_to_target > 0.001:
				desired = -to_target.normalized() * (chase_speed * 0.55)
			else:
				desired = Vector2.ZERO
		elif distance_to_target > 4.0:
			desired = to_target.normalized() * chase_speed
	else:
		_wander_time += delta
		desired = Vector2(cos(_wander_time * 2.1), sin(_wander_time * 2.7)).normalized() * chase_speed * idle_speed_factor

	velocity = velocity.move_toward(desired, chase_acceleration * delta)
	move_and_slide()
	queue_redraw()


func _update_descend_mode(delta: float) -> void:
	if _emerge_time < emerge_duration:
		_emerge_time += delta
		var t: float = clampf(_emerge_time / maxf(0.01, emerge_duration), 0.0, 1.0)
		var eased: float = t * t * (3.0 - 2.0 * t)
		global_position = _emerge_start.lerp(_emerge_end, eased)
		return

	global_position += Vector2(0.0, descend_speed) * delta
	if global_position.y > descend_cleanup_y:
		queue_free()


func _reset_emerge_track() -> void:
	_emerge_time = 0.0
	_emerge_start = global_position + Vector2(-3.0, 3.0)
	_emerge_end = global_position + emerge_offset


func _draw() -> void:
	var shell := Color(0.67, 0.14, 0.18, 0.95)
	var dark := Color(0.08, 0.01, 0.01, 1.0)
	var eye := Color(0.96, 0.26, 0.22, 0.95)

	draw_circle(Vector2(1.0, 0.0), 10.5, shell)
	draw_circle(Vector2(10.0, -1.0), 6.2, dark)
	draw_circle(Vector2(7.0, -1.5), 2.0, eye)
	draw_circle(Vector2(11.2, -2.0), 1.8, eye)

	# Eight stylized legs.
	for i in range(4):
		var y := -6.0 + float(i) * 3.6
		draw_line(Vector2(-2.0, y), Vector2(-13.0, y - 5.0), dark, 2.0)
		draw_line(Vector2(4.0, y), Vector2(16.0, y - 4.0), dark, 2.0)


func _get_target_speed() -> float:
	if target == null:
		return 0.0

	if target is CharacterBody2D:
		var body: CharacterBody2D = target as CharacterBody2D
		return body.velocity.length()

	if target.has_method("get_real_velocity"):
		var vel: Variant = target.call("get_real_velocity")
		if vel is Vector2:
			return (vel as Vector2).length()

	if target.has_method("get_velocity"):
		var vel2: Variant = target.call("get_velocity")
		if vel2 is Vector2:
			return (vel2 as Vector2).length()

	return 0.0
