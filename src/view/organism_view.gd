# Vista de depuración de un organismo (M3): dibuja cada nodo como un punto y
# cada hifa como la polilínea de la curva que ya calculó el modelo.
# Recibe el modelo con setup(); no decide nada del juego, solo pinta lo que el
# núcleo resolvió. El nodo origen se marca con otro color.
# Sin animación: el pulso y el flash llegan en M4.

class_name OrganismView
extends Node2D

const NODE_RADIUS := 7.0
const ORIGIN_RADIUS := 10.0
const EDGE_WIDTH := 2.0
const COLOR_NODE := Color(0.65, 0.85, 0.75)
const COLOR_ORIGIN := Color(1.0, 0.85, 0.45)
const COLOR_EDGE := Color(0.35, 0.55, 0.5, 0.8)

var _model: OrganismModel


func setup(model: OrganismModel) -> void:
	_model = model
	queue_redraw()


func _draw() -> void:
	if _model == null:
		return

	# Primero las hifas: los nodos tienen que quedar encima.
	for i in _model.n:
		var points := _model.edge_curve(i).get_baked_points()
		if points.size() >= 2:
			draw_polyline(points, COLOR_EDGE, EDGE_WIDTH, true)

	for i in _model.n:
		if i == _model.origin:
			draw_circle(_model.nodes[i], ORIGIN_RADIUS, COLOR_ORIGIN)
		else:
			draw_circle(_model.nodes[i], NODE_RADIUS, COLOR_NODE)
