# Modelo temporal de un organismo: anillo de n nodos, una hifa entre cada par
# consecutivo y un pulso que reparte un ciclo fijo de n beats (ESPECIFICACION §3).
# No conoce nodos de escena ni sonido: emite node_fired(id, nodo, tick, es_eco).
# Recibe id, cantidad de nodos, tick actual y un RNG inyectado; la geometría y
# los tiempos se recalculan solo cuando se mueve un nodo (R-13), nunca por tick.

class_name OrganismModel
extends RefCounted

signal node_fired(organism_id: int, node_index: int, tick: int, is_echo: bool)

# Tolerancia para comparar fracciones al repartir ticks (R-14, paso 4).
const EPSILON := 1e-9

var id: int
var n: int
var anchor_tick: int
var cycle_ticks: int
var origin: int = 0

# Estado público de solo lectura para vistas y tests: posiciones locales,
# largos de hifa, ticks por hifa y arranque de cada nodo en el ciclo.
var nodes: Array[Vector2] = []
var edge_lengths: Array[float] = []
var edge_ticks: Array[int] = []
var starts: Array[int] = []

var _curvatures: Array[float] = []
var _curves: Array[Curve2D] = []
var _fired: Array[bool] = []
var _rng: RandomNumberGenerator


# El ancla es el primer múltiplo de TICKS_PER_BEAT estrictamente posterior al
# tick actual (R-17): el organismo no suena antes de esa marca.
func _init(organism_id: int, node_count: int, current_tick: int, rng: RandomNumberGenerator) -> void:
	id = organism_id
	n = clampi(node_count, Config.N_MIN, Config.N_MAX)
	_rng = rng
	anchor_tick = (current_tick / Config.TICKS_PER_BEAT + 1) * Config.TICKS_PER_BEAT
	cycle_ticks = n * Config.TICKS_PER_BEAT
	_build_geometry()
	_recompute_ticks()
	_recompute_starts()


# Reparte el ciclo fijo entre las hifas en proporción a su largo (R-14).
# Es estática y pura para poder testearla sin geometría real.
static func distribute_ticks(lengths: Array[float]) -> Array[int]:
	var count := lengths.size()
	var ticks: Array[int] = []
	ticks.resize(count)
	var cycle := count * Config.TICKS_PER_BEAT

	var total_length := 0.0
	for length in lengths:
		total_length += length
	# Caso degenerado: sin largo no hay proporción posible (R-14, paso 5).
	if total_length <= 0.0:
		for i in count:
			ticks[i] = cycle / count
		return ticks

	var budget := cycle - count * Config.MIN_EDGE_TICKS
	var fractions: Array[float] = []
	var assigned_ticks := 0
	for i in count:
		var share := budget * lengths[i] / total_length
		ticks[i] = Config.MIN_EDGE_TICKS + int(floor(share))
		assigned_ticks += ticks[i]
		fractions.append(share - floor(share))

	# Las hifas con mayor parte fraccionaria reciben el tick que sobra; en
	# empate gana el menor índice, y por eso se recorre en orden ascendente
	# sin reemplazar cuando la diferencia es indistinguible.
	var remainder := cycle - assigned_ticks
	var already_extra: Array[bool] = []
	already_extra.resize(count)
	already_extra.fill(false)
	for extra in remainder:
		var best := -1
		for i in count:
			if already_extra[i]:
				continue
			if best == -1 or fractions[i] > fractions[best] + EPSILON:
				best = i
		if best >= 0:
			ticks[best] += 1
			already_extra[best] = true

	return ticks


# Geometría inicial orgánica (R-20): anillo con jitter angular y radial.
# Con estos rangos la distancia mínima queda garantizada por construcción
# (peor caso n=8: ~36 unidades contra MIN_NODE_DIST=18).
static func generate_positions(node_count: int, rng: RandomNumberGenerator) -> Array[Vector2]:
	var count := clampi(node_count, Config.N_MIN, Config.N_MAX)
	var max_radius := Config.r_max(count)
	var base_radius := max_radius * Config.NODE_RING_RATIO
	var positions: Array[Vector2] = []
	for i in count:
		var base_angle := TAU * float(i) / float(count)
		var jitter := rng.randf_range(Config.NODE_ANGLE_JITTER_MIN, Config.NODE_ANGLE_JITTER_MAX)
		# Signos alternados: garantiza que no queden ángulos iguales (R-20) en
		# vez de confiar en que dos jitters al azar no se cancelen. La magnitud
		# sigue siendo aleatoria.
		if i % 2 == 1:
			jitter = -jitter
		var radial_jitter := rng.randf_range(-1.0, 1.0) * Config.NODE_RADIAL_JITTER * max_radius
		positions.append(Vector2.from_angle(base_angle + jitter) * (base_radius + radial_jitter))
	return positions


# Avanza un tick global. Los disparos siguen R-18 al pie de la letra.
func on_tick(tick: int) -> void:
	if tick < anchor_tick:
		return
	var phi := (tick - anchor_tick) % cycle_ticks
	if phi == 0:
		for i in n:
			_fired[i] = false
	for p in n:
		var node_index := (origin + p) % n
		if starts[p] == phi and not _fired[node_index]:
			_fired[node_index] = true
			node_fired.emit(id, node_index, tick, false)


# Cambia el nodo origen (R-19): solo se reordena S, no los ticks por hifa,
# y se conservan los disparos ya hechos en el ciclo.
func set_origin(node_index: int) -> void:
	origin = posmod(node_index, n)
	_recompute_starts()


# Arrastre de un nodo (R-22). La dirección llega como vector de joystick.
# Si el movimiento completo viola la distancia mínima, se anula por eje.
func move_node(node_index: int, direction: Vector2, delta: float) -> void:
	var index := posmod(node_index, n)
	var step := direction * Config.DRAG_SPEED * delta
	if step == Vector2.ZERO:
		return

	var current := nodes[index]
	var full := _clamp_to_radius(current + step)
	if _respects_min_distance(index, full):
		_apply_move(index, full)
		return

	var moved := current
	var on_x := _clamp_to_radius(Vector2(current.x + step.x, current.y))
	if _respects_min_distance(index, on_x):
		moved = on_x
	var on_y := _clamp_to_radius(Vector2(moved.x, moved.y + step.y))
	if _respects_min_distance(index, on_y):
		moved = on_y
	if moved != current:
		_apply_move(index, moved)


# Arranque del nodo i dentro del ciclo (R-16).
func node_start_of(node_index: int) -> int:
	return starts[posmod(node_index - origin, n)]


# Fase del organismo en un tick, o -1 antes del ancla (R-17).
func phase_at(tick: int) -> int:
	if tick < anchor_tick:
		return -1
	return (tick - anchor_tick) % cycle_ticks


# Curva de la hifa i, para que la vista la dibuje sin recalcular nada (R-13).
func edge_curve(i: int) -> Curve2D:
	return _curves[posmod(i, n)]


func _build_geometry() -> void:
	nodes = generate_positions(n, _rng)
	edge_lengths.resize(n)
	_curves.resize(n)
	_curvatures.clear()

	for i in n:
		var magnitude: float
		if n == 2:
			# R-12: en n=2 las hifas se curvan a lados opuestos, mínimo 0.25.
			magnitude = _rng.randf_range(Config.EDGE_CURVATURE_N2_MIN, Config.EDGE_CURVATURE_N2_MAX)
			if i == 1:
				magnitude = -_curvatures[0]
		else:
			magnitude = _rng.randf_range(Config.EDGE_CURVATURE_MIN, Config.EDGE_CURVATURE_MAX)
			if _rng.randf() < 0.5:
				magnitude = -magnitude
		_curvatures.append(magnitude)

	for i in n:
		_rebuild_edge(i)

	_fired.resize(n)
	_fired.fill(false)


# Recalcula la curva y el largo de una hifa. Se llama solo cuando cambia uno
# de sus nodos: el largo es la fuente del reparto de tiempo (R-13).
func _rebuild_edge(i: int) -> void:
	var a := nodes[i]
	var b := nodes[(i + 1) % n]
	var chord := a.distance_to(b)
	if chord <= 0.0:
		edge_lengths[i] = 0.0
		_curves[i] = Curve2D.new()
		return

	var direction := (b - a) / chord
	var normal := Vector2(-direction.y, direction.x)
	var offset := normal * chord * _curvatures[i]
	# Bézier cúbica: los dos manejadores se desplazan al mismo lado, así la
	# hifa queda como un arco suave y no como una polilínea.
	var control_a := a + direction * chord / 3.0 + offset
	var control_b := b - direction * chord / 3.0 + offset

	var curve := Curve2D.new()
	curve.add_point(a, Vector2.ZERO, control_a - a)
	curve.add_point(b, control_b - b, Vector2.ZERO)
	_curves[i] = curve
	edge_lengths[i] = curve.get_baked_length()


func _apply_move(index: int, position: Vector2) -> void:
	nodes[index] = position
	# Solo cambian las hifas que tocan el nodo movido.
	_rebuild_edge(posmod(index - 1, n))
	_rebuild_edge(index)
	_recompute_ticks()
	_recompute_starts()


func _recompute_ticks() -> void:
	edge_ticks = distribute_ticks(edge_lengths)


func _recompute_starts() -> void:
	starts.resize(n)
	var accumulated := 0
	for p in n:
		starts[p] = accumulated
		accumulated += edge_ticks[(origin + p) % n]


func _clamp_to_radius(position: Vector2) -> Vector2:
	var limit := Config.r_max(n)
	if position.length() > limit:
		return position.normalized() * limit
	return position


func _respects_min_distance(index: int, position: Vector2) -> bool:
	var limit_squared := Config.MIN_NODE_DIST * Config.MIN_NODE_DIST
	for j in n:
		if j == index:
			continue
		if position.distance_squared_to(nodes[j]) < limit_squared:
			return false
	return true
