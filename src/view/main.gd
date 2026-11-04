# Escena de depuración de M6: el mundo Macro con varios organismos y su
# gestión. Mantiene el estado de vista (Macro/Micro) y traduce los gestos a las
# reglas del World (selección, siembra, disolución) o de la MicroSession del
# organismo enfocado. Crea una vista y un bus por organismo; las reglas viven
# en World y MicroSession, no acá.

extends Control

const DEV_SEED := 20260101
const MODE_MACRO := 0
const MODE_MICRO := 1

# Los placeholders están numerados 1..3 en el archivo (R-25).
const SAMPLE_PATH := "res://audio/placeholder/family_%d_%d.wav"
# El metrónomo queda bajo para no tapar las notas de los organismos.
const NODE_SAMPLE_DB := -6.0
const METRONOME_DB := -18.0
const REJECT_DB := -18.0
const REJECT_FREQ_HZ := 110.0
const REJECT_SEC := 0.09

# Escala de dibujo de Micro: la misma de M4/M5, para poder juzgar el pulso.
const MICRO_VIEW_SCALE := 3.0
# Macro dibuja el mundo entero escalado al viewport; MACRO_ORG_SCALE es la
# escala de la especificación y este multiplicador es cosmético, para que los
# nodos se puedan contar en 1280x720. La cámara de M7 lo reemplaza.
const MACRO_DEBUG_SCALE := 2.5

# Tres organismos de distinto N y familia para ver polimetría y V-02 en Macro.
# El estado inicial definitivo (uno solo en Micro) es de M9.
const INITIAL_COUNTS := [3, 4, 5]

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

var _clock := Clock.new()
var _router := InputRouter.new()
var _world: World
var _mode := MODE_MACRO
var _samples: Array[AudioStream] = []
var _reject_stream: AudioStream
var _scale: Array = []
var _tonic: int = 0
var _stick := Vector2.ZERO
var _views: Dictionary = {}
var _buses: Dictionary = {}


func _ready() -> void:
	_action_label.text = "última acción: (ninguna)"
	_note_label.text = "última nota: (ninguna)"
	_metronome.stream = ClickStream.make()
	_metronome.volume_db = METRONOME_DB
	_reject_stream = ClickStream.make(REJECT_FREQ_HZ, REJECT_SEC)
	_clock.tick_emitted.connect(_on_tick_emitted)

	# La escala y la tónica se sortean una vez por sesión y no cambian (R-24).
	var rng := RandomNumberGenerator.new()
	rng.seed = DEV_SEED
	var scale_index := rng.randi_range(0, Config.SCALES.size() - 1)
	_scale = Config.SCALES[scale_index]
	_tonic = rng.randi_range(0, 11)
	_scale_label.text = "escala: %d   tónica: %d" % [scale_index + 1, _tonic]

	for family in Config.FAMILY_COUNT:
		for variant in Config.VARIANT_COUNT:
			_samples.append(load(SAMPLE_PATH % [family + 1, variant]))

	_world = World.new(rng)
	_world.organism_added.connect(_on_organism_added)
	_world.organism_removed.connect(_on_organism_removed)
	_world.organism_rebuilt.connect(_on_organism_rebuilt)
	_world.selection_changed.connect(_on_world_selection_changed)
	_world.rejected.connect(_on_world_rejected)

	_router.nav_step.connect(_on_nav_step)
	_router.stick_changed.connect(_on_stick_changed)
	_router.button_pressed.connect(_on_button_pressed)
	_router.button_released.connect(_on_button_released)

	for count in INITIAL_COUNTS:
		_world.add_organism(count)
	_world.select(0)

	_layout_views()
	_update_labels()
	get_viewport().size_changed.connect(_layout_views)


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
	for organism in _world.organisms:
		var view: OrganismView = _views.get(organism.id)
		if view != null and view.visible:
			view.update_visuals(_current_phase_f(organism.model), delta)
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


# La altura del nodo se convierte en nota al momento del disparo: si se movió
# el nodo, la nota nueva sale sola (R-23) sin recalcular nada por tick.
func _on_node_fired(organism_id: int, node_index: int, _tick: int, _is_echo: bool) -> void:
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
	if _mode == MODE_MACRO:
		_world.nav_step(direction)
		return
	var organism := _world.selected_organism()
	if organism != null:
		organism.session.nav_step(direction)


func _on_stick_changed(direction: Vector2) -> void:
	_stick = direction


func _on_button_pressed(action: String) -> void:
	if _mode == MODE_MACRO:
		_press_in_macro(action)
	else:
		_press_in_micro(action)


func _on_button_released(action: String) -> void:
	if _mode == MODE_MACRO:
		_release_in_macro(action)
	else:
		_release_in_micro(action)


# En Macro: B1 entra a Micro (corte directo, sin animación todavía: M7), B2
# siembra, B3 es puentes (M8) y B4 disuelve. B1 se rechaza mientras hay una
# siembra o disolución en curso: entrar a Micro dejaría el gesto a medias y la
# especificación no define qué hacer con la siembra abierta.
func _press_in_macro(action: String) -> void:
	match action:
		"btn_1":
			if _world.is_spawning() or _world.is_dissolving():
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
	organism.session.reset_gestures()
	_layout_views()
	_update_labels()


func _exit_micro() -> void:
	var organism := _world.selected_organism()
	if organism != null:
		organism.session.reset_gestures()
	_mode = MODE_MACRO
	_layout_views()
	_update_labels()


func _on_organism_added(organism: OrganismState) -> void:
	var view := OrganismView.new()
	view.setup(organism.model, organism.family)
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


# El mundo entero entra en el viewport en Macro; en Micro se centra solo el
# organismo enfocado. El cambio es directo: la animación de cámara es M7.
func _layout_views() -> void:
	var size := get_viewport_rect().size
	if _mode == MODE_MACRO:
		var fit := minf(size.x / Config.WORLD_SIZE.x, size.y / Config.WORLD_SIZE.y)
		_world_layer.position = size * 0.5
		_world_layer.scale = Vector2(fit, fit)
		for organism in _world.organisms:
			var view: OrganismView = _views.get(organism.id)
			if view == null:
				continue
			view.visible = true
			view.position = organism.position - Config.WORLD_SIZE * 0.5
			view.scale = Vector2.ONE * Config.MACRO_ORG_SCALE * MACRO_DEBUG_SCALE
			view.set_macro_selected(organism == _world.selected_organism())
			view.set_selection(-1)
		return

	_world_layer.position = size * 0.5
	_world_layer.scale = Vector2.ONE
	var selected := _world.selected_organism()
	for organism in _world.organisms:
		var view: OrganismView = _views.get(organism.id)
		if view == null:
			continue
		var is_selected := organism == selected
		view.visible = is_selected
		if is_selected:
			view.position = Vector2.ZERO
			view.scale = Vector2.ONE * MICRO_VIEW_SCALE
			view.set_macro_selected(false)
			view.set_selection(organism.session.selected)


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


func _update_labels() -> void:
	var organism := _world.selected_organism()
	if organism == null:
		_world_label.text = "mundo vacío"
		_session_label.text = ""
		return

	if _mode == MODE_MACRO:
		_world_label.text = "modo: macro   organismos: %d   seleccionado: %d (n=%d, familia %d)" % [
			_world.count(),
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
