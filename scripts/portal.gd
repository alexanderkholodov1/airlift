extends Area2D

@export_enum("WHEEL_UP", "WHEEL_DOWN") var scroll_direction: String = "WHEEL_UP"
@export var portal_enabled: bool = true

var player_inside: bool = false
var is_transitioning: bool = false

const LIMBO_SCENE := "res://scenes/limbo.tscn"
const CAVERN_SCENE := "res://scenes/cavern.tscn"
const FOREST_SCENE := "res://scenes/forest.tscn"
const BOSS_SCENE := "res://scenes/boss.tscn"
const ARENA_SCENE := "res://scenes/arena.tscn"

const PORTAL_TARGET_BY_NAME := {
	"PortalExitCavern": CAVERN_SCENE,
	"PortalDEVCavern": CAVERN_SCENE,
	"PortalEntranceLimbo": LIMBO_SCENE,
	"PortalExitForest": FOREST_SCENE,
	"PortalEntranceCavern": CAVERN_SCENE,
	"PortalEntranceBoss": BOSS_SCENE,
	"PortalExitBoss": FOREST_SCENE,
	"PortalExitArena": ARENA_SCENE,
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
			_try_activate_portal()

func _on_body_entered(body: Node2D) -> void:
	if _is_player_body(body):
		player_inside = true
		if _should_auto_activate():
			_try_activate_portal()


func _on_body_exited(body: Node2D) -> void:
	if _is_player_body(body):
		player_inside = false


func _resolve_target_scene() -> String:
	if PORTAL_TARGET_BY_NAME.has(name):
		return PORTAL_TARGET_BY_NAME[name]

	return ""


func _try_activate_portal() -> void:
	if is_transitioning:
		return

	var target_scene := _resolve_target_scene()
	if target_scene == "":
		push_warning("Portal '%s' sin ruta para escena actual." % name)
		return

	_register_limbo_outcome_if_needed(target_scene)

	is_transitioning = true
	_change_scene(target_scene)


func _should_auto_activate() -> bool:
	return name == "PortalExitArena"


func _change_scene(target_scene: String) -> void:
	var transition := get_node_or_null("/root/SceneTransition")

	# Priorizamos destino explícito por portal, usando fade del autoload si está disponible.
	if transition != null and transition.has_method("go_to_scene"):
		transition.call("go_to_scene", target_scene, name)
		return

	get_tree().change_scene_to_file(target_scene)


func _register_limbo_outcome_if_needed(target_scene: String) -> void:
	if name != "PortalExitCavern":
		return
	if target_scene != CAVERN_SCENE:
		return

	var current_scene := get_tree().current_scene
	if current_scene == null or current_scene.scene_file_path != LIMBO_SCENE:
		return

	var purification_manager := get_node_or_null("/root/PurificationManager")
	if purification_manager == null or not purification_manager.has_method("ingest_game_signal"):
		return

	if _has_alive_limbo_enemy(current_scene):
		purification_manager.call("ingest_game_signal", "limbo_enemy_spared", {"intensity": 1.0})


func _has_alive_limbo_enemy(root: Node) -> bool:
	var stack: Array = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)

		if not (node is CharacterBody2D):
			continue

		var script_resource = node.get_script()
		if not (script_resource is Script):
			continue
		if script_resource.resource_path != "res://scripts/enemy.gd":
			continue
		if node.is_queued_for_deletion():
			continue

		if not bool(node.get("is_dead")):
			return true

	return false


func _is_player_body(body: Node2D) -> bool:
	if not (body is CharacterBody2D):
		return false

	return body.name.begins_with("CharacterBody2D") or body.name == "Logan" or body.has_method("_try_interact_with_arches")
