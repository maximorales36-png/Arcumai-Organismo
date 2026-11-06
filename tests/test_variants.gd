# Test del ciclo de variantes de un nodo (R-25): T-24.
# Comprueba que B2 recorre nota, cross-stick, bombo y silencio, y que el
# silencio es una variante válida que no gasta voz.
# Contrato: `extends RefCounted` con `run() -> Array[Dictionary]`.

extends RefCounted


func run() -> Array[Dictionary]:
	return [_t24()]


func _t24() -> Dictionary:
	if Config.VARIANT_COUNT != 4:
		return _fail("VARIANT_COUNT debería ser 4 y es %d" % Config.VARIANT_COUNT)

	var model := OrganismModel.new(1, 4, 0, _seeded_rng(7))
	var session := MicroSession.new(model)
	if session.variant_of(0) != Config.VARIANT_PITCHED:
		return _fail("un nodo nuevo debería arrancar en la nota afinada")

	# Después de cada toque de B2, el nodo avanza una variante.
	var expected := [
		Config.VARIANT_CROSS_STICK,
		Config.VARIANT_KICK,
		Config.VARIANT_SILENCE,
		Config.VARIANT_PITCHED,
	]
	for i in expected.size():
		session.b2_pressed()
		if session.variant_of(0) != expected[i]:
			return _fail("toque %d: se esperaba %s y quedó %s" % [
				i + 1,
				Config.variant_name(expected[i]),
				Config.variant_name(session.variant_of(0)),
			])

	if Config.variant_name(Config.VARIANT_SILENCE) != "silencio":
		return _fail("la variante de silencio no se llama silencio")

	return _ok("T-24", "B2 recorre nota, cross-stick, bombo y silencio")


func _seeded_rng(value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = value
	return rng


func _ok(test_id: String, detail: String) -> Dictionary:
	return {"id": test_id, "ok": true, "detail": detail}


func _fail(detail: String) -> Dictionary:
	return {"id": "T-24", "ok": false, "detail": detail}
