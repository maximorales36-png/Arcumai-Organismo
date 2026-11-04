# Bus de audio propio de un organismo (R-26, R-36): un pasabajos cuyo corte
# depende del brillo y del foco, y un volumen que baja cuando el organismo no
# está enfocado. Recibe el nombre del bus al construirse; no reproduce sonido.
# La escena le avisa si está enfocado y lo actualiza por frame para el fundido.

class_name OrganismBus
extends RefCounted

var _name: String
var _filter: AudioEffectLowPassFilter
var _own_cutoff := 0.0
var _focused := true
var _focus := 1.0


func _init(bus_name: String) -> void:
	_name = bus_name
	AudioServer.add_bus()
	var index := AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(index, bus_name)
	_filter = AudioEffectLowPassFilter.new()
	AudioServer.add_bus_effect(index, _filter)
	_own_cutoff = Config.cutoff_hz(Config.BRIGHTNESS_DEFAULT)
	_apply()


# El brillo define el corte propio; el foco decide cuánto de ese corte llega
# al oído cuando el organismo no está enfocado (R-26, R-36).
func set_brightness(brightness: float) -> void:
	_own_cutoff = Config.cutoff_hz(brightness)
	_apply()


func set_focused(focused: bool) -> void:
	_focused = focused
	_apply()


# R-36: el cambio de foco se funde en FOCUS_FADE_S. El delta solo anima la
# mezcla; no interviene en el tiempo musical.
func update(delta: float) -> void:
	var target := 1.0 if _focused else 0.0
	if is_equal_approx(_focus, target):
		return
	_focus = move_toward(_focus, target, delta / Config.FOCUS_FADE_S)
	_apply()


func cutoff_hz() -> float:
	return _filter.cutoff_hz


func volume_db() -> float:
	var index := AudioServer.get_bus_index(_name)
	return 0.0 if index <= 0 else AudioServer.get_bus_volume_db(index)


func bus_name() -> String:
	return _name


# Al disolver un organismo se quita su bus para no acumular canales. Las voces
# que lo usaban se cortan antes desde VoicePool.stop_bus().
func dispose() -> void:
	var index := AudioServer.get_bus_index(_name)
	if index > 0:
		AudioServer.remove_bus(index)


# El índice se busca por nombre cada vez: quitar el bus de otro organismo
# corre los índices de los que están detrás.
func _apply() -> void:
	var index := AudioServer.get_bus_index(_name)
	if index <= 0:
		return
	var others_cutoff := minf(_own_cutoff, Config.FOCUS_OTHERS_LPF_HZ)
	var cutoff := _own_cutoff
	if _focus < 1.0:
		# El corte se interpola en escala logarítmica: en Hz lineales el fundido
		# se queda casi todo el tiempo arriba y se cierra de golpe al final.
		cutoff = exp(lerpf(log(others_cutoff), log(_own_cutoff), _focus))
	_filter.cutoff_hz = cutoff
	AudioServer.set_bus_volume_db(index, lerpf(Config.FOCUS_OTHERS_DB, 0.0, _focus))
