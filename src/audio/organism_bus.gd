# Bus de audio propio de un organismo (R-26): un pasabajos cuyo corte depende
# del brillo. Cada organismo tiene el suyo, así el brillo de uno no colorea a
# los demás. Recibe el nombre del bus al construirse; no reproduce sonido.

class_name OrganismBus
extends RefCounted

var _name: String
var _filter: AudioEffectLowPassFilter


func _init(bus_name: String) -> void:
	_name = bus_name
	AudioServer.add_bus()
	var index := AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(index, bus_name)
	_filter = AudioEffectLowPassFilter.new()
	AudioServer.add_bus_effect(index, _filter)
	set_brightness(Config.BRIGHTNESS_DEFAULT)


func set_brightness(brightness: float) -> void:
	_filter.cutoff_hz = Config.cutoff_hz(brightness)


func cutoff_hz() -> float:
	return _filter.cutoff_hz


func bus_name() -> String:
	return _name


# Al disolver un organismo se quita su bus para no acumular canales. Las voces
# que lo usaban se cortan antes desde VoicePool.stop_bus().
func dispose() -> void:
	var index := AudioServer.get_bus_index(_name)
	if index > 0:
		AudioServer.remove_bus(index)
