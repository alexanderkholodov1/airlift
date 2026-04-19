extends RigidBody2D
class_name DecisionVisualNode

@export var radius: float = 12.0
@export var good_color: Color = Color(0.43, 0.82, 0.51, 0.94)
@export var bad_color: Color = Color(0.87, 0.33, 0.29, 0.94)
@export var neutral_color: Color = Color(0.54, 0.64, 0.74, 0.88)

var decision_id: int = -1
var polarity: String = "neutral"
var label_text: String = "decision"
var weight: float = 1.0


func _ready() -> void:
	gravity_scale = 0.0
	linear_damp = 6.0
	angular_damp = 12.0
	lock_rotation = true
	collision_layer = 0
	collision_mask = 0
	can_sleep = false
	_ensure_collision()
	_refresh_visuals()


func setup(decision_data: Dictionary) -> void:
	decision_id = int(decision_data.get("id", -1))
	polarity = str(decision_data.get("polarity", "neutral"))
	label_text = str(decision_data.get("label", decision_data.get("event", "decision")))
	weight = clampf(float(decision_data.get("weight", 1.0)), 0.5, 2.5)
	mass = clampf(weight, 0.7, 2.0)
	radius = 10.0 + weight * 5.0
	if is_inside_tree():
		_ensure_collision()
		_refresh_visuals()


func _ensure_collision() -> void:
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null:
		collision = CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		add_child(collision)

	var circle := collision.shape as CircleShape2D
	if circle == null:
		circle = CircleShape2D.new()
		collision.shape = circle
	circle.radius = radius


func _refresh_visuals() -> void:
	queue_redraw()


func _draw() -> void:
	var fill := _get_color_for_polarity()
	draw_circle(Vector2.ZERO, radius, fill)
	draw_arc(Vector2.ZERO, radius + 1.5, 0.0, TAU, 28, fill.lightened(0.2), 2.0, true)

	if polarity == "bad":
		draw_circle(Vector2.ZERO, radius * 0.34, Color(0.17, 0.05, 0.05, 0.45))
	elif polarity == "good":
		draw_circle(Vector2.ZERO, radius * 0.34, Color(0.05, 0.17, 0.08, 0.45))

	var font: Font = ThemeDB.fallback_font
	if font != null:
		var text := _get_short_label()
		var font_size := 12
		var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(
			font,
			Vector2(-text_width * 0.5, radius + 14.0),
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			font_size,
			Color(1.0, 1.0, 1.0, 0.92)
		)


func _get_color_for_polarity() -> Color:
	if polarity == "bad":
		return bad_color
	if polarity == "good":
		return good_color
	return neutral_color


func _get_short_label() -> String:
	if label_text.length() <= 18:
		return label_text
	return "%s..." % label_text.substr(0, 18)
