# Escena de arranque del proyecto: fondo oscuro y overlay de depuración.
# En M0 solo muestra qué acción de input llegó y cuántos FPS hay, para
# verificar el mapeo de teclado. No tiene lógica de juego.
# Recibe eventos de input; no emite nada.

extends Control

@onready var _action_label: Label = $Overlay/ActionLabel
@onready var _fps_label: Label = $Overlay/FpsLabel


func _ready() -> void:
	_action_label.text = "última acción: (ninguna)"


# Se usa _unhandled_input para ver el evento tal como llegó, sin depender
# del orden de _process ni de que el nodo tenga foco.
func _unhandled_input(event: InputEvent) -> void:
	for action in Config.INPUT_ACTIONS:
		if event.is_action_pressed(action):
			_action_label.text = "última acción: %s" % action
			return


func _process(_delta: float) -> void:
	_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
