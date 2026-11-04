# Reglas de interacción Micro (R-19, R-22, R-26, R-30, R-31, R-32, R-35).
# Mantiene la selección, el estado de los gestos, la variante de cada nodo y el
# brillo; aplica los cambios al OrganismModel y emite señales para la vista y
# el audio. No conoce nodos de escena ni reproduce sonido.
# Recibe eventos del InputRouter y el delta de la escena (el delta es parte de
# la regla de arrastre de R-22, no del tiempo musical).

class_name MicroSession
extends RefCounted

signal selection_changed(node_index: int)
signal origin_changed(node_index: int)
signal variant_changed(node_index: int, variant: int)
signal brightness_changed(brightness: float)
signal rejected

var selected: int = 0

var _model: OrganismModel
var _variants: Array[int] = []
var _brightness := Config.BRIGHTNESS_DEFAULT
var _dragging := false
var _moved_during_press := false
var _adjusting_brightness := false


func _init(model: OrganismModel) -> void:
	_model = model
	_variants.resize(model.n)
	_variants.fill(0)


func variant_of(node_index: int) -> int:
	return _variants[posmod(node_index, _model.n)]


func brightness() -> float:
	return _brightness


func is_dragging() -> bool:
	return _dragging


# R-33: al cambiar n durante la siembra el modelo se regenera; la sesión
# ajusta su lista de variantes y mantiene la selección dentro de rango.
func on_model_rebuilt() -> void:
	_variants.resize(_model.n)
	if selected >= _model.n:
		selected = 0
		selection_changed.emit(selected)


# Al entrar o salir de Micro se cortan los gestos a medias: si B1 o B3
# quedaron apretados, no deben seguir actuando al volver a la vista.
func reset_gestures() -> void:
	_dragging = false
	_moved_during_press = false
	_adjusting_brightness = false


# R-30: un empuje mueve la selección al nodo vecino en esa dirección. Con B1 o
# B3 apretados el joystick tiene otro verbo, así que no navega.
func nav_step(direction: Vector2) -> void:
	if _dragging or _adjusting_brightness:
		return
	var next := Selection.pick(_model.nodes[selected], direction, _model.nodes)
	if next < 0:
		rejected.emit()
		return
	selected = next
	selection_changed.emit(selected)


func b1_pressed() -> void:
	_dragging = true
	_moved_during_press = false


# R-32: se decide al soltar. Si el joystick se movió en algún momento de la
# pulsación fue arrastre; si no, el nodo seleccionado pasa a ser el origen.
func b1_released() -> void:
	if not _dragging:
		return
	_dragging = false
	if _moved_during_press:
		return
	_model.set_origin(selected)
	origin_changed.emit(selected)


func b2_pressed() -> void:
	_variants[selected] = (_variants[selected] + 1) % Config.VARIANT_COUNT
	variant_changed.emit(selected, _variants[selected])


func b3_pressed() -> void:
	_adjusting_brightness = true


func b3_released() -> void:
	_adjusting_brightness = false


# Una vez por frame: aplica arrastre (R-22) o brillo (R-35) según el gesto.
func update(direction: Vector2, delta: float) -> void:
	if _dragging:
		if direction != Vector2.ZERO:
			# Cuenta como movimiento aunque la geometría impida mover el nodo:
			# R-32 habla del joystick, no de la posición resultante.
			_moved_during_press = true
			_model.move_node(selected, direction, delta)
	elif _adjusting_brightness and direction.y != 0.0:
		# Arriba es -y en pantalla, y arriba tiene que aclarar.
		_set_brightness(_brightness - direction.y * Config.BRIGHTNESS_SPEED * delta)


func _set_brightness(value: float) -> void:
	var clamped := clampf(value, 0.0, 1.0)
	if is_equal_approx(clamped, _brightness):
		return
	_brightness = clamped
	brightness_changed.emit(_brightness)
