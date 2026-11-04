# Test de la siembra en Macro (R-33): T-17.
# Verifica que n se recorta a [N_MIN, N_MAX] al cambiarlo en vivo, que la
# posición elegida respeta MIN_ORG_DISTANCE cuando hay lugar y que el tope de
# organismos produce rechazo. Usa semillas fijas e inyectadas.
# Contrato: `extends RefCounted` con `run() -> Array[Dictionary]`.

extends RefCounted


func run() -> Array[Dictionary]:
	return [_t17()]


func _t17() -> Dictionary:
	var problem := _clamp_n()
	if problem != "":
		return _fail(problem)
	problem = _position_respects_distance()
	if problem != "":
		return _fail(problem)
	problem = _max_organisms_rejects()
	if problem != "":
		return _fail(problem)
	return _ok("T-17", "n recortado a [2, 8], posición con MIN_ORG_DISTANCE y tope de organismos")


func _make_world(seed_value: int) -> World:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return World.new(rng)


# R-33: izq/der cambia n en pasos de 1 y se recorta en los extremos.
func _clamp_n() -> String:
	var world := _make_world(100)
	world.add_organism(Config.N_DEFAULT)
	world.select(0)
	world.b2_pressed()
	if world.count() != 2:
		return "la siembra no agregó un organismo"

	for i in 20:
		world.nav_step(Vector2.LEFT)
	var organism := world.selected_organism()
	if organism == null:
		return "la siembra no dejó un organismo seleccionado"
	if organism.model.n != Config.N_MIN:
		return "n no se recortó a N_MIN: quedó en %d" % organism.model.n
	if organism.model.cycle_ticks != Config.N_MIN * Config.TICKS_PER_BEAT:
		return "el ciclo no se recalculó al cambiar n"

	for i in 20:
		world.nav_step(Vector2.RIGHT)
	organism = world.selected_organism()
	if organism.model.n != Config.N_MAX:
		return "n no se recortó a N_MAX: quedó en %d" % organism.model.n
	if organism.model.cycle_ticks != Config.N_MAX * Config.TICKS_PER_BEAT:
		return "el ciclo no se recalculó al cambiar n"

	world.b2_released()
	if world.is_spawning():
		return "soltar B2 no confirmó la siembra"
	return ""


# R-33: entre 20 candidatas se elige la que maximiza la distancia mínima; con
# lugar de sobra, dos organismos quedan a MIN_ORG_DISTANCE o más.
func _position_respects_distance() -> String:
	for seed_value in range(200, 220):
		var world := _make_world(seed_value)
		world.add_organism(Config.N_DEFAULT)
		world.add_organism(Config.N_DEFAULT)
		var first := world.organisms[0]
		var second := world.organisms[1]
		var distance := first.position.distance_to(second.position)
		if distance < Config.MIN_ORG_DISTANCE - 1e-3:
			return "semilla %d: dos organismos a %.1f (< %.1f)" % [
				seed_value, distance, Config.MIN_ORG_DISTANCE
			]
	return ""


# R-33/R-31: con MAX_ORGANISMS ya sembrados, B2 da rechazo y no agrega nada.
func _max_organisms_rejects() -> String:
	var world := _make_world(300)
	for i in Config.MAX_ORGANISMS:
		world.add_organism(Config.N_DEFAULT)

	var rejected := [false]
	var handler := func() -> void:
		rejected[0] = true
	world.rejected.connect(handler)
	world.b2_pressed()
	world.rejected.disconnect(handler)

	if not rejected[0]:
		return "el tope de organismos no produjo rechazo"
	if world.count() != Config.MAX_ORGANISMS:
		return "el tope agregó un organismo igual"
	return ""


func _ok(test_id: String, detail: String) -> Dictionary:
	return {"id": test_id, "ok": true, "detail": detail}


func _fail(detail: String) -> Dictionary:
	return {"id": "T-17", "ok": false, "detail": detail}
