# Tests del mapeo de altura a nota (R-23): T-13.
# Recorre todas las combinaciones de n, escala y tónica y comprueba rango MIDI,
# pertenencia a la escala y monotonía del grado respecto de la altura.
# Contrato: `extends RefCounted` con `run() -> Array[Dictionary]`.

extends RefCounted

const MIDI_MIN := 24
const MIDI_MAX := 96


func run() -> Array[Dictionary]:
	return [_t13()]


func _t13() -> Dictionary:
	var problem := _range_and_scale_violation()
	if problem != "":
		return _fail(problem)
	problem = _monotonic_violation()
	if problem != "":
		return _fail(problem)
	return _ok("T-13", "midi en [24, 96] y dentro de la escala; el grado nunca baja al subir el nodo")


# Para todo n y tónica, la nota queda en [24, 96] y pertenece a la escala
# única. Se prueban los bordes del radio y las alturas reales de organismos
# generados, porque el borde es donde el clamp de R-23 puede fallar.
func _range_and_scale_violation() -> String:
	for n in range(Config.N_MIN, Config.N_MAX + 1):
		var radius := Config.r_max(n)
		var heights: Array[float] = [-radius * 1.5, -radius, -radius * 0.5, 0.0, radius * 0.5, radius, radius * 1.5]
		for seed_value in 10:
			var model := OrganismModel.new(1, n, 0, _seeded_rng(seed_value))
			for position in model.nodes:
				heights.append(position.y)

		var scale: Array = Config.SCALE
		for tonic in 12:
			for y_local in heights:
				var midi := PitchMapping.midi_for_node(y_local, n, scale, tonic)
				if midi < MIDI_MIN or midi > MIDI_MAX:
					return "n=%d escala=%s tónica=%d y=%.1f dio midi %d" % [n, Config.SCALE_NAME, tonic, y_local, midi]
				var semitones := midi - Config.base_midi(n) - tonic
				if not scale.has(posmod(semitones, 12)):
					return "n=%d escala=%s tónica=%d dio midi %d, fuera de la escala" % [n, Config.SCALE_NAME, tonic, midi]
	return ""


# Subir un nodo nunca baja el grado: se recorre la altura de abajo hacia arriba
# (y decreciente en Godot) y el grado tiene que ser no decreciente.
func _monotonic_violation() -> String:
	for n in range(Config.N_MIN, Config.N_MAX + 1):
		var radius := Config.r_max(n)
		for tonic in 12:
			var previous := -1
			for step in 101:
				# De +radius (abajo) a -radius (arriba).
				var y_local := radius - 2.0 * radius * step / 100.0
				var degree := PitchMapping.degree_for_height(y_local, n)
				if degree < 0 or degree >= Config.PITCH_SPAN_DEGREES:
					return "el grado %d quedó fuera de [0, %d]" % [degree, Config.PITCH_SPAN_DEGREES - 1]
				if degree < previous:
					return "n=%d escala=%s: subir el nodo bajó el grado de %d a %d" % [n, Config.SCALE_NAME, previous, degree]
				previous = degree
	return ""


func _seeded_rng(value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = value
	return rng


func _ok(test_id: String, detail: String) -> Dictionary:
	return {"id": test_id, "ok": true, "detail": detail}


func _fail(detail: String) -> Dictionary:
	return {"id": "T-13", "ok": false, "detail": detail}
