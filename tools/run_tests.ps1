# Corre los tests headless del proyecto en la maquina de desarrollo (Windows).
# La ruta del binario de Godot vive solo aca: si cambia la version o la carpeta,
# es la unica linea a tocar. Propaga el codigo de salida del runner, asi que
# sirve tal cual en un hook o en un script de CI.
# Equivalente en Fedora: godot --headless --path . --script res://tests/run_tests.gd
# Se usa el binario _console.exe para que la salida llegue a stdout de forma confiable.

$ErrorActionPreference = 'Stop'

$GodotExe = 'C:\Users\maxim\OneDrive\Desktop\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$TestScript = Join-Path $ProjectRoot 'tests\run_tests.gd'

if (-not (Test-Path -LiteralPath $GodotExe)) {
    [Console]::Error.WriteLine("No se encontro Godot en '$GodotExe'. Ajustar `$GodotExe en tools/run_tests.ps1.")
    exit 2
}

if (-not (Test-Path -LiteralPath $TestScript)) {
    [Console]::Error.WriteLine("No se encontro el runner en '$TestScript'.")
    exit 2
}

# Godot no registra un class_name nuevo hasta importar el proyecto. Se importa
# siempre (es incremental, ~1 s) para que un script recien creado no rompa los tests.
& $GodotExe --headless --path $ProjectRoot --import | Out-Null
if ($LASTEXITCODE -ne 0) {
    [Console]::Error.WriteLine("Fallo la importacion del proyecto (codigo $LASTEXITCODE).")
    exit $LASTEXITCODE
}

& $GodotExe --headless --path $ProjectRoot --script 'res://tests/run_tests.gd'
exit $LASTEXITCODE
