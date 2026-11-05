# Vista de los puentes (R-27, R-28): dibuja cada puente como un filamento
# luminoso tensado entre el nodo emisor y el receptor, y el eco como un punto
# que viaja por ese filamento durante BRIDGE_DELAY_TICKS. Recibe el mundo y el
# reloj; no decide reglas. Los extremos siguen a los nodos, así la deriva y el
# arrastre mueven el filamento sin recalcular nada en el núcleo.

class_name BridgesView
extends Node2D

# Todo lo de acá es cosmético: se ajusta a ojo.
const FILAMENT_WIDTH := 1.8
const FILAMENT_ALPHA := 0.34
const FILAMENT_BOW := 0.05
const FILAMENT_SEGMENTS := 18
const ECHO_RADIUS := 4.5
const ECHO_HALO := 2.2
const ECHO_ALPHA := 0.95

var _world: World
var _clock: Clock


func setup(world: World, clock: Clock) -> void:
	_world = world
	_clock = clock


# El filamento y los ecos se mueven todos los frames: el dibujo se rehace.
func update_visuals() -> void:
	queue_redraw()


func _draw() -> void:
	if _world == null:
		return
	for bridge in _world.bridges.bridges:
		var source := _world.find_by_id(bridge.from_id)
		var target := _world.find_by_id(bridge.to_id)
		if source == null or target == null:
			continue
		var from := _node_world(source, bridge.from_node)
		var to := _node_world(target, bridge.to_node)
		var color := OrganismView.family_pulse_color(source.family)
		draw_polyline(_filament(from, to), Color(color, FILAMENT_ALPHA), FILAMENT_WIDTH, true)
	for echo in _world.bridges.echoes:
		_draw_echo(echo)


# El eco recorre la misma curva que el filamento, de A hacia B. La fracción
# sale del tick y de la fracción del reloj: la vista no lleva estado propio.
func _draw_echo(echo: Dictionary) -> void:
	var source := _world.find_by_id(echo.from_id)
	var target := _world.find_by_id(echo.to_id)
	if source == null or target == null:
		return
	var from := _node_world(source, echo.from_node)
	var to := _node_world(target, echo.to_node)
	var delay := maxf(1.0, float(Config.BRIDGE_DELAY_TICKS))
	var start := float(echo.tick) - delay
	var now := float(_clock.tick) + _clock.fraction()
	var u := clampf((now - start) / delay, 0.0, 1.0)
	var position := _point_on(from, to, u)
	var color := OrganismView.family_pulse_color(source.family)
	draw_circle(position, ECHO_RADIUS * ECHO_HALO, Color(color, 0.16))
	draw_circle(position, ECHO_RADIUS, Color(color, ECHO_ALPHA))


func _filament(from: Vector2, to: Vector2) -> PackedVector2Array:
	var control := _control_point(from, to)
	var points := PackedVector2Array()
	for i in FILAMENT_SEGMENTS + 1:
		var t := float(i) / float(FILAMENT_SEGMENTS)
		points.append(_quadratic(from, control, to, t))
	return points


# Curva cuadrática con un arco apenas marcado: un filamento tensado, no una
# recta geométrica. El control se corre perpendicular al segmento.
func _control_point(from: Vector2, to: Vector2) -> Vector2:
	var chord := to - from
	if chord.length_squared() <= 0.0:
		return from
	var normal := Vector2(-chord.y, chord.x).normalized()
	return (from + to) * 0.5 + normal * chord.length() * FILAMENT_BOW


func _point_on(from: Vector2, to: Vector2, t: float) -> Vector2:
	return _quadratic(from, _control_point(from, to), to, t)


func _quadratic(from: Vector2, control: Vector2, to: Vector2, t: float) -> Vector2:
	return from.lerp(control, t).lerp(control.lerp(to, t), t)


func _node_world(organism: OrganismState, node_index: int) -> Vector2:
	if node_index < 0 or node_index >= organism.model.nodes.size():
		return organism.position
	return organism.position + organism.model.nodes[node_index]
