extends Node2D

var _camera: Camera2D = null
var _particles: Array[GPUParticles2D] = []


func _ready() -> void:
	_camera = get_node_or_null("CharacterBody2D/Camera2D")

	for pname in ["GPUParticles2D2_Back1", "GPUParticles2D2_Back2",
				  "GPUParticles2D2_Front1", "GPUParticles2D2_Front2"]:
		var p: GPUParticles2D = get_node_or_null(pname)
		if p != null:
			_particles.append(p)


func _process(_delta: float) -> void:
	if _camera == null or _particles.is_empty():
		return
	var cam_pos := _camera.global_position
	for p in _particles:
		p.global_position = cam_pos
