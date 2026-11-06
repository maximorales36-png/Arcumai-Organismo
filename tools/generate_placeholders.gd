# Genera los placeholders de audio de R-25: 3 familias x 4 variantes.
# Variante 0: nota afinada de la familia (pluck) en C4.
# Variante 1: cross-stick (rim click / side-stick), corto y seco.
# Variante 2: bombo grave con barrido de altura.
# Variante 3: silencio, para mutear un nodo desde Micro.
# Se corre una sola vez:
#   godot --headless --path . --script res://tools/generate_placeholders.gd
# Escribe WAV mono de 16 bits en res://audio/placeholder/ y sale.
# No se usa en tiempo de ejecución: es una herramienta de desarrollo.

extends SceneTree

const OUT_DIR := "res://audio/placeholder"
const MIX_RATE := 44100
const DURATION_S := 0.45
const ATTACK_S := 0.004
const AMPLITUDE := 0.6
# C4, la nota en la que están grabadas las muestras afinadas (SAMPLE_ROOT_MIDI).
const ROOT_HZ := 261.6255653


func _initialize() -> void:
	if not DirAccess.dir_exists_absolute(OUT_DIR):
		DirAccess.make_dir_recursive_absolute(OUT_DIR)

	for family in 3:
		for variant in 4:
			var stream := _render(family, variant)
			var path := "%s/family_%d_%d.wav" % [OUT_DIR, family + 1, variant]
			var error := stream.save_to_wav(path)
			if error != OK:
				printerr("No se pudo escribir %s (error %d)" % [path, error])
				quit(1)
				return
			print("OK %s" % path)

	quit(0)


# Cada familia conserva un timbre propio en la variante 0; las percusiones
# cambian apenas de color por familia para que los organismos no suenen
# idénticos. La variante 3 se deja en cero a propósito.
func _render(family: int, variant: int) -> AudioStreamWAV:
	var sample_count := int(MIX_RATE * DURATION_S)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var kick_phase := 0.0
	for i in sample_count:
		var t := float(i) / MIX_RATE
		var value := 0.0
		match variant:
			0:
				value = _pluck(family, t)
			1:
				value = _cross_stick(family, i, t)
			2:
				# El barrido de 168 Hz a 48 Hz da el golpe de bombo; la fase se
				# acumula para que el barrido no se oiga como un chirrido.
				var frequency := 48.0 + 120.0 * exp(-t * 30.0)
				kick_phase += TAU * frequency / MIX_RATE
				value = _kick(t, kick_phase, i, family)
			3:
				value = 0.0
		data.encode_s16(i * 2, int(clampf(value, -1.0, 1.0) * 32767.0))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream


# Variante 0: el pluck original. Cada familia cambia la mezcla de armónicos.
func _pluck(family: int, t: float) -> float:
	var second := 0.0
	var third := 0.0
	match family:
		0:
			second = 0.0
			third = 0.0
		1:
			second = 0.35
			third = 0.0
		_:
			second = 0.20
			third = 0.15

	var attack := minf(1.0, t / ATTACK_S)
	var envelope := attack * exp(-t * 7.0)
	var value := sin(TAU * ROOT_HZ * t)
	value += second * sin(TAU * ROOT_HZ * 2.0 * t)
	value += third * sin(TAU * ROOT_HZ * 3.0 * t)
	return value * envelope * AMPLITUDE


# Variante 1: cross-stick. Un click de ruido muy corto más un tono de madera;
# la caída rápida es lo que lo separa de la nota.
func _cross_stick(family: int, index: int, t: float) -> float:
	if t > 0.14:
		return 0.0
	var attack := minf(1.0, t / 0.001)
	var envelope := attack * exp(-t * 55.0)
	var center := 1500.0 + family * 350.0
	var tone := sin(TAU * center * t) * 0.55
	var noise := _noise(index, family) * 0.55
	return (tone + noise) * envelope * 0.7


# Variante 2: bombo. Cuerpo grave con un click de ataque; el decaimiento es
# más largo que el del cross-stick para que se sienta el peso.
func _kick(t: float, phase: float, index: int, family: int) -> float:
	var attack := minf(1.0, t / 0.002)
	var envelope := attack * exp(-t * 9.0)
	var body := sin(phase) * 0.9
	var click := _noise(index, family) * exp(-t * 120.0) * 0.25
	return (body + click) * envelope * 0.8


# Ruido blanco determinista: el mismo índice y familia dan siempre el mismo
# valor, así los placeholders se pueden regenerar sin cambios inesperados.
func _noise(index: int, seed_value: int) -> float:
	var x := (index * 1103515245 + seed_value * 12345) & 0x7fffffff
	return float(x) / 1073741823.5 - 1.0
