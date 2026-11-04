# Mapeo de altura de un nodo a nota MIDI y a pitch_scale (ESPECIFICACION R-23).
# Recibe la posición vertical local del nodo, la cantidad de pulsos y la escala
# de la sesión; no conoce audio ni escenas. Todo el cálculo es puro y testeable.
# La tónica y la escala las sortea la sesión (R-24); acá solo se aplican.

class_name PitchMapping
extends RefCounted


# Grado dentro de la escala (0 a PITCH_SPAN_DEGREES-1). Arriba del organismo
# es positivo, y por eso se invierte la Y de Godot, que crece hacia abajo.
static func degree_for_height(y_local: float, n: int) -> int:
	var height := clampf(-(y_local / Config.r_max(n)), -1.0, 1.0)
	return int(round((height + 1.0) / 2.0 * (Config.PITCH_SPAN_DEGREES - 1)))


# Semitonos desde la tónica. Pasado el largo de la escala se sube una octava,
# así el grado nunca queda fuera de rango (R-23).
static func semitones_for_degree(degree: int, scale: Array) -> int:
	return 12 * (degree / scale.size()) + int(scale[degree % scale.size()])


static func midi_for_node(y_local: float, n: int, scale: Array, tonic: int) -> int:
	var degree := degree_for_height(y_local, n)
	return Config.base_midi(n) + tonic + semitones_for_degree(degree, scale)


# Las muestras están grabadas en C4 (SAMPLE_ROOT_MIDI), así que la distancia
# en semitonos se convierte en un factor de reproducción.
static func pitch_scale_for_midi(midi: int) -> float:
	return pow(2.0, float(midi - Config.SAMPLE_ROOT_MIDI) / 12.0)
