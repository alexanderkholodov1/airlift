extends Node2D
class_name LevelPopulator

signal wave_state_changed(phase: int, ambient_per_cycle: int, chaser_per_cycle: int, max_chasers: int)

enum Phase {
	PHASE_1 = 1,
	PHASE_2 = 2,
	PHASE_3 = 3,
}

@export var progress_anchor_path: NodePath

@export var holes_layer_path: NodePath = ^"HolesLayer"
@export var creatures_layer_path: NodePath = ^"CreaturesLayer"
@export var cycle_timer_path: NodePath = ^"CycleTimer"

@export var hole_scene: PackedScene
@export var creature_scene: PackedScene

@export var phase_2_start_x: float = 900.0
@export var phase_3_start_x: float = 2300.0

@export var hole_spawn_ahead_min: float = 280.0
@export var hole_spawn_ahead_max: float = 980.0
@export var hole_min_x_gap: float = 120.0
@export var hole_y_min: float = -280.0
@export var hole_y_max: float = -90.0
@export var hole_cleanup_distance_behind: float = 1800.0

@export var ambient_hole_back_range: float = 900.0
@export var ambient_hole_front_range: float = 480.0
@export var ambient_spawn_jitter: Vector2 = Vector2(14.0, 10.0)
@export var ambient_cleanup_y_offset_from_anchor: float = 900.0
@export var ambient_max_alive_soft_cap: int = 36

@export var chaser_spawn_behind_min: float = 420.0
@export var chaser_spawn_behind_max: float = 880.0
@export var chaser_spawn_y_min: float = -30.0
@export var chaser_spawn_y_max: float = 120.0
@export var chaser_spawn_jitter: Vector2 = Vector2(18.0, 10.0)
@export var chaser_hole_back_range: float = 1000.0
@export var chaser_hole_front_range: float = 180.0
@export var chaser_spawn_from_hole_chance: float = 1.0
@export var chaser_hole_spawn_offset: Vector2 = Vector2(0.0, -6.0)
@export var chaser_hole_spawn_delay_distance: float = 110.0
@export var phase_1_silent_hole_count: int = 5
@export var deterministic_seed: int = 270319

@export var auto_start: bool = true

var _anchor: Node2D
var _holes_layer: Node2D
var _creatures_layer: Node2D
var _timer: Timer

var _phase: int = Phase.PHASE_1
var _last_hole_x: float = -INF

var _cycle_interval: float = 3.5
var _holes_min_per_cycle: int = 1
var _holes_max_per_cycle: int = 1
var _ambient_spawn_chance: float = 0.0
var _ambient_burst_min: int = 0
var _ambient_burst_max: int = 0
var _ambient_descend_speed_min: float = 160.0
var _ambient_descend_speed_max: float = 220.0

var _chaser_spawn_chance: float = 0.0
var _chaser_burst_min: int = 0
var _chaser_burst_max: int = 0
var _chaser_max_alive: int = 0
var _chaser_speed_min: float = 150.0
var _chaser_speed_max: float = 170.0

var _holes: Array[Node2D] = []
var _ambient_spiders: Array[Node] = []
var _chaser_spiders: Array[Node] = []
var _hole_spawn_order: Dictionary = {}
var _hole_chaser_spawned: Dictionary = {}
var _next_hole_order: int = 1

var _warned_missing_hole_scene: bool = false
var _warned_missing_creature_scene: bool = false

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = deterministic_seed
	_resolve_nodes()
	_set_wave_profile(_phase_from_progress(_anchor.global_position.x if _anchor != null else 0.0))
	_on_cycle_timeout()

	if auto_start and _timer != null:
		_timer.start()


func _process(_delta: float) -> void:
	if _anchor == null:
		return

	var progress_phase := _phase_from_progress(_anchor.global_position.x)
	if progress_phase != _phase:
		_set_wave_profile(progress_phase)

	_cleanup_old_holes()
	_cleanup_dead_spiders()


func _resolve_nodes() -> void:
	_anchor = get_node_or_null(progress_anchor_path) as Node2D

	_holes_layer = get_node_or_null(holes_layer_path) as Node2D
	if _holes_layer == null:
		_holes_layer = Node2D.new()
		_holes_layer.name = "HolesLayer"
		add_child(_holes_layer)

	_creatures_layer = get_node_or_null(creatures_layer_path) as Node2D
	if _creatures_layer == null:
		_creatures_layer = Node2D.new()
		_creatures_layer.name = "CreaturesLayer"
		add_child(_creatures_layer)

	_timer = get_node_or_null(cycle_timer_path) as Timer
	if _timer == null:
		_timer = Timer.new()
		_timer.name = "CycleTimer"
		_timer.one_shot = false
		add_child(_timer)

	if not _timer.timeout.is_connected(_on_cycle_timeout):
		_timer.timeout.connect(_on_cycle_timeout)

	_register_existing_holes()


func _register_existing_holes() -> void:
	_holes.clear()
	_hole_spawn_order.clear()
	_hole_chaser_spawned.clear()
	_next_hole_order = 1
	_last_hole_x = -INF

	if _holes_layer == null:
		return

	var collected_holes: Array[Node2D] = []
	for child in _holes_layer.get_children():
		if child is Node2D:
			collected_holes.push_back(child as Node2D)

	collected_holes.sort_custom(_sort_holes_by_x)
	for hole in collected_holes:
		_register_hole(hole)


func _sort_holes_by_x(a: Node2D, b: Node2D) -> bool:
	return a.global_position.x < b.global_position.x


func _register_hole(hole: Node2D) -> void:
	if hole == null or not is_instance_valid(hole):
		return

	var hole_id: int = hole.get_instance_id()
	if _hole_spawn_order.has(hole_id):
		return

	_holes.push_back(hole)
	_hole_spawn_order[hole_id] = _next_hole_order
	_hole_chaser_spawned[hole_id] = false
	_next_hole_order += 1
	_last_hole_x = maxf(_last_hole_x, hole.global_position.x)


func _get_hole_order(hole: Node2D) -> int:
	if hole == null or not is_instance_valid(hole):
		return -1

	var hole_id: int = hole.get_instance_id()
	if not _hole_spawn_order.has(hole_id):
		_register_hole(hole)

	return int(_hole_spawn_order.get(hole_id, -1))


func _has_hole_spawned_chaser(hole: Node2D) -> bool:
	if hole == null or not is_instance_valid(hole):
		return false

	var hole_id: int = hole.get_instance_id()
	return bool(_hole_chaser_spawned.get(hole_id, false))


func _mark_hole_chaser_spawned(hole: Node2D) -> void:
	if hole == null or not is_instance_valid(hole):
		return

	var hole_id: int = hole.get_instance_id()
	_hole_chaser_spawned[hole_id] = true


func _phase_from_progress(progress_x: float) -> int:
	if progress_x >= phase_3_start_x:
		return Phase.PHASE_3
	if progress_x >= phase_2_start_x:
		return Phase.PHASE_2
	return Phase.PHASE_1


func _set_wave_profile(phase_value: int) -> void:
	_phase = clampi(phase_value, Phase.PHASE_1, Phase.PHASE_3)

	match _phase:
		Phase.PHASE_1:
			_cycle_interval = 2.2
			_holes_min_per_cycle = 0
			_holes_max_per_cycle = 0
			_ambient_spawn_chance = 0.0
			_ambient_burst_min = 0
			_ambient_burst_max = 0
			_ambient_descend_speed_min = 150.0
			_ambient_descend_speed_max = 190.0
			_chaser_spawn_chance = 1.0
			_chaser_burst_min = 1
			_chaser_burst_max = 1
			_chaser_max_alive = 12
			_chaser_speed_min = 145.0
			_chaser_speed_max = 158.0

		Phase.PHASE_2:
			_cycle_interval = 1.6
			_holes_min_per_cycle = 0
			_holes_max_per_cycle = 0
			_ambient_spawn_chance = 0.0
			_ambient_burst_min = 0
			_ambient_burst_max = 0
			_ambient_descend_speed_min = 170.0
			_ambient_descend_speed_max = 220.0
			_chaser_spawn_chance = 1.0
			_chaser_burst_min = 4
			_chaser_burst_max = 4
			_chaser_max_alive = 20
			_chaser_speed_min = 158.0
			_chaser_speed_max = 175.0

		Phase.PHASE_3:
			_cycle_interval = 0.75
			_holes_min_per_cycle = 0
			_holes_max_per_cycle = 0
			_ambient_spawn_chance = 0.0
			_ambient_burst_min = 0
			_ambient_burst_max = 0
			_ambient_descend_speed_min = 190.0
			_ambient_descend_speed_max = 250.0
			_chaser_spawn_chance = 1.0
			_chaser_burst_min = 6
			_chaser_burst_max = 9
			_chaser_max_alive = 18
			_chaser_speed_min = 172.0
			_chaser_speed_max = 200.0

	if _timer != null:
		_timer.wait_time = _cycle_interval
		if auto_start and _timer.is_stopped():
			_timer.start()

	_clear_ambient_spiders()
	_enforce_chaser_cap()

	var ambient_avg := int(round((float(_ambient_burst_min) + float(_ambient_burst_max)) * 0.5))
	var chaser_avg := int(round((float(_chaser_burst_min) + float(_chaser_burst_max)) * 0.5))
	wave_state_changed.emit(_phase, ambient_avg, chaser_avg, _chaser_max_alive)


func _on_cycle_timeout() -> void:
	if _anchor == null:
		return

	_spawn_hole_wave()
	_spawn_ambient_spider_wave()
	_spawn_chaser_wave()
	_cleanup_old_holes()
	_cleanup_dead_spiders()


func _spawn_hole_wave() -> void:
	if _holes_layer == null:
		return

	var amount := _rng.randi_range(_holes_min_per_cycle, _holes_max_per_cycle)
	for _i in range(amount):
		_spawn_single_hole()


func _spawn_single_hole() -> void:
	if _anchor == null:
		return

	var anchor_x := _anchor.global_position.x
	var min_x := maxf(anchor_x + hole_spawn_ahead_min, _last_hole_x + hole_min_x_gap)
	var max_x := anchor_x + hole_spawn_ahead_max
	if min_x > max_x:
		return

	var spawn_x := _rng.randf_range(min_x, max_x)
	var spawn_y := _rng.randf_range(hole_y_min, hole_y_max)

	var hole := _instantiate_hole()
	if hole == null:
		return

	hole.global_position = Vector2(spawn_x, spawn_y)
	_holes_layer.add_child(hole)
	_register_hole(hole)


func _instantiate_hole() -> Node2D:
	if hole_scene == null:
		if not _warned_missing_hole_scene:
			_warned_missing_hole_scene = true
			push_warning("LevelPopulator: hole_scene is not assigned. Using invisible placeholder nodes.")
		var placeholder := Node2D.new()
		placeholder.name = "HolePlaceholder"
		return placeholder

	var instance := hole_scene.instantiate()
	if instance is Node2D:
		return instance as Node2D

	push_warning("LevelPopulator: hole_scene root must be Node2D.")
	return null


func _spawn_ambient_spider_wave() -> void:
	if creature_scene == null:
		if not _warned_missing_creature_scene:
			_warned_missing_creature_scene = true
			push_warning("LevelPopulator: creature_scene is not assigned.")
		return

	if _alive_ambient_count() >= ambient_max_alive_soft_cap:
		return
	if _rng.randf() > _ambient_spawn_chance:
		return

	var spawn_count := _rng.randi_range(_ambient_burst_min, _ambient_burst_max)
	spawn_count = mini(spawn_count, ambient_max_alive_soft_cap - _alive_ambient_count())
	if spawn_count <= 0:
		return

	var candidate_holes := _collect_candidate_holes(ambient_hole_back_range, ambient_hole_front_range)
	if candidate_holes.is_empty():
		return

	for _i in range(spawn_count):
		var hole := candidate_holes[_rng.randi_range(0, candidate_holes.size() - 1)]
		_spawn_ambient_spider_from_hole(hole)


func _spawn_chaser_wave() -> void:
	if creature_scene == null:
		if not _warned_missing_creature_scene:
			_warned_missing_creature_scene = true
			push_warning("LevelPopulator: creature_scene is not assigned.")
		return
	if _chaser_max_alive <= 0:
		return

	var candidate_holes: Array[Node2D] = _collect_chaser_ready_holes()
	if _phase == Phase.PHASE_1 or _phase == Phase.PHASE_2:
		if candidate_holes.is_empty():
			return
		for hole in candidate_holes:
			if _alive_chaser_count() >= _chaser_max_alive:
				break
			if _has_hole_spawned_chaser(hole):
				continue
			if _phase == Phase.PHASE_1 and _get_hole_order(hole) <= phase_1_silent_hole_count:
				continue
			if _spawn_chaser_from_hole(hole):
				_mark_hole_chaser_spawned(hole)
		return

	if _alive_chaser_count() >= _chaser_max_alive:
		return
	if _rng.randf() > _chaser_spawn_chance:
		return

	var spawn_count := _rng.randi_range(_chaser_burst_min, _chaser_burst_max)
	spawn_count = mini(spawn_count, _chaser_max_alive - _alive_chaser_count())
	if spawn_count <= 0:
		return

	for _i in range(spawn_count):
		if not candidate_holes.is_empty() and _rng.randf() <= chaser_spawn_from_hole_chance:
			var hole: Node2D = candidate_holes[_rng.randi_range(0, candidate_holes.size() - 1)] as Node2D
			if _spawn_chaser_from_hole(hole):
				_mark_hole_chaser_spawned(hole)
		else:
			_spawn_chaser_from_left()


func _collect_chaser_ready_holes() -> Array[Node2D]:
	var candidates: Array[Node2D] = _collect_candidate_holes(chaser_hole_back_range, chaser_hole_front_range)
	var ready: Array[Node2D] = []

	if _anchor == null:
		return ready

	var max_hole_x_to_spawn := _anchor.global_position.x - chaser_hole_spawn_delay_distance
	for hole in candidates:
		if not is_instance_valid(hole):
			continue
		if hole.global_position.x <= max_hole_x_to_spawn:
			ready.push_back(hole)

	return ready


func _collect_candidate_holes(back_range: float, front_range: float) -> Array[Node2D]:
	var candidates: Array[Node2D] = []
	if _anchor == null:
		return candidates

	var anchor_x := _anchor.global_position.x
	var min_x := anchor_x - back_range
	var max_x := anchor_x + front_range

	for hole in _holes:
		if not is_instance_valid(hole):
			continue
		var hx := hole.global_position.x
		if hx >= min_x and hx <= max_x:
			candidates.push_back(hole)

	return candidates


func _spawn_ambient_spider_from_hole(hole: Node2D) -> void:
	var instance := creature_scene.instantiate()
	if instance == null:
		return

	if instance is Node2D:
		var spider_2d := instance as Node2D
		var jitter := Vector2(
			_rng.randf_range(-ambient_spawn_jitter.x, ambient_spawn_jitter.x),
			_rng.randf_range(-ambient_spawn_jitter.y, ambient_spawn_jitter.y)
		)
		spider_2d.global_position = hole.global_position + jitter
		spider_2d.z_index = 1

	_creatures_layer.add_child(instance)
	_ambient_spiders.push_back(instance)

	var cleanup_y := hole.global_position.y + 1000.0
	if _anchor != null:
		cleanup_y = _anchor.global_position.y + ambient_cleanup_y_offset_from_anchor

	var descend_speed := _rng.randf_range(_ambient_descend_speed_min, _ambient_descend_speed_max)
	if instance.has_method("configure_as_descender"):
		instance.call("configure_as_descender", descend_speed, cleanup_y)


func _spawn_chaser_from_hole(hole: Node2D) -> bool:
	if _anchor == null or hole == null:
		return false

	var instance := creature_scene.instantiate()
	if instance == null:
		return false

	if instance is Node2D:
		var spider_2d := instance as Node2D
		var jitter := Vector2(
			_rng.randf_range(-chaser_spawn_jitter.x, chaser_spawn_jitter.x),
			_rng.randf_range(-chaser_spawn_jitter.y, chaser_spawn_jitter.y)
		)
		spider_2d.global_position = hole.global_position + chaser_hole_spawn_offset + jitter
		spider_2d.z_index = 2

	_creatures_layer.add_child(instance)
	_chaser_spiders.push_back(instance)

	var chaser_speed := _rng.randf_range(_chaser_speed_min, _chaser_speed_max)
	if instance.has_method("configure_as_chaser"):
		instance.call("configure_as_chaser", _anchor, chaser_speed)
		return true

	_assign_creature_target(instance)
	if _has_property(instance, "chase_speed"):
		instance.set("chase_speed", chaser_speed)
	elif _has_property(instance, "speed"):
		instance.set("speed", chaser_speed)

	return true


func _spawn_chaser_from_left() -> void:
	if _anchor == null:
		return

	var instance := creature_scene.instantiate()
	if instance == null:
		return

	if instance is Node2D:
		var spider_2d := instance as Node2D
		var spawn_x := _anchor.global_position.x - _rng.randf_range(chaser_spawn_behind_min, chaser_spawn_behind_max)
		var spawn_y := _anchor.global_position.y + _rng.randf_range(chaser_spawn_y_min, chaser_spawn_y_max)
		spawn_x += _rng.randf_range(-chaser_spawn_jitter.x, chaser_spawn_jitter.x)
		spawn_y += _rng.randf_range(-chaser_spawn_jitter.y, chaser_spawn_jitter.y)
		spider_2d.global_position = Vector2(spawn_x, spawn_y)
		spider_2d.z_index = 2

	_creatures_layer.add_child(instance)
	_chaser_spiders.push_back(instance)

	var chaser_speed := _rng.randf_range(_chaser_speed_min, _chaser_speed_max)
	if instance.has_method("configure_as_chaser"):
		instance.call("configure_as_chaser", _anchor, chaser_speed)
		return

	_assign_creature_target(instance)
	if _has_property(instance, "chase_speed"):
		instance.set("chase_speed", chaser_speed)
	elif _has_property(instance, "speed"):
		instance.set("speed", chaser_speed)


func _assign_creature_target(creature: Node) -> void:
	if _anchor == null or creature == null:
		return

	if creature.has_method("set_target"):
		creature.call("set_target", _anchor)
		return

	if _has_property(creature, "target"):
		creature.set("target", _anchor)
		return

	if _has_property(creature, "player"):
		creature.set("player", _anchor)
		return

	if _has_property(creature, "target_path"):
		creature.set("target_path", _anchor.get_path())
		return

	if _has_property(creature, "player_path"):
		creature.set("player_path", _anchor.get_path())


func _has_property(object_ref: Object, property_name: String) -> bool:
	for property_data in object_ref.get_property_list():
		if String(property_data.get("name", "")) == property_name:
			return true
	return false


func _cleanup_old_holes() -> void:
	if _anchor == null:
		return

	var min_x := _anchor.global_position.x - hole_cleanup_distance_behind
	for i in range(_holes.size() - 1, -1, -1):
		var hole := _holes[i]
		if not is_instance_valid(hole):
			_holes.remove_at(i)
			continue
		if hole.global_position.x < min_x:
			var hole_id: int = hole.get_instance_id()
			hole.queue_free()
			_holes.remove_at(i)
			_hole_spawn_order.erase(hole_id)
			_hole_chaser_spawned.erase(hole_id)


func _cleanup_dead_spiders() -> void:
	for i in range(_ambient_spiders.size() - 1, -1, -1):
		if not is_instance_valid(_ambient_spiders[i]):
			_ambient_spiders.remove_at(i)

	for i in range(_chaser_spiders.size() - 1, -1, -1):
		if not is_instance_valid(_chaser_spiders[i]):
			_chaser_spiders.remove_at(i)


func _alive_ambient_count() -> int:
	_cleanup_dead_spiders()
	return _ambient_spiders.size()


func _alive_chaser_count() -> int:
	_cleanup_dead_spiders()
	return _chaser_spiders.size()


func _seed_initial_holes(amount: int) -> void:
	if amount <= 0:
		return
	for _i in range(amount):
		_spawn_single_hole()


func _clear_ambient_spiders() -> void:
	for spider in _ambient_spiders:
		if is_instance_valid(spider):
			spider.queue_free()
	_ambient_spiders.clear()


func _enforce_chaser_cap() -> void:
	_cleanup_dead_spiders()
	while _chaser_spiders.size() > _chaser_max_alive:
		var spider: Node = _chaser_spiders.pop_front() as Node
		if is_instance_valid(spider):
			spider.queue_free()
