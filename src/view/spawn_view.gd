# Destello de siembra (R-33): mientras B2 se mantiene en Macro, un resplandor
# crece en el punto donde va a aparecer el organismo. El progreso lo decide
# World (spawn_charge_progress); esta vista solo lo dibuja y nunca toca reglas.
# Recibe el mundo con setup() y avanza con update_visuals(delta).

class_name SpawnView
extends Node2D

const CORE_RADIUS_MIN := 6.0
const CORE_RADIUS_MAX := 30.0
const HALO_RADIUS_MIN := 24.0
const HALO_RADIUS_MAX := 130.0
const PULSE_HZ := 3.0
const PULSE_DEPTH := 0.08
const HALO_ALPHA_MIN := 0.05
const HALO_ALPHA_MAX := 0.30
const RING_WIDTH := 2.5

var _world: World
var _time := 0.0


func setup(world: World) -> void:
	_world = world
	visible = false


func update_visuals(delta: float) -> void:
	if _world == null or not _world.is_spawn_charging():
		visible = false
		return
	_time += delta
	visible = true
	position = _world.spawn_point()
	queue_redraw()


func _draw() -> void:
	if _world == null:
		return
	var progress := _world.spawn_charge_progress()
	var color := OrganismView.family_node_color(_world.next_family())
	var pulse := 1.0 + PULSE_DEPTH * sin(_time * TAU * PULSE_HZ)
	var halo := lerpf(HALO_RADIUS_MIN, HALO_RADIUS_MAX, progress) * pulse
	var core := lerpf(CORE_RADIUS_MIN, CORE_RADIUS_MAX, progress) * pulse

	# Tres capas: halo tenue, núcleo y anillo. El crecimiento y el brillo leen
	# como una carga que está por completarse.
	draw_circle(Vector2.ZERO, halo, Color(color, lerpf(HALO_ALPHA_MIN, HALO_ALPHA_MAX, progress)))
	draw_circle(Vector2.ZERO, core, Color(color, 0.15 + 0.35 * progress))
	draw_arc(Vector2.ZERO, core, 0.0, TAU, 48, Color(color, 0.55 + 0.40 * progress), RING_WIDTH, true)
