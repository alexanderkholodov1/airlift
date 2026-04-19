extends Node
class_name PersecutionLevelManager

signal phase_changed(new_phase: int)

enum Phase {
	PHASE_1 = 1,
	PHASE_2 = 2,
	PHASE_3 = 3,
}

@export var player_path: NodePath
@export var enemy_spawner_path: NodePath
@export var camera_path: NodePath
@export var danger_overlay_path: NodePath
@export var phase_1_background_path: NodePath
@export var phase_2_background_path: NodePath
@export var phase_3_background_path: NodePath

@export var phase_2_start_x: float = 1400.0
@export var phase_3_start_x: float = 3100.0

@export var phase_2_overlay_alpha: float = 0.06
@export var phase_3_overlay_alpha_min: float = 0.10
@export var phase_3_overlay_alpha_max: float = 0.24
@export var overlay_tint: Color = Color(0.32, 0.18, 0.10, 1.0)
@export var phase_3_overlay_tint: Color = Color(0.86, 0.12, 0.10, 1.0)

@export var phase_3_pulse_time: float = 0.90

@export var phase_3_shake: float = 6.0
@export var shake_response_speed: float = 10.0

var current_phase: int = Phase.PHASE_1

var _player: Node2D
var _spawner: Node
var _camera: Camera2D
var _overlay: ColorRect
var _backgrounds_by_phase: Dictionary = {}

var _overlay_tween: Tween
var _rng := RandomNumberGenerator.new()

var _base_camera_offset := Vector2.ZERO
var _shake_current: float = 0.0
var _shake_target: float = 0.0
var _active_overlay_tint: Color = Color(0.32, 0.18, 0.10, 1.0)


func _ready() -> void:
	_rng.randomize()
	_resolve_nodes()
	_apply_phase(current_phase, true)


func _process(delta: float) -> void:
	if _player == null:
		return

	var next_phase := _phase_from_player_x(_player.global_position.x)
	if next_phase != current_phase:
		current_phase = next_phase
		_apply_phase(current_phase, false)
		phase_changed.emit(current_phase)

	_update_camera_shake(delta)


func _resolve_nodes() -> void:
	_player = get_node_or_null(player_path) as Node2D
	_spawner = get_node_or_null(enemy_spawner_path)
	_camera = get_node_or_null(camera_path) as Camera2D
	_overlay = get_node_or_null(danger_overlay_path) as ColorRect
	_backgrounds_by_phase[Phase.PHASE_1] = get_node_or_null(phase_1_background_path) as CanvasItem
	_backgrounds_by_phase[Phase.PHASE_2] = get_node_or_null(phase_2_background_path) as CanvasItem
	_backgrounds_by_phase[Phase.PHASE_3] = get_node_or_null(phase_3_background_path) as CanvasItem

	if _camera != null:
		_base_camera_offset = _camera.offset

	_active_overlay_tint = overlay_tint

	if _overlay != null:
		_overlay.color = Color(_active_overlay_tint.r, _active_overlay_tint.g, _active_overlay_tint.b, 0.0)
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _phase_from_player_x(player_x: float) -> int:
	if player_x >= phase_3_start_x:
		return Phase.PHASE_3
	if player_x >= phase_2_start_x:
		return Phase.PHASE_2
	return Phase.PHASE_1


func _apply_phase(phase: int, instant: bool) -> void:
	if _spawner != null and _spawner.has_method("set_phase"):
		_spawner.call("set_phase", phase, _player)

	match phase:
		Phase.PHASE_1:
			_active_overlay_tint = overlay_tint
			_set_overlay(0.0, 0.0, 0.0, instant)
			_set_shake_target(0.0)
		Phase.PHASE_2:
			_active_overlay_tint = overlay_tint
			_set_overlay(phase_2_overlay_alpha, phase_2_overlay_alpha, 0.0, instant)
			_set_shake_target(0.0)
		Phase.PHASE_3:
			_active_overlay_tint = phase_3_overlay_tint
			_set_overlay(phase_3_overlay_alpha_min, phase_3_overlay_alpha_max, phase_3_pulse_time, instant)
			_set_shake_target(phase_3_shake)

	_apply_background_for_phase(phase)


func _apply_background_for_phase(phase: int) -> void:
	if _backgrounds_by_phase.is_empty():
		return

	for phase_key in [Phase.PHASE_1, Phase.PHASE_2, Phase.PHASE_3]:
		var bg := _backgrounds_by_phase.get(phase_key) as CanvasItem
		if bg == null:
			continue
		bg.visible = phase_key == phase


func _set_overlay(min_alpha: float, max_alpha: float, pulse_time: float, instant: bool) -> void:
	if _overlay == null:
		return

	if is_instance_valid(_overlay_tween):
		_overlay_tween.kill()

	var color := _overlay.color
	color.r = _active_overlay_tint.r
	color.g = _active_overlay_tint.g
	color.b = _active_overlay_tint.b

	if instant or pulse_time <= 0.0:
		color.a = max_alpha
		_overlay.color = color
		return

	color.a = min_alpha
	_overlay.color = color

	_overlay_tween = create_tween()
	_overlay_tween.set_loops()
	_overlay_tween.tween_property(_overlay, "color:a", max_alpha, pulse_time)
	_overlay_tween.tween_property(_overlay, "color:a", min_alpha, pulse_time)


func _set_shake_target(value: float) -> void:
	_shake_target = maxf(value, 0.0)


func _update_camera_shake(delta: float) -> void:
	if _camera == null:
		return

	_shake_current = move_toward(_shake_current, _shake_target, shake_response_speed * delta)

	if _shake_current <= 0.01:
		_camera.offset = _base_camera_offset
		return

	var jitter := Vector2(
		_rng.randf_range(-1.0, 1.0),
		_rng.randf_range(-1.0, 1.0)
	) * _shake_current
	_camera.offset = _base_camera_offset + jitter
