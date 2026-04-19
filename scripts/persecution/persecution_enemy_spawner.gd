extends Node2D
class_name PersecutionEnemySpawner

enum Phase {
	PHASE_1 = 1,
	PHASE_2 = 2,
	PHASE_3 = 3,
	PHASE_4 = 4,
}

@export var enemy_scene: PackedScene
@export var spawn_points_root_path: NodePath = ^"SpawnPoints"
@export var enemies_container_path: NodePath = ^"Enemies"
@export var spawn_timer_path: NodePath = ^"SpawnTimer"

@export var phase_3_interval: float = 2.2
@export var phase_4_interval: float = 0.45
@export var phase_3_spawn_count: int = 1
@export var phase_4_spawn_count: int = 3
@export var phase_4_extra_random_spawns: int = 2

var _phase: int = Phase.PHASE_1
var _phase_2_spawned: bool = false

var _spawn_points: Array[Marker2D] = []
var _enemies_container: Node
var _timer: Timer
var _player: Node2D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_resolve_nodes()
	_refresh_spawn_points()


func set_phase(new_phase: int, player_ref: Node2D = null) -> void:
	if player_ref != null:
		_player = player_ref

	if new_phase == _phase:
		return

	_phase = new_phase
	_apply_phase_rules()


func _resolve_nodes() -> void:
	_enemies_container = get_node_or_null(enemies_container_path)
	if _enemies_container == null:
		_enemies_container = self

	_timer = get_node_or_null(spawn_timer_path) as Timer
	if _timer == null:
		_timer = Timer.new()
		_timer.name = "SpawnTimer"
		_timer.one_shot = false
		add_child(_timer)

	if not _timer.timeout.is_connected(_on_spawn_timer_timeout):
		_timer.timeout.connect(_on_spawn_timer_timeout)


func _refresh_spawn_points() -> void:
	_spawn_points.clear()

	var root := get_node_or_null(spawn_points_root_path)
	if root == null:
		push_warning("PersecutionEnemySpawner: SpawnPoints root not found.")
		return

	for child in root.get_children():
		if child is Marker2D:
			_spawn_points.push_back(child)

	if _spawn_points.is_empty():
		push_warning("PersecutionEnemySpawner: no Marker2D spawn points found.")


func _apply_phase_rules() -> void:
	match _phase:
		Phase.PHASE_1:
			_timer.stop()

		Phase.PHASE_2:
			_timer.stop()
			if not _phase_2_spawned:
				_spawn_phase_2_enemy()
				_phase_2_spawned = true

		Phase.PHASE_3:
			_timer.wait_time = maxf(0.1, phase_3_interval)
			_timer.start()

		Phase.PHASE_4:
			_timer.wait_time = maxf(0.05, phase_4_interval)
			_timer.start()


func _on_spawn_timer_timeout() -> void:
	if _phase == Phase.PHASE_3:
		_spawn_batch(maxi(1, phase_3_spawn_count))
	elif _phase == Phase.PHASE_4:
		var total := maxi(1, phase_4_spawn_count) + _rng.randi_range(0, maxi(0, phase_4_extra_random_spawns))
		_spawn_batch(total)


func _spawn_phase_2_enemy() -> void:
	if _spawn_points.is_empty():
		return

	_spawn_enemy_at(_spawn_points[0].global_position)


func _spawn_batch(amount: int) -> void:
	if amount <= 0 or _spawn_points.is_empty():
		return

	for _i in range(amount):
		var index := _rng.randi_range(0, _spawn_points.size() - 1)
		var spawn_point := _spawn_points[index]
		_spawn_enemy_at(spawn_point.global_position)


func _spawn_enemy_at(position_world: Vector2) -> void:
	if enemy_scene == null:
		push_warning("PersecutionEnemySpawner: enemy_scene is not assigned.")
		return

	var enemy := enemy_scene.instantiate()
	if enemy is Node2D:
		enemy.global_position = position_world

	_enemies_container.add_child(enemy)
	_try_assign_player_target(enemy)


func _try_assign_player_target(enemy: Node) -> void:
	if enemy == null or _player == null:
		return

	if enemy.has_method("set_target"):
		enemy.call("set_target", _player)
		return

	if _has_property(enemy, "target"):
		enemy.set("target", _player)
		return

	if _has_property(enemy, "player"):
		enemy.set("player", _player)
		return

	if _has_property(enemy, "target_path"):
		enemy.set("target_path", _player.get_path())
		return

	if _has_property(enemy, "player_path"):
		enemy.set("player_path", _player.get_path())


func _has_property(object_ref: Object, property_name: String) -> bool:
	for property_data in object_ref.get_property_list():
		if String(property_data.get("name", "")) == property_name:
			return true
	return false
