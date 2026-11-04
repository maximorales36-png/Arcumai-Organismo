# Cultivo (nombre provisorio)

Instalación musical jugable para el arcumai: organismos tipo micelio que suenan
al circular un pulso, y que la persona deforma y conecta.

Las reglas del juego están en `DISENO.md`, `ESPECIFICACION.md` y `PLAN.md`.
Este archivo solo cubre cómo correr y empaquetar el proyecto.

## Requisitos

- Godot 4.7.2 (el editor usado en desarrollo).
- Windows para desarrollar; Linux Fedora x86_64 como destino.

## Correr el juego

Abrí `project.godot` con el editor de Godot y ejecutá el proyecto (F5), o desde
la terminal:

```powershell
godot --path .
```

La escena `src/view/main.tscn` es la de depuración: arranca en Macro con tres
organismos de distinto N (3, 4 y 5) que pulsan a la vez. B1 entra a la vista
Micro del organismo seleccionado y B4 vuelve a Macro. El overlay muestra tick,
beat, escala, modo, organismos, selección, variante, brillo, última acción,
última nota y FPS.

### Controles (vista Macro)

| Acción | Teclado | Efecto |
|---|---|---|
| Joystick | W / A / S / D | Selecciona el organismo vecino en esa dirección (mantener repite) |
| B1 tap | H | Entra a Micro con el organismo seleccionado |
| B2 mantener | J | Siembra un organismo; izquierda/derecha cambia su N en vivo |
| B2 soltar | J | Confirma la siembra |
| B4 durante la siembra | L | Cancela y elimina el organismo sembrado |
| B4 mantener 1 s | L | Disuelve el organismo seleccionado (soltar antes lo recupera) |
| B3 | K | Puentes: todavía no (M8), produce rechazo |

### Controles (vista Micro)

| Acción | Teclado | Efecto |
|---|---|---|
| Joystick | W / A / S / D | Selecciona el nodo contiguo en esa dirección (mantener repite) |
| B1 mantener + joystick | H + WASD | Arrastra el nodo seleccionado |
| B1 tap | H | El nodo seleccionado pasa a ser el origen |
| B2 tap | J | Cambia la variante de sonido del nodo seleccionado |
| B3 mantener + arriba/abajo | K + W/S | Brillo del organismo (arriba = más brillante) |
| B4 | L | Vuelve a Macro |

En el arcumai, el joystick y los botones llegan como un dispositivo USB; el
mapeo de ejes y botones se ajusta cuando se pruebe en el hardware.

## Placeholders de audio

Las muestras definitivas todavía no existen (R-25). Los placeholders de las 3
familias × 3 variantes se generan por script y se versionan en
`audio/placeholder/`:

```powershell
godot --headless --path . --script res://tools/generate_placeholders.gd
```

El script es de desarrollo: no se usa en tiempo de ejecución. Cuando Maxi aporte
las muestras reales, van en `audio/<familia>/<variante>.wav`.

## Correr los tests

En Windows:

```powershell
.\tools\run_tests.ps1
```

En Fedora:

```bash
godot --headless --path . --script res://tests/run_tests.gd
```

El runner descubre y corre todos los `tests/test_*.gd` y sale con código 0 solo
si todos los tests pasan. Antes de correrlos importa el proyecto (incremental,
~1 s): sin eso, un `class_name` recién creado no existe y los tests no compilan.

## Export

Preset **Linux x86_64** en `export_presets.cfg`. El binario va a `build/linux/`
(ignorado por git):

```powershell
New-Item -ItemType Directory -Force build\linux
godot --headless --path . --export-release "Linux x86_64" build/linux/cultivo.x86_64
```

Godot no crea la carpeta de destino: si no existe, el export falla. El export
debe correr en Fedora sin dependencias extra (se prueba en M9).
