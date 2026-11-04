# Test de humo de M0: que el Input Map tenga las 8 acciones con al menos un
# evento, y que las constantes básicas de Config sean coherentes.
# No valida reglas del juego: eso empieza en M1.
# Contrato: `extends RefCounted` con `run() -> Array[Dictionary]`.

extends RefCounted


func run() -> Array[Dictionary]:
	return [
		_check_input_actions(),
		_check_input_keycodes(),
		_check_config_bounds(),
	]


func _check_input_actions() -> Dictionary:
	var missing: Array[String] = []
	for action in Config.INPUT_ACTIONS:
		if not InputMap.has_action(action):
			missing.append(action)
		elif InputMap.action_get_events(action).is_empty():
			missing.append(action + " (sin eventos)")
	if missing.is_empty():
		return {
			"id": "M0-input",
			"ok": true,
			"detail": "las 8 acciones existen y tienen eventos",
		}
	return {"id": "M0-input", "ok": false, "detail": "faltan: %s" % ", ".join(missing)}


# El mapeo de teclado es parte del criterio de M0: sin esto, un error de
# tipeo en project.godot pasaría inadvertido hasta probar a mano.
func _check_input_keycodes() -> Dictionary:
	var expected := {
		"joy_up": KEY_W,
		"joy_down": KEY_S,
		"joy_left": KEY_A,
		"joy_right": KEY_D,
		"btn_1": KEY_H,
		"btn_2": KEY_J,
		"btn_3": KEY_K,
		"btn_4": KEY_L,
	}
	var wrong: Array[String] = []
	for action in expected:
		var events := InputMap.action_get_events(action)
		if events.is_empty():
			wrong.append(action)
			continue
		var key_event := events[0] as InputEventKey
		if key_event == null or key_event.physical_keycode != expected[action]:
			wrong.append(action)
	if wrong.is_empty():
		return {"id": "M0-input-keys", "ok": true, "detail": "WASD y HJKL mapeados como corresponde"}
	return {"id": "M0-input-keys", "ok": false, "detail": "mapeo incorrecto en: %s" % ", ".join(wrong)}


func _check_config_bounds() -> Dictionary:
	if Config.N_MIN > Config.N_DEFAULT or Config.N_DEFAULT > Config.N_MAX:
		return {"id": "M0-config", "ok": false, "detail": "N_DEFAULT fuera de [N_MIN, N_MAX]"}
	if Config.BPM <= 0 or Config.TICKS_PER_BEAT <= 0:
		return {"id": "M0-config", "ok": false, "detail": "BPM o TICKS_PER_BEAT no positivos"}
	if not is_equal_approx(Config.TICK_SEC, 0.15):
		return {"id": "M0-config", "ok": false, "detail": "TICK_SEC no es 0.15 con los valores iniciales"}
	return {
		"id": "M0-config",
		"ok": true,
		"detail": "constantes coherentes (TICK_SEC = %.3f s)" % Config.TICK_SEC,
	}
