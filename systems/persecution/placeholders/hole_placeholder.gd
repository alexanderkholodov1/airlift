extends Node2D

@export var radius: float = 34.0
@export var rim_width: float = 6.0
@export var rim_color: Color = Color(0.54, 0.13, 0.12, 0.84)
@export var core_color: Color = Color(0.02, 0.02, 0.03, 0.96)
@export var glow_color: Color = Color(0.75, 0.18, 0.18, 0.42)
@export var pulse_strength: float = 0.08
@export var pulse_speed: float = 2.4

var _time := 0.0


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var pulse := 1.0 + sin(_time * pulse_speed) * pulse_strength
	var r := radius * pulse

	draw_circle(Vector2.ZERO, r, rim_color)
	draw_circle(Vector2.ZERO, maxf(4.0, r - rim_width), core_color)
	draw_arc(Vector2.ZERO, r + 2.0, 0.0, TAU, 28, glow_color, 2.0, true)
