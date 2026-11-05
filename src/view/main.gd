# Escena principal (M9): sesión de instalación. Arranca en Micro con un
# organismo (N_DEFAULT, familia 0) y se reinicia por inactividad con un fundido
# de 2 s (R-37). Traduce los gestos a las reglas de World o de la MicroSession
# del organismo enfocado; crea una vista y un bus por organismo. Las reglas
# viven en World, MicroSession, SessionReset y OrganismBus, no acá.

extends Control

const MODE_MACRO := 0
const MODE_MICRO := 1

# Los placeholders están numerados 1..3 en el archivo (R-25).
const SAMPLE_PATH := "res://audio/placeholder/family_%d_%d.wav"

# El destello de siembra se carga por ruta y no por class_name: así la escena
# no depende de que el editor haya registrado la clase global del script.
const SpawnViewScript := preload("res://src/view/spawn_view.gd")

# Cada voz deja 9 dB de headroom: con 5 organismos y puentes la suma de picos
# puede superar 0 dBFS. El limitador del Master (default_bus_layout.tres) es la
# red de seguridad; este margen evita que tenga que trabajar de más (V-11).
const NODE_SAMPLE_DB := -9.0
# El metrónomo queda silenciado por ahora: a -80 dB no se oye, así no compite
# con las notas de los organismos.
const METRONOME_DB := -80
const REJECT_DB := -18.0
const REJECT_FREQ_HZ := 110.0
const REJECT_SEC := 0.09

# Escala aparente de Micro: la misma de M4/M5, para poder juzgar el pulso.
const MICRO_VIEW_SCALE := 3.0
# Fracción del medio-pantalla que el organismo puede ocupar antes de que la
# cámara retroceda. Con 0.8 el encuadre de siempre no cambia y la cámara solo
# se aleja cuando un nodo se arrastra hasta el borde.
const MICRO_FIT_MARGIN := 0.8
# MACRO_ORG_SCALE (0.3) es la escala de dibujo de la especificación. Este
# multiplicador cosmético mantiene legibles los nodos en la ventana de
# desarrollo 1280x720; la calibración final depende de la resolución del
# arcumai (M9). La cámara de M7 anima el zoom, no cambia esta escala.
# 3.0 agranda los organismos en Macro sin tocar el zoom de Micro.
const MACRO_DEBUG_SCALE := 3.0

@onready var _tick_label: Label = $Overlay/TickLabel
@onready var _beat_label: Label = $Overlay/BeatLabel
@onready var _scale_label: Label = $Overlay/ScaleLabel
@onready var _world_label: Label = $Overlay/WorldLabel
@onready var _session_label: Label = $Overlay/SessionLabel
@onready var _action_label: Label = $Overlay/ActionLabel
@onready var _note_label: Label = $Overlay/NoteLabel
@onready var _fps_label: Label = $Overlay/FpsLabel
@onready var _metronome: AudioStreamPlayer = $Metronome
@onready var _world_layer: Node2D = $WorldLayer
@onready var _voices: VoicePool = $VoicePool
@onready var _fade: ColorRect = $Fade
@onready var _status_label: Label = $StatusLabel

var _clock := Clock.new()
var _router := InputRouter.new()
var _reset := SessionReset.new()
var _world: World
var _mode := MODE_MICRO
# 0 = Macro, 1 = Micro. La cámara y el aura lo siguen; el modo de input cambia
# en el acto para que los botones respondan sin esperar la animación.
var _zoom := 1.0
var _zoom_target := 1.0
# Escala de cámara de Micro: la normal y la que hace falta para que el
# organismo entero entre en cuadro.
var _micro_zoom := MICRO_VIEW_SCALE / (Config.MACRO_ORG_SCALE * MACRO_DEBUG_SCALE)
var _micro_zoom_target := _micro_zoom
var _samples: Array[AudioStream] = []
var _reject_stream: AudioStream
var _scale: Array = []
var _tonic: int = 0
var _stick := Vector2.ZERO
var _views: Dictionary = {}
var _buses: Dictionary = {}
var _bridges_view: BridgesView
var _spawn_view: SpawnViewScript


func _ready() -> void:
	_metronome.stream = ClickStream.make()
	_metronome.volume_db = METRONOME_DB
	_reject_stream = ClickStream.make(REJECT_FREQ_HZ, REJECT_SEC)
	_clock.tick_emitted.connect(_on_tick_emitted)

	for family in Config.FAMILY_COUNT:
		for variant in Config.VARIANT_COUNT:
			_samples.append(load(SAMPLE_PATH % [family + 1, variant]))

	# El destello de siembra y los puentes se dibujan detrás de los organismos:
	# se agregan antes que las vistas de organismo y se reusan en cada sesión.
	_spawn_view = SpawnViewScript.new()
	_world_layer.add_child(_spawn_view)
	_bridges_view = BridgesView.new()
	_world_layer.add_child(_bridges_view)

	_router.nav_step.connect(_on_nav_step)
	_router.stick_changed.connect(_on_stick_changed)
	_router.button_pressed.connect(_on_button_pressed)
	_router.button_released.connect(_on_button_released)

	# R-37: el reinicio se avisa en el punto negro del fundido.
	_reset.reset_due.connect(_start_session)

	# El overlay es de desarrollo: en el export de la instalación no se muestra.
	$Overlay.visible = OS.is_debug_build()

	_start_session()
	get_viewport().size_changed.connect(_layout_views)


# R-37: estado inicial de una sesión. Un organismo N_DEFAULT de la familia 0 en
# Micro, sin puentes, con escala y tónica nuevas. El reloj no se toca.
func _start_session() -> void:
	_dispose_world()

	# Cada sesión sortea de nuevo escala y tónica (R-24, R-37). La semilla sale
	# del reloj del sistema: el juego no debe repetir la misma pieza siempre.
	var rng := RandomNumberGenerator.new()
	rng.seed = Time.get_ticks_usec()
	var scale_index := rng.randi_range(0, Config.SCALES.size() - 1)
	_scale = Config.SCALES[scale_index]
	_tonic = rng.randi_range(0, 11)
	_scale_label.text = "escala: %d   tónica: %d" % [scale_index + 1, _tonic]

	_world = World.new(rng)
	# El mundo nuevo necesita el tick actual para anclar bien el organismo.
	_world.set_tick(_clock.tick)
	_bridges_view.setup(_world, _clock)
	_spawn_view.setup(_world)
	_world.organism_added.connect(_on_organism_added)
	_world.organism_removed.connect(_on_organism_removed)
	_world.organism_rebuilt.connect(_on_organism_rebuilt)
	_world.selection_changed.connect(_on_world_selection_changed)
	_world.rejected.connect(_on_world_rejected)

	_mode = MODE_MICRO
	_zoom = 1.0
	_zoom_target = 1.0
	_micro_zoom = _base_micro_zoom()
	_micro_zoom_target = _micro_zoom
	_action_label.text = "última acción: (ninguna)"
	_note_label.text = "última nota: (ninguna)"
	_world.add_organism(Config.N_DEFAULT)
	_world.select(0)
	_reset.note_activity()

	_update_focus_targets()
	_layout_views()
	_update_labels()


# Suelta la sesión anterior: corta sus voces, libera vistas y buses y descarta
# el mundo. Las señales del mundo viejo mueren con él (RefCounted).
func _dispose_world() -> void:
	if _world == null:
		return
	for organism in _world.organisms:
		var bus: OrganismBus = _buses.get(organism.id)
		if bus != null:
			_voices.stop_bus(bus.bus_name())
			bus.dispose()
		var view: OrganismView = _views.get(organism.id)
		if view != null:
			view.queue_free()
	_buses.clear()
	_views.clear()
	_spawn_view.setup(null)
	_world = null


# El reloj se alimenta con el delta real: es el único lugar donde el delta
# decide tiempo musical (R-02). El mundo lo usa solo para deriva y disolución.
func _process(delta: float) -> void:
	_clock.advance(delta)
	_router.update(delta)
	if _mode == MODE_MICRO:
		var organism := _world.selected_organism()
		if organism != null:
			organism.session.update(_stick, delta)
	_world.update(delta)
	_update_fades()
	_update_zoom(delta)
	_update_buses(delta)
	_layout_views()
	for organism in _world.organisms:
		var view: OrganismView = _views.get(organism.id)
		if view != null and view.visible:
			view.update_visuals(_current_phase_f(organism.model), delta)
	_bridges_view.update_visuals()
	_spawn_view.update_visuals(delta)
	# R-37: la inactividad se mide al final del frame; si vence, el fundido
	# arranca y el mundo se reconstruye en el punto negro.
	_reset.update(delta, _router.is_any_active())
	_fade.color.a = _reset.fade_alpha()
	_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()


# Fase continua del organismo: tick entero más la fracción que ya corrió el
# reloj. Antes del ancla no hay pulso y se informa -1 (R-17, R-21).
func _current_phase_f(model: OrganismModel) -> float:
	var phase := model.phase_at(_clock.tick)
	if phase < 0:
		return -1.0
	return float(phase) + _clock.fraction()


func _on_tick_emitted(tick: int) -> void:
	_tick_label.text = "tick: %d" % tick
	_beat_label.text = "beat: %d" % _beat_of(tick)
	if (tick - 1) % Config.TICKS_PER_BEAT == 0:
		_metronome.play()
	# R-04: cada organismo evalúa sus disparos en orden de creación.
	_world.set_tick(tick)
	for organism in _world.organisms:
		organism.model.on_tick(tick)
	# R-04: recién después de los disparos de los organismos vencen los ecos.
	_world.flush_echoes(tick)


# La altura del nodo se convierte en nota al momento del disparo: si se movió
# el nodo, la nota nueva sale sola (R-23) sin recalcular nada por tick. Los
# ecos pasan por acá igual que los disparos propios: sonido y flash del nodo.
func _on_node_fired(organism_id: int, node_index: int, tick: int, is_echo: bool) -> void:
	_world.on_node_fired(organism_id, node_index, tick, is_echo)
	var organism := _world.find_by_id(organism_id)
	if organism == null:
		return
	var view: OrganismView = _views.get(organism.id)
	if view != null:
		view.flash(node_index)
	_play_node(organism, node_index)


# Cada nodo suena con su variante y en el bus de su organismo (R-25, R-26).
func _play_node(organism: OrganismState, node_index: int) -> void:
	var midi := PitchMapping.midi_for_node(organism.model.nodes[node_index].y, organism.model.n, _scale, _tonic)
	var pitch := PitchMapping.pitch_scale_for_midi(midi)
	var variant := organism.session.variant_of(node_index)
	var sample := _samples[organism.family * Config.VARIANT_COUNT + variant]
	var bus: OrganismBus = _buses.get(organism.id)
	var bus_name := bus.bus_name() if bus != null else "Master"
	_voices.play(sample, pitch, NODE_SAMPLE_DB, bus_name)
	_note_label.text = "última nota: midi %d   pitch %.2f" % [midi, pitch]


func _on_nav_step(direction: Vector2) -> void:
	_reset.note_activity()
	if _mode == MODE_MACRO:
		_world.nav_step(direction)
		return
	var organism := _world.selected_organism()
	if organism != null:
		organism.session.nav_step(direction)


func _on_stick_changed(direction: Vector2) -> void:
	_reset.note_activity()
	_stick = direction
	# R-28: con B3 apretado el joystick conecta, no navega. Se usa el cambio de
	# dirección (sin auto-repetición) para que un gesto cree o quite un puente.
	if _mode == MODE_MACRO and _world.is_connecting() and direction != Vector2.ZERO:
		_world.connect_toward(direction)
		_update_labels()


func _on_button_pressed(action: String) -> void:
	_reset.note_activity()
	if _mode == MODE_MACRO:
		_press_in_macro(action)
	else:
		_press_in_micro(action)


func _on_button_released(action: String) -> void:
	_reset.note_activity()
	if _mode == MODE_MACRO:
		_release_in_macro(action)
	else:
		_release_in_micro(action)


# En Macro: B1 entra a Micro (con el zoom de M7), B2 siembra, B3 es puentes
# (M8) y B4 disuelve. B1 se rechaza mientras hay una siembra o disolución en
# curso: entrar a Micro dejaría el gesto a medias y la especificación no define
# qué hacer con la siembra abierta.
func _press_in_macro(action: String) -> void:
	match action:
		"btn_1":
			if _world.is_spawning() or _world.is_dissolving() or _world.is_spawn_charging():
				_reject(_world.selected_organism())
			else:
				_enter_micro()
		"btn_2":
			_world.b2_pressed()
		"btn_3":
			_world.b3_pressed()
		"btn_4":
			_world.b4_pressed()


func _release_in_macro(action: String) -> void:
	match action:
		"btn_2":
			_world.b2_released()
		"btn_3":
			_world.b3_released()
		"btn_4":
			_world.b4_released()


# En Micro: los verbos de M5 sobre el organismo enfocado; B4 vuelve a Macro.
func _press_in_micro(action: String) -> void:
	var organism := _world.selected_organism()
	if organism == null:
		return
	match action:
		"btn_1":
			organism.session.b1_pressed()
		"btn_2":
			organism.session.b2_pressed()
		"btn_3":
			organism.session.b3_pressed()
		"btn_4":
			_exit_micro()


func _release_in_micro(action: String) -> void:
	var organism := _world.selected_organism()
	if organism == null:
		return
	match action:
		"btn_1":
			organism.session.b1_released()
		"btn_3":
			organism.session.b3_released()


func _enter_micro() -> void:
	var organism := _world.selected_organism()
	if organism == null:
		return
	_mode = MODE_MICRO
	_zoom_target = 1.0
	_world.reset_gestures()
	organism.session.reset_gestures()
	_update_focus_targets()
	_layout_views()
	_update_labels()


func _exit_micro() -> void:
	var organism := _world.selected_organism()
	if organism != null:
		organism.session.reset_gestures()
	_mode = MODE_MACRO
	_zoom_target = 0.0
	_world.reset_gestures()
	_update_focus_targets()
	_layout_views()
	_update_labels()


func _on_organism_added(organism: OrganismState) -> void:
	var view := OrganismView.new()
	view.setup(organism.model, organism.family)
	view.set_brightness(organism.session.brightness())
	_world_layer.add_child(view)
	_views[organism.id] = view

	# R-26: cada organismo tiene su bus con su propio pasabajos.
	var bus := OrganismBus.new("organism_%d" % organism.id)
	bus.set_brightness(organism.session.brightness())
	_buses[organism.id] = bus

	organism.model.node_fired.connect(_on_node_fired)
	organism.session.selection_changed.connect(_on_node_selection_changed)
	organism.session.origin_changed.connect(_on_node_origin_changed)
	organism.session.variant_changed.connect(_on_node_variant_changed)
	organism.session.brightness_changed.connect(_on_node_brightness_changed)
	organism.session.rejected.connect(_on_node_rejected)
	_update_focus_targets()
	_layout_views()
	_update_labels()


func _on_organism_removed(organism: OrganismState) -> void:
	organism.model.node_fired.disconnect(_on_node_fired)
	organism.session.selection_changed.disconnect(_on_node_selection_changed)
	organism.session.origin_changed.disconnect(_on_node_origin_changed)
	organism.session.variant_changed.disconnect(_on_node_variant_changed)
	organism.session.brightness_changed.disconnect(_on_node_brightness_changed)
	organism.session.rejected.disconnect(_on_node_rejected)

	var bus: OrganismBus = _buses.get(organism.id)
	if bus != null:
		_voices.stop_bus(bus.bus_name())
		bus.dispose()
		_buses.erase(organism.id)

	var view: OrganismView = _views.get(organism.id)
	if view != null:
		view.queue_free()
		_views.erase(organism.id)

	_update_focus_targets()
	_layout_views()
	_update_labels()


# R-33: al cambiar n en vivo la geometría se regenera; la vista se rehace.
func _on_organism_rebuilt(organism: OrganismState) -> void:
	var view: OrganismView = _views.get(organism.id)
	if view != null:
		view.setup(organism.model, organism.family)
	_layout_views()
	_update_labels()


func _on_world_selection_changed(_organism: OrganismState) -> void:
	_update_focus_targets()
	_layout_views()
	_update_labels()


func _on_world_rejected() -> void:
	_reject(_world.selected_organism())


func _on_node_selection_changed(node_index: int) -> void:
	var organism := _world.selected_organism()
	if organism == null:
		return
	if _mode == MODE_MICRO:
		var view: OrganismView = _views.get(organism.id)
		if view != null:
			view.set_selection(node_index)
	_update_labels()


func _on_node_origin_changed(_node_index: int) -> void:
	_update_labels()


# El preview de B2 usa el mismo camino que un disparo: respuesta audible
# inmediata al cambiar de variante (criterio [OJO] de M5).
func _on_node_variant_changed(node_index: int, _variant: int) -> void:
	var organism := _world.selected_organism()
	if organism == null:
		return
	if _mode == MODE_MICRO:
		_play_node(organism, node_index)
	_update_labels()


func _on_node_brightness_changed(brightness: float) -> void:
	var organism := _world.selected_organism()
	if organism == null:
		return
	var bus: OrganismBus = _buses.get(organism.id)
	if bus != null:
		bus.set_brightness(brightness)
	# El mismo parámetro que abre el filtro también aclara u oscurece el
	# dibujo del organismo (R-26/R-35).
	var view: OrganismView = _views.get(organism.id)
	if view != null:
		view.set_brightness(brightness)
	_update_labels()


func _on_node_rejected() -> void:
	_reject(_world.selected_organism())


# R-31: sonido corto, grave y bajo más temblor sobre el elemento seleccionado.
func _reject(organism: OrganismState) -> void:
	_voices.play(_reject_stream, 1.0, REJECT_DB)
	if organism == null:
		return
	var view: OrganismView = _views.get(organism.id)
	if view == null:
		return
	if _mode == MODE_MACRO:
		view.shake_organism()
	else:
		view.shake(organism.session.selected)


# La cámara tarda ZOOM_TIME_S en llegar (DISENO 5.3). El delta solo anima la
# vista; ningún disparo depende de esto.
func _update_zoom(delta: float) -> void:
	_zoom = move_toward(_zoom, _zoom_target, delta / Config.ZOOM_TIME_S)
	_micro_zoom_target = _target_micro_zoom()
	_micro_zoom = move_toward(_micro_zoom, _micro_zoom_target, delta / Config.ZOOM_TIME_S)


# Escala de cámara normal de Micro: la que hace ver el organismo al tamaño de
# siempre.
func _base_micro_zoom() -> float:
	return MICRO_VIEW_SCALE / (Config.MACRO_ORG_SCALE * MACRO_DEBUG_SCALE)


# La cámara de Micro se aleja si el organismo no entra en cuadro: cuando un
# nodo se arrastra al borde, el centro visual se corre y con él la cámara.
func _target_micro_zoom() -> float:
	var base := _base_micro_zoom()
	var selected := _world.selected_organism()
	if selected == null:
		return base
	var center := selected.model.visual_center()
	var extent := 0.0
	for node in selected.model.nodes:
		extent = maxf(extent, node.distance_to(center))
	if extent <= 0.0:
		return base
	var size := get_viewport_rect().size
	var limit := minf(size.x, size.y) * 0.5 * MICRO_FIT_MARGIN
	var view_scale := Config.MACRO_ORG_SCALE * MACRO_DEBUG_SCALE
	return minf(base, limit / (extent * view_scale))


# R-36: el foco se funde en FOCUS_FADE_S. Se actualiza por frame porque la
# mezcla es audio, no tiempo musical.
func _update_buses(delta: float) -> void:
	for bus: OrganismBus in _buses.values():
		bus.update(delta)


# R-36: en Macro todos al frente; en Micro solo el enfocado. Los demás bajan
# de volumen y de corte, pero no desaparecen.
func _update_focus_targets() -> void:
	var focused := _world.selected_organism()
	for organism in _world.organisms:
		var bus: OrganismBus = _buses.get(organism.id)
		if bus == null:
			continue
		bus.set_focused(_mode == MODE_MACRO or organism == focused)


# La cámara encuadra el mundo entero en Macro y centra el organismo enfocado en
# Micro (DISENO 5.3). La escala de dibujo de los organismos no cambia: lo que
# cambia es la cámara, y _zoom la interpola durante ZOOM_TIME_S.
func _layout_views() -> void:
	var size := get_viewport_rect().size
	var fit := minf(size.x / Config.WORLD_SIZE.x, size.y / Config.WORLD_SIZE.y)
	var view_scale := Config.MACRO_ORG_SCALE * MACRO_DEBUG_SCALE
	var t := _smoothstep(_zoom)
	var selected := _world.selected_organism()
	var center := Config.WORLD_SIZE * 0.5
	if selected != null:
		# En Micro se centra el centro visual (caja de los nodos), no el origen:
		# si un nodo se arrastra lejos, el organismo entero sigue encuadrado.
		var focus_point := selected.position + selected.model.visual_center() * view_scale
		center = center.lerp(focus_point, t)
	var camera_scale := lerpf(fit, _micro_zoom, t)
	_world_layer.scale = Vector2(camera_scale, camera_scale)
	_world_layer.position = size * 0.5 - center * camera_scale

	for organism in _world.organisms:
		var view: OrganismView = _views.get(organism.id)
		if view == null:
			continue
		var is_selected := organism == selected
		view.visible = true
		view.position = organism.position
		view.scale = Vector2.ONE * view_scale
		# El aura del seleccionado se apaga en la primera mitad del zoom: si no,
		# al agrandarse la cámara queda un círculo enorme alrededor del organismo.
		view.set_aura_strength(clampf(1.0 - t * 2.0, 0.0, 1.0) if is_selected else 0.0)
		view.set_selection(organism.session.selected if (is_selected and _mode == MODE_MICRO) else -1)
		# R-22: las flechas de arrastre solo tienen sentido en Micro con B1
		# apretado sobre el organismo enfocado.
		view.set_drag_hint(is_selected and _mode == MODE_MICRO and organism.session.is_dragging())


# Suaviza el arranque y la llegada de la cámara. La forma no está fijada por la
# especificación: es cosmética.
func _smoothstep(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


# R-34: el organismo seleccionado se desvanece mientras se mantiene B4; si se
# suelta, la vista vuelve a opacidad plena con una transición corta.
func _update_fades() -> void:
	for organism in _world.organisms:
		var view: OrganismView = _views.get(organism.id)
		if view == null:
			continue
		var target := 1.0
		if _mode == MODE_MACRO and _world.is_dissolving() and organism == _world.selected_organism():
			target = 1.0 - 0.85 * _world.dissolve_progress()
		view.set_fade_target(target)
	_update_status_label()


# R-33/R-34: el aviso de abajo al centro dice qué está pasando: "borrando"
# mientras se disuelve y "sembrando" mientras se carga o se ajusta el
# organismo nuevo. Va con el color del organismo y se intensifica con el
# progreso del gesto.
func _update_status_label() -> void:
	var organism := _world.selected_organism()
	var text := ""
	var color := Color.WHITE
	var progress := 0.0
	if _mode == MODE_MACRO and _world.is_dissolving() and organism != null:
		text = "borrando"
		color = OrganismView.family_node_color(organism.family)
		progress = _world.dissolve_progress()
	elif _mode == MODE_MACRO and (_world.is_spawn_charging() or _world.is_spawning()):
		text = "sembrando"
		if _world.is_spawning() and organism != null:
			color = OrganismView.family_node_color(organism.family)
		else:
			color = OrganismView.family_node_color(_world.next_family())
		progress = _world.spawn_charge_progress()
	_status_label.visible = text != ""
	if text == "":
		return
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", color)
	_status_label.modulate.a = 0.55 + 0.45 * progress


func _update_labels() -> void:
	var organism := _world.selected_organism()
	if organism == null:
		_world_label.text = "mundo vacío"
		_session_label.text = ""
		return

	if _mode == MODE_MACRO:
		_world_label.text = "modo: macro   organismos: %d   puentes: %d   seleccionado: %d (n=%d, familia %d)" % [
			_world.count(),
			_world.bridges.count(),
			_world.selected + 1,
			organism.model.n,
			organism.family + 1,
		]
		_session_label.text = "nodo: —   variante: —   brillo: %.2f" % organism.session.brightness()
		return

	_world_label.text = "modo: micro   organismo %d (n=%d, familia %d)" % [
		_world.selected + 1,
		organism.model.n,
		organism.family + 1,
	]
	_session_label.text = "nodo: %d   variante: %d   brillo: %.2f" % [
		organism.session.selected,
		organism.session.variant_of(organism.session.selected),
		organism.session.brightness(),
	]


# Beat en base 1: el tick 1 abre el primer beat, no el tick 0.
func _beat_of(tick: int) -> int:
	return (tick - 1) / Config.TICKS_PER_BEAT + 1


# Se usa _unhandled_input para ver el evento tal como llegó, sin depender
# del orden de _process ni de que el nodo tenga foco.
func _unhandled_input(event: InputEvent) -> void:
	for action in Config.INPUT_ACTIONS:
		if event.is_action_pressed(action):
			_action_label.text = "última acción: %s" % action
			return
