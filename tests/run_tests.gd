# Runner de tests headless del proyecto. Descubre todos los tests/test_*.gd,
# ejecuta su run() e imprime una línea por test. No usa árbol de escenas ni
# gráficos. Contrato de cada test: `extends RefCounted` y
# `run() -> Array[Dictionary]` con entradas {id, ok, detail}.
# Sale con código 1 si algo falla y 0 si todo pasa.

extends SceneTree

const TESTS_DIR := "res://tests"
const TEST_PREFIX := "test_"


func _initialize() -> void:
	var files := _discover_tests()
	var total := 0
	var failures := 0

	for path in files:
		var script := load(path) as Script
		# Un script roto no debe abortar el runner: se reporta y se sigue,
		# porque si _initialize sale por una excepción el proceso queda vivo.
		if script == null or not script.can_instantiate():
			print("FALLA %s  no se pudo cargar el script" % path)
			failures += 1
			continue

		var test = script.new()
		if not test.has_method("run"):
			print("FALLA %s  no expone run()" % path)
			failures += 1
			continue

		for result in test.run():
			total += 1
			if result["ok"]:
				print("OK    %s  %s" % [result["id"], result["detail"]])
			else:
				failures += 1
				print("FALLA %s  %s" % [result["id"], result["detail"]])

	if total == 0:
		print("FALLA no se encontraron tests en %s" % TESTS_DIR)
		failures += 1

	print("%d tests, %d fallas" % [total, failures])
	quit(0 if failures == 0 else 1)


# Ordena los archivos para que la salida sea estable entre corridas.
func _discover_tests() -> Array[String]:
	var files: Array[String] = []
	var dir := DirAccess.open(TESTS_DIR)
	if dir == null:
		return files
	for file_name in dir.get_files():
		if file_name.begins_with(TEST_PREFIX) and file_name.ends_with(".gd"):
			files.append(TESTS_DIR.path_join(file_name))
	files.sort()
	return files
