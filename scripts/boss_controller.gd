extends Node2D

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/Projectile.tscn")
const BOLT_SCRIPT: Script = preload("res://scripts/boss_bolt.gd")
const CREDITS_SCENE := "res://scenes/credits.tscn"

@export var boss_texture: Texture2D = preload("res://assets/sprites/Slastic.png")
@export var arena_center: Vector2 = Vector2(-1700.0, -260.0)
@export var arena_half_size: Vector2 = Vector2(520.0, 220.0)
@export var boss_speed: float = 120.0
@export var projectile_speed: float = 500.0
@export var projectile_interval: float = 0.3
@export var attack_phase_time: float = 2.7
@export var cooldown_phase_time: float = 2.6
@export var bricks_to_win: int = 5
@export var plugs_to_win: int = 4

var _player: CharacterBody2D = null
var _purification_manager: Node = null

var _boss_core: Node2D
var _boss_hitbox: CharacterBody2D
var _boss_screen: Sprite2D
var _dialog_label: Label
var _battery_label: Label
var _overlay: ColorRect
var _overlay_text: Label
var _shooting_hand_1: Node2D
var _shooting_hand_2: Node2D

var _projectiles: Node2D
var _plugs: Array = []

var _move_target: Vector2
var _move_target_time: float = 0.0
var _shake_time: float = 0.0
var _shake_strength: float = 6.0
var _hit_flash_time: float = 0.0
var _unplug_flash_time: float = 0.0
var _hit_cooldown: float = 0.0

var _hits_taken: int = 0
var _crack_level: int = 0
var _unplugged: int = 0
var _battery_percent: int = 100

var _attack_clock: float = 0.0
var _phase_time: float = 0.0
var _is_attack_phase: bool = true
var _fight_finished: bool = false
var _player_collision_ignored: bool = false


func _ready() -> void:
	randomize()
	_player = _find_player()
	_purification_manager = get_node_or_null("/root/PurificationManager")

	_build_runtime_nodes()
	_bind_existing_plugs()
	arena_center = _boss_core.global_position

	_shooting_hand_1 = _boss_core.get_node_or_null("ShootingHand1") as Node2D
	_shooting_hand_2 = _boss_core.get_node_or_null("ShootingHand2") as Node2D

	_move_target = _boss_core.global_position
	_start_attack_phase()


func _process(delta: float) -> void:
	if _fight_finished:
		return

	if _player == null or not is_instance_valid(_player):
		_player = _find_player()
		_player_collision_ignored = false

	_ensure_player_pass_through()
	_update_boss_movement(delta)
	_update_boss_vfx(delta)
	_update_attack_cycle(delta)

	if _hit_cooldown > 0.0:
		_hit_cooldown -= delta


func _build_runtime_nodes() -> void:
	_projectiles = Node2D.new()
	_projectiles.name = "BossProjectiles"
	add_child(_projectiles)

	var slastic_node := get_node_or_null("Slastic") as Node2D
	if slastic_node != null:
		_boss_core = slastic_node
	else:
		_boss_core = self

	_boss_hitbox = _boss_core as CharacterBody2D

	_boss_screen = _boss_core.get_node_or_null("Sprite2D") as Sprite2D

	_dialog_label = Label.new()
	_dialog_label.name = "BossDialog"
	_dialog_label.position = arena_center + Vector2(-260, -280)
	_dialog_label.text = "..."
	_dialog_label.modulate = Color(0.9, 0.95, 1.0, 1.0)
	_dialog_label.add_theme_font_size_override("font_size", 24)
	add_child(_dialog_label)

	_battery_label = Label.new()
	_battery_label.name = "BatteryLabel"
	_battery_label.position = arena_center + Vector2(-260, -245)
	_battery_label.text = "BATERIA: 100%"
	_battery_label.modulate = Color(0.95, 1.0, 0.95, 1.0)
	_battery_label.add_theme_font_size_override("font_size", 21)
	add_child(_battery_label)

	_overlay = ColorRect.new()
	_overlay.name = "EndingOverlay"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0, 0, 0, 0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

	_overlay_text = Label.new()
	_overlay_text.name = "EndingText"
	_overlay_text.set_anchors_preset(Control.PRESET_CENTER)
	_overlay_text.position = Vector2(-320, -40)
	_overlay_text.size = Vector2(640, 140)
	_overlay_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_overlay_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_overlay_text.modulate = Color(1, 1, 1, 0)
	_overlay_text.add_theme_font_size_override("font_size", 34)
	_overlay.add_child(_overlay_text)


func _bind_existing_plugs() -> void:
	_plugs.clear()
	for child in get_children():
		if child is Area2D and child.has_signal("unplugged"):
			if not child.is_connected("unplugged", Callable(self, "_on_plug_unplugged")):
				child.connect("unplugged", Callable(self, "_on_plug_unplugged"))
			_plugs.append(child)

	if not _plugs.is_empty():
		plugs_to_win = _plugs.size()


func _find_player() -> CharacterBody2D:
	var stack: Array = [self]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if node is CharacterBody2D and (node.name == "CharacterBody2D" or node.name == "Logan" or node.has_method("_try_interact_with_arches")):
			return node
	return null


func _update_boss_movement(delta: float) -> void:
	_move_target_time -= delta
	if _move_target_time <= 0.0:
		_move_target_time = randf_range(0.9, 1.8)
		_move_target = arena_center + Vector2(
			randf_range(-arena_half_size.x, arena_half_size.x),
			0.0
		)

	var new_x := move_toward(_boss_core.global_position.x, _move_target.x, boss_speed * delta)
	_boss_core.global_position = Vector2(new_x, arena_center.y)


func _update_boss_vfx(delta: float) -> void:
	if _hit_flash_time > 0.0:
		_hit_flash_time -= delta
		_boss_screen.modulate = Color(1.0, 0.35, 0.35, 1.0)
	elif _unplug_flash_time > 0.0:
		_unplug_flash_time -= delta
		_boss_screen.modulate = Color(0.38, 0.62, 1.0, 1.0)
	else:
		var base_tint := 1.0 - float(_crack_level) * 0.12
		_boss_screen.modulate = Color(base_tint, base_tint, base_tint, 1.0)

	if _shake_time > 0.0:
		_shake_time -= delta
		_boss_screen.offset = Vector2(randf_range(-_shake_strength, _shake_strength), randf_range(-_shake_strength, _shake_strength))
	else:
		_boss_screen.offset = Vector2.ZERO


func _update_attack_cycle(delta: float) -> void:
	_phase_time -= delta
	_attack_clock -= delta

	if _is_attack_phase and _attack_clock <= 0.0:
		_attack_clock = projectile_interval
		_spawn_attack_bolt()

	if _phase_time > 0.0:
		return

	if _is_attack_phase:
		_start_cooldown_phase()
	else:
		_start_attack_phase()


func _start_attack_phase() -> void:
	_is_attack_phase = true
	_phase_time = attack_phase_time
	_attack_clock = 0.05
	_set_dialog(_random_attack_line())


func _start_cooldown_phase() -> void:
	_is_attack_phase = false
	_phase_time = cooldown_phase_time
	_set_dialog(_random_cooldown_line())


func _spawn_attack_bolt() -> void:
	if _player == null:
		return

	var bolt := PROJECTILE_SCENE.instantiate() as Area2D
	if bolt == null:
		return

	_projectiles.add_child(bolt)

	var spawn := global_position
	var anchors: Array[Node2D] = []
	if _shooting_hand_1 != null:
		anchors.append(_shooting_hand_1)
	if _shooting_hand_2 != null:
		anchors.append(_shooting_hand_2)

	if not anchors.is_empty():
		var anchor := anchors[randi() % anchors.size()]
		spawn = anchor.global_position
	else:
		spawn = _boss_core.global_position + Vector2(0, 130)

	bolt.global_position = spawn
	var dir := (_player.global_position - spawn).normalized()
	bolt.call("setup", dir, projectile_speed, 1)
	bolt.queue_redraw()


func _ensure_player_pass_through() -> void:
	if _player_collision_ignored:
		return
	if _player == null or not is_instance_valid(_player):
		return
	if _boss_hitbox == null or not is_instance_valid(_boss_hitbox):
		return

	_boss_hitbox.add_collision_exception_with(_player)
	_player.add_collision_exception_with(_boss_hitbox)
	_player_collision_ignored = true


func _on_plug_unplugged(_plug: Area2D) -> void:
	if _fight_finished:
		return

	_unplugged += 1
	_battery_percent = max(0, 100 - int(round(100.0 * float(_unplugged) / float(plugs_to_win))))
	if _battery_label != null:
		_battery_label.text = "BATERIA: %d%%" % _battery_percent
	_unplug_flash_time = 0.2
	_shake_time = 0.28
	_shake_strength = 5.0
	_set_dialog("CABLE DESCONECTADO... %d/%d" % [_unplugged, plugs_to_win])
	_emit_purification_signal("boss_unplugged_cable", {"count": _unplugged})

	if _unplugged >= plugs_to_win:
		_finish_boss("pacifista")


func take_damage(_damage: int = 1) -> void:
	if _fight_finished:
		return

	if _hit_cooldown > 0.0:
		return

	_hit_cooldown = 0.22
	_hits_taken += 1
	_crack_level = min(_hits_taken, 5)
	_hit_flash_time = 0.18
	_shake_time = 0.3
	_shake_strength = 7.0
	_set_dialog("PANTALLA DANADA %d/%d" % [_hits_taken, bricks_to_win])
	_emit_purification_signal("boss_hit_by_brick", {"hits": _hits_taken})

	if _hits_taken >= bricks_to_win:
		_finish_boss("violento")


func _finish_boss(mode: String) -> void:
	if _fight_finished:
		return

	_fight_finished = true
	for bolt in _projectiles.get_children():
		bolt.queue_free()

	if mode == "violento":
		await _violent_end_sequence()
	else:
		await _pacifist_end_sequence()


func _violent_end_sequence() -> void:
	_set_dialog("SISTEMA CRITICO. ADIOS.")
	_emit_purification_signal("boss_defeated_violent", {"hits": _hits_taken})
	_spawn_explosion_burst(18)
	await get_tree().create_timer(0.22).timeout
	_spawn_explosion_burst(24)

	var tw := create_tween()
	tw.tween_property(_overlay, "color", Color(0, 0, 0, 1), 1.2)
	tw.parallel().tween_property(_overlay_text, "modulate", Color(1, 1, 1, 1), 0.6)
	_overlay_text.text = "FINAL: PANTALLA ROTA"
	await tw.finished
	await get_tree().create_timer(1.4).timeout

	_go_to_credits("FINAL: PANTALLA ROTA", "violento")


func _pacifist_end_sequence() -> void:
	_set_dialog("BATERIA EN 0%. MODO SEGURO.")
	_emit_purification_signal("boss_defeated_pacifist", {"cables": _unplugged})

	_overlay.color = Color(1, 1, 1, 0)
	_overlay_text.modulate = Color(0, 0, 0, 0)
	_overlay_text.text = "FINAL: APAGADO PACIFISTA"

	var tw_white := create_tween()
	tw_white.tween_property(_overlay, "color", Color(1, 1, 1, 1), 1.1)
	tw_white.parallel().tween_property(_overlay_text, "modulate", Color(0, 0, 0, 1), 0.7)
	await tw_white.finished
	await get_tree().create_timer(1.2).timeout

	var tw_black := create_tween()
	tw_black.tween_property(_overlay, "color", Color(0, 0, 0, 1), 0.9)
	tw_black.parallel().tween_property(_overlay_text, "modulate", Color(1, 1, 1, 0), 0.5)
	await tw_black.finished
	await get_tree().create_timer(0.5).timeout

	_go_to_credits("FINAL: APAGADO PACIFISTA", "pacifista")


func _go_to_credits(ending_name: String, ending_mode: String) -> void:
	var stats := _collect_stats(ending_name, ending_mode)
	EndRunState.set_result(ending_name, ending_mode, stats)
	get_tree().change_scene_to_file(CREDITS_SCENE)


func _collect_stats(ending_name: String, ending_mode: String) -> Dictionary:
	var stats := {
		"ending": ending_name,
		"mode": ending_mode,
		"boss_hits": _hits_taken,
		"cables_disconnected": _unplugged,
		"battery_final": _battery_percent,
	}

	if _purification_manager != null:
		if _purification_manager.has_method("get_statistics"):
			stats["probabilidades"] = _purification_manager.call("get_statistics")
		elif _purification_manager.has_method("get_stats"):
			stats["probabilidades"] = _purification_manager.call("get_stats")
		elif _purification_manager.has_method("build_summary"):
			stats["probabilidades"] = _purification_manager.call("build_summary")

	return stats


func _emit_purification_signal(signal_name: String, payload: Dictionary) -> void:
	if _purification_manager != null and _purification_manager.has_method("ingest_game_signal"):
		_purification_manager.call("ingest_game_signal", signal_name, payload)


func _set_dialog(text: String) -> void:
	if _dialog_label != null:
		_dialog_label.text = text


func _spawn_explosion_burst(count: int) -> void:
	for i in range(count):
		var bolt := PROJECTILE_SCENE.instantiate() as Area2D
		if bolt == null:
			continue

		_projectiles.add_child(bolt)

		bolt.global_position = _boss_core.global_position + Vector2(randf_range(-24, 24), randf_range(-20, 20))
		var angle := (TAU * float(i) / float(max(1, count))) + randf_range(-0.22, 0.22)
		var dir := Vector2(cos(angle), sin(angle))
		bolt.call("setup", dir, projectile_speed * randf_range(0.65, 1.1), 1)
		bolt.queue_redraw()


func _random_attack_line() -> String:
	var lines := [
		"TE VOY A FORMATEAR.",
		"ESQUIVA ESTO.",
		"NO APAGARAS MI SISTEMA.",
		"PROYECTILES EN CURSO.",
	]
	return lines[randi() % lines.size()]


func _random_cooldown_line() -> String:
	var lines := [
		"...recalculando trayectoria.",
		"ventiladores al 100%.",
		"mi bateria sigue viva.",
		"no te rindas, humano.",
	]
	return lines[randi() % lines.size()]
