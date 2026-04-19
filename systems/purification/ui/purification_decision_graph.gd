extends Node2D
class_name PurificationDecisionGraph

const DecisionVisualNode := preload("res://systems/purification/ui/decision_visual_node.gd")

@export var node_scene: PackedScene
@export var max_nodes: int = 70
@export var graph_size: Vector2 = Vector2(1080.0, 560.0)

@export var good_cluster_anchor: Vector2 = Vector2(310.0, 300.0)
@export var bad_cluster_anchor: Vector2 = Vector2(770.0, 300.0)

@export var anchor_attraction: float = 9.5
@export var same_group_attraction: float = 5.0
@export var global_repulsion: float = 130000.0
@export var velocity_damping: float = 6.0
@export var max_pair_force: float = 230.0
@export var max_linear_speed: float = 120.0

@export var spring_length: float = 125.0
@export var spring_stiffness: float = 7.2
@export var spring_damping: float = 9.0

@export var auto_demo: bool = false

@onready var nodes_root: Node2D = $Nodes
@onready var joints_root: Node2D = $Joints

var _rng := RandomNumberGenerator.new()
var _nodes: Array[DecisionVisualNode] = []
var _edges: Array[Dictionary] = []
var _manager: Node = null


func _ready() -> void:
	_rng.randomize()
	_manager = get_node_or_null("/root/PurificationManager")
	if _manager and _manager.has_signal("decision_registered"):
		_manager.decision_registered.connect(_on_decision_registered)

	if auto_demo:
		_spawn_demo_nodes()


func _process(_delta: float) -> void:
	queue_redraw()


func _physics_process(delta: float) -> void:
	_purge_invalid_nodes()
	if _nodes.is_empty():
		return

	_apply_anchor_forces(delta)
	_apply_pair_forces()
	_apply_soft_bounds()
	_limit_velocities()


func _draw() -> void:
	for edge in _edges:
		var a := edge.get("a") as DecisionVisualNode
		var b := edge.get("b") as DecisionVisualNode
		if not is_instance_valid(a) or not is_instance_valid(b):
			continue

		var color := Color(0.77, 0.80, 0.87, 0.36)
		if a.polarity == "bad" and b.polarity == "bad":
			color = Color(0.90, 0.44, 0.42, 0.42)
		elif a.polarity == "good" and b.polarity == "good":
			color = Color(0.49, 0.87, 0.57, 0.42)

		draw_line(to_local(a.global_position), to_local(b.global_position), color, 1.6, true)

	draw_rect(Rect2(Vector2.ZERO, graph_size), Color(0.28, 0.31, 0.39, 0.25), false, 1.0)


func add_decision(decision: Dictionary) -> void:
	var node: DecisionVisualNode = _instantiate_node(decision)
	nodes_root.add_child(node)
	_nodes.push_back(node)
	_connect_to_neighbors(node)
	_trim_nodes()


func clear_graph() -> void:
	for edge in _edges:
		var joint: Object = edge.get("joint")
		if is_instance_valid(joint):
			joint.queue_free()
	_edges.clear()

	for node in _nodes:
		if is_instance_valid(node):
			node.queue_free()
	_nodes.clear()


func set_seed_decisions(decisions: Array[Dictionary], clear_existing: bool = true) -> void:
	if clear_existing:
		clear_graph()

	for decision in decisions:
		add_decision(decision)


func _on_decision_registered(decision: Dictionary) -> void:
	add_decision(decision)


func _instantiate_node(decision: Dictionary) -> DecisionVisualNode:
	var node: DecisionVisualNode = null
	if node_scene:
		var inst: Node = node_scene.instantiate()
		if inst is DecisionVisualNode:
			node = inst as DecisionVisualNode
	if node == null:
		node = DecisionVisualNode.new()

	node.setup(decision)
	var anchor := _anchor_for(node.polarity)
	var spread := Vector2(_rng.randf_range(-180.0, 180.0), _rng.randf_range(-130.0, 130.0))
	node.position = anchor + spread
	node.linear_velocity = Vector2(_rng.randf_range(-45.0, 45.0), _rng.randf_range(-45.0, 45.0))
	return node


func _connect_to_neighbors(node: DecisionVisualNode) -> void:
	var candidates: Array[Dictionary] = []
	for other in _nodes:
		if other == node or not is_instance_valid(other):
			continue

		var score: float = node.global_position.distance_to(other.global_position)
		if node.polarity == other.polarity:
			score *= 0.60

		candidates.push_back({"node": other, "score": score})

	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("score", 0.0)) < float(b.get("score", 0.0))
	)

	var links: int = mini(3, candidates.size())
	for i in range(links):
		var candidate := candidates[i].get("node") as DecisionVisualNode
		if is_instance_valid(candidate):
			_create_joint(node, candidate)


func _create_joint(a: DecisionVisualNode, b: DecisionVisualNode) -> void:
	if not is_instance_valid(a) or not is_instance_valid(b):
		return

	var joint := DampedSpringJoint2D.new()
	joint.global_position = (a.global_position + b.global_position) * 0.5
	joint.node_a = a.get_path()
	joint.node_b = b.get_path()
	joint.length = spring_length
	joint.stiffness = spring_stiffness
	joint.damping = spring_damping
	joints_root.add_child(joint)

	_edges.push_back({
		"a": a,
		"b": b,
		"joint": joint,
	})


func _apply_anchor_forces(_delta: float) -> void:
	for node in _nodes:
		if not is_instance_valid(node):
			continue

		var target: Vector2 = to_global(_anchor_for(node.polarity))
		var to_target: Vector2 = target - node.global_position
		node.apply_central_force(to_target * anchor_attraction)
		node.apply_central_force(-node.linear_velocity * velocity_damping)


func _apply_pair_forces() -> void:
	for i in range(_nodes.size()):
		var a: DecisionVisualNode = _nodes[i]
		if not is_instance_valid(a):
			continue

		for j in range(i + 1, _nodes.size()):
			var b: DecisionVisualNode = _nodes[j]
			if not is_instance_valid(b):
				continue

			var offset: Vector2 = b.global_position - a.global_position
			var dist_sq: float = maxf(offset.length_squared(), 120.0)
			var dist: float = sqrt(dist_sq)
			var dir: Vector2 = offset / dist

			var repulse_strength: float = minf(global_repulsion / dist_sq, max_pair_force)
			var repulse: Vector2 = dir * repulse_strength
			a.apply_central_force(-repulse)
			b.apply_central_force(repulse)

			if a.polarity == b.polarity:
				var attract_strength: float = clampf((dist - spring_length) * same_group_attraction, -max_pair_force, max_pair_force)
				var attract: Vector2 = dir * attract_strength
				a.apply_central_force(attract)
				b.apply_central_force(-attract)


func _apply_soft_bounds() -> void:
	var rect := Rect2(Vector2.ZERO, graph_size)
	for node in _nodes:
		if not is_instance_valid(node):
			continue

		var local_pos: Vector2 = to_local(node.global_position)
		var correction: Vector2 = Vector2.ZERO

		if local_pos.x < rect.position.x:
			correction.x = (rect.position.x - local_pos.x) * 45.0
		elif local_pos.x > rect.position.x + rect.size.x:
			correction.x = (rect.position.x + rect.size.x - local_pos.x) * 45.0

		if local_pos.y < rect.position.y:
			correction.y = (rect.position.y - local_pos.y) * 45.0
		elif local_pos.y > rect.position.y + rect.size.y:
			correction.y = (rect.position.y + rect.size.y - local_pos.y) * 45.0

		node.apply_central_force(correction)


func _anchor_for(polarity: String) -> Vector2:
	if polarity == "bad":
		return bad_cluster_anchor
	if polarity == "good":
		return good_cluster_anchor
	return graph_size * 0.5


func _limit_velocities() -> void:
	for node in _nodes:
		if not is_instance_valid(node):
			continue
		node.linear_velocity = node.linear_velocity.limit_length(max_linear_speed)


func _trim_nodes() -> void:
	while _nodes.size() > max_nodes:
		var stale: DecisionVisualNode = _nodes.pop_front()
		_remove_edges_for(stale)
		if is_instance_valid(stale):
			stale.queue_free()


func _remove_edges_for(node: DecisionVisualNode) -> void:
	for i in range(_edges.size() - 1, -1, -1):
		var edge: Dictionary = _edges[i]
		var a: Object = edge.get("a")
		var b: Object = edge.get("b")
		if a == node or b == node or not is_instance_valid(a) or not is_instance_valid(b):
			var joint: Object = edge.get("joint")
			if is_instance_valid(joint):
				joint.queue_free()
			_edges.remove_at(i)


func _purge_invalid_nodes() -> void:
	for i in range(_nodes.size() - 1, -1, -1):
		if not is_instance_valid(_nodes[i]):
			_nodes.remove_at(i)

	for i in range(_edges.size() - 1, -1, -1):
		var edge: Dictionary = _edges[i]
		var a: Object = edge.get("a")
		var b: Object = edge.get("b")
		if not is_instance_valid(a) or not is_instance_valid(b):
			var joint: Object = edge.get("joint")
			if is_instance_valid(joint):
				joint.queue_free()
			_edges.remove_at(i)


func _spawn_demo_nodes() -> void:
	for index in range(16):
		var is_bad := index % 2 == 0
		var decision := {
			"id": index,
			"label": "Demo %d" % index,
			"polarity": "bad" if is_bad else "good",
			"weight": _rng.randf_range(0.8, 1.8),
		}
		add_decision(decision)
