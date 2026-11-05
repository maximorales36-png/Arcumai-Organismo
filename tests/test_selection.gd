# Test de selección por vecindad (R-30): T-16.
# Comprueba el límite de 60°, que gane el más cercano dentro del cono, el
# desempate por ángulo a igual distancia y los casos de 0, 1 y varios
# candidatos. Incluye una disposición real de 5 organismos en la que la regla
# anterior dejaba uno inalcanzable.
# Contrato: `extends RefCounted` con `run() -> Array[Dictionary]`.

extends RefCounted

const DIRECTIONS := [
	Vector2.RIGHT, Vector2.RIGHT + Vector2.DOWN, Vector2.DOWN, Vector2.LEFT + Vector2.DOWN,
	Vector2.LEFT, Vector2.LEFT + Vector2.UP, Vector2.UP, Vector2.RIGHT + Vector2.UP,
]


func run() -> Array[Dictionary]:
	return [_t16()]


func _t16() -> Dictionary:
	var problem := _empty_cases()
	if problem != "":
		return _fail(problem)
	problem = _angle_limit()
	if problem != "":
		return _fail(problem)
	problem = _nearest_in_cone()
	if problem != "":
		return _fail(problem)
	problem = _tie_by_angle()
	if problem != "":
		return _fail(problem)
	problem = _all_reachable()
	if problem != "":
		return _fail(problem)
	return _ok("T-16", "0, 1 y varios candidatos; cono de 60°, gana el más cercano y todos alcanzables")


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


# Dentro del cono gana el más cercano, aunque esté menos alineado que otro.
func _nearest_in_cone() -> String:
	var reference := Vector2.ZERO
	var candidates: Array[Vector2] = []
	candidates.append(_point(10.0, 500.0))
	candidates.append(_point(45.0, 80.0))
	candidates.append(_point(-30.0, 300.0))
	if Selection.pick(reference, Vector2.RIGHT, candidates) != 1:
		return "no eligió el candidato más cercano dentro del cono"

	# Uno fuera del cono no compite por estar más cerca.
	var outside: Array[Vector2] = []
	outside.append(_point(61.0, 10.0))
	outside.append(_point(20.0, 400.0))
	if Selection.pick(reference, Vector2.RIGHT, outside) != 1:
		return "un candidato fuera del cono compitió por cercanía"
	return ""


# A igual distancia, gana el mejor alineado con el joystick.
func _tie_by_angle() -> String:
	var reference := Vector2.ZERO
	var candidates: Array[Vector2] = []
	candidates.append(_point(20.0, 200.0))
	candidates.append(_point(-20.0, 200.0))
	candidates.append(_point(5.0, 200.0))
	if Selection.pick(reference, Vector2.RIGHT, candidates) != 2:
		return "a igual distancia no eligió el candidato de menor ángulo"

	# La diagonal es una dirección válida del joystick de 8 vías.
	var diagonal := Vector2.ONE.normalized()
	var along: Array[Vector2] = [_point(45.0, 80.0)]
	if Selection.pick(reference, diagonal, along) != 0:
		return "la dirección diagonal no eligió el candidato alineado"
	return ""


# Con 5 organismos, desde cada uno se debe poder llegar a todos los demás. Esta
# es la disposición real que con la regla anterior dejaba un organismo tapado.
func _all_reachable() -> String:
	var positions: Array[Vector2] = [
		Vector2(904.3597, 601.1069),
		Vector2(2335.377, 1006.053),
		Vector2(1682.279, 80.93888),
		Vector2(448.9243, 1227.069),
		Vector2(70.85844, 375.6544),
	]
	for start in positions.size():
		var seen := {start: true}
		var queue: Array[int] = [start]
		while not queue.is_empty():
			var current: int = queue.pop_front()
			for direction in DIRECTIONS:
				var next := Selection.pick(positions[current], direction, positions)
				if next >= 0 and not seen.has(next):
					seen[next] = true
					queue.append(next)
		if seen.size() < positions.size():
			return "desde el organismo %d quedó uno inalcanzable" % start
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
