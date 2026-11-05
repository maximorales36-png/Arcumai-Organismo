# Puente dirigido entre dos organismos (R-27, R-28): guarda los ids de origen y
# destino y los índices de nodo emisor y receptor. Los índices se calculan una
# vez al crear el puente y quedan fijos; la posición de mundo de cada nodo se
# recalcula al dibujar, así la deriva y el arrastre mueven el filamento.
# No conoce escenas, audio ni el tiempo: es solo el dato del puente.

class_name Bridge
extends RefCounted

var from_id: int
var from_node: int
var to_id: int
var to_node: int


func _init(source_id: int, source_node: int, target_id: int, target_node: int) -> void:
	from_id = source_id
	from_node = source_node
	to_id = target_id
	to_node = target_node
