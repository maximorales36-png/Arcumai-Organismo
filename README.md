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

En M0 la escena `src/view/main.tscn` solo muestra un fondo oscuro, la última
acción de input recibida y los FPS.

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
