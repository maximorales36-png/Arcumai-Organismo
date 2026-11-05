# Tests de puentes (R-27, R-28): T-11 y T-12.
# T-11: un disparo no-eco del nodo emisor produce exactamente un eco en el nodo
# receptor a T + BRIDGE_DELAY_TICKS, y el eco no encola otros ecos.
# T-12: los topes se respetan y disolver un organismo descarta sus puentes y
# ecos pendientes sin error.
# Contrato: `extends RefCounted` con `run() -> Array[Dictionary]`.

extends RefCounted

var _rejections := 0


func run() -> Array[Dictionary]:
	return [_t11(), _t12()]


func _t11() -> Dictionary:
	var network := BridgeNetwork.new()
	if not network.add(Bridge.new(1, 2, 2, 3)):
		return _fail("T-11", "no se pudo crear el puente")

	network.on_node_fired(1, 2, 10, false)
	if network.take_due(10 + Config.BRIDGE_DELAY_TICKS - 1, _alive([1, 2])).size() != 0:
		return _fail("T-11", "el eco venció antes de tiempo")
	var due := network.take_due(10 + Config.BRIDGE_DELAY_TICKS, _alive([1, 2]))
	if due.size() != 1:
		return _fail("T-11", "el eco no venció exactamente una vez")
	if due[0].to_id != 2 or due[0].to_node != 3:
		return _fail("T-11", "el eco no llegó al nodo receptor")

	# Un eco no encola otro eco (sin contagio).
	network.on_node_fired(2, 3, 20, true)
	if network.take_due(100, _alive([1, 2])).size() != 0:
		return _fail("T-11", "un eco encoló otro eco")

	# Un disparo de un nodo que no es emisor no encola nada.
	network.on_node_fired(1, 0, 30, false)
	if network.take_due(100, _alive([1, 2])).size() != 0:
		return _fail("T-11", "un nodo que no es emisor encoló un eco")

	# El eco sale por el modelo del destino como disparo con is_echo = true.
	var model := OrganismModel.new(7, 3, 0, _rng())
	var recorded: Array = []
	model.node_fired.connect(_record.bind(recorded))
	model.emit_echo(1, 40)
	if recorded.size() != 1:
		return _fail("T-11", "emit_echo no emitió exactamente un disparo")
	var shot: Dictionary = recorded[0]
	if shot.node != 1 or shot.tick != 40 or not shot.is_echo:
		return _fail("T-11", "el eco no se emitió como disparo de eco")

	return _ok("T-11", "un disparo no-eco produce un eco a T + %d y el eco no encola otros" % [
		Config.BRIDGE_DELAY_TICKS
	])


func _t12() -> Dictionary:
	# Tope de puentes.
	var network := BridgeNetwork.new()
	for i in Config.MAX_BRIDGES:
		if not network.add(Bridge.new(1, 0, i + 2, 0)):
			return _fail("T-12", "no se pudo llegar a MAX_BRIDGES")
	if network.add(Bridge.new(1, 0, 999, 0)):
		return _fail("T-12", "se superó MAX_BRIDGES")

	# Un puente por par ordenado; A->B y B->A pueden coexistir.
	var pair := BridgeNetwork.new()
	if not pair.add(Bridge.new(1, 0, 2, 0)):
		return _fail("T-12", "no se pudo crear el puente directo")
	if not pair.add(Bridge.new(2, 0, 1, 0)):
		return _fail("T-12", "no se pudo crear el puente inverso")
	if pair.add(Bridge.new(1, 0, 2, 0)):
		return _fail("T-12", "se duplicó un par ordenado")

	# Quitar un puente cancela su eco pendiente.
	var toggled := BridgeNetwork.new()
	toggled.add(Bridge.new(1, 0, 2, 0))
	toggled.on_node_fired(1, 0, 5, false)
	toggled.remove(1, 2)
	if toggled.take_due(100, _alive([1, 2])).size() != 0:
		return _fail("T-12", "un puente quitado dejó su eco pendiente")

	# Disolver un organismo elimina sus puentes y descarta ecos sin error.
	var world := World.new(_rng())
	world.set_tick(0)
	world.add_organism(3)
	world.add_organism(3)
	var first := world.organisms[0]
	var second := world.organisms[1]
	world.bridges.add(Bridge.new(first.id, 0, second.id, 0))
	world.on_node_fired(first.id, 0, 10, false)
	world.select(0)
	world.b4_pressed()
	world.update(Config.DISSOLVE_HOLD_MS / 1000.0 + 0.1)
	if world.count() != 1:
		return _fail("T-12", "la disolución no eliminó el organismo")
	if world.bridges.count() != 0:
		return _fail("T-12", "quedaron puentes del organismo disuelto")
	world.flush_echoes(10 + Config.BRIDGE_DELAY_TICKS)
	if world.bridges.echoes.size() != 0:
		return _fail("T-12", "quedaron ecos pendientes del organismo disuelto")

	# Tope de organismos (R-33): al llegar a MAX_ORGANISMS, B2 rechaza.
	var full := World.new(_rng())
	full.rejected.connect(_count_rejection)
	for i in Config.MAX_ORGANISMS:
		full.add_organism(Config.N_DEFAULT)
	full.b2_pressed()
	if _rejections != 1:
		return _fail("T-12", "B2 no rechazó con MAX_ORGANISMS alcanzado")

	return _ok("T-12", "MAX_BRIDGES y MAX_ORGANISMS se respetan; disolver descarta puentes y ecos")


func _count_rejection() -> void:
	_rejections += 1


func _record(_organism_id: int, node_index: int, tick: int, is_echo: bool, into: Array) -> void:
	into.append({"node": node_index, "tick": tick, "is_echo": is_echo})


func _alive(ids: Array) -> Dictionary:
	var alive := {}
	for id in ids:
		alive[id] = true
	return alive


func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260101
	return rng


func _ok(test_id: String, detail: String) -> Dictionary:
	return {"id": test_id, "ok": true, "detail": detail}


func _fail(test_id: String, detail: String) -> Dictionary:
	return {"id": test_id, "ok": false, "detail": detail}
