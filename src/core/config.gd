# Todas las constantes del juego, en un solo lugar (ESPECIFICACION.md sección 1).
# Es una clase estática: solo `const` y funciones puras de las fórmulas.
# No es autoload, para que los tests headless no dependan del árbol de escenas.
# No define reglas: las reglas viven en ESPECIFICACION.md.

class_name Config
extends RefCounted

# --- Reloj (sección 2) ---
const BPM := 100
const TICKS_PER_BEAT := 4
const TICK_SEC := 60.0 / (BPM * TICKS_PER_BEAT)

# --- Organismo ---
const N_MIN := 2
const N_MAX := 8
const N_DEFAULT := 4
const MIN_EDGE_TICKS := 1
const MIN_NODE_DIST := 18.0
const PITCH_SPAN_DEGREES := 8

# --- Mundo ---
const MAX_ORGANISMS := 5
const MAX_BRIDGES := 6
const WORLD_SIZE := Vector2(2400.0, 1350.0)
const MIN_ORG_DISTANCE := 350.0
const DRIFT_MAX_SPEED := 6.0
const MACRO_ORG_SCALE := 0.3

# --- Puentes ---
const BRIDGE_DELAY_TICKS := 2

# --- Audio ---
const VOICE_CAP := 16
const SAMPLE_ROOT_MIDI := 60
const FOCUS_OTHERS_DB := -9.0
const FOCUS_OTHERS_LPF_HZ := 1200.0
const FOCUS_FADE_S := 0.4

# --- Input y presentación ---
const DRAG_SPEED := 180.0
const NAV_REPEAT_FIRST_MS := 350
const NAV_REPEAT_MS := 200
const DISSOLVE_HOLD_MS := 1000
const INACTIVITY_RESET_S := 90.0
const ZOOM_TIME_S := 0.5
const BRIGHTNESS_DEFAULT := 0.7
const BRIGHTNESS_SPEED := 0.8

# Escalas en semitonos desde la tónica, en el orden del sorteo de R-24.
const SCALES := [
	[0, 3, 5, 7, 10],
	[0, 2, 4, 7, 9],
	[0, 2, 3, 5, 7, 9, 10],
]

# Único listado de acciones de input: la escena de depuración y el router
# leen de acá para no repetir strings.
const INPUT_ACTIONS := [
	"joy_up",
	"joy_down",
	"joy_left",
	"joy_right",
	"btn_1",
	"btn_2",
	"btn_3",
	"btn_4",
]


# Radio máximo del organismo: crece con la cantidad de pulsos (R_MAX(n)).
static func r_max(n: int) -> float:
	return 100.0 + 15.0 * (n - 2)


# Registro por cantidad de pulsos: más pulsos = más grave (BASE_MIDI(n)).
static func base_midi(n: int) -> int:
	var t := float(n - 2) / 6.0
	return int(round(lerp(60.0, 36.0, t)))
