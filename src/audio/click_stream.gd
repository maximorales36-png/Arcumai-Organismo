# Click de metrónomo de M1: placeholder sintetizado, no una muestra final.
# Genera en memoria un seno corto con caída exponencial, así no hay archivos
# binarios en el repo ni depende de assets que todavía no existen (R-25, M3).
# Recibe frecuencia y duración; devuelve un AudioStreamWAV mono de 16 bits.

class_name ClickStream
extends RefCounted

const MIX_RATE := 44100
const FREQ_HZ := 880.0
const DURATION_S := 0.04
const AMPLITUDE := 0.5
const DECAY := 120.0
const INT16_MAX := 32767.0


static func make(freq_hz: float = FREQ_HZ, duration_s: float = DURATION_S) -> AudioStreamWAV:
	var sample_count := int(MIX_RATE * duration_s)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in sample_count:
		var t := float(i) / MIX_RATE
		# La caída rápida deja un click seco: una cola larga taparía el pulso siguiente.
		var envelope := exp(-t * DECAY)
		var value := sin(TAU * freq_hz * t) * envelope * AMPLITUDE
		data.encode_s16(i * 2, int(clamp(value, -1.0, 1.0) * INT16_MAX))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream
