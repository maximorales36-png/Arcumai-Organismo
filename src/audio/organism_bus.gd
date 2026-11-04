# Bus de audio propio de un organismo (R-26): un pasabajos cuyo corte depende
# del brillo. Cada organismo tendrá el suyo cuando haya varios (M6/M7); por
# ahora la escena crea uno solo.
# Recibe el nombre del bus al construirse; no reproduce sonido.

class_name OrganismBus
extends RefCounted

var bus_index: int = -1

var _filter: AudioEffectLowPassFilter


func _init(bus_name: String) -> void:
	AudioServer.add_bus()
	bus_index = AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(bus_index, bus_name)
	_filter = AudioEffectLowPassFilter.new()
	AudioServer.add_bus_effect(bus_index, _filter)
	set_brightness(Config.BRIGHTNESS_DEFAULT)


func set_brightness(brightness: float) -> void:
	_filter.cutoff_hz = Config.cutoff_hz(brightness)


func cutoff_hz() -> float:
	return _filter.cutoff_hz


func bus_name() -> String:
	return AudioServer.get_bus_name(bus_index)
