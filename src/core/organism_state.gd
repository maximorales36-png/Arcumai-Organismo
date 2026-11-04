# Estado de un organismo dentro del mundo Macro: su modelo temporal, su sesión
# de interacción Micro, su familia de sonido y su posición de mundo (R-38).
# No conoce escenas ni audio: la vista y el sonido lo leen desde la escena.
# La deriva es cosmética y no toca el modelo ni el audio.

class_name OrganismState
extends RefCounted

var id: int = 0
var family: int = 0
var model: OrganismModel
var session: MicroSession
var position := Vector2.ZERO
var drift_velocity := Vector2.ZERO
var drift_timer := 0.0
