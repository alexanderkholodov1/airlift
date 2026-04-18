extends Resource
class_name PurificationResource

@export_range(0.0, 100.0, 0.01) var ira: float = 0.0
@export_range(0.0, 100.0, 0.01) var pereza: float = 0.0
@export_range(0.0, 100.0, 0.01) var gula: float = 0.0
@export_range(0.0, 100.0, 0.01) var soberbia: float = 0.0


func clamp_all() -> void:
	ira = clampf(ira, 0.0, 100.0)
	pereza = clampf(pereza, 0.0, 100.0)
	gula = clampf(gula, 0.0, 100.0)
	soberbia = clampf(soberbia, 0.0, 100.0)


func to_dictionary() -> Dictionary:
	return {
		"ira": ira,
		"pereza": pereza,
		"gula": gula,
		"soberbia": soberbia,
	}


func to_normalized_dictionary() -> Dictionary:
	return {
		"ira": ira / 100.0,
		"pereza": pereza / 100.0,
		"gula": gula / 100.0,
		"soberbia": soberbia / 100.0,
	}


func apply_delta(delta: Dictionary) -> void:
	ira += float(delta.get("ira", 0.0))
	pereza += float(delta.get("pereza", 0.0))
	gula += float(delta.get("gula", 0.0))
	soberbia += float(delta.get("soberbia", 0.0))
	clamp_all()
