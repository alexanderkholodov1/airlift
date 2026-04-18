extends Control
class_name PurificationHeartUI

@export var auto_poll: bool = true
@export_range(0.05, 2.0, 0.01) var poll_interval: float = 0.20

@onready var heart_fill: ColorRect = $Panel/Margin/VBox/HeartFill
@onready var ira_value: Label = $Panel/Margin/VBox/Stats/IraValue
@onready var pereza_value: Label = $Panel/Margin/VBox/Stats/PerezaValue
@onready var gula_value: Label = $Panel/Margin/VBox/Stats/GulaValue
@onready var soberbia_value: Label = $Panel/Margin/VBox/Stats/SoberbiaValue

var _manager: Node = null
var _time_since_poll := 0.0


func _ready() -> void:
	_manager = get_node_or_null("/root/PurificationManager")
	if _manager and _manager.has_signal("metrics_changed"):
		_manager.metrics_changed.connect(_on_metrics_changed)
	_refresh_from_manager()


func _process(delta: float) -> void:
	if not auto_poll:
		return

	_time_since_poll += delta
	if _time_since_poll >= poll_interval:
		_time_since_poll = 0.0
		_refresh_from_manager()


func _refresh_from_manager() -> void:
	if _manager and _manager.has_method("get_metrics"):
		var metrics: Dictionary = _manager.call("get_metrics")
		_on_metrics_changed(metrics)


func _on_metrics_changed(metrics: Dictionary) -> void:
	var ira := clampf(float(metrics.get("ira", 0.0)), 0.0, 100.0)
	var pereza := clampf(float(metrics.get("pereza", 0.0)), 0.0, 100.0)
	var gula := clampf(float(metrics.get("gula", 0.0)), 0.0, 100.0)
	var soberbia := clampf(float(metrics.get("soberbia", 0.0)), 0.0, 100.0)

	_set_shader_parameter("ira", ira / 100.0)
	_set_shader_parameter("pereza", pereza / 100.0)
	_set_shader_parameter("gula", gula / 100.0)
	_set_shader_parameter("soberbia", soberbia / 100.0)

	if ira_value:
		ira_value.text = "%.1f%%" % ira
	if pereza_value:
		pereza_value.text = "%.1f%%" % pereza
	if gula_value:
		gula_value.text = "%.1f%%" % gula
	if soberbia_value:
		soberbia_value.text = "%.1f%%" % soberbia


func _set_shader_parameter(param_name: String, value: Variant) -> void:
	if heart_fill == null:
		return

	var shader_material := heart_fill.material as ShaderMaterial
	if shader_material == null:
		return

	shader_material.set_shader_parameter(param_name, value)
