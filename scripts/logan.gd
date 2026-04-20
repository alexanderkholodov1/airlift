extends CharacterBody2D

signal health_changed(current_health: int, max_health: int)
signal player_died

const DEATH_SCREEN_SCENE := preload("res://scenes/ui/death_screen.tscn")

const MAX_HEALTH: int = 5
const DAMAGE_INVULNERABILITY_TIME: float = 1.0

var current_health: int = MAX_HEALTH
var is_invulnerable: bool = false
var is_dead: bool = false

# ==========================================
# VARIABLES DE MOVIMIENTO Y ANIMACIÓN
# ==========================================
@export var anim: AnimatedSprite2D
var speed: float = 170.0	
@export var slope_max_angle_degrees: float = 50.0
@export var slope_snap_length: float = 12.0
@export var step_assist_max_height: float = 40.0
@export var step_assist_probe_distance: float = 14.0
@export var step_assist_step_size: float = 4.0

var puede_trepar: bool = false
var trepando: bool = false
var climb_speed: float = 120.0

# ==========================================
# VARIABLES DE INTERACCIÓN (OBJETOS)
# ==========================================
var objeto_en_mano = null
@onready var zona_deteccion = $Area2D # El área de alcance de tus brazos
@onready var punto_agarre = $Marker2D # El punto donde sostendrá la caja


func _ready() -> void:
	# Permite caminar por pendientes tipo rampa (~45°) sin escalar paredes verticales.
	floor_max_angle = deg_to_rad(slope_max_angle_degrees)
	floor_snap_length = slope_snap_length

# ==========================================
# FÍSICAS Y MOVIMIENTO CONSTANTE
# ==========================================
func _physics_process(delta):
	
	# 1. VERIFICAR SI ESTAMOS TREPANDO
	# Nos enganchamos a la liana si podemos trepar y mantenemos el click derecho
	if puede_trepar and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		trepando = true
		
	# Si salimos del área de la liana, dejamos de trepar
	if not puede_trepar:
		trepando = false

	# ==========================================
	# ESTADO: TREPANDO (Sin gravedad, sube con arrastre de click derecho)
	# ==========================================
	if trepando:
		velocity.x = 0 # No nos movemos hacia los lados en la liana
		
		# Leer posición vertical del mouse MIENTRAS mantenemos click derecho
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			var direccion_mouse_y = get_local_mouse_position().y
			
			if direccion_mouse_y < -10: # Mouse arriba del personaje
				velocity.y = -climb_speed
			elif direccion_mouse_y > 10: # Mouse abajo del personaje
				velocity.y = climb_speed
			else:
				velocity.y = 0
		else:
			# Si soltamos el click derecho, nos quedamos quietos colgando
			velocity.y = 0
			
		# MECÁNICA DE SALIDA: Nos soltamos de la liana con el click izquierdo (caminar)
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			trepando = false
			if velocity.y < 0:
				velocity.y = 0

	# ==========================================
	# ESTADO: NORMAL (Gravedad + Caminar con click izquierdo)
	# ==========================================
	else:
		# APLICAR GRAVEDAD
		if not is_on_floor():
			velocity += get_gravity() * delta
			
		# Caminar arrastrando el mouse con el click izquierdo
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			var direccion_mouse = get_local_mouse_position().x
			
			if direccion_mouse > 10:
				velocity.x = speed
				anim.flip_h = true # Mirar a la derecha
			elif direccion_mouse < -10:
				velocity.x = -speed
				anim.flip_h = false  # Mirar a la izquierda
			else:
				velocity.x = 0
		else:
			velocity.x = 0

		_try_step_slope_assist()
			
	# 2. APLICAR EL MOVIMIENTO FINAL
	move_and_slide()
	
	# 3. CONTROL DE ANIMACIONES
	if trepando:
		pass
	elif velocity.x != 0:
		anim.play("Run")
	else:
		anim.play("IDLE")

# ==========================================
# DETECCIÓN DE CLICKS 
# ==========================================
func _input(event):
	# Detectar Click Derecho PARA OBJETOS
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			# IMPORTANTE: Solo agarramos o lanzamos cosas si NO estamos en una liana
			if not puede_trepar:
				if objeto_en_mano == null:
					intentar_agarrar_objeto()
				else:
					lanzar_objeto()

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if _try_interact_with_arches(event.button_index):
				get_viewport().set_input_as_handled()

# ==========================================
# FUNCIONES DE OBJETOS
# ==========================================
func intentar_agarrar_objeto():
	var cuerpos = zona_deteccion.get_overlapping_bodies()
	
	for cuerpo in cuerpos:
		if cuerpo.has_method("ser_agarrado"):
			objeto_en_mano = cuerpo
			objeto_en_mano.ser_agarrado(self) 
			break

	if objeto_en_mano == null:
		var areas = zona_deteccion.get_overlapping_areas()
		for area in areas:
			if area.has_method("ser_agarrado"):
				objeto_en_mano = area
				objeto_en_mano.ser_agarrado(self)
				break

	if objeto_en_mano != null:
		return

	# Fallback por proximidad: permite agarrar ladrillos en reposo sin colisión física activa.
	var scene_root = get_tree().current_scene
	if scene_root == null:
		return

	var radio = 120.0
	var candidato = null
	var mejor_dist = radio
	var stack: Array = [scene_root]

	while not stack.is_empty():
		var node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)

		if node is Node2D and node.has_method("ser_agarrado"):
			var d = global_position.distance_to(node.global_position)
			if d <= mejor_dist:
				candidato = node
				mejor_dist = d

	if candidato != null:
		objeto_en_mano = candidato
		objeto_en_mano.ser_agarrado(self)

func lanzar_objeto():
	if objeto_en_mano:
		var direccion = (get_global_mouse_position() - global_position).normalized()
		var fuerza_lanzamiento = 700.0
		
		objeto_en_mano.ser_soltado(direccion * fuerza_lanzamiento)
		objeto_en_mano = null


func _try_interact_with_arches(wheel_button: int) -> bool:
	var root = get_tree().current_scene
	if root == null:
		return false

	var arches: Array = []
	var stack: Array = [root]

	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)

		if node.has_method("try_interact_with_player"):
			var d = global_position.distance_to(node.global_position)
			arches.append({"node": node, "dist": d})

	if arches.is_empty():
		return false

	arches.sort_custom(func(a, b): return a["dist"] < b["dist"])

	for entry in arches:
		var arch: Node = entry["node"]
		if arch.call("try_interact_with_player", self, wheel_button):
			return true

	return false


func _on_liana_detector_body_entered(body: Node2D) -> void:
	puede_trepar = true


func _on_liana_detector_body_exited(body: Node2D) -> void:
	puede_trepar = false
	trepando = false # Nos soltamos obligatoriamente


func receive_damage(damage: int) -> void:
	if is_dead or is_invulnerable:
		return

	current_health = max(0, current_health - max(1, damage))
	emit_signal("health_changed", current_health, MAX_HEALTH)

	if current_health <= 0:
		_die()
		return

	is_invulnerable = true
	if anim != null:
		anim.modulate = Color(1.0, 0.6, 0.6, 1.0)

	await get_tree().create_timer(DAMAGE_INVULNERABILITY_TIME).timeout
	if is_dead:
		return

	is_invulnerable = false
	if anim != null:
		anim.modulate = Color(1, 1, 1, 1)


func _die() -> void:
	if is_dead:
		return

	is_dead = true
	emit_signal("player_died")

	set_physics_process(false)
	set_process_input(false)
	velocity = Vector2.ZERO

	if anim != null:
		var tween := create_tween()
		tween.tween_property(anim, "modulate:a", 0.0, 0.45)
		await tween.finished

	_show_death_screen()


func _show_death_screen() -> void:
	var tree := get_tree()
	if tree == null:
		return

	var root := tree.current_scene
	if root == null:
		return

	var death_ui := DEATH_SCREEN_SCENE.instantiate() as CanvasLayer
	if death_ui == null:
		tree.reload_current_scene()
		return

	if death_ui.has_method("set_death_context"):
		death_ui.call("set_death_context", "salud agotada", root.name)

	if death_ui.has_signal("retry_requested"):
		death_ui.connect("retry_requested", Callable(self, "_on_death_retry_requested"), CONNECT_ONE_SHOT)

	if death_ui.has_signal("exit_requested"):
		death_ui.connect("exit_requested", Callable(self, "_on_death_retry_requested"), CONNECT_ONE_SHOT)

	root.add_child(death_ui)


func _on_death_retry_requested() -> void:
	get_tree().reload_current_scene()


func _try_step_slope_assist() -> void:
	if absf(velocity.x) < 0.1:
		return

	if step_assist_max_height <= 0.0 or step_assist_probe_distance <= 0.0 or step_assist_step_size <= 0.0:
		return

	var dir := signf(velocity.x)
	var horizontal_probe := Vector2(dir * step_assist_probe_distance, 0.0)

	# Solo intentamos asistencia si algo bloquea el avance horizontal inmediato.
	if not test_move(global_transform, horizontal_probe):
		return

	# Sube en incrementos pequeños hasta encontrar altura libre para seguir avanzando.
	# Esto permite trepar rampas triangulares, pero limita escalada por altura máxima.
	var climbed := 0.0
	while climbed < step_assist_max_height:
		climbed += step_assist_step_size
		var raised_xform := global_transform.translated(Vector2(0.0, -climbed))
		if test_move(raised_xform, horizontal_probe):
			continue

		global_position.y -= climbed
		return
