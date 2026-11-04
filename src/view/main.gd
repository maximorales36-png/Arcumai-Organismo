# Escena de arranque del proyecto: fondo oscuro y overlay de depuración.
# En M1 alimenta el reloj maestro, muestra tick, beat, última acción y FPS,
# y hace sonar un click en cada beat. No tiene lógica de juego.
# Recibe eventos de input; no emite nada.

extends Control

@onready var _tick_label: Label = $Overlay/TickLabel
@onready var _beat_label: Label = $Overlay/BeatLabel
@onready var _action_label: Label = $Overlay/ActionLabel
@onready var _fps_label: Label = $Overlay/FpsLabel
@onready var _metronome: AudioStreamPlayer = $Metronome

var _clock := Clock.new()


func _ready() -> void:
	_action_label.text = "última acción: (ninguna)"
	_metronome.stream = ClickStream.make()
	_clock.tick_emitted.connect(_on_tick_emitted)


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
