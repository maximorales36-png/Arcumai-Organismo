# Test del reloj maestro (T-15): con deltas irregulares, incluido uno de
# varios ticks, la cantidad de ticks emitidos es floor(tiempo_total / TICK_SEC)
# y llegan en orden, sin saltear ninguno.
# Contrato: `extends RefCounted` con `run() -> Array[Dictionary]`.

extends RefCounted

const EPSILON := 1e-9


func run() -> Array[Dictionary]:
	return [_check_t15(), _check_click_stream()]


func _check_t15() -> Dictionary:
	var irregular := [0.016, 0.033, 0.007, 0.05, 0.1, 0.02, 0.25, 0.0, 0.016, 0.4]
	var first := _simulate(irregular)
	if not first["ok"]:
		return {"id": "T-15", "ok": false, "detail": "deltas irregulares: " + first["detail"]}

	# Corrida larga: ~3 minutos a 60 FPS, para que un error de acumulación
	# aparezca como diferencia de conteo y no solo como jitter.
	var long_run: Array[float] = []
	for i in 11260:
		long_run.append(0.016)
	var second := _simulate(long_run)
	if not second["ok"]:
		return {"id": "T-15", "ok": false, "detail": "corrida larga: " + second["detail"]}

	return {
		"id": "T-15",
		"ok": true,
		"detail": "ticks en orden y sin salteos (%s y %s)" % [first["detail"], second["detail"]],
	}


func _simulate(deltas: Array) -> Dictionary:
	var clock := Clock.new()
	var ticks: Array[int] = []
	clock.tick_emitted.connect(func(t: int) -> void: ticks.append(t))

	var total := 0.0
	for delta in deltas:
		total += delta
		clock.advance(delta)

	var expected := int(floor(total / Config.TICK_SEC + EPSILON))
	if ticks.size() != expected:
		return {
			"ok": false,
			"detail": "se esperaban %d ticks y llegaron %d" % [expected, ticks.size()],
		}
	for i in ticks.size():
		if ticks[i] != i + 1:
			return {
				"ok": false,
				"detail": "fuera de orden: en la posición %d llegó el tick %d" % [i + 1, ticks[i]],
			}
	return {"ok": true, "detail": "%d ticks" % ticks.size()}


# El click de metrónomo no tiene ID en la especificación: es un entregable de
# M1. Se verifica que el stream generado tenga muestras y no sea silencio, para
# que la prueba a oído (V-04) no falle por un placeholder vacío.
func _check_click_stream() -> Dictionary:
	var stream := ClickStream.make()
	var expected_samples := int(ClickStream.MIX_RATE * ClickStream.DURATION_S)
	if stream == null or stream.data.size() != expected_samples * 2:
		return {"id": "M1-click", "ok": false, "detail": "el stream no tiene el tamaño esperado"}
	var peak := 0
	for i in expected_samples:
		peak = maxi(peak, absi(stream.data.decode_s16(i * 2)))
	if peak == 0:
		return {"id": "M1-click", "ok": false, "detail": "el stream generado es silencio"}
	return {"id": "M1-click", "ok": true, "detail": "%d muestras, pico %d" % [expected_samples, peak]}
