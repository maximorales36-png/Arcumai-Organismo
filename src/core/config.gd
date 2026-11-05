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
# N_DEFAULT es el organismo con el que arranca la sesión; las siembras con B2
# usan N_SPAWN para que el mundo no crezca siempre con organismos grandes.
const N_DEFAULT := 4
const N_SPAWN := 2
const MIN_EDGE_TICKS := 1
const MIN_NODE_DIST := 18.0
const PITCH_SPAN_DEGREES := 8

# Geometría orgánica (R-20, R-12). La especificación exige que sea irregular,
# pero no fija magnitudes: estos valores son propuestos y ajustables a ojo.
const NODE_RING_RATIO := 0.6
const NODE_ANGLE_JITTER_MIN := 0.052
const NODE_ANGLE_JITTER_MAX := 0.209
const NODE_RADIAL_JITTER := 0.08
const EDGE_CURVATURE_MIN := 0.10
const EDGE_CURVATURE_MAX := 0.25
const EDGE_CURVATURE_N2_MIN := 0.25
const EDGE_CURVATURE_N2_MAX := 0.35

# --- Mundo ---
const MAX_ORGANISMS := 6
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
const FAMILY_COUNT := 3
const VARIANT_COUNT := 3
const FOCUS_OTHERS_DB := -9.0
const FOCUS_OTHERS_LPF_HZ := 1200.0
const FOCUS_FADE_S := 0.4

# --- Input y presentación ---
const DRAG_SPEED := 180.0
const NAV_REPEAT_FIRST_MS := 350
const NAV_REPEAT_MS := 200
const DISSOLVE_HOLD_MS := 600
# B2 en Macro carga antes de crear el organismo; soltar antes cancela.
const SPAWN_HOLD_MS := 2000
# Después de crear un organismo no se puede sembrar otro por este tiempo.
const SPAWN_COOLDOWN_S := 5.0
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

# Los 4 botones, separados del joystick: el router los lee por flanco y las
# direcciones por nivel.
const BUTTON_ACTIONS := ["btn_1", "btn_2", "btn_3", "btn_4"]


# Radio máximo del organismo: crece con la cantidad de pulsos (R_MAX(n)).
static func r_max(n: int) -> float:
	return 100.0 + 15.0 * (n - 2)


# Registro por cantidad de pulsos: más pulsos = más grave (BASE_MIDI(n)).
static func base_midi(n: int) -> int:
	var t := float(n - 2) / 6.0
	return int(round(lerp(60.0, 36.0, t)))


# R-26: el brillo mueve el corte del pasabajos entre 800 Hz y 16 kHz.
static func cutoff_hz(brightness: float) -> float:
	return 800.0 * pow(20.0, clampf(brightness, 0.0, 1.0))
