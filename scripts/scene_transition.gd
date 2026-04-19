# Autoload: agregar en Project > Project Settings > Autoload
# Nombre: SceneTransition
extends CanvasLayer

const SCENE_ROUTES = {
	"res://scenes/limbo.tscn": "res://scenes/cavern.tscn",
	"res://scenes/cavern.tscn": "res://scenes/limbo.tscn",
}

var _overlay: ColorRect
var _is_busy: bool = false


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS

	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

	# Fade in al arrancar la escena inicial
	_fade_in()


func go_to_next() -> void:
	if _is_busy:
		return

	var current = get_tree().current_scene.scene_file_path
	var target = SCENE_ROUTES.get(current, "")
	if target == "":
		push_error("SceneTransition: no hay ruta para '%s'" % current)
		return

	_is_busy = true
	_fade_out(func(): 
		get_tree().change_scene_to_file(target)
		await get_tree().process_frame
		_fade_in()
		_is_busy = false
	)


func _fade_out(on_done: Callable) -> void:
	var tween = create_tween()
	tween.tween_property(_overlay, "color:a", 1.0, 0.5)
	tween.tween_callback(on_done)


func _fade_in() -> void:
	_overlay.color = Color(0, 0, 0, 1)
	var tween = create_tween()
	tween.tween_property(_overlay, "color:a", 0.0, 0.5)
