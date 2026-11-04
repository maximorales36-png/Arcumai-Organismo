# Test de la posición derivada del pulso (R-21): T-19.
# Comprueba que `pulse_at` coincide con `S`, `t` y `phi` en todo el ciclo,
# incluida la fracción de tick, y que el instante en que el pulso entra en una
# hifa es exactamente el tick en que dispara su nodo.
# Contrato: `extends RefCounted` con `run() -> Array[Dictionary]`.

extends RefCounted

const EPSILON := 1e-6
const SPATIAL_EPSILON := 1e-3
const FRACTIONS := [0.0, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99]


func run() -> Array[Dictionary]:
	return [_t19()]


func _t19() -> Dictionary:
	var problem := _clock_fraction()
	if problem != "":
		return _fail(problem)

	for node_count in range(Config.N_MIN, Config.N_MAX + 1):
		for seed_value in 5:
			var model := OrganismModel.new(1, node_count, 0, _seeded_rng(seed_value))
			problem = _check_model(model)
			if problem != "":
				return _fail("n=%d seed=%d: %s" % [node_count, seed_value, problem])
	return _ok("T-19", "la posición del pulso sigue S, t y phi en todo el ciclo, con fracción de tick")


# La fracción que la vista suma a phi sale del reloj, no de un delta aparte.
func _clock_fraction() -> String:
	var clock := Clock.new()
	clock.advance(Config.TICK_SEC * 0.4)
	if absf(clock.fraction() - 0.4) > EPSILON:
		return "a 0,4 ticks el reloj informa fracción %.4f" % clock.fraction()
	clock.advance(Config.TICK_SEC * 0.7)
	if clock.tick != 1:
		return "tras 1,1 ticks el reloj quedó en el tick %d" % clock.tick
	if absf(clock.fraction() - 0.1) > EPSILON:
		return "tras 1,1 ticks la fracción es %.4f y debería ser 0,1" % clock.fraction()
	return ""


func _check_model(model: OrganismModel) -> String:
	if model.pulse_at(-1.0)["active"]:
		return "hay pulso antes del ancla"

	var problem := _starts_and_fractions(model)
	if problem != "":
		return problem
	problem = _boundaries(model)
	if problem != "":
		return problem
	problem = _fires_align(model)
	if problem != "":
		return problem

	# El origen y las ediciones cambian S y t: la posición tiene que seguirlos.
	model.set_origin(2)
	problem = _starts_and_fractions(model)
	if problem != "":
		return "tras cambiar el origen: " + problem
	model.move_node(1, Vector2(1.0, 0.3), 0.05)
	problem = _starts_and_fractions(model)
	if problem != "":
		return "tras mover un nodo: " + problem
	return ""


# En el arranque S[p] el pulso entra en la hifa (origin+p) con u = 0, y avanza
# linealmente hasta u = 1 justo cuando vence esa hifa.
func _starts_and_fractions(model: OrganismModel) -> String:
	for p in model.n:
		var edge := (model.origin + p) % model.n
		var ticks := model.edge_ticks[edge]
		if ticks <= 0:
			return "la hifa %d no tiene ticks" % edge

		var start_pulse := model.pulse_at(float(model.starts[p]))
		if not start_pulse["active"] or start_pulse["edge"] != edge:
			return "en S[%d]=%d el pulso no está en la hifa %d" % [p, model.starts[p], edge]
		if absf(start_pulse["u"]) > EPSILON:
			return "en S[%d] el progreso es %.4f y debería ser 0" % [p, start_pulse["u"]]

		for fraction in FRACTIONS:
			var fraction_value := float(fraction)
			var phi_f := float(model.starts[p]) + fraction_value * float(ticks)
			var pulse := model.pulse_at(phi_f)
			if not pulse["active"]:
				return "el pulso no está activo en phi_f=%.3f" % phi_f
			if pulse["edge"] != edge:
				return "en phi_f=%.3f el pulso está en la hifa %d y debería estar en la %d" % [phi_f, pulse["edge"], edge]
			if absf(pulse["u"] - fraction) > EPSILON:
				return "en phi_f=%.3f el progreso es %.4f y debería ser %.4f" % [phi_f, pulse["u"], fraction]
	return ""


# La cabeza salta de una hifa a la siguiente sin salto espacial: el final de
# una hifa y el principio de la siguiente son el mismo nodo.
func _boundaries(model: OrganismModel) -> String:
	for p in model.n:
		var edge := (model.origin + p) % model.n
		var next_edge := (edge + 1) % model.n
		var node_point := model.nodes[(edge + 1) % model.n]
		var end_point := model.edge_curve(edge).sample_baked(model.edge_lengths[edge])
		var start_point := model.edge_curve(next_edge).sample_baked(0.0)
		if end_point.distance_to(node_point) > SPATIAL_EPSILON:
			return "el final de la hifa %d no llega al nodo" % edge
		if start_point.distance_to(node_point) > SPATIAL_EPSILON:
			return "el principio de la hifa %d no sale del nodo" % next_edge

		# Justo al vencer la hifa, el pulso ya está al principio de la siguiente.
		var boundary := model.pulse_at(float(model.starts[p] + model.edge_ticks[edge]))
		if not boundary["active"] or boundary["edge"] != next_edge or absf(boundary["u"]) > EPSILON:
			return "al vencer la hifa %d el pulso no arranca la %d" % [edge, next_edge]

	# El fin del ciclo es el principio del siguiente.
	var wrapped := model.pulse_at(float(model.cycle_ticks))
	var at_zero := model.pulse_at(0.0)
	if wrapped["edge"] != at_zero["edge"] or absf(wrapped["u"] - at_zero["u"]) > EPSILON:
		return "el fin del ciclo no coincide con su principio"
	return ""


# Cuando un nodo dispara, el pulso está saliendo de él (u = 0 de su hifa).
func _fires_align(model: OrganismModel) -> String:
	var fires: Array = []
	var handler := func(_id: int, node: int, tick: int, _echo: bool) -> void:
		fires.append([node, tick])
	model.node_fired.connect(handler)
	for tick in range(model.anchor_tick, model.anchor_tick + model.cycle_ticks):
		model.on_tick(tick)
	model.node_fired.disconnect(handler)

	if fires.size() != model.n:
		return "en un ciclo dispararon %d nodos y son %d" % [fires.size(), model.n]
	for fire in fires:
		var pulse := model.pulse_at(float(fire[1] - model.anchor_tick))
		if not pulse["active"] or pulse["edge"] != fire[0]:
			return "el nodo %d disparó en el tick %d y el pulso no está en su hifa" % [fire[0], fire[1]]
		if absf(pulse["u"]) > EPSILON:
			return "el nodo %d disparó con el pulso en u=%.4f" % [fire[0], pulse["u"]]
	return ""


func _seeded_rng(value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = value
	return rng


func _ok(test_id: String, detail: String) -> Dictionary:
	return {"id": test_id, "ok": true, "detail": detail}


func _fail(detail: String) -> Dictionary:
	return {"id": "T-19", "ok": false, "detail": detail}
