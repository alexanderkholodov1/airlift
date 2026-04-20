extends Control

@onready var _ending_label: Label = $VBoxContainer/EndingLabel
@onready var _mode_label: Label = $VBoxContainer/ModeLabel
@onready var _stats_label: RichTextLabel = $VBoxContainer/StatsLabel
@onready var _credits_label: RichTextLabel = $VBoxContainer/CreditsLabel


func _ready() -> void:
	var ending := EndRunState.ending_name
	if ending == "":
		ending = "FINAL DESCONOCIDO"
	if not ending.begins_with("FINAL:"):
		ending = "FINAL: %s" % ending
	_ending_label.text = ending

	var mode := EndRunState.ending_mode
	if mode == "":
		mode = "sin-datos"
	_mode_label.text = "Ruta: %s" % mode

	var resolved_stats := _resolve_stats()
	_stats_label.text = _format_stats(resolved_stats)
	_credits_label.text = "GRACIAS POR JUGAR"


func _resolve_stats() -> Dictionary:
	var stats: Dictionary = EndRunState.statistics.duplicate(true)
	var needs_probabilities := stats.is_empty() or not (stats.get("probabilidades", {}) is Dictionary) or Dictionary(stats.get("probabilidades", {})).is_empty()

	if needs_probabilities:
		var manager := get_node_or_null("/root/PurificationManager")
		if manager != null:
			if manager.has_method("get_statistics"):
				stats["probabilidades"] = manager.call("get_statistics")
			elif manager.has_method("get_stats"):
				stats["probabilidades"] = manager.call("get_stats")
			elif manager.has_method("build_summary"):
				stats["probabilidades"] = manager.call("build_summary")

	if not stats.has("ending"):
		stats["ending"] = EndRunState.ending_name
	if not stats.has("mode"):
		stats["mode"] = EndRunState.ending_mode

	return stats


func _format_stats(stats: Dictionary) -> String:
	if stats.is_empty():
		return "ESTADISTICAS\n\nSin datos de Probabilidades."

	var lines: Array[String] = []
	lines.append("ESTADISTICAS")
	lines.append("")

	var probs: Dictionary = stats.get("probabilidades", {})
	if probs.is_empty():
		lines.append("Sin datos de Probabilidades.")
		return "\n".join(lines)

	var p_bondad := float(probs.get("probabilidad_bondad", 0.0))
	var p_pecado := float(probs.get("probabilidad_pecado", 0.0))
	lines.append("Probabilidad de bondad: %.1f%%" % p_bondad)
	lines.append("Probabilidad de pecado: %.1f%%" % p_pecado)
	lines.append("")

	lines.append("Porcentajes de pecados:")
	var sins: Dictionary = probs.get("porcentajes_pecados", {})
	if sins.is_empty():
		lines.append("- Sin datos")
	else:
		lines.append("- Ira: %.1f%%" % float(sins.get("ira", 0.0)))
		lines.append("- Pereza: %.1f%%" % float(sins.get("pereza", 0.0)))
		lines.append("- Gula: %.1f%%" % float(sins.get("gula", 0.0)))
		lines.append("- Soberbia: %.1f%%" % float(sins.get("soberbia", 0.0)))

	return "\n".join(lines)
