extends Control
class_name PixelHeartDisplay

@export_range(16, 96, 1) var grid_resolution: int = 54
@export_range(0.005, 0.060, 0.001) var divider_thickness: float = 0.018

@export var ira_color: Color = Color(0.87, 0.22, 0.20, 1.0)
@export var pereza_color: Color = Color(0.96, 0.68, 0.24, 1.0)
@export var gula_color: Color = Color(0.29, 0.72, 0.85, 1.0)
@export var soberbia_color: Color = Color(0.74, 0.39, 0.82, 1.0)
@export var empty_color: Color = Color(0.16, 0.10, 0.10, 1.0)
@export var outline_color: Color = Color(0.98, 0.93, 0.89, 0.95)
@export var divider_color: Color = Color(1.00, 0.97, 0.92, 1.0)

var _ira: float = 0.0
var _pereza: float = 0.0
var _gula: float = 0.0
var _soberbia: float = 0.0


func set_metrics(ira: float, pereza: float, gula: float, soberbia: float) -> void:
	_ira = clampf(ira, 0.0, 1.0)
	_pereza = clampf(pereza, 0.0, 1.0)
	_gula = clampf(gula, 0.0, 1.0)
	_soberbia = clampf(soberbia, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var resolution := maxi(grid_resolution, 16)
	var px_size := minf(size.x, size.y) / float(resolution)
	if px_size <= 0.0:
		return

	var draw_size := Vector2(px_size * resolution, px_size * resolution)
	var origin := (size - draw_size) * 0.5

	for y in range(resolution):
		for x in range(resolution):
			var uv := (Vector2(x, y) + Vector2(0.5, 0.5)) / float(resolution)
			if not _inside_heart(uv):
				continue

			var color := _cell_color(uv)
			if _is_divider(uv):
				color = divider_color
			if _is_outline(uv, 1.0 / float(resolution)):
				color = outline_color

			draw_rect(Rect2(origin + Vector2(x, y) * px_size, Vector2(px_size, px_size)), color, true)


func _cell_color(uv: Vector2) -> Color:
	var metric := 0.0
	var tint := empty_color

	# Top-left: Ira | Bottom-left: Pereza | Top-right: Gula | Bottom-right: Soberbia
	if uv.x < 0.5 and uv.y < 0.5:
		metric = _ira
		tint = ira_color
	elif uv.x < 0.5 and uv.y >= 0.5:
		metric = _pereza
		tint = pereza_color
	elif uv.x >= 0.5 and uv.y < 0.5:
		metric = _gula
		tint = gula_color
	else:
		metric = _soberbia
		tint = soberbia_color

	var local_quad_uv := Vector2(_quad_coord(uv.x), _quad_coord(uv.y))
	var height_from_bottom := 1.0 - local_quad_uv.y
	if metric >= height_from_bottom:
		return tint
	return empty_color


func _quad_coord(value: float) -> float:
	if value < 0.5:
		return value * 2.0
	return (value - 0.5) * 2.0


func _is_divider(uv: Vector2) -> bool:
	return absf(uv.x - 0.5) <= divider_thickness or absf(uv.y - 0.5) <= divider_thickness


func _is_outline(uv: Vector2, step_uv: float) -> bool:
	return (
		_inside_heart(uv)
		and (
			not _inside_heart(uv + Vector2(step_uv, 0.0))
			or not _inside_heart(uv - Vector2(step_uv, 0.0))
			or not _inside_heart(uv + Vector2(0.0, step_uv))
			or not _inside_heart(uv - Vector2(0.0, step_uv))
		)
	)


func _inside_heart(uv: Vector2) -> bool:
	var p := uv * 2.0 - Vector2.ONE
	p.y *= -1.0
	p *= 1.25
	p.y += 0.08

	var x2 := p.x * p.x
	var y2 := p.y * p.y
	var part := x2 + y2 - 1.0
	var value := part * part * part - x2 * p.y * p.y * p.y
	return value <= 0.0
