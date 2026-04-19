extends CharacterBody2D


const SPEED = 130.0
const JUMP_VELOCITY = -110.0
const LIMBO_SCENE_PATH := "res://scenes/limbo.tscn"
const DEATH_SCREEN_SCENE := preload("res://scenes/ui/death_screen.tscn")

@export var death_y_threshold: float = 900.0
@export var debug_kill_key: Key = KEY_K

var _is_dead: bool = false


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

	if global_position.y > death_y_threshold:
		_trigger_death("Caida al abismo")


func _unhandled_input(event: InputEvent) -> void:
	if _is_dead:
		return

	if not (event is InputEventKey):
		return
	if not event.pressed or event.echo:
		return

	if event.keycode == debug_kill_key:
		_trigger_death("Condena voluntaria")


func _trigger_death(reason: String) -> void:
	if _is_dead:
		return

	_is_dead = true
	velocity = Vector2.ZERO
	set_physics_process(false)

	var overlay := DEATH_SCREEN_SCENE.instantiate()
	overlay.call("set_death_context", reason, _current_scene_name())
	overlay.connect("retry_requested", Callable(self, "_on_retry_requested"))
	overlay.connect("exit_requested", Callable(self, "_on_exit_requested"))
	_attach_death_overlay(overlay)


func _attach_death_overlay(overlay: Node) -> void:
	var tree := get_tree()
	if tree.current_scene:
		tree.current_scene.add_child(overlay)
		return

	tree.root.add_child(overlay)


func _on_retry_requested() -> void:
	get_tree().reload_current_scene()


func _on_exit_requested() -> void:
	get_tree().change_scene_to_file(LIMBO_SCENE_PATH)


func _current_scene_name() -> String:
	var tree := get_tree()
	if tree.current_scene:
		return tree.current_scene.name
	return "Escena"
