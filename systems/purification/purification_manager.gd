extends Node
class_name PurificationManager

const PurificationResource := preload("res://systems/purification/purification_resource.gd")

signal metrics_changed(metrics: Dictionary)
signal dda_profile_changed(profile: Dictionary)
signal decision_registered(decision: Dictionary)

const SAVE_PATH := "user://purification_data.tres"
const METRICS := ["ira", "pereza", "gula", "soberbia"]

# Each event starts as a base impulse and then propagates over the metric graph.
const EVENT_IMPULSES := {
	"attack_pacifist": {"ira": 7.0, "pereza": 0.3, "gula": 0.1, "soberbia": 1.4},
	"ignore_npc_favor": {"ira": 0.9, "pereza": 6.8, "gula": 0.2, "soberbia": 0.8},
	"hoard_bricks": {"ira": 0.4, "pereza": 1.2, "gula": 7.4, "soberbia": 0.9},
	"ignore_shortcuts_or_defense": {"ira": 1.1, "pereza": 0.7, "gula": 0.2, "soberbia": 7.1},
	"help_npc": {"ira": 1.5, "pereza": 3.6, "gula": 0.6, "soberbia": 0.8},
	"spare_pacifist": {"ira": 3.9, "pereza": 0.3, "gula": 0.4, "soberbia": 0.4},
	"use_bricks_creatively": {"ira": 0.6, "pereza": 1.1, "gula": 3.8, "soberbia": 2.5},
}

# Row-stochastic transition graph between sins.
const TRANSITION_MATRIX := {
	"ira": {"ira": 0.68, "pereza": 0.08, "gula": 0.07, "soberbia": 0.17},
	"pereza": {"ira": 0.11, "pereza": 0.66, "gula": 0.15, "soberbia": 0.08},
	"gula": {"ira": 0.09, "pereza": 0.12, "gula": 0.71, "soberbia": 0.08},
	"soberbia": {"ira": 0.17, "pereza": 0.07, "gula": 0.10, "soberbia": 0.66},
}

const DIRECT_WEIGHT := 0.65
const PROPAGATION_WEIGHT := 0.45
const STOCHASTIC_RATIO := 0.18
const MAX_HISTORY := 250

var data: PurificationResource
var history: Array[Dictionary] = []

var _rng := RandomNumberGenerator.new()
var _decision_counter := 0
var _brick_hoard_time := 0.0


func _ready() -> void:
	_rng.randomize()
	_load_or_create_data()
	_emit_all()


func register_attack_pacifist(intensity: float = 1.0) -> void:
	_register_bad_event("attack_pacifist", intensity)


func register_ignore_npc_favor(intensity: float = 1.0) -> void:
	_register_bad_event("ignore_npc_favor", intensity)


func register_hoard_bricks(intensity: float = 1.0) -> void:
	_register_bad_event("hoard_bricks", intensity)


func register_ignore_shortcuts_or_defense(intensity: float = 1.0) -> void:
	_register_bad_event("ignore_shortcuts_or_defense", intensity)


func register_help_npc(intensity: float = 1.0) -> void:
	_register_good_event("help_npc", intensity)


func register_spare_pacifist(intensity: float = 1.0) -> void:
	_register_good_event("spare_pacifist", intensity)


func register_use_bricks_creatively(intensity: float = 1.0) -> void:
	_register_good_event("use_bricks_creatively", intensity)


func ingest_game_signal(signal_name: String, payload: Dictionary = {}) -> void:
	var intensity := float(payload.get("intensity", 1.0))
	match signal_name:
		"attacked_pacifist_enemy":
			register_attack_pacifist(intensity)
		"ignored_npc_favor":
			register_ignore_npc_favor(intensity)
		"hoarded_bricks":
			register_hoard_bricks(intensity)
		"ignored_shortcuts_or_defense":
			register_ignore_shortcuts_or_defense(intensity)
		"helped_npc":
			register_help_npc(intensity)
		"spared_pacifist":
			register_spare_pacifist(intensity)
		"used_bricks_creatively":
			register_use_bricks_creatively(intensity)
		_:
			push_warning("PurificationManager: unknown game signal '%s'." % signal_name)


func track_brick_inventory(current_bricks: int, used_brick_recently: bool, delta: float) -> void:
	if current_bricks >= 6 and not used_brick_recently:
		_brick_hoard_time += delta
		if _brick_hoard_time >= 7.0:
			register_hoard_bricks(clampf(_brick_hoard_time / 7.0, 1.0, 2.5))
			_brick_hoard_time = 0.0
	else:
		_brick_hoard_time = maxf(_brick_hoard_time - delta * 2.0, 0.0)


func get_metrics() -> Dictionary:
	if data == null:
		return _zero_metrics()
	return data.to_dictionary()


func get_metrics_normalized() -> Dictionary:
	if data == null:
		return _zero_metrics()
	return data.to_normalized_dictionary()


func get_recent_decisions(limit: int = 30) -> Array[Dictionary]:
	if limit <= 0:
		return []
	if history.size() <= limit:
		return history.duplicate(true)
	return history.slice(history.size() - limit, history.size()).duplicate(true)


func get_dda_profile() -> Dictionary:
	var n := get_metrics_normalized()
	var impurity := (
		float(n.ira) * 0.33
		+ float(n.pereza) * 0.22
		+ float(n.gula) * 0.20
		+ float(n.soberbia) * 0.25
	)
	var aggression_bias := clampf(impurity * 0.68 + float(n.ira) * 0.32, 0.0, 1.0)
	var pressure_bias := clampf((float(n.soberbia) + float(n.gula)) * 0.5, 0.0, 1.0)

	return {
		"enemy_aggressiveness": lerpf(0.85, 1.65, aggression_bias),
		"enemy_reaction_speed": lerpf(0.90, 1.40, pressure_bias),
		"pacifist_enemy_ratio": lerpf(1.20, 0.65, float(n.ira)),
		"npc_request_rate": lerpf(0.80, 1.30, float(n.pereza)),
		"resource_scarcity": lerpf(0.90, 1.45, float(n.gula)),
		"shortcut_hint_visibility": lerpf(1.20, 0.65, float(n.soberbia)),
		"boss_pattern_complexity": lerpf(0.85, 1.55, (impurity + pressure_bias) * 0.5),
	}


func reset_all() -> void:
	data = PurificationResource.new()
	history.clear()
	_brick_hoard_time = 0.0
	_save_data()
	_emit_all()


func _register_bad_event(event_name: String, intensity: float) -> void:
	_apply_event(event_name, "bad", intensity)


func _register_good_event(event_name: String, intensity: float) -> void:
	_apply_event(event_name, "good", intensity)


func _apply_event(event_name: String, polarity: String, intensity: float) -> void:
	if data == null:
		return

	var impulse := _scaled_impulse_for(event_name, intensity)
	var delta := _run_stochastic_graph_step(impulse, polarity)
	data.apply_delta(delta)
	_save_data()

	var decision := _build_decision(event_name, polarity, intensity, delta)
	history.push_back(decision)
	if history.size() > MAX_HISTORY:
		history.pop_front()

	decision_registered.emit(decision)
	_emit_all()


func _scaled_impulse_for(event_name: String, intensity: float) -> Dictionary:
	var base: Dictionary = EVENT_IMPULSES.get(event_name, {})
	var scaled := _zero_metrics()
	var safe_intensity := clampf(intensity, 0.1, 4.0)

	for metric in METRICS:
		scaled[metric] = float(base.get(metric, 0.0)) * safe_intensity

	return scaled


func _run_stochastic_graph_step(impulse: Dictionary, polarity: String) -> Dictionary:
	var propagated := _zero_metrics()
	for source in METRICS:
		var source_value := float(impulse.get(source, 0.0))
		var transitions: Dictionary = TRANSITION_MATRIX.get(source, {})
		for target in METRICS:
			propagated[target] = float(propagated.get(target, 0.0)) + source_value * float(transitions.get(target, 0.0))

	var direction_sign := 1.0
	if polarity == "good":
		direction_sign = -1.0

	var delta := _zero_metrics()
	for metric in METRICS:
		var direct := float(impulse.get(metric, 0.0)) * DIRECT_WEIGHT
		var spread := float(propagated.get(metric, 0.0)) * PROPAGATION_WEIGHT
		var sigma := maxf(0.025, (direct + spread) * STOCHASTIC_RATIO)
		var jitter := _rng.randf_range(-sigma, sigma)
		var magnitude := maxf(0.0, direct + spread + jitter)
		delta[metric] = direction_sign * magnitude

	return delta


func _build_decision(event_name: String, polarity: String, intensity: float, delta: Dictionary) -> Dictionary:
	_decision_counter += 1
	return {
		"id": _decision_counter,
		"event": event_name,
		"label": _event_to_label(event_name),
		"polarity": polarity,
		"intensity": intensity,
		"weight": clampf(intensity, 0.6, 2.2),
		"timestamp": int(Time.get_unix_time_from_system()),
		"delta": delta.duplicate(true),
		"metrics_after": get_metrics(),
	}


func _event_to_label(event_name: String) -> String:
	match event_name:
		"attack_pacifist":
			return "Ataca pacifista"
		"ignore_npc_favor":
			return "Ignora favor"
		"hoard_bricks":
			return "Acumula ladrillos"
		"ignore_shortcuts_or_defense":
			return "Ignora defensa"
		"help_npc":
			return "Ayuda NPC"
		"spare_pacifist":
			return "Perdona enemigo"
		"use_bricks_creatively":
			return "Usa ladrillos"
		_:
			return event_name


func _emit_all() -> void:
	metrics_changed.emit(get_metrics())
	dda_profile_changed.emit(get_dda_profile())


func _load_or_create_data() -> void:
	if ResourceLoader.exists(SAVE_PATH):
		var loaded := ResourceLoader.load(SAVE_PATH)
		if loaded is PurificationResource:
			data = loaded

	if data == null:
		data = PurificationResource.new()
		_save_data()

	data.clamp_all()


func _save_data() -> void:
	if data == null:
		return
	var err := ResourceSaver.save(data, SAVE_PATH)
	if err != OK:
		push_warning("PurificationManager: could not save resource at %s (error %s)." % [SAVE_PATH, err])


func _zero_metrics() -> Dictionary:
	return {
		"ira": 0.0,
		"pereza": 0.0,
		"gula": 0.0,
		"soberbia": 0.0,
	}
