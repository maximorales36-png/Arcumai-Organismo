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
# R-27/R-28: puentes dirigidos y su cola de ecos. La vista los lee para dibujar.
var bridges := BridgeNetwork.new()

var _rng: RandomNumberGenerator
var _next_id := 1
var _next_family := 0
var _tick := 0
var _spawn_charging := false
var _spawn_charge := 0.0
var _spawn_point := Vector2.ZERO
var _spawn_cooldown := 0.0
var _adjusting := false
var _spawning := false
var _spawn_index := -1
var _spawn_previous_id := -1
var _dissolving := false
var _dissolve_elapsed := 0.0
var _connecting := false


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


# Carga de B2 antes de crear el organismo (R-33). Mientras dura, la vista
# dibuja el destello en spawn_point().
func is_spawn_charging() -> bool:
	return _spawn_charging


func spawn_charge_progress() -> float:
	if not _spawn_charging:
		return 0.0
	return clampf(_spawn_charge / (Config.SPAWN_HOLD_MS / 1000.0), 0.0, 1.0)


func spawn_point() -> Vector2:
	return _spawn_point


# Enfriamiento posterior a una siembra: bloquea B2 sin cambiar la selección.
func spawn_cooldown_left() -> float:
	return _spawn_cooldown


# Modo ajuste: B2 está apretado durante el enfriamiento, así que no crea un
# organismo nuevo pero sí deja cambiarle los nodos al que quedó seleccionado.
func is_adjusting() -> bool:
	return _adjusting


# Familia que va a recibir el próximo organismo (R-25): la vista de la carga
# usa su color para anticipar el destello.
func next_family() -> int:
	return _next_family


func is_dissolving() -> bool:
	return _dissolving


func is_connecting() -> bool:
	return _connecting


# Progreso del desvanecimiento de R-34, de 0 a 1 durante DISSOLVE_HOLD_MS.
func dissolve_progress() -> float:
	if not _dissolving:
		return 0.0
	return clampf(_dissolve_elapsed / (Config.DISSOLVE_HOLD_MS / 1000.0), 0.0, 1.0)


# Agrega un organismo ya sonando. La familia rota (R-25) y la posición sale de
# 20 candidatas que maximizan la distancia mínima a los existentes (R-33).
# `at` permite usar el punto que la carga de B2 ya venía mostrando; si se omite,
# se sortea una posición nueva.
func add_organism(node_count: int, at: Vector2 = Vector2.INF) -> OrganismState:
	var organism := OrganismState.new()
	organism.id = _next_id
	_next_id += 1
	organism.family = _next_family
	_next_family = (_next_family + 1) % Config.FAMILY_COUNT
	organism.model = OrganismModel.new(organism.id, node_count, _tick, _rng)
	organism.session = MicroSession.new(organism.model)
	organism.position = at if at != Vector2.INF else pick_position(_positions(), _rng)
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
	# Durante la carga todavía no hay organismo que ajustar ni selección que
	# mover: el joystick se ignora hasta que el destello completa.
	if _spawn_charging:
		return
	if _spawning or _adjusting:
		var step := 0
		if direction.x > 0.0:
			step = 1
		elif direction.x < 0.0:
			step = -1
		if step != 0:
			if _spawning:
				_change_spawn_n(step)
			else:
				_change_selected_n(step)
		return
	if _dissolving:
		return
	if _connecting:
		return

	var next := Selection.pick(organisms[selected].position, direction, _positions())
	if next < 0:
		rejected.emit()
		return
	select(next)


# R-33: B2 mantiene una carga de SPAWN_HOLD_MS; al completarla se crea el
# organismo y sigue el ajuste de n hasta soltar. Soltar antes no crea nada.
# Después de una siembra hay un enfriamiento: durante ese tiempo B2 no crea
# nada, pero sirve para cambiarle los nodos al organismo seleccionado.
func b2_pressed() -> void:
	if _spawn_charging or _spawning:
		return
	if _dissolving:
		rejected.emit()
		return
	if _spawn_cooldown > 0.0:
		_adjusting = true
		return
	if organisms.size() >= Config.MAX_ORGANISMS:
		rejected.emit()
		return

	_start_charge()


func b2_released() -> void:
	_adjusting = false
	if _spawn_charging:
		_cancel_charge()
	_spawning = false
	_spawn_index = -1


# R-34: B4 mantiene la disolución. Durante la carga o la siembra, B4 cancela
# (R-33).
func b4_pressed() -> void:
	if _spawn_charging:
		_cancel_charge()
		return
	if _spawning:
		_cancel_spawn()
		return
	_adjusting = false
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


# R-28: B3 en Macro arma el gesto de puente; la dirección llega como cambio de
# joystick. Durante una siembra o disolución no hay puente posible.
func b3_pressed() -> void:
	if _spawn_charging or _spawning or _dissolving:
		rejected.emit()
		return
	_connecting = true


func b3_released() -> void:
	_connecting = false


# Al cambiar de vista se cortan los gestos a medias: si B3 quedó apretado, no
# debe seguir armado al volver a Macro (B3 en Micro es otra función).
func reset_gestures() -> void:
	_connecting = false
	_adjusting = false


# R-28: B3 mantenido + dirección. El vecino se elige con la misma regla que
# R-30; si el puente ya existe se quita, y si no hay lugar se rechaza.
func connect_toward(direction: Vector2) -> void:
	if _spawn_charging or _spawning or _dissolving:
		return
	var source := selected_organism()
	if source == null:
		return
	var target_index := Selection.pick(source.position, direction, _positions())
	if target_index < 0:
		rejected.emit()
		return
	var target := organisms[target_index]
	if bridges.remove(source.id, target.id):
		return
	if not bridges.can_add(source.id, target.id):
		rejected.emit()
		return
	bridges.add(make_bridge(source, target))


# R-27: la escena le pasa cada disparo. El disparo de un nodo emisor encola el
# eco del puente; los ecos no vuelven a encolar (sin contagio).
func on_node_fired(organism_id: int, node_index: int, tick: int, is_echo: bool) -> void:
	bridges.on_node_fired(organism_id, node_index, tick, is_echo)


# R-04: después de que todos los organismos evaluaron sus disparos, vencen los
# ecos. Se entregan en orden de la cola y se descartan si A o B ya no existe.
func flush_echoes(tick: int) -> void:
	var alive := {}
	for organism in organisms:
		alive[organism.id] = true
	for echo in bridges.take_due(tick, alive):
		var target := find_by_id(echo.to_id)
		if target != null:
			target.model.emit_echo(echo.to_node, tick)


# Deriva cosmética (R-38) y reloj de la disolución. El delta solo anima: no
# decide ningún disparo ni toca el modelo temporal.
func update(delta: float) -> void:
	_drift(delta)
	var started_charge := false
	if _spawn_cooldown > 0.0:
		_spawn_cooldown = maxf(0.0, _spawn_cooldown - delta)
		# Si el enfriamiento terminó con B2 apretado, la carga arranca sola.
		if _spawn_cooldown <= 0.0 and _adjusting:
			_adjusting = false
			if organisms.size() >= Config.MAX_ORGANISMS:
				rejected.emit()
			else:
				_start_charge()
				started_charge = true
	# La carga que arranca en este frame no avanza: si no, el delta del
	# enfriamiento la completaría de un golpe.
	if _spawn_charging and not started_charge:
		_advance_charge(delta)
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


# R-28: el nodo emisor es el de A más cercano al centro de B y el receptor el
# de B más cercano al centro de A, en coordenadas de mundo. Se guardan como
# índices fijos; la vista sigue la posición de esos nodos.
static func make_bridge(source: OrganismState, target: OrganismState) -> Bridge:
	return Bridge.new(
		source.id,
		closest_node_to(source, target.position),
		target.id,
		closest_node_to(target, source.position)
	)


static func closest_node_to(organism: OrganismState, point: Vector2) -> int:
	var best := 0
	var best_distance := INF
	for i in organism.model.n:
		var world_position := organism.position + organism.model.nodes[i]
		var distance := world_position.distance_squared_to(point)
		if distance < best_distance:
			best_distance = distance
			best = i
	return best


static func random_world_point(rng: RandomNumberGenerator) -> Vector2:
	var margin := Config.r_max(Config.N_MAX) * Config.MACRO_ORG_SCALE
	return Vector2(
		rng.randf_range(margin, Config.WORLD_SIZE.x - margin),
		rng.randf_range(margin, Config.WORLD_SIZE.y - margin)
	)


# Arranca la carga de siembra: se fija el punto de aparición para que el
# destello y el organismo que aparece después coincidan.
func _start_charge() -> void:
	var previous := selected_organism()
	_spawn_previous_id = previous.id if previous != null else -1
	_spawn_charging = true
	_spawn_charge = 0.0
	_spawn_point = pick_position(_positions(), _rng)


# La carga completa crea el organismo en el punto que se venía mostrando y
# arranca el enfriamiento. La selección pasa al organismo nuevo para que el
# ajuste de n con izquierda/derecha siga funcionando (R-33).
func _advance_charge(delta: float) -> void:
	_spawn_charge += delta
	if _spawn_charge < Config.SPAWN_HOLD_MS / 1000.0:
		return
	_spawn_charging = false
	_spawn_charge = 0.0
	add_organism(Config.N_SPAWN, _spawn_point)
	_spawn_cooldown = Config.SPAWN_COOLDOWN_S
	_spawning = true
	_spawn_index = organisms.size() - 1
	select(_spawn_index)


func _cancel_charge() -> void:
	_spawn_charging = false
	_spawn_charge = 0.0


func _change_spawn_n(step: int) -> void:
	_change_n(organisms[_spawn_index], step)


# Durante el enfriamiento B2 cambia los nodos del organismo que está
# seleccionado, sin crear nada nuevo.
func _change_selected_n(step: int) -> void:
	if organisms.is_empty():
		return
	_change_n(organisms[selected], step)


# Cambiar n regenera la geometría con la misma semilla, recalcula los tiempos y
# reinicia el ciclo del organismo (R-33).
func _change_n(organism: OrganismState, step: int) -> void:
	var new_n := clampi(organism.model.n + step, Config.N_MIN, Config.N_MAX)
	if new_n == organism.model.n:
		return
	organism.model.rebuild(new_n, _tick)
	organism.session.on_model_rebuilt()
	organism_rebuilt.emit(organism)


func _cancel_spawn() -> void:
	var organism := organisms[_spawn_index]
	organisms.remove_at(_spawn_index)
	bridges.remove_for(organism.id)
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
	bridges.remove_for(organism.id)
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
