# Autoload: agregar en Project > Project Settings > Autoload
# Nombre: SceneTransition
extends CanvasLayer

const LIMBO_SCENE := "res://scenes/limbo.tscn"
const CAVERN_SCENE := "res://scenes/cavern.tscn"
const FOREST_SCENE := "res://scenes/forest.tscn"

# Ruta por defecto usada por go_to_next().
const SCENE_ROUTES := {
	LIMBO_SCENE: CAVERN_SCENE,
	CAVERN_SCENE: LIMBO_SCENE,
	FOREST_SCENE: CAVERN_SCENE,
}

@export var fade_out_time: float = 0.35
@export var fade_in_time: float = 0.35

var _overlay: ColorRect
var _is_busy: bool = false
var _pending_arrival_portal_name: String = ""

const ARRIVAL_PORTAL_BY_SOURCE := {
	"PortalExitCavern": "PortalEntranceLimbo",
	"PortalDEVCavern": "PortalEntranceLimbo",
	"PortalEntranceLimbo": "PortalExitCavern",
	"PortalExitForest": "PortalEntranceCavern",
	"PortalEntranceCavern": "PortalExitForest",
	"PortalEntranceBoss": "PortalExitBoss",
	"PortalExitBoss": "PortalEntranceBoss",
	"PortalExitArena": "PortalEntranceArena",
}


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_overlay()

	# Fade in al arrancar la escena inicial.
	_overlay.color.a = 1.0
	await _fade_in()


func go_to_next() -> bool:
	var current := _get_current_scene_path()
	if current == "":
		return false

	var target: String = SCENE_ROUTES.get(current, "")
	if target == "":
		push_error("SceneTransition: no hay ruta por defecto para '%s'" % current)
		return false

	return await go_to_scene(target)


func go_to_scene(target_scene: String, source_portal_name: String = "") -> bool:
	if _is_busy:
		return false

	if target_scene == "":
		push_error("SceneTransition: target_scene vacío")
		return false

	var current := _get_current_scene_path()
	if current == "":
		return false

	if current == target_scene:
		return false

	_pending_arrival_portal_name = ARRIVAL_PORTAL_BY_SOURCE.get(source_portal_name, "")

	_is_busy = true
	_ensure_overlay()

	await _fade_out()
	var err := get_tree().change_scene_to_file(target_scene)
	if err != OK:
		_is_busy = false
		push_error("SceneTransition: error al cambiar a '%s'" % target_scene)
		return false

	# Esperar un frame para asegurar que el árbol cargó la escena nueva.
	await get_tree().process_frame
	await get_tree().process_frame
	_apply_pending_portal_arrival_spawn()
	await _fade_in()

	_is_busy = false
	return true


func is_busy() -> bool:
	return _is_busy


func _get_current_scene_path() -> String:
	if get_tree() == null or get_tree().current_scene == null:
		push_error("SceneTransition: current_scene no disponible")
		return ""
	return get_tree().current_scene.scene_file_path


func _ensure_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		return

	_overlay = ColorRect.new()
	_overlay.name = "FadeOverlay"
	_overlay.color = Color(0, 0, 0, 0)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)


func _fade_out() -> void:
	var tween := create_tween()
	tween.tween_property(_overlay, "color:a", 1.0, fade_out_time)
	await tween.finished


func _fade_in() -> void:
	var tween := create_tween()
	tween.tween_property(_overlay, "color:a", 0.0, fade_in_time)
	await tween.finished


func _apply_pending_portal_arrival_spawn() -> void:
	if _pending_arrival_portal_name == "":
		return

	var root := get_tree().current_scene
	if root == null:
		_pending_arrival_portal_name = ""
		return

	var arrival_portal := root.get_node_or_null(NodePath(_pending_arrival_portal_name))
	if not (arrival_portal is Node2D):
		_pending_arrival_portal_name = ""
		return

	var player := _find_first_player_body(root)
	if player == null:
		_pending_arrival_portal_name = ""
		return

	var spawn_pos := _compute_spawn_in_front_of_portal(arrival_portal as Node2D)
	player.global_position = spawn_pos

	_pending_arrival_portal_name = ""


func _find_first_player_body(root: Node) -> CharacterBody2D:
	var fallback_named: CharacterBody2D = null
	var stack: Array = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)

		if not (node is CharacterBody2D):
			continue

		var body := node as CharacterBody2D
		if body.has_method("_try_interact_with_arches") or body.has_method("intentar_agarrar_objeto"):
			return body

		if body.name == "CharacterBody2D" or body.name == "Logan":
			fallback_named = body

	return fallback_named


func _compute_spawn_in_front_of_portal(portal: Node2D) -> Vector2:
	var shape := portal.get_node_or_null("CollisionShape2D")
	if shape is CollisionShape2D and (shape as CollisionShape2D).shape is RectangleShape2D:
		var rect_shape := (shape as CollisionShape2D).shape as RectangleShape2D
		var half_h := rect_shape.size.y * 0.5
		return (shape as CollisionShape2D).global_position + Vector2(0, half_h + 18.0)

	return portal.global_position + Vector2(0, 96.0)
