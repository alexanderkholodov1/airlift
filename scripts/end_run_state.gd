extends RefCounted
class_name EndRunState

static var ending_name: String = ""
static var ending_mode: String = ""
static var statistics: Dictionary = {}


static func set_result(name: String, mode: String, stats: Dictionary) -> void:
	ending_name = name
	ending_mode = mode
	statistics = stats.duplicate(true)


static func clear() -> void:
	ending_name = ""
	ending_mode = ""
	statistics.clear()
