extends Area2D

@export_enum("WHEEL_UP", "WHEEL_DOWN") var scroll_direction: String = "WHEEL_UP"
@export var portal_enabled: bool = true

var player_inside: bool = false
var is_transitioning: bool = false

const LIMBO_SCENE := "res://scenes/limbo.tscn"
const CAVERN_SCENE := "res://scenes/cavern.tscn"
const FOREST_SCENE := "res://scenes/forest.tscn"

const PORTAL_TARGET_BY_NAME := {
	"PortalExitCavern": CAVERN_SCENE,
	"PortalDEVCavern": CAVERN_SCENE,
	"PortalEntranceLimbo": LIMBO_SCENE,
	"PortalExitForest": FOREST_SCENE,
	"PortalEntranceCavern": CAVERN_SCENE,
}


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _input(event: InputEvent) -> void:
	if not player_inside or is_transitioning:
		return

	if not portal_enabled:
		return

	if event is InputEventMouseButton and event.pressed:
		var correct_scroll = (
			event.button_index == MOUSE_BUTTON_WHEEL_UP and scroll_direction == "WHEEL_UP"
		) or (
			event.button_index == MOUSE_BUTTON_WHEEL_DOWN and scroll_direction == "WHEEL_DOWN"
		)
		if correct_scroll:
			var target_scene := _resolve_target_scene()
			if target_scene == "":
				push_warning("Portal '%s' sin ruta para escena actual." % name)
				return

			is_transitioning = true
			_change_scene(target_scene)

func _on_body_entered(body: Node2D) -> void:
	if _is_player_body(body):
		player_inside = true


func _on_body_exited(body: Node2D) -> void:
	if _is_player_body(body):
		player_inside = false


func _resolve_target_scene() -> String:
	if PORTAL_TARGET_BY_NAME.has(name):
		return PORTAL_TARGET_BY_NAME[name]

	return ""


func _change_scene(target_scene: String) -> void:
	var transition := get_node_or_null("/root/SceneTransition")

	# Priorizamos destino explícito por portal, usando fade del autoload si está disponible.
	if transition != null and transition.has_method("go_to_scene"):
		transition.call("go_to_scene", target_scene, name)
		return

	get_tree().change_scene_to_file(target_scene)


func _is_player_body(body: Node2D) -> bool:
	if not (body is CharacterBody2D):
		return false

	return body.name.begins_with("CharacterBody2D") or body.name == "Logan" or body.has_method("_try_interact_with_arches")
