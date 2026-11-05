# Reinicio por inactividad (R-37): cuenta el tiempo sin entrada y, al llegar a
# INACTIVITY_RESET_S, dispara un fundido de FADE_S. Avisa `reset_due` en el
# punto negro (la mitad del fundido) para que la escena reconstruya la sesión
# mientras la pantalla está tapada. Es una máquina de estados pura: recibe
# delta y si hay entrada sostenida; no conoce escenas, audio ni el reloj.

class_name SessionReset
extends RefCounted

signal reset_due

# El fundido total dura 2 s (R-37): 1 s a negro y 1 s de vuelta.
const FADE_S := 2.0

var _idle_s := 0.0
var _fade_s := 0.0
var _fading := false
var _reset_emitted := false


# Cualquier entrada reinicia la cuenta (R-37).
func note_activity() -> void:
	_idle_s = 0.0


func is_fading() -> bool:
	return _fading


# Opacidad del velo negro: 0 transparente, 1 negro. Sube en la primera mitad
# del fundido y baja en la segunda, para no cortar a negro de golpe.
func fade_alpha() -> float:
	if not _fading:
		return 0.0
	var t := clampf(_fade_s / FADE_S, 0.0, 1.0)
	return 1.0 - absf(2.0 * t - 1.0)


# `input_held` mantiene viva la sesión aunque no lleguen flancos nuevos (por
# ejemplo, un botón o el joystick mantenidos). Durante el fundido no se puede
# cancelar: el reinicio ya está en curso (R-37).
func update(delta: float, input_held: bool) -> void:
	if _fading:
		_fade_s += delta
		if not _reset_emitted and _fade_s >= FADE_S * 0.5:
			_reset_emitted = true
			reset_due.emit()
		if _fade_s >= FADE_S:
			_fading = false
			_fade_s = 0.0
			_reset_emitted = false
			_idle_s = 0.0
		return

	if input_held:
		_idle_s = 0.0
		return

	_idle_s += delta
	if _idle_s >= Config.INACTIVITY_RESET_S:
		_fading = true
		_fade_s = 0.0
		_reset_emitted = false
