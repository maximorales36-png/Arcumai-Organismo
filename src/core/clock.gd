# Reloj maestro: única fuente de verdad del tiempo musical (ESPECIFICACION §2).
# Recibe delta en segundos y emite un tick entero por cada TICK_SEC acumulado.
# Nunca saltea ticks: si un frame trae mucho delta, emite los atrasados en orden.
# No conoce nodos, escenas ni audio; el Node que lo alimenta vive en la vista.

class_name Clock
extends RefCounted

signal tick_emitted(tick: int)

# Tolerancia para comparar floats: sin esto, un residuo de 0.14999999
# retrasaría un tick un frame entero por error de redondeo.
const EPSILON := 1e-9

# Tick global desde que arrancó la sesión. Es el único contador de tiempo.
var tick: int = 0

var _accumulator: float = 0.0


# Fracción del tick en curso (0 a 1): es el "tiempo desde el último tick" que
# pide R-21 para la posición visual del pulso. No altera el tiempo musical.
func fraction() -> float:
	return clampf(_accumulator / Config.TICK_SEC, 0.0, 1.0)


# Avanza el reloj con el tiempo real transcurrido. Un solo frame puede
# contener varios ticks (frame lento) y se emiten todos, en orden (R-02).
func advance(delta: float) -> void:
	if delta <= 0.0:
		return
	_accumulator += delta
	while _accumulator + EPSILON >= Config.TICK_SEC:
		_accumulator -= Config.TICK_SEC
		tick += 1
		tick_emitted.emit(tick)
