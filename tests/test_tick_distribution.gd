# Tests del reparto de ticks entre hifas (R-14): T-01 a T-05.
# No usa geometría real: alimenta largos aleatorios a la función pura
# distribute_ticks, que es la misma que usa OrganismModel.
# Contrato: `extends RefCounted` con `run() -> Array[Dictionary]`.

extends RefCounted

const ITERATIONS := 10000


func run() -> Array[Dictionary]:
	return [_t01_sum(), _t02_minimum(), _t03_deterministic(), _t04_equal_lengths(), _t05_monotonic()]


func _t01_sum() -> Dictionary:
	var rng := _seeded_rng()
	for iteration in ITERATIONS:
		var lengths := _random_lengths(rng)
		var ticks := OrganismModel.distribute_ticks(lengths)
		var total := 0
		for value in ticks:
			total += value
		var expected := lengths.size() * Config.TICKS_PER_BEAT
		if total != expected:
			return _fail("T-01", "n=%d suma=%d esperado=%d" % [lengths.size(), total, expected])
	return _ok("T-01", "%d repartos, la suma siempre da C" % ITERATIONS)


func _t02_minimum() -> Dictionary:
	var rng := _seeded_rng()
	for iteration in ITERATIONS:
		var lengths := _random_lengths(rng)
		for value in OrganismModel.distribute_ticks(lengths):
			if value < Config.MIN_EDGE_TICKS:
				return _fail("T-02", "una hifa quedó con %d ticks" % value)
	return _ok("T-02", "ninguna hifa baja de MIN_EDGE_TICKS")


func _t03_deterministic() -> Dictionary:
	var rng := _seeded_rng()
	for iteration in 1000:
		var lengths := _random_lengths(rng)
		if OrganismModel.distribute_ticks(lengths) != OrganismModel.distribute_ticks(lengths):
			return _fail("T-03", "dos llamadas con el mismo largo dieron distinto")
	return _ok("T-03", "el reparto es determinista")


func _t04_equal_lengths() -> Dictionary:
	for count in range(Config.N_MIN, Config.N_MAX + 1):
		var lengths: Array[float] = []
		lengths.resize(count)
		lengths.fill(42.0)
		for value in OrganismModel.distribute_ticks(lengths):
			if value != Config.TICKS_PER_BEAT:
				return _fail("T-04", "n=%d: con largos iguales una hifa quedó con %d" % [count, value])
	return _ok("T-04", "con hifas iguales cada una recibe un beat")


func _t05_monotonic() -> Dictionary:
	var rng := _seeded_rng()
	for iteration in ITERATIONS:
		var lengths := _random_lengths(rng)
		var ticks := OrganismModel.distribute_ticks(lengths)
		for i in lengths.size():
			for j in lengths.size():
				if lengths[i] > lengths[j] and ticks[i] < ticks[j]:
					return _fail("T-05", "la hifa %d es más larga pero recibió menos ticks" % i)
	return _ok("T-05", "más largo nunca recibe menos ticks")


func _seeded_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260101
	return rng


func _random_lengths(rng: RandomNumberGenerator) -> Array[float]:
	var lengths: Array[float] = []
	var count := rng.randi_range(Config.N_MIN, Config.N_MAX)
	for i in count:
		lengths.append(rng.randf_range(0.1, 200.0))
	return lengths


func _ok(test_id: String, detail: String) -> Dictionary:
	return {"id": test_id, "ok": true, "detail": detail}


func _fail(test_id: String, detail: String) -> Dictionary:
	return {"id": test_id, "ok": false, "detail": detail}
