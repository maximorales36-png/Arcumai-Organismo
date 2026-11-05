# Selección por vecindad (R-30): entre los candidatos dentro de un cono de 60°
# alrededor del empuje del joystick, gana el más cercano a la referencia; a igual
# distancia, el mejor alineado. Es una función pura, sin estado: la usan tanto
# los nodos (Micro) como los organismos (Macro). Devuelve el índice del
# candidato o -1 si no hay ninguno. No conoce escenas, audio ni el modelo.

class_name Selection
extends RefCounted

const MAX_ANGLE_DEGREES := 60.0
const EPSILON := 1e-4


static func pick(reference: Vector2, direction: Vector2, candidates: Array[Vector2]) -> int:
	if direction.length_squared() <= 0.0:
		return -1

	var best := -1
	var best_distance := INF
	var best_angle := MAX_ANGLE_DEGREES + EPSILON

	for i in candidates.size():
		var offset := candidates[i] - reference
		var distance := offset.length()
		# El candidato en la misma posición es la referencia, no un vecino.
		if distance <= EPSILON:
			continue

		var angle := rad_to_deg(absf(direction.angle_to(offset)))
		if angle > MAX_ANGLE_DEGREES + EPSILON:
			continue

		# Gana el más cercano: es el "vecino" en esa dirección. Si dos están a la
		# misma distancia, gana el que está mejor alineado con el joystick.
		if distance < best_distance - EPSILON:
			best = i
			best_distance = distance
			best_angle = angle
		elif absf(distance - best_distance) <= EPSILON and angle < best_angle - EPSILON:
			best = i
			best_angle = angle

	return best
