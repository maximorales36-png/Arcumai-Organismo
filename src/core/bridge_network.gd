# Red de puentes dirigidos y su cola de ecos (R-27, R-28). Mantiene los puentes
# existentes, encola un eco por cada disparo no-eco de un nodo emisor y entrega
# los ecos vencidos en orden de llegada. Los puentes se identifican por el par
# ordenado (origen, destino). No conoce escenas ni audio: el mundo le pasa los
# disparos y le pide los ecos que vencen; `echoes` es de lectura para la vista.

class_name BridgeNetwork
extends RefCounted

var bridges: Array[Bridge] = []

# Cola FIFO de ecos. Cada evento guarda el puente que lo originó y el tick en
# que vence; se conserva el orden de encolado (R-04).
var echoes: Array[Dictionary] = []


func count() -> int:
	return bridges.size()


func find(from_id: int, to_id: int) -> Bridge:
	for bridge in bridges:
		if bridge.from_id == from_id and bridge.to_id == to_id:
			return bridge
	return null


func has(from_id: int, to_id: int) -> bool:
	return find(from_id, to_id) != null


# R-28: máximo un puente por par ordenado y MAX_BRIDGES en total.
func can_add(from_id: int, to_id: int) -> bool:
	return not has(from_id, to_id) and bridges.size() < Config.MAX_BRIDGES


func add(bridge: Bridge) -> bool:
	if not can_add(bridge.from_id, bridge.to_id):
		return false
	bridges.append(bridge)
	return true


# Quitar un puente también descarta los ecos que todavía no vencieron: si el
# puente ya no está, no tiene sentido que su eco siga viajando.
func remove(from_id: int, to_id: int) -> bool:
	for i in bridges.size():
		if bridges[i].from_id == from_id and bridges[i].to_id == to_id:
			bridges.remove_at(i)
			_drop_echoes_of(from_id, to_id)
			return true
	return false


# R-28: al eliminar un organismo se van todos sus puentes, como origen o destino.
func remove_for(organism_id: int) -> void:
	var i := 0
	while i < bridges.size():
		if bridges[i].from_id == organism_id or bridges[i].to_id == organism_id:
			bridges.remove_at(i)
		else:
			i += 1
	_drop_echoes_for(organism_id)


# R-27: un disparo no-eco de un nodo emisor encola exactamente un eco en el
# receptor. Los ecos no encolan otros ecos (sin contagio).
func on_node_fired(organism_id: int, node_index: int, tick: int, is_echo: bool) -> void:
	if is_echo:
		return
	for bridge in bridges:
		if bridge.from_id == organism_id and bridge.from_node == node_index:
			echoes.append({
				"tick": tick + Config.BRIDGE_DELAY_TICKS,
				"from_id": bridge.from_id,
				"from_node": bridge.from_node,
				"to_id": bridge.to_id,
				"to_node": bridge.to_node,
			})


# R-04: entrega los ecos vencidos en orden de la cola. `alive` es el conjunto de
# ids que todavía existen: si A o B ya no está, el evento se descarta (R-27).
func take_due(tick: int, alive: Dictionary) -> Array[Dictionary]:
	var due: Array[Dictionary] = []
	var i := 0
	while i < echoes.size():
		var echo: Dictionary = echoes[i]
		if echo.tick > tick:
			i += 1
			continue
		echoes.remove_at(i)
		if alive.has(echo.from_id) and alive.has(echo.to_id):
			due.append(echo)
	return due


func _drop_echoes_of(from_id: int, to_id: int) -> void:
	var i := 0
	while i < echoes.size():
		var echo: Dictionary = echoes[i]
		if echo.from_id == from_id and echo.to_id == to_id:
			echoes.remove_at(i)
		else:
			i += 1


func _drop_echoes_for(organism_id: int) -> void:
	var i := 0
	while i < echoes.size():
		var echo: Dictionary = echoes[i]
		if echo.from_id == organism_id or echo.to_id == organism_id:
			echoes.remove_at(i)
		else:
			i += 1
