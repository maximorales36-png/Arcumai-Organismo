# Asignación de voces del pool (R-29): decide qué reproductor usar y cuál robar.
# No reproduce nada ni conoce nodos: solo lleva el orden de uso. Eso permite
# testear la política headless, sin audio ni escena.
# `acquire()` devuelve un índice y, si todo está ocupado, roba el más antiguo.

class_name VoiceAllocator
extends RefCounted

var _busy: Array[bool] = []
var _order: Array[int] = []
var _next_order: int = 0


func _init(capacity: int = Config.VOICE_CAP) -> void:
	_busy.resize(capacity)
	_busy.fill(false)
	_order.resize(capacity)
	_order.fill(0)


# Siempre devuelve una voz: si no hay libres, se lleva la que empezó antes.
func acquire() -> int:
	for i in _busy.size():
		if not _busy[i]:
			return _take(i)

	var oldest := 0
	for i in _busy.size():
		if _order[i] < _order[oldest]:
			oldest = i
	return _take(oldest)


func release(index: int) -> void:
	if index >= 0 and index < _busy.size():
		_busy[index] = false


func active_count() -> int:
	var count := 0
	for busy in _busy:
		if busy:
			count += 1
	return count


func capacity() -> int:
	return _busy.size()


func _take(index: int) -> int:
	_busy[index] = true
	_order[index] = _next_order
	_next_order += 1
	return index
