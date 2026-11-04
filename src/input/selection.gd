# Selección por vecindad (R-30): elige el candidato más alineado con el empuje
# del joystick, con un máximo de 60° y desempate por cercanía a la referencia.
# Es una función pura, sin estado: la usan tanto los nodos (Micro) como los
# organismos (Macro). Devuelve el índice del candidato o -1 si no hay ninguno.
# No conoce escenas, audio ni el modelo: recibe posiciones y una dirección.

class_name Selection
extends RefCounted

const MAX_ANGLE_DEGREES := 60.0
const EPSILON := 1e-4


static func pick(reference: Vector2, direction: Vector2, candidates: Array[Vector2]) -> int:
	if direction.length_squared() <= 0.0:
		return -1

	var best := -1
	var best_angle := MAX_ANGLE_DEGREES + EPSILON
	var best_distance := INF

	for i in candidates.size():
		var offset := candidates[i] - reference
		var distance := offset.length()
		# El candidato en la misma posición es la referencia, no un vecino.
		if distance <= EPSILON:
			continue

		var angle := rad_to_deg(absf(direction.angle_to(offset)))
		if angle > MAX_ANGLE_DEGREES + EPSILON:
			continue

		# Gana el ángulo menor; si empatan, el más cercano a la referencia.
		if angle < best_angle - EPSILON:
			best = i
			best_angle = angle
			best_distance = distance
		elif absf(angle - best_angle) <= EPSILON and distance < best_distance:
			best = i
			best_distance = distance

	return best
