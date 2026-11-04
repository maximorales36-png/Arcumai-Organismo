# Reglas del mundo Macro (R-30, R-31, R-33, R-34, R-38): mantiene la lista de
# organismos, la selección por vecindad, la siembra con n en vivo, la disolución
# y la deriva cosmética. No conoce escenas ni audio: emite señales para que la
# vista y el sonido se actualicen. Recibe el RNG de la sesión y el tick actual
# por set_tick().

class_name World
extends RefCounted

signal organism_added(organism: OrganismState)
signal organism_removed(organism: OrganismState)
signal organism_rebuilt(organism: OrganismState)
signal selection_changed(organism: OrganismState)
signal rejected

# La deriva no tiene tiempos fijados por la especificación: estos son visuales.
const DRIFT_RETARGET_MIN_S := 2.0
const DRIFT_RETARGET_MAX_S := 5.0
const DRIFT_MIN_SPEED_RATIO := 0.3
const SPAWN_CANDIDATES := 20

var organisms: Array[OrganismState] = []
var selected: int = 0

var _rng: RandomNumberGenerator
var _next_id := 1
var _next_family := 0
var _tick := 0
var _spawning := false
var _spawn_index := -1
var _spawn_previous_id := -1
var _dissolving := false
var _dissolve_elapsed := 0.0


func _init(rng: RandomNumberGenerator) -> void:
	_rng = rng


# El reloj es la única fuente de tiempo musical; el mundo solo necesita el tick
# para calcular el ancla de un organismo nuevo o regenerado (R-17, R-33).
func set_tick(tick: int) -> void:
	_tick = tick


func count() -> int:
	return organisms.size()


func selected_organism() -> OrganismState:
	if selected < 0 or selected >= organisms.size():
		return null
	return organisms[selected]


func find_by_id(organism_id: int) -> OrganismState:
	for organism in organisms:
		if organism.id == organism_id:
			return organism
	return null


func index_of_id(organism_id: int) -> int:
	for i in organisms.size():
		if organisms[i].id == organism_id:
			return i
	return -1


func is_spawning() -> bool:
	return _spawning


func is_dissolving() -> bool:
	return _dissolving


# Progreso del desvanecimiento de R-34, de 0 a 1 durante DISSOLVE_HOLD_MS.
func dissolve_progress() -> float:
	if not _dissolving:
		return 0.0
	return clampf(_dissolve_elapsed / (Config.DISSOLVE_HOLD_MS / 1000.0), 0.0, 1.0)


# Agrega un organismo ya sonando. La familia rota (R-25) y la posición sale de
# 20 candidatas que maximizan la distancia mínima a los existentes (R-33).
func add_organism(node_count: int) -> OrganismState:
	var organism := OrganismState.new()
	organism.id = _next_id
	_next_id += 1
	organism.family = _next_family
	_next_family = (_next_family + 1) % Config.FAMILY_COUNT
	organism.model = OrganismModel.new(organism.id, node_count, _tick, _rng)
	organism.session = MicroSession.new(organism.model)
	organism.position = pick_position(_positions(), _rng)
	_retarget_drift(organism)
	organisms.append(organism)
	organism_added.emit(organism)
	return organism


func select(index: int) -> void:
	if organisms.is_empty():
		return
	selected = clampi(index, 0, organisms.size() - 1)
	selection_changed.emit(organisms[selected])


# R-30: un empuje elige el organismo vecino en esa dirección. Durante la
# siembra el joystick izquierda/derecha cambia n en pasos de 1 (R-33).
func nav_step(direction: Vector2) -> void:
	if _spawning:
		var step := 0
		if direction.x > 0.0:
			step = 1
		elif direction.x < 0.0:
			step = -1
		if step != 0:
			_change_spawn_n(step)
		return
	if _dissolving:
		return

	var next := Selection.pick(organisms[selected].position, direction, _positions())
	if next < 0:
		rejected.emit()
		return
	select(next)


# R-33: B2 crea el organismo en el acto y ya suena. Si no hay lugar, rechazo.
func b2_pressed() -> void:
	if _spawning or _dissolving:
		return
	if organisms.size() >= Config.MAX_ORGANISMS:
		rejected.emit()
		return

	var previous := selected_organism()
	_spawn_previous_id = previous.id if previous != null else -1
	add_organism(Config.N_DEFAULT)
	_spawning = true
	_spawn_index = organisms.size() - 1
	select(_spawn_index)


func b2_released() -> void:
	_spawning = false
	_spawn_index = -1


# R-34: B4 mantiene la disolución. Durante la siembra, B4 cancela (R-33).
func b4_pressed() -> void:
	if _spawning:
		_cancel_spawn()
		return
	if _dissolving:
		return
	if organisms.size() <= 1:
		rejected.emit()
		return
	_dissolving = true
	_dissolve_elapsed = 0.0


func b4_released() -> void:
	if _dissolving:
		_dissolving = false
		_dissolve_elapsed = 0.0


# B3 en Macro crea puentes, que son M8: por ahora es una acción imposible.
func b3_pressed() -> void:
	rejected.emit()


# Deriva cosmética (R-38) y reloj de la disolución. El delta solo anima: no
# decide ningún disparo ni toca el modelo temporal.
func update(delta: float) -> void:
	_drift(delta)
	if not _dissolving:
		return
	_dissolve_elapsed += delta
	if _dissolve_elapsed >= Config.DISSOLVE_HOLD_MS / 1000.0:
		_remove_selected()


# R-33: entre 20 candidatas al azar dentro del mundo, la que maximiza la
# distancia mínima a los organismos existentes. Sin candidatas mejores, queda
# la mejor encontrada (la especificación no define un rechazo por posición).
static func pick_position(existing: Array[Vector2], rng: RandomNumberGenerator) -> Vector2:
	var best := Vector2.ZERO
	var best_distance := -1.0
	for i in SPAWN_CANDIDATES:
		var candidate := random_world_point(rng)
		var min_distance := INF
		for position in existing:
			min_distance = minf(min_distance, candidate.distance_to(position))
		if min_distance > best_distance:
			best_distance = min_distance
			best = candidate
	return best


static func random_world_point(rng: RandomNumberGenerator) -> Vector2:
	var margin := Config.r_max(Config.N_MAX) * Config.MACRO_ORG_SCALE
	return Vector2(
		rng.randf_range(margin, Config.WORLD_SIZE.x - margin),
		rng.randf_range(margin, Config.WORLD_SIZE.y - margin)
	)


func _change_spawn_n(step: int) -> void:
	var organism := organisms[_spawn_index]
	var new_n := clampi(organism.model.n + step, Config.N_MIN, Config.N_MAX)
	if new_n == organism.model.n:
		return
	organism.model.rebuild(new_n, _tick)
	organism.session.on_model_rebuilt()
	organism_rebuilt.emit(organism)


func _cancel_spawn() -> void:
	var organism := organisms[_spawn_index]
	organisms.remove_at(_spawn_index)
	_spawning = false
	_spawn_index = -1
	var previous := index_of_id(_spawn_previous_id)
	selected = previous if previous >= 0 else 0
	organism_removed.emit(organism)
	if not organisms.is_empty():
		selection_changed.emit(organisms[selected])


func _remove_selected() -> void:
	var organism := organisms[selected]
	organisms.remove_at(selected)
	_dissolving = false
	_dissolve_elapsed = 0.0
	if selected >= organisms.size():
		selected = 0
	organism_removed.emit(organism)
	selection_changed.emit(organisms[selected])


func _drift(delta: float) -> void:
	for organism in organisms:
		organism.drift_timer -= delta
		if organism.drift_timer <= 0.0:
			_retarget_drift(organism)
		if organism.drift_velocity == Vector2.ZERO:
			continue
		var proposed := _clamp_to_world(organism.position + organism.drift_velocity * delta, organism.model.n)
		if _far_enough(organism, proposed):
			organism.position = proposed
		else:
			# Si el paso choca con otro organismo, se busca otra dirección en
			# vez de quedarse trabado contra el vecino.
			_retarget_drift(organism)


func _retarget_drift(organism: OrganismState) -> void:
	var angle := _rng.randf_range(0.0, TAU)
	var speed := _rng.randf_range(DRIFT_MIN_SPEED_RATIO, 1.0) * Config.DRIFT_MAX_SPEED
	organism.drift_velocity = Vector2.from_angle(angle) * speed
	organism.drift_timer = _rng.randf_range(DRIFT_RETARGET_MIN_S, DRIFT_RETARGET_MAX_S)


func _far_enough(organism: OrganismState, position: Vector2) -> bool:
	for other in organisms:
		if other == organism:
			continue
		if position.distance_to(other.position) < Config.MIN_ORG_DISTANCE:
			return false
	return true


func _clamp_to_world(position: Vector2, n: int) -> Vector2:
	var margin := Config.r_max(n) * Config.MACRO_ORG_SCALE
	return Vector2(
		clampf(position.x, margin, Config.WORLD_SIZE.x - margin),
		clampf(position.y, margin, Config.WORLD_SIZE.y - margin)
	)


func _positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for organism in organisms:
		positions.append(organism.position)
	return positions
