# Cultivo (nombre provisorio)

Instalación musical jugable para el arcumai: organismos tipo micelio que suenan
al circular un pulso, y que la persona deforma y conecta.

Las reglas del juego están en `DISENO.md`, `ESPECIFICACION.md` y `PLAN.md`.
Este archivo solo cubre cómo correr y empaquetar el proyecto.

## Requisitos

- Godot 4.7.2 (el editor usado en desarrollo).
- Windows para desarrollar; Linux Fedora x86_64 como destino.

## Correr los tests

En Windows:

```powershell
.\tools\run_tests.ps1
```

En Fedora:

```bash
godot --headless --path . --script res://tests/run_tests.gd
```

El runner sale con código 0 solo si todos los tests pasan.

## Export

Preset de export **Linux x86_64** (pendiente de crear en M0). El export debe
correr en Fedora sin dependencias extra.
