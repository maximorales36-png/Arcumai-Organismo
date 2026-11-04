# Tests del modelo del organismo (ESPECIFICACION §3): T-06 a T-10, T-18 y T-20.
# Simulan el reloj tick a tick con deltas fijos y semilla inyectada, sin escena.
# Contrato: `extends RefCounted` con `run() -> Array[Dictionary]`.

extends RefCounted


func run() -> Array[Dictionary]:
	return [
		_t06_one_fire_per_cycle(),
		_t07_origin_period(),
		_t08_edits_no_duplicates(),
		_t09_same_anchor(),
		_t10_origin_rotation(),
		_t18_drag_constraints(),
		_t20_geometry(),
	]


# T-06: sin ediciones, cada nodo dispara una vez por ciclo en anchor + k*C + S[p].
func _t06_one_fire_per_cycle() -> Dictionary:
	var model := OrganismModel.new(1, 5, 0, _seeded_rng())
	var fires := _collect_fires(model, 0, model.anchor_tick + 3 * model.cycle_ticks)

	if fires.size() != 3 * model.n:
		return _fail("T-06", "se esperaban %d disparos y hubo %d" % [3 * model.n, fires.size()])

	for cycle in 3:
		for node in model.n:
			var expected := model.anchor_tick + cycle * model.cycle_ticks + model.node_start_of(node)
			if not fires.has([expected, node]):
				return _fail("T-06", "el nodo %d no disparó en el tick %d" % [node, expected])
	return _ok("T-06", "%d nodos x 3 ciclos, cada uno en su tick" % model.n)


# T-07: el nodo origen dispara cada C ticks exactos aunque se editen posiciones.
func _t07_origin_period() -> Dictionary:
	var model := OrganismModel.new(1, 6, 0, _seeded_rng())
	var origin_fires: Array = []
	var handler := func(_id: int, node: int, tick: int, _echo: bool) -> void:
		if node == 0:
			origin_fires.append(tick)
	model.node_fired.connect(handler)

	for tick in range(0, model.anchor_tick + 4 * model.cycle_ticks):
		# Ediciones a mitad de ciclo: mueven arranques sin tocar el período.
		if tick % 7 == 0:
			model.move_node(2, Vector2(1.0, 0.35), 0.03)
		model.on_tick(tick)
	model.node_fired.disconnect(handler)

	for cycle in 4:
		var expected := model.anchor_tick + cycle * model.cycle_ticks
		if not origin_fires.has(expected):
			return _fail("T-07", "el origen no disparó en el tick %d" % expected)
	if origin_fires.size() != 4:
		return _fail("T-07", "el origen disparó %d veces y se esperaban 4" % origin_fires.size())
	return _ok("T-07", "el origen se mantiene en cada múltiplo de C")


# T-08: con ediciones aleatorias, ningún nodo dispara dos veces en un ciclo.
func _t08_edits_no_duplicates() -> Dictionary:
	var rng := _seeded_rng()
	var model := OrganismModel.new(1, 7, 0, rng)
	var state := {"cycle": -1, "seen": {}, "duplicates": 0}
	var handler := func(_id: int, node: int, tick: int, _echo: bool) -> void:
		var cycle := (tick - model.anchor_tick) / model.cycle_ticks
		if cycle != state["cycle"]:
			state["cycle"] = cycle
			state["seen"] = {}
		if state["seen"].has(node):
			state["duplicates"] += 1
		state["seen"][node] = true
	model.node_fired.connect(handler)

	for tick in range(0, model.anchor_tick + 6 * model.cycle_ticks):
		if tick % 3 == 0:
			var direction := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
			model.move_node(rng.randi_range(0, model.n - 1), direction, 0.04)
		model.on_tick(tick)
	model.node_fired.disconnect(handler)

	if state["duplicates"] > 0:
		return _fail("T-08", "hubo %d disparos repetidos en un ciclo" % state["duplicates"])
	return _ok("T-08", "6 ciclos con ediciones: ningún nodo repite")


# T-09: dos organismos con el mismo ancla coinciden en el origen cada 60 ticks.
func _t09_same_anchor() -> Dictionary:
	var model_a := OrganismModel.new(1, 3, 0, _seeded_rng())
	var model_b := OrganismModel.new(2, 5, 0, _seeded_rng())
	if model_a.anchor_tick != model_b.anchor_tick:
		return _fail("T-09", "los anclas no coinciden")

	var fires_a := {}
	var fires_b := {}
	var handler_a := func(_id: int, node: int, tick: int, _echo: bool) -> void:
		if node == 0:
			fires_a[tick] = true
	var handler_b := func(_id: int, node: int, tick: int, _echo: bool) -> void:
		if node == 0:
			fires_b[tick] = true
	model_a.node_fired.connect(handler_a)
	model_b.node_fired.connect(handler_b)

	var span := 600
	for tick in range(model_a.anchor_tick, model_a.anchor_tick + span):
		model_a.on_tick(tick)
		model_b.on_tick(tick)
	model_a.node_fired.disconnect(handler_a)
	model_b.node_fired.disconnect(handler_b)

	for offset in span:
		var should_fire := offset % 60 == 0
		var fired := fires_a.has(model_a.anchor_tick + offset) and fires_b.has(model_a.anchor_tick + offset)
		if fired != should_fire:
			return _fail("T-09", "en el tick %d los orígenes no coinciden" % (model_a.anchor_tick + offset))
	return _ok("T-09", "n=3 y n=5 coinciden cada 60 ticks")


# T-10: cambiar el origen rota el patrón y conserva el multiconjunto de intervalos.
func _t10_origin_rotation() -> Dictionary:
	var model := OrganismModel.new(1, 6, 0, _seeded_rng())
	var first := _firing_ticks(model, model.anchor_tick, model.cycle_ticks)
	model.set_origin(3)
	var second := _firing_ticks(model, model.anchor_tick + model.cycle_ticks, model.cycle_ticks)

	if first.size() != model.n or second.size() != model.n:
		return _fail("T-10", "un ciclo no disparó todos los nodos")
	if second[0] != model.anchor_tick + model.cycle_ticks:
		return _fail("T-10", "el nuevo origen no disparó al abrir el ciclo")
	if _gaps(first, model.cycle_ticks) != _gaps(second, model.cycle_ticks):
		return _fail("T-10", "los intervalos entre disparos cambiaron")
	return _ok("T-10", "el cambio de origen conserva intervalos y período")


# T-18: el arrastre no saca nodos del radio ni los acerca de más.
func _t18_drag_constraints() -> Dictionary:
	var rng := _seeded_rng()
	var model := OrganismModel.new(1, 8, 0, rng)
	var max_radius := Config.r_max(model.n)

	for step in 2000:
		var node := rng.randi_range(0, model.n - 1)
		# Mitad de los pasos empujan hacia afuera, para forzar el límite.
		var direction: Vector2
		if step % 2 == 0:
			direction = model.nodes[node].normalized()
		else:
			direction = Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
		model.move_node(node, direction, 0.05)
		var violation := _constraint_violation(model, max_radius)
		if violation != "":
			return _fail("T-18", violation)
	return _ok("T-18", "2000 arrastres sin salir del radio ni invadir otro nodo")


# T-20: geometría orgánica, determinista y con hifas de largo positivo.
func _t20_geometry() -> Dictionary:
	for count in range(Config.N_MIN, Config.N_MAX + 1):
		for seed_value in 50:
			var model := OrganismModel.new(1, count, 0, _seeded_rng(seed_value))
			var max_radius := Config.r_max(count)

			var violation := _constraint_violation(model, max_radius)
			if violation != "":
				return _fail("T-20", "n=%d seed=%d: %s" % [count, seed_value, violation])
			for i in count:
				if model.edge_lengths[i] <= 0.0:
					return _fail("T-20", "n=%d seed=%d: la hifa %d mide 0" % [count, seed_value, i])
			if _is_regular(model):
				return _fail("T-20", "n=%d seed=%d: la geometría salió regular" % [count, seed_value])

			var twin := OrganismModel.new(1, count, 0, _seeded_rng(seed_value))
			if twin.nodes != model.nodes:
				return _fail("T-20", "n=%d seed=%d: la misma semilla dio otra geometría" % [count, seed_value])
	return _ok("T-20", "n=2..8, 50 semillas cada uno: orgánica, válida y determinista")


func _seeded_rng(value: int = 4242) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = value
	return rng


func _collect_fires(model: OrganismModel, from_tick: int, to_tick: int) -> Array:
	var fires: Array = []
	var handler := func(_id: int, node: int, tick: int, _echo: bool) -> void:
		fires.append([tick, node])
	model.node_fired.connect(handler)
	for tick in range(from_tick, to_tick):
		model.on_tick(tick)
	model.node_fired.disconnect(handler)
	return fires


func _firing_ticks(model: OrganismModel, from_tick: int, count: int) -> Array[int]:
	var ticks: Array[int] = []
	var handler := func(_id: int, _node: int, tick: int, _echo: bool) -> void:
		ticks.append(tick)
	model.node_fired.connect(handler)
	for tick in range(from_tick, from_tick + count):
		model.on_tick(tick)
	model.node_fired.disconnect(handler)
	ticks.sort()
	return ticks


# Intervalos entre disparos consecutivos, incluido el salto de fin a principio.
func _gaps(ticks: Array[int], cycle: int) -> Array[int]:
	var gaps: Array[int] = []
	for i in ticks.size() - 1:
		gaps.append(ticks[i + 1] - ticks[i])
	gaps.append(cycle - ticks[-1] + ticks[0])
	gaps.sort()
	return gaps


# Devuelve el primer problema encontrado, o "" si la geometría es válida.
# La tolerancia es de milésimas: Vector2 usa float de 32 bits y normalizar
# deja un error de ~2e-5 unidades, que no es una violación de la regla.
func _constraint_violation(model: OrganismModel, max_radius: float) -> String:
	for i in model.n:
		if model.nodes[i].length() > max_radius + 1e-3:
			return "el nodo %d se fue del radio (%.3f > %.3f)" % [i, model.nodes[i].length(), max_radius]
		for j in range(i + 1, model.n):
			if model.nodes[i].distance_to(model.nodes[j]) < Config.MIN_NODE_DIST - 1e-3:
				return "los nodos %d y %d quedaron demasiado cerca" % [i, j]
	return ""


# Un polígono regular tendría todos los huecos angulares iguales.
func _is_regular(model: OrganismModel) -> bool:
	var expected := TAU / float(model.n)
	var angles: Array[float] = []
	for position in model.nodes:
		angles.append(position.angle())
	for i in model.n:
		var next := angles[(i + 1) % model.n]
		var gap := fposmod(next - angles[i], TAU)
		if absf(gap - expected) > 0.02:
			return false
	return true


func _ok(test_id: String, detail: String) -> Dictionary:
	return {"id": test_id, "ok": true, "detail": detail}


func _fail(test_id: String, detail: String) -> Dictionary:
	return {"id": test_id, "ok": false, "detail": detail}
