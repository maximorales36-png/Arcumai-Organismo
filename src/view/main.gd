# Escena de depuración de M3: un organismo que suena al disparar.
# Crea el OrganismModel con semilla fija, sortea escala y tónica (R-24), lo
# dibuja con OrganismView y toca el placeholder de la familia 1 en cada disparo.
# Recibe eventos de input; no emite nada.

extends Control

const ORGANISM_ID := 1
const DEV_SEED := 20260101
const PLACEHOLDER_SAMPLE := "res://audio/placeholder/family_1_0.wav"
# El metrónomo queda bajo para no tapar las notas del organismo.
const NODE_SAMPLE_DB := -6.0
const METRONOME_DB := -18.0

@onready var _tick_label: Label = $Overlay/TickLabel
@onready var _beat_label: Label = $Overlay/BeatLabel
@onready var _scale_label: Label = $Overlay/ScaleLabel
@onready var _action_label: Label = $Overlay/ActionLabel
@onready var _note_label: Label = $Overlay/NoteLabel
@onready var _fps_label: Label = $Overlay/FpsLabel
@onready var _metronome: AudioStreamPlayer = $Metronome
@onready var _view: OrganismView = $OrganismView
@onready var _voices: VoicePool = $VoicePool

var _clock := Clock.new()
var _model: OrganismModel
var _sample: AudioStream
var _scale: Array = []
var _tonic: int = 0


func _ready() -> void:
	_action_label.text = "última acción: (ninguna)"
	_note_label.text = "última nota: (ninguna)"
	_metronome.stream = ClickStream.make()
	_metronome.volume_db = METRONOME_DB
	_clock.tick_emitted.connect(_on_tick_emitted)

	# La escala y la tónica se sortean una vez por sesión y no cambian (R-24).
	var rng := RandomNumberGenerator.new()
	rng.seed = DEV_SEED
	var scale_index := rng.randi_range(0, Config.SCALES.size() - 1)
	_scale = Config.SCALES[scale_index]
	_tonic = rng.randi_range(0, 11)
	_scale_label.text = "escala: %d   tónica: %d" % [scale_index + 1, _tonic]

	_sample = load(PLACEHOLDER_SAMPLE)
	_model = OrganismModel.new(ORGANISM_ID, Config.N_DEFAULT, _clock.tick, rng)
	_model.node_fired.connect(_on_node_fired)
	_view.setup(_model)

	_center_view()
	get_viewport().size_changed.connect(_center_view)


# El reloj se alimenta con el delta real: es el único lugar donde el delta
# decide tiempo musical, tal como pide R-02. Nada más usa delta acá.
func _process(delta: float) -> void:
	_clock.advance(delta)
	_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()


func _on_tick_emitted(tick: int) -> void:
	_tick_label.text = "tick: %d" % tick
	_beat_label.text = "beat: %d" % _beat_of(tick)
	if (tick - 1) % Config.TICKS_PER_BEAT == 0:
		_metronome.play()
	_model.on_tick(tick)


# La altura del nodo se convierte en nota al momento del disparo: si se movió
# el nodo, la nota nueva sale sola (R-23) sin recalcular nada por tick.
func _on_node_fired(_organism_id: int, node_index: int, _tick: int, _is_echo: bool) -> void:
	var midi := PitchMapping.midi_for_node(_model.nodes[node_index].y, _model.n, _scale, _tonic)
	_voices.play(_sample, PitchMapping.pitch_scale_for_midi(midi), NODE_SAMPLE_DB)
	_note_label.text = "última nota: midi %d   pitch %.2f" % [midi, PitchMapping.pitch_scale_for_midi(midi)]


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
