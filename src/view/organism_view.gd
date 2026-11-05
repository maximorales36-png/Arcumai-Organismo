# Vista de un organismo: dibuja el micelio y el pulso como una cabeza luminosa
# con cola. Además: bulbos que respiran, motas de flujo, anticipación y flash al
# disparar, nodo origen destacado, anillo de selección y aura de foco.
# Recibe el modelo con setup(), la fase continua con update_visuals() y los
# disparos con flash(). La escala, la posición y la cámara las decide la escena.
# Todo lo visual es cosmético: la posición del pulso la decide
# OrganismModel.pulse_at (R-21) y el suavizado no toca el núcleo.

class_name OrganismView
extends Node2D

# El suavizado de R-21 es visual: constante de tiempo de 80 ms.
const SMOOTH_TIME := 0.08

const NODE_RADIUS := 9.0
const ORIGIN_RADIUS := 12.0
const ORIGIN_HALO := 2.4
const EDGE_WIDTH := 1.6

const HEAD_RADIUS := 5.0
const HEAD_HALO := 2.4
const TRAIL_POINTS := 26

# Respiración cosmética: no entra en el modelo ni altera tiempos (DISENO 5.1).
const BREATH_DEPTH := 0.06
const BREATH_SPEED := 1.6
const BREATH_PHASE_STEP := 1.3

# Anticipación: el nodo se hincha en el tick previo a la llegada (DISENO 5.2).
const ANTICIPATION_DEPTH := 0.35

# Flash y onda al disparar.
const FLASH_DECAY := 3.5
const WAVE_RADIUS := 26.0

# Motas de flujo: deriva constante por el filamento (DISENO 5.2).
const FLOW_SPEED := 45.0
const FLOW_DOTS := 3
const FLOW_DOT_RADIUS := 1.6
const FLOW_ALPHA := 0.35

# Anillo de selección: el nodo que el joystick está apuntando (Micro).
const SELECTION_GAP := 6.0
const SELECTION_WIDTH := 1.5

# Flechas de arrastre (R-22): aparecen mientras B1 está apretado para indicar
# que el joystick puede mover el nodo en cualquier dirección.
const DRAG_ARROW_LENGTH := 14.0
const DRAG_ARROW_HEAD := 5.0
const DRAG_ARROW_WIDTH := 2.0
const DRAG_ARROW_PULSE_HZ := 2.0

# Aura de Macro: el organismo seleccionado (DISENO 5.3).
const AURA_GAP := 14.0
const AURA_ALPHA := 0.10
const AURA_RING_ALPHA := 0.55
const AURA_RING_WIDTH := 3.0

# Temblor de rechazo (R-31): 150 ms sobre el nodo o el organismo seleccionado.
const SHAKE_TIME := 0.15
const SHAKE_HZ := 12.0
const SHAKE_AMPLITUDE := 4.0

# Recuperación visual al soltar B4 antes de disolver (R-34).
const FADE_TIME := 0.12

var _model: OrganismModel
var _base_hue := 0.38
var _time := 0.0
var _phase := -1.0
var _head := Vector2.ZERO
var _has_head := false
var _trail: Array[Vector2] = []
var _flash: Array[float] = []
var _selected := -1
var _drag_hint := false
var _aura_strength := 0.0
var _fade_target := 1.0
var _shake_node := -1
var _shake_whole := false
var _shake_left := 0.0


func setup(model: OrganismModel, family: int = 0) -> void:
	_model = model
	# Cada familia tiene su matiz (DISENO 5.1): las 3 quedan separadas 0,24.
	_base_hue = family_hue(family)
	_flash.resize(model.n)
	_flash.fill(0.0)
	_trail.clear()
	_has_head = false
	_selected = -1
	_drag_hint = false
	_aura_strength = 0.0
	_shake_node = -1
	_shake_whole = false
	_shake_left = 0.0
	_fade_target = 1.0
	modulate.a = 1.0
	queue_redraw()


# Anillo del nodo seleccionado en Micro; -1 lo apaga.
func set_selection(node_index: int) -> void:
	_selected = node_index
	queue_redraw()


# R-22: mientras B1 está apretado, el nodo seleccionado muestra flechas de
# arrastre. Es una ayuda visual, no cambia la regla de movimiento.
func set_drag_hint(value: bool) -> void:
	if _drag_hint == value:
		return
	_drag_hint = value
	queue_redraw()


# Intensidad del aura de foco (0 a 1). En Macro está en 1 para el seleccionado;
# la cámara la apaga al entrar a Micro, donde el centro ya dice cuál es.
func set_aura_strength(value: float) -> void:
	_aura_strength = clampf(value, 0.0, 1.0)
	queue_redraw()


# Opacidad objetivo: 1 normal, menos mientras se mantiene B4 (R-34).
func set_fade_target(value: float) -> void:
	_fade_target = clampf(value, 0.0, 1.0)


func flash(node_index: int) -> void:
	if _model == null:
		return
	var index := posmod(node_index, _model.n)
	if index < _flash.size():
		_flash[index] = 1.0


# Temblor de un nodo (Micro).
func shake(node_index: int) -> void:
	if _model == null:
		return
	_shake_node = posmod(node_index, _model.n)
	_shake_whole = false
	_shake_left = SHAKE_TIME


# Temblor de todo el organismo (Macro): el elemento seleccionado es el organismo.
func shake_organism() -> void:
	_shake_whole = true
	_shake_left = SHAKE_TIME


# Avanza la animación visual. `phi_f` es la fase continua que calcula la escena
# (R-21); `delta` solo mueve el suavizado, la opacidad y las motas.
func update_visuals(phi_f: float, delta: float) -> void:
	if _model == null:
		return
	_time += delta
	_phase = phi_f
	_shake_left = maxf(0.0, _shake_left - delta)
	modulate.a = lerpf(modulate.a, _fade_target, 1.0 - exp(-delta / FADE_TIME))
	_update_head(phi_f, delta)
	for i in _flash.size():
		_flash[i] = maxf(0.0, _flash[i] - delta * FLASH_DECAY)
	queue_redraw()


func _draw() -> void:
	if _model == null:
		return
	var whole := _whole_shake_offset()
	if whole != Vector2.ZERO:
		draw_set_transform(whole, 0.0, Vector2.ONE)
	if _aura_strength > 0.0:
		_draw_aura()
	_draw_edges()
	_draw_flow()
	_draw_nodes()
	_draw_pulse()


func _draw_aura() -> void:
	var radius := Config.r_max(_model.n) + AURA_GAP
	var color := _pulse_color()
	draw_circle(Vector2.ZERO, radius, Color(color, AURA_ALPHA * _aura_strength))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(color, AURA_RING_ALPHA * _aura_strength), AURA_RING_WIDTH, true)


func _update_head(phi_f: float, delta: float) -> void:
	var pulse := _model.pulse_at(phi_f)
	if not pulse["active"]:
		_trail.clear()
		_has_head = false
		return

	var target := _point_on_edge(int(pulse["edge"]), float(pulse["u"]))
	if not _has_head:
		_head = target
		_has_head = true
	else:
		# Suavizado exponencial: el peso no depende de los FPS. Absorbe los
		# saltos que producen las ediciones sin tocar el tiempo musical.
		_head = _head.lerp(target, 1.0 - exp(-delta / SMOOTH_TIME))
	_trail.push_front(_head)
	if _trail.size() > TRAIL_POINTS:
		_trail.pop_back()


func _draw_edges() -> void:
	var color := _node_color().darkened(0.55)
	for i in _model.n:
		var points := _model.edge_curve(i).get_baked_points()
		if points.size() >= 2:
			draw_polyline(points, color, EDGE_WIDTH, true)


func _draw_flow() -> void:
	var color := Color(_pulse_color(), FLOW_ALPHA)
	for i in _model.n:
		var length := _model.edge_lengths[i]
		if length <= 0.0:
			continue
		var curve := _model.edge_curve(i)
		for k in FLOW_DOTS:
			# Fase fija por mota: no hace falta azar y así la vista es estable.
			var phase := fposmod(float(i) * 0.37 + float(k) / float(FLOW_DOTS), 1.0)
			var offset := fposmod(_time * FLOW_SPEED + phase * length, length)
			draw_circle(curve.sample_baked(offset), FLOW_DOT_RADIUS, color)


func _draw_nodes() -> void:
	for i in _model.n:
		var node := _model.nodes[i] + _shake_offset(i)
		var breath := 1.0 + BREATH_DEPTH * sin(_time * BREATH_SPEED + float(i) * BREATH_PHASE_STEP)
		var swell := 1.0 + ANTICIPATION_DEPTH * _anticipation(i)
		var is_origin := i == _model.origin
		var base_radius := ORIGIN_RADIUS if is_origin else NODE_RADIUS
		var radius := base_radius * breath * swell
		var color := _node_color().lerp(Color.WHITE, _flash[i])

		if i == _selected:
			# El anillo dice qué nodo va a recibir el próximo gesto.
			draw_arc(node, radius + SELECTION_GAP, 0.0, TAU, 40, Color(_pulse_color(), 0.85), SELECTION_WIDTH, true)
			if _drag_hint:
				_draw_drag_arrows(node, radius)
		if is_origin:
			draw_circle(node, radius * ORIGIN_HALO, Color(color, 0.14))
		if _flash[i] > 0.0:
			# La onda se aleja y se apaga mientras el bulbo vuelve a su color.
			var wave := 1.0 - _flash[i]
			draw_arc(node, radius + wave * WAVE_RADIUS, 0.0, TAU, 32, Color(color, _flash[i] * 0.7), 2.0, true)
		draw_circle(node, radius, color)


# Cuatro flechas alrededor del nodo seleccionado. El pulso lento de opacidad
# las hace notar sin tapar la geometría ni el anillo de selección.
func _draw_drag_arrows(center: Vector2, radius: float) -> void:
	var alpha := 0.55 + 0.35 * sin(_time * TAU * DRAG_ARROW_PULSE_HZ)
	var color := Color(_pulse_color(), clampf(alpha, 0.0, 1.0))
	var start_radius := radius + SELECTION_GAP + 3.0
	var directions: Array[Vector2] = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	for direction in directions:
		var tail := center + direction * start_radius
		var tip := tail + direction * DRAG_ARROW_LENGTH
		var back := -direction
		var side := Vector2(-direction.y, direction.x)
		draw_line(tail, tip, color, DRAG_ARROW_WIDTH, true)
		draw_line(tip, tip + back * DRAG_ARROW_HEAD + side * DRAG_ARROW_HEAD * 0.7, color, DRAG_ARROW_WIDTH, true)
		draw_line(tip, tip + back * DRAG_ARROW_HEAD - side * DRAG_ARROW_HEAD * 0.7, color, DRAG_ARROW_WIDTH, true)


func _draw_pulse() -> void:
	if not _has_head:
		return
	var color := _pulse_color()
	# Cola: círculos que se achican y se apagan hacia atrás, como un cometa
	# (DISENO 5.2). Se dibuja del más viejo al más nuevo para que la cabeza quede
	# encima y la estela no tape el borde delantero.
	var trail_color := _trail_color()
	for k in range(_trail.size() - 1, 0, -1):
		var fade := 1.0 - float(k) / float(_trail.size())
		draw_circle(_trail[k], HEAD_RADIUS * 0.75 * fade, Color(trail_color, fade * fade * 0.6))
	draw_circle(_head, HEAD_RADIUS * HEAD_HALO, Color(color, 0.16))
	draw_circle(_head, HEAD_RADIUS, color)


# Temblor de rechazo (R-31): oscilación horizontal corta que se apaga.
func _shake_offset(node_index: int) -> Vector2:
	if _shake_whole or node_index != _shake_node or _shake_left <= 0.0:
		return Vector2.ZERO
	var strength := _shake_left / SHAKE_TIME
	return Vector2(sin(_time * TAU * SHAKE_HZ) * SHAKE_AMPLITUDE * strength, 0.0)


# Temblor de todo el dibujo: se aplica como transformación de dibujo para no
# mover la posición del nodo (la escena la usa para el layout de Macro).
func _whole_shake_offset() -> Vector2:
	if not _shake_whole or _shake_left <= 0.0:
		return Vector2.ZERO
	var strength := _shake_left / SHAKE_TIME
	return Vector2(sin(_time * TAU * SHAKE_HZ) * SHAKE_AMPLITUDE * strength, 0.0)


# Cuánto falta (en ticks) para que el pulso llegue a este nodo, como hinchazón
# de 0 a 1 durante el último tick. Se usa fposmod para que la anticipación
# también funcione al final del ciclo, cuando el arranque ya pasó.
func _anticipation(node_index: int) -> float:
	var p := posmod(node_index - _model.origin, _model.n)
	var until := fposmod(float(_model.starts[p]) - _phase, float(_model.cycle_ticks))
	if until > 0.0 and until <= 1.0:
		return 1.0 - until
	return 0.0


func _point_on_edge(edge: int, u: float) -> Vector2:
	var length := _model.edge_lengths[edge]
	if length <= 0.0:
		return _model.nodes[edge]
	return _model.edge_curve(edge).sample_baked(clampf(u, 0.0, 1.0) * length)


func _node_color() -> Color:
	return Color.from_hsv(_base_hue, 0.45, 0.95)


func _pulse_color() -> Color:
	return Color.from_hsv(fposmod(_base_hue + 0.08, 1.0), 0.25, 1.0)


# Matiz de la familia (DISENO 5.1): las 3 quedan separadas 0,24. La comparten
# la vista del organismo y la de los puentes para que el color sea el mismo.
static func family_hue(family: int) -> float:
	return fposmod(0.38 + 0.24 * float(family), 1.0)


static func family_pulse_color(family: int) -> Color:
	return Color.from_hsv(fposmod(family_hue(family) + 0.08, 1.0), 0.25, 1.0)


# Color de los nodos de una familia: lo usan el aviso de borrado y el destello
# de siembra para anticipar el color del organismo.
static func family_node_color(family: int) -> Color:
	return Color.from_hsv(family_hue(family), 0.45, 0.95)


# La cola usa el matiz saturado: a baja opacidad el color pálido se ve gris.
func _trail_color() -> Color:
	return Color.from_hsv(fposmod(_base_hue + 0.08, 1.0), 0.55, 1.0)
