# Pool de reproductores de audio (R-29). Crea VOICE_CAP AudioStreamPlayer y
# delega la elección de voz en VoiceAllocator; al terminar un sonido, la voz
# vuelve a quedar libre.
# Recibe stream, pitch_scale y volumen; no decide alturas ni mezcla.

class_name VoicePool
extends Node

var _allocator: VoiceAllocator
var _players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	_allocator = VoiceAllocator.new(Config.VOICE_CAP)
	for i in Config.VOICE_CAP:
		var player := AudioStreamPlayer.new()
		# Cada reproductor avisa con su índice para liberar la voz correcta.
		player.finished.connect(_on_player_finished.bind(i))
		add_child(player)
		_players.append(player)


func play(stream: AudioStream, pitch_scale: float, volume_db: float = 0.0) -> void:
	if stream == null or _allocator == null:
		return
	var index := _allocator.acquire()
	var player := _players[index]
	player.stream = stream
	player.pitch_scale = pitch_scale
	player.volume_db = volume_db
	player.play()


func active_voices() -> int:
	return 0 if _allocator == null else _allocator.active_count()


# Enruta todas las voces al bus del organismo (R-26: brillo por bus).
func set_bus(bus_name: String) -> void:
	for player in _players:
		player.bus = bus_name


# Al desmontar el pool se cortan las voces y se sueltan los streams: si no, un
# sonido en curso queda vivo en el servidor de audio después de cerrar.
func _exit_tree() -> void:
	for player in _players:
		player.stop()
		player.stream = null


func _on_player_finished(index: int) -> void:
	_allocator.release(index)
