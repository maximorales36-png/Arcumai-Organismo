# Test de selección por vecindad (R-30): T-16.
# Comprueba el límite de 60°, el desempate por cercanía y los casos de 0, 1 y
# varios candidatos. Usa posiciones sintéticas para que los ángulos sean exactos.
# Contrato: `extends RefCounted` con `run() -> Array[Dictionary]`.

extends RefCounted


func run() -> Array[Dictionary]:
	return [_t16()]


func _t16() -> Dictionary:
	var problem := _empty_cases()
	if problem != "":
		return _fail(problem)
	problem = _angle_limit()
	if problem != "":
		return _fail(problem)
	problem = _best_angle()
	if problem != "":
		return _fail(problem)
	problem = _tie_by_distance()
	if problem != "":
		return _fail(problem)
	return _ok("T-16", "0, 1 y varios candidatos; límite de 60° y desempate por cercanía")


# Sin candidatos o sin empuje no hay selección.
func _empty_cases() -> String:
	var reference := Vector2.ZERO
	var empty: Array[Vector2] = []
	if Selection.pick(reference, Vector2.RIGHT, empty) != -1:
		return "sin candidatos devolvió una selección"
	if Selection.pick(reference, Vector2.ZERO, _ring(1)) != -1:
		return "sin empuje devolvió una selección"

	# El único candidato está en la misma posición que la referencia.
	var same: Array[Vector2] = [reference]
	if Selection.pick(reference, Vector2.RIGHT, same) != -1:
		return "un candidato en la referencia se tomó como vecino"
	return ""


# Un candidato a 60° entra; a 61° queda fuera.
func _angle_limit() -> String:
	var reference := Vector2.ZERO
	if Selection.pick(reference, Vector2.RIGHT, _at(60.0, 100.0)) != 0:
		return "un candidato a 60° fue rechazado"
	if Selection.pick(reference, Vector2.RIGHT, _at(61.0, 100.0)) != -1:
		return "un candidato a 61° fue aceptado"
	if Selection.pick(reference, Vector2.RIGHT, _at(-60.0, 100.0)) != 0:
		return "un candidato a -60° fue rechazado"
	return ""


# Gana el ángulo menor, aunque esté más lejos que otro candidato.
func _best_angle() -> String:
	var reference := Vector2.ZERO
	var candidates: Array[Vector2] = []
	candidates.append(_point(30.0, 100.0))
	candidates.append(_point(10.0, 500.0))
	candidates.append(_point(-45.0, 50.0))
	if Selection.pick(reference, Vector2.RIGHT, candidates) != 1:
		return "no eligió el candidato de menor ángulo"
	return ""


# Con el mismo ángulo, gana el más cercano a la referencia.
func _tie_by_distance() -> String:
	var reference := Vector2.ZERO
	var candidates: Array[Vector2] = []
	candidates.append(_point(20.0, 400.0))
	candidates.append(_point(-20.0, 100.0))
	candidates.append(_point(20.0, 250.0))
	if Selection.pick(reference, Vector2.RIGHT, candidates) != 1:
		return "en empate no eligió el candidato más cercano"

	# La diagonal es una dirección válida del joystick de 8 vías.
	var diagonal := Vector2.ONE.normalized()
	var along: Array[Vector2] = [_point(45.0, 80.0)]
	if Selection.pick(reference, diagonal, along) != 0:
		return "la dirección diagonal no eligió el candidato alineado"
	return ""


func _ring(distance: float) -> Array[Vector2]:
	var candidates: Array[Vector2] = [_point(0.0, distance)]
	return candidates


func _at(degrees: float, distance: float) -> Array[Vector2]:
	var candidates: Array[Vector2] = [_point(degrees, distance)]
	return candidates


func _point(degrees: float, distance: float) -> Vector2:
	return Vector2.from_angle(deg_to_rad(degrees)) * distance


func _ok(test_id: String, detail: String) -> Dictionary:
	return {"id": test_id, "ok": true, "detail": detail}


func _fail(detail: String) -> Dictionary:
	return {"id": "T-16", "ok": false, "detail": detail}
