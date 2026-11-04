# Escena de depuración de M5: un organismo jugable en vista Micro.
# Crea el modelo, el router de input, la sesión y el bus del organismo; traduce
# los gestos a reglas (selección, arrastre, origen, variante, brillo, rechazo)
# y los refleja en la vista y el audio. Las reglas viven en MicroSession.

extends Control

const ORGANISM_ID := 1
const DEV_SEED := 20260101
const FAMILY := 1
const SAMPLE_PATH := "res://audio/placeholder/family_%d_%d.wav"
# El metrónomo queda bajo para no tapar las notas del organismo.
const NODE_SAMPLE_DB := -6.0
const METRONOME_DB := -18.0
const REJECT_DB := -18.0
const REJECT_FREQ_HZ := 110.0
const REJECT_SEC := 0.09

@onready var _tick_label: Label = $Overlay/TickLabel
@onready var _beat_label: Label = $Overlay/BeatLabel
@onready var _scale_label: Label = $Overlay/ScaleLabel
@onready var _session_label: Label = $Overlay/SessionLabel
@onready var _action_label: Label = $Overlay/ActionLabel
@onready var _note_label: Label = $Overlay/NoteLabel
@onready var _fps_label: Label = $Overlay/FpsLabel
@onready var _metronome: AudioStreamPlayer = $Metronome
@onready var _view: OrganismView = $OrganismView
@onready var _voices: VoicePool = $VoicePool

var _clock := Clock.new()
var _router := InputRouter.new()
var _model: OrganismModel
var _session: MicroSession
var _bus: OrganismBus
var _samples: Array[AudioStream] = []
var _reject_stream: AudioStream
var _scale: Array = []
var _tonic: int = 0
var _stick := Vector2.ZERO


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

	for variant in Config.VARIANT_COUNT:
		_samples.append(load(SAMPLE_PATH % [FAMILY, variant]))

	_model = OrganismModel.new(ORGANISM_ID, Config.N_DEFAULT, _clock.tick, rng)
	_model.node_fired.connect(_on_node_fired)
	_session = MicroSession.new(_model)
	_session.selection_changed.connect(_on_selection_changed)
	_session.origin_changed.connect(_on_origin_changed)
	_session.variant_changed.connect(_on_variant_changed)
	_session.brightness_changed.connect(_on_brightness_changed)
	_session.rejected.connect(_on_rejected)

	# R-26: el organismo suena a través de su propio bus con pasabajos.
	_bus = OrganismBus.new("organism_%d" % ORGANISM_ID)
	_voices.set_bus(_bus.bus_name())

	_router.nav_step.connect(_session.nav_step)
	_router.stick_changed.connect(_on_stick_changed)
	_router.button_pressed.connect(_on_button_pressed)
	_router.button_released.connect(_on_button_released)

	_view.setup(_model, FAMILY)
	_view.set_selection(_session.selected)
	_update_session_label()

	_center_view()
	get_viewport().size_changed.connect(_center_view)


# El reloj se alimenta con el delta real: es el único lugar donde el delta
# decide tiempo musical (R-02). La sesión lo usa solo para arrastre y brillo.
func _process(delta: float) -> void:
	_clock.advance(delta)
	_router.update(delta)
	_session.update(_stick, delta)
	_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	_view.update_visuals(_current_phase_f(), delta)


# Fase continua del organismo: tick entero más la fracción que ya corrió el
# reloj. Antes del ancla no hay pulso y se informa -1 (R-17, R-21).
func _current_phase_f() -> float:
	var phase := _model.phase_at(_clock.tick)
	if phase < 0:
		return -1.0
	return float(phase) + _clock.fraction()


func _on_tick_emitted(tick: int) -> void:
	_tick_label.text = "tick: %d" % tick
	_beat_label.text = "beat: %d" % _beat_of(tick)
	if (tick - 1) % Config.TICKS_PER_BEAT == 0:
		_metronome.play()
	_model.on_tick(tick)


# La altura del nodo se convierte en nota al momento del disparo: si se movió
# el nodo, la nota nueva sale sola (R-23) sin recalcular nada por tick.
func _on_node_fired(_organism_id: int, node_index: int, _tick: int, _is_echo: bool) -> void:
	_view.flash(node_index)
	_play_node(node_index)


# Cada nodo suena con su variante (R-25); el preview de B2 usa este mismo
# camino para que el cambio se escuche en menos de un segundo.
func _play_node(node_index: int) -> void:
	var midi := PitchMapping.midi_for_node(_model.nodes[node_index].y, _model.n, _scale, _tonic)
	var pitch := PitchMapping.pitch_scale_for_midi(midi)
	_voices.play(_samples[_session.variant_of(node_index)], pitch, NODE_SAMPLE_DB)
	_note_label.text = "última nota: midi %d   pitch %.2f" % [midi, pitch]


func _on_stick_changed(direction: Vector2) -> void:
	_stick = direction


func _on_button_pressed(action: String) -> void:
	match action:
		"btn_1":
			_session.b1_pressed()
		"btn_2":
			_session.b2_pressed()
		"btn_3":
			_session.b3_pressed()
		"btn_4":
			# B4 vuelve a Macro, que todavía no existe: la sesión da rechazo.
			_session.b4_pressed()


func _on_button_released(action: String) -> void:
	match action:
		"btn_1":
			_session.b1_released()
		"btn_3":
			_session.b3_released()


func _on_selection_changed(node_index: int) -> void:
	_view.set_selection(node_index)
	_update_session_label()


func _on_origin_changed(_node_index: int) -> void:
	_update_session_label()


func _on_variant_changed(node_index: int, _variant: int) -> void:
	_update_session_label()
	_play_node(node_index)


func _on_brightness_changed(brightness: float) -> void:
	_bus.set_brightness(brightness)
	_update_session_label()


# R-31: sonido corto, grave y bajo más temblor sobre el nodo seleccionado.
func _on_rejected() -> void:
	_voices.play(_reject_stream, 1.0, REJECT_DB)
	_view.shake(_session.selected)


func _update_session_label() -> void:
	_session_label.text = "nodo: %d   variante: %d   brillo: %.2f" % [
		_session.selected,
		_session.variant_of(_session.selected),
		_session.brightness(),
	]


# El organismo se dibuja en coordenadas locales; el nodo 0 va al centro de la
# pantalla para que la geometría quede alrededor y no pegada a la esquina.
func _center_view() -> void:
	_view.position = get_viewport_rect().size * 0.5


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
