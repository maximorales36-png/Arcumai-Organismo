# Router de input (R-30): traduce las 8 acciones a eventos semánticos.
# Emite un paso de navegación al empujar el joystick y lo repite mientras se
# mantiene (primero a NAV_REPEAT_FIRST_MS, después cada NAV_REPEAT_MS).
# También informa los flancos de los botones y la dirección actual, que usan
# el arrastre y el brillo. No conoce reglas: la sesión decide qué hacer.

class_name InputRouter
extends RefCounted

signal nav_step(direction: Vector2)
signal stick_changed(direction: Vector2)
signal button_pressed(action: String)
signal button_released(action: String)

const REPEAT_FIRST_S := Config.NAV_REPEAT_FIRST_MS / 1000.0
const REPEAT_S := Config.NAV_REPEAT_MS / 1000.0

var _direction := Vector2.ZERO
var _held_s := 0.0
var _next_repeat_s := REPEAT_FIRST_S
var _pressed: Dictionary = {}


func update(delta: float) -> void:
	# Los botones primero: si B1 y el joystick llegan en el mismo frame, el
	# gesto ya está activo y el empuje se interpreta como arrastre, no como
	# navegación (R-32).
	_update_buttons()
	_update_stick(delta)


# R-37: una entrada sostenida (joystick inclinado o cualquier botón apretado)
# cuenta como actividad aunque no haya flancos nuevos.
func is_any_active() -> bool:
	return _direction != Vector2.ZERO or not _pressed.is_empty()


func _update_stick(delta: float) -> void:
	var direction := read_direction()
	if direction != _direction:
		_direction = direction
		stick_changed.emit(direction)
		_held_s = 0.0
		_next_repeat_s = REPEAT_FIRST_S
		if direction != Vector2.ZERO:
			nav_step.emit(direction)
		return

	if direction == Vector2.ZERO:
		return

	_held_s += delta
	while _held_s >= _next_repeat_s:
		nav_step.emit(direction)
		_next_repeat_s += REPEAT_S


func _update_buttons() -> void:
	for action in Config.BUTTON_ACTIONS:
		var is_down := Input.is_action_pressed(action)
		var was_down: bool = _pressed.get(action, false)
		if is_down == was_down:
			continue
		_pressed[action] = is_down
		if is_down:
			button_pressed.emit(action)
		else:
			button_released.emit(action)


# Vector de 8 direcciones: con joystick digital alcanza con el signo de cada
# eje, y se normaliza para que la diagonal no arrastre más rápido (R-22).
static func read_direction() -> Vector2:
	var x := Input.get_action_strength("joy_right") - Input.get_action_strength("joy_left")
	var y := Input.get_action_strength("joy_down") - Input.get_action_strength("joy_up")
	if is_zero_approx(x) and is_zero_approx(y):
		return Vector2.ZERO
	return Vector2(signf(x), signf(y)).normalized()
