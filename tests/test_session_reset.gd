# Test del reinicio por inactividad (R-37): T-22.
# Comprueba el umbral de INACTIVITY_RESET_S, el fundido de 2 s, el aviso
# `reset_due` en el punto negro, la cancelación por entrada y el reinicio de la
# cuenta después de un reset. Es una máquina de estados pura: no hay escena.
# Contrato: `extends RefCounted` con `run() -> Array[Dictionary]`.

extends RefCounted

var _resets := 0


func run() -> Array[Dictionary]:
	return [_t22()]


func _t22() -> Dictionary:
	var problem := _threshold()
	if problem != "":
		return _fail(problem)
	problem = _fade_shape()
	if problem != "":
		return _fail(problem)
	problem = _activity_cancels()
	if problem != "":
		return _fail(problem)
	problem = _held_input_keeps_alive()
	if problem != "":
		return _fail(problem)
	problem = _restarts_after_reset()
	if problem != "":
		return _fail(problem)
	return _ok("T-22", "R-37: umbral, fundido de 2 s, cancelación por entrada y reinicio de la cuenta")


# Antes del umbral no pasa nada; al llegar, arranca el fundido.
func _threshold() -> String:
	var reset := SessionReset.new()
	_simulate(reset, Config.INACTIVITY_RESET_S - 0.5, false)
	if reset.is_fading():
		return "empezó el fundido antes de INACTIVITY_RESET_S"
	if not is_zero_approx(reset.fade_alpha()):
		return "el velo no estaba transparente antes del umbral"
	_simulate(reset, 1.0, false)
	if not reset.is_fading():
		return "no empezó el fundido al llegar a INACTIVITY_RESET_S"
	return ""


# El velo sube, avisa en negro y vuelve a bajar; el reset se avisa una sola vez.
func _fade_shape() -> String:
	var reset := SessionReset.new()
	_resets = 0
	reset.reset_due.connect(_count_reset)
	_simulate(reset, Config.INACTIVITY_RESET_S + 0.1, false)
	if not reset.is_fading():
		return "no estaba en fundido al pasar el umbral"

	_simulate(reset, 0.4, false)
	var early := reset.fade_alpha()
	if early <= 0.0 or early >= 1.0:
		return "el velo no subió de forma gradual"
	if _resets != 0:
		return "avisó el reset antes del punto negro"

	_simulate(reset, 0.6, false)
	if _resets != 1:
		return "no avisó el reset en el punto negro"
	if reset.fade_alpha() < 0.85:
		return "el punto de reset no estaba casi a negro"

	_simulate(reset, 1.0, false)
	if reset.is_fading():
		return "el fundido no terminó a los 2 s"
	if not is_zero_approx(reset.fade_alpha()):
		return "el velo no volvió a transparente"
	if _resets != 1:
		return "avisó el reset más de una vez"
	return ""


# Cualquier entrada reinicia la cuenta: 80 s + entrada + 80 s no reinicia.
func _activity_cancels() -> String:
	var reset := SessionReset.new()
	_simulate(reset, Config.INACTIVITY_RESET_S - 10.0, false)
	reset.note_activity()
	_simulate(reset, Config.INACTIVITY_RESET_S - 10.0, false)
	if reset.is_fading():
		return "se reinició aunque hubo una entrada a mitad de la espera"

	# Una entrada de un frame también alcanza.
	reset.note_activity()
	_simulate(reset, Config.INACTIVITY_RESET_S - 1.0, false)
	reset.note_activity()
	_simulate(reset, Config.INACTIVITY_RESET_S - 1.0, false)
	if reset.is_fading():
		return "se reinició después de una entrada reciente"
	return ""


# Mantener una entrada (botón o joystick) impide el reinicio por más que pase
# el tiempo: la instalación no debe reiniciarse mientras alguien interactúa.
func _held_input_keeps_alive() -> String:
	var reset := SessionReset.new()
	_simulate(reset, Config.INACTIVITY_RESET_S * 3.0, true)
	if reset.is_fading():
		return "se reinició con una entrada sostenida"
	return ""


# Después del fundido, la cuenta vuelve a cero: hace falta otro ciclo completo.
func _restarts_after_reset() -> String:
	var reset := SessionReset.new()
	_resets = 0
	reset.reset_due.connect(_count_reset)
	_simulate(reset, Config.INACTIVITY_RESET_S + SessionReset.FADE_S + 0.1, false)
	if _resets != 1:
		return "no hubo exactamente un reset"
	_simulate(reset, Config.INACTIVITY_RESET_S - 1.0, false)
	if reset.is_fading():
		return "la cuenta no se reinició después del reset"
	_simulate(reset, 2.0, false)
	if not reset.is_fading():
		return "no se reinició la cuenta completa tras el reset"
	return ""


func _count_reset() -> void:
	_resets += 1


func _simulate(reset: SessionReset, seconds: float, input_held: bool) -> void:
	var frames := int(round(seconds * 60.0))
	for i in frames:
		reset.update(1.0 / 60.0, input_held)


func _ok(test_id: String, detail: String) -> Dictionary:
	return {"id": test_id, "ok": true, "detail": detail}


func _fail(detail: String) -> Dictionary:
	return {"id": "T-22", "ok": false, "detail": detail}
