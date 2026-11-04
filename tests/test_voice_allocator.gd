# Tests de la política de voces (R-29): T-14.
# Nunca hay más de VOICE_CAP voces activas y el robo se lleva la más antigua.
# Se testea VoiceAllocator, que es la política pura; VoicePool solo la envuelve.
# Contrato: `extends RefCounted` con `run() -> Array[Dictionary]`.

extends RefCounted


func run() -> Array[Dictionary]:
	return [_t14()]


func _t14() -> Dictionary:
	var problem := _cap_violation()
	if problem != "":
		return _fail(problem)
	problem = _steal_violation()
	if problem != "":
		return _fail(problem)
	problem = _release_violation()
	if problem != "":
		return _fail(problem)
	return _ok("T-14", "nunca más de %d voces; el robo toma la más antigua" % Config.VOICE_CAP)


# Aunque se pidan muchos disparos, la cantidad activa no pasa del tope.
func _cap_violation() -> String:
	var allocator := VoiceAllocator.new()
	if allocator.capacity() != Config.VOICE_CAP:
		return "el pool tiene %d voces y VOICE_CAP es %d" % [allocator.capacity(), Config.VOICE_CAP]

	for i in Config.VOICE_CAP * 3:
		allocator.acquire()
		if allocator.active_count() > Config.VOICE_CAP:
			return "tras %d disparos hay %d voces activas" % [i + 1, allocator.active_count()]
	if allocator.active_count() != Config.VOICE_CAP:
		return "con todo ocupado hay %d voces activas" % allocator.active_count()
	return ""


# Con el pool lleno, cada pedido nuevo devuelve la voz que empezó antes.
func _steal_violation() -> String:
	var allocator := VoiceAllocator.new(4)
	for i in 4:
		allocator.acquire()

	for expected in [0, 1, 2]:
		var stolen := allocator.acquire()
		if stolen != expected:
			return "se esperaba robar la voz %d y se robó la %d" % [expected, stolen]
		if allocator.active_count() != 4:
			return "tras robar quedaron %d voces activas" % allocator.active_count()
	return ""


# Una voz liberada vuelve a estar disponible antes que robar una ocupada.
func _release_violation() -> String:
	var allocator := VoiceAllocator.new(4)
	var first := allocator.acquire()
	allocator.acquire()
	allocator.release(first)

	var reused := allocator.acquire()
	if reused != first:
		return "la voz liberada %d no se reutilizó (se usó la %d)" % [first, reused]
	if allocator.active_count() != 2:
		return "quedaron %d voces activas y se esperaban 2" % allocator.active_count()
	return ""


func _ok(test_id: String, detail: String) -> Dictionary:
	return {"id": test_id, "ok": true, "detail": detail}


func _fail(detail: String) -> Dictionary:
	return {"id": "T-14", "ok": false, "detail": detail}
