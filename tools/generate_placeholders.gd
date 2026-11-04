# Genera los placeholders de audio de R-25: 3 familias x 3 variantes, en C4,
# con timbres distintos y envolvente corta. Se corre una sola vez:
#   godot --headless --path . --script res://tools/generate_placeholders.gd
# Escribe WAV mono de 16 bits en res://audio/placeholder/ y sale.
# No se usa en tiempo de ejecución: es una herramienta de desarrollo.

extends SceneTree

const OUT_DIR := "res://audio/placeholder"
const MIX_RATE := 44100
const DURATION_S := 0.45
const ATTACK_S := 0.004
const AMPLITUDE := 0.6
# C4, la nota en la que están grabadas las muestras (SAMPLE_ROOT_MIDI).
const ROOT_HZ := 261.6255653


func _initialize() -> void:
	if not DirAccess.dir_exists_absolute(OUT_DIR):
		DirAccess.make_dir_recursive_absolute(OUT_DIR)

	for family in 3:
		for variant in 3:
			var stream := _render(family, variant)
			var path := "%s/family_%d_%d.wav" % [OUT_DIR, family + 1, variant]
			var error := stream.save_to_wav(path)
			if error != OK:
				printerr("No se pudo escribir %s (error %d)" % [path, error])
				quit(1)
				return
			print("OK %s" % path)

	quit(0)


# Cada familia tiene un timbre propio y cada variante cambia la caída y la
# mezcla de armónicos, para que B2 (ciclar variantes) se note a oído.
func _render(family: int, variant: int) -> AudioStreamWAV:
	var decay := 7.0 + variant * 2.5
	var second := 0.0
	var third := 0.0
	match family:
		0:
			second = 0.0
			third = 0.0
		1:
			second = 0.35 - variant * 0.05
			third = 0.0
		_:
			second = 0.20
			third = 0.15 + variant * 0.05

	var sample_count := int(MIX_RATE * DURATION_S)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in sample_count:
		var t := float(i) / MIX_RATE
		# Ataque corto para que el pluck no empiece con un chasquido.
		var attack := minf(1.0, t / ATTACK_S)
		var envelope := attack * exp(-t * decay)
		var value := sin(TAU * ROOT_HZ * t)
		value += second * sin(TAU * ROOT_HZ * 2.0 * t)
		value += third * sin(TAU * ROOT_HZ * 3.0 * t)
		value *= envelope * AMPLITUDE
		data.encode_s16(i * 2, int(clampf(value, -1.0, 1.0) * 32767.0))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream
