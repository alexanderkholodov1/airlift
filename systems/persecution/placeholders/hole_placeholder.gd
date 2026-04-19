extends Node2D

@export var pixel_size: float = 4.0
@export var outer_radius_pixels: int = 11
@export var inner_radius_pixels: int = 6

@export var rock_shadow_color: Color = Color(0.20, 0.14, 0.10, 1.0)
@export var rock_mid_color: Color = Color(0.32, 0.24, 0.18, 1.0)
@export var rock_light_color: Color = Color(0.48, 0.38, 0.28, 1.0)

@export var core_dark_color: Color = Color(0.02, 0.02, 0.03, 1.0)
@export var core_mid_color: Color = Color(0.08, 0.05, 0.04, 1.0)
@export var ember_color: Color = Color(0.46, 0.16, 0.10, 0.75)

@export var pulse_strength: float = 0.05
@export var pulse_speed: float = 1.9

var _time := 0.0


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var pulse: float = 1.0 + sin(_time * pulse_speed) * pulse_strength
	var cell: float = pixel_size * pulse

	var outer_r: int = max(outer_radius_pixels, inner_radius_pixels + 2)
	var inner_r: int = max(2, min(inner_radius_pixels, outer_r - 2))
	var offset: Vector2 = Vector2(-float(outer_r) * cell, -float(outer_r) * cell)

	for py in range(-outer_r, outer_r + 1):
		for px in range(-outer_r, outer_r + 1):
			var grid_pos: Vector2 = Vector2(float(px), float(py))
			var distance: float = grid_pos.length()
			var noise: float = _rock_noise(px, py)

			var ring_outer: float = float(outer_r) + noise * 0.95
			var ring_inner: float = float(inner_r) + noise * 0.45

			if distance > ring_outer:
				continue

			var color: Color
			if distance >= ring_inner:
				color = _rock_color(distance, ring_inner, ring_outer, px, py)
			else:
				color = _core_color(distance, ring_inner, px, py)

			if color.a <= 0.001:
				continue

			var rect_pos := offset + Vector2(float(px + outer_r) * cell, float(py + outer_r) * cell)
			draw_rect(Rect2(rect_pos, Vector2(cell, cell)), color, true, -1.0, false)


func _rock_noise(px: int, py: int) -> float:
	var n: int = px * 1619 + py * 31337
	n = (n << 13) ^ n
	var nn: int = n * (n * n * 15731 + 789221) + 1376312589
	var sample: float = float(nn & 0x7fffffff) / 1073741824.0
	return 1.0 - sample


func _rock_color(distance: float, inner: float, outer: float, px: int, py: int) -> Color:
	var t: float = 0.0
	if outer > inner:
		t = clampf((distance - inner) / (outer - inner), 0.0, 1.0)

	var shade_pick: int = abs((px * 3 + py * 5)) % 5
	if shade_pick == 0:
		return rock_light_color
	if t > 0.64:
		return rock_shadow_color
	if t < 0.25:
		return rock_light_color
	return rock_mid_color


func _core_color(distance: float, inner: float, px: int, py: int) -> Color:
	if inner <= 0.001:
		return core_dark_color

	var t: float = clampf(distance / inner, 0.0, 1.0)
	var core := core_dark_color.lerp(core_mid_color, t * 0.55)

	# Sparse embers near the rim to sell a dangerous cave opening.
	var ember_pattern: int = abs(px * 7 + py * 11) % 17
	if t > 0.72 and ember_pattern == 0:
		core = ember_color

	return core
