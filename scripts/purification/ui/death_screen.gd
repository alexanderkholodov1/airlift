extends CanvasLayer
class_name DeathScreenUI

signal retry_requested
signal exit_requested

@onready var title_label: Label = $Root/MainPanel/Margin/VBox/Title
@onready var reason_label: Label = $Root/MainPanel/Margin/VBox/Reason
@onready var retry_button: Button = $Root/MainPanel/Margin/VBox/ButtonRow/RetryButton
@onready var exit_button: Button = $Root/MainPanel/Margin/VBox/ButtonRow/ExitButton
@onready var graph: Node = $Root/MainPanel/Margin/VBox/Body/GraphPanel/GraphAnchor/PurificationDecisionGraph

var _death_reason: String = "Te consumio la oscuridad"
var _origin_scene_name: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_end_state_if_available()
	_bind_buttons()
	_update_reason_label()
	_populate_graph_from_purification()


func _apply_end_state_if_available() -> void:
	if EndRunState.ending_name == "":
		return

	var ending := EndRunState.ending_name
	if ending.begins_with("FINAL:"):
		ending = ending.substr(6).strip_edges()

	title_label.text = "TIPO DE FINAL: %s" % ending
	_death_reason = ending


func set_death_context(reason: String, scene_name: String = "") -> void:
	_death_reason = reason
	_origin_scene_name = scene_name
	if is_inside_tree():
		_update_reason_label()


func _bind_buttons() -> void:
	if not retry_button.pressed.is_connected(_on_retry_pressed):
		retry_button.pressed.connect(_on_retry_pressed)
	if not exit_button.pressed.is_connected(_on_exit_pressed):
		exit_button.pressed.connect(_on_exit_pressed)


func _update_reason_label() -> void:
	var scene_suffix := ""
	if not _origin_scene_name.is_empty():
		scene_suffix = " / %s" % _origin_scene_name.to_upper()
	reason_label.text = "CAUSA: %s%s" % [_death_reason.to_upper(), scene_suffix]


func _populate_graph_from_purification() -> void:
	var manager := get_node_or_null("/root/PurificationManager")
	var decisions: Array[Dictionary] = []

	if manager and manager.has_method("get_recent_decisions"):
		decisions = manager.call("get_recent_decisions", 42)

	if decisions.is_empty():
		decisions = _build_fallback_decisions(manager)

	if graph and graph.has_method("set_seed_decisions"):
		graph.call("set_seed_decisions", decisions, true)
		return

	if graph and graph.has_method("add_decision"):
		for decision in decisions:
			graph.call("add_decision", decision)


func _build_fallback_decisions(manager: Node) -> Array[Dictionary]:
	var metrics := {
		"ira": 25.0,
		"pereza": 25.0,
		"gula": 25.0,
		"soberbia": 25.0,
	}

	if manager and manager.has_method("get_metrics"):
		metrics = manager.call("get_metrics")

	return [
		_metric_to_decision(1, "ira", "Ira", float(metrics.get("ira", 0.0)), "attack_pacifist"),
		_metric_to_decision(2, "pereza", "Pereza", float(metrics.get("pereza", 0.0)), "ignore_npc_favor"),
		_metric_to_decision(3, "gula", "Gula", float(metrics.get("gula", 0.0)), "hoard_bricks"),
		_metric_to_decision(4, "soberbia", "Soberbia", float(metrics.get("soberbia", 0.0)), "ignore_shortcuts_or_defense"),
	]


func _metric_to_decision(id_value: int, key: String, label: String, value: float, event_name: String) -> Dictionary:
	var safe_value := clampf(value, 0.0, 100.0)
	var polarity := "good"
	if safe_value >= 40.0:
		polarity = "bad"

	var delta := {
		"ira": 0.0,
		"pereza": 0.0,
		"gula": 0.0,
		"soberbia": 0.0,
	}
	delta[key] = safe_value * 0.1

	return {
		"id": id_value,
		"event": event_name,
		"label": "%s %.0f%%" % [label, safe_value],
		"polarity": polarity,
		"weight": clampf(0.7 + safe_value / 65.0, 0.7, 2.2),
		"delta": delta,
	}


func _on_retry_pressed() -> void:
	retry_requested.emit()
	queue_free()


func _on_exit_pressed() -> void:
	exit_requested.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	if not event.pressed or event.echo:
		return

	if event.keycode == KEY_R:
		_on_retry_pressed()
	elif event.keycode == KEY_ESCAPE:
		_on_exit_pressed()
