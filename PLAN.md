# PLAN.md — Cultivo (nombre provisorio)

Una sesión de opencode = un hito. Cada hito termina con los tests en verde y un reporte (ver `AGENTS.md`).

## Cómo arrancar una sesión

Prompt sugerido:

> Leé AGENTS.md, DISENO.md, ESPECIFICACION.md y PLAN.md. Trabajá solo el hito **M#**. No adelantes otros hitos. Al terminar, reportá según AGENTS.md.

## Resumen

| Hito | Qué | Lógica pura | Se mira/escucha |
|---|---|---|---|
| M0 | Base del proyecto | | |
| M1 | Reloj maestro | sí | oído |
| M2 | Modelo del organismo | sí | |
| M3 | Audio mínimo | parcial | oído |
| M4 | Vista Micro (solo visual) | | ojo |
| M5 | Interacción Micro | parcial | ojo y oído |
| M6 | Macro: varios organismos | parcial | ojo |
| M7 | Zoom y mezcla por foco | | ojo y oído |
| M8 | Puentes | sí | ojo y oído |
| M9 | Sesión, pulido y export | | todo |

## Punto de decisión (después de M5)

Con un solo organismo jugable (M0 a M5), Maxi lo prueba y decide si sigue. **Si un organismo solo no es entretenido en 30 segundos, se frena y se revisa el diseño antes de construir Macro, zoom y puentes.** Es el corte mínimo del proyecto: todo lo que viene después multiplica esto, no lo arregla.

---

## M0 — Base del proyecto

- **Objetivo:** proyecto Godot que corre, con estructura, configuración, input y test runner.
- **Leé:** AGENTS.md (estructura, input, tests), ESPECIFICACION sección 1.
- **Entregables:**
  - `project.godot`, carpetas de `AGENTS.md`, `src/core/config.gd` (`class_name Config` con `const`) con todas las constantes de la sección 1.
  - Input Map con las 8 acciones (`joy_up/down/left/right`, `btn_1..4`) y su mapeo de teclado.
  - `.gitignore` (`.godot/`, `/build/`), `.editorconfig` (tabs en `.gd`) y `README.md`.
  - `tools/run_tests.ps1`, el único lugar con la ruta del binario de Godot.
  - Escena `Main` con fondo oscuro y un overlay de depuración que muestra la última acción de input y el FPS.
  - `tests/run_tests.gd`, que descubre y corre todo `tests/test_*.gd`, con un test de ejemplo y salida con código distinto de cero si algo falla.
  - Un preset de export Linux x86_64 documentado en el README del proyecto (no hace falta exportar todavía).
- **Criterios:**
  - `[SCRIPT]` el runner corre con `tools\run_tests.ps1` y termina con código 0.
  - `[SCRIPT]` el proyecto importa limpio con `--headless`: 0 errores y 0 warnings en consola.
  - `[OJO]` el overlay muestra la acción correcta al apretar W A S D y H J K L.
- **No hacer:** lógica de juego.

## M1 — Reloj maestro

- **Objetivo:** el tick entero global, confiable.
- **Leé:** ESPECIFICACION sección 2.
- **Entregables:** `Clock` (`RefCounted`) con `advance(delta)` y señal `tick_emitted`; un `Node` que lo alimenta; overlay con tick y beat actual; un click sintético de metrónomo en cada beat (placeholder).
- **Criterios:**
  - `[SCRIPT]` T-15.
  - `[OÍDO]` V-04: metrónomo estable 3 minutos sin deriva audible.
- **No hacer:** organismos, escalas.

## M2 — Modelo del organismo

- **Objetivo:** todo el modelo temporal, sin gráficos ni sonido.
- **Leé:** ESPECIFICACION secciones 1 y 3.
- **Entregables:** `OrganismModel` con generación de geometría orgánica (R-20), longitudes de hifa (R-13), reparto de ticks (R-14), fase y ancla (R-17), disparos (R-18), origen (R-19), movimiento de nodos con restricciones (R-22). Todo con semilla controlable y emitiendo `node_fired`.
- **Criterios:** `[SCRIPT]` T-01 a T-10, T-18 y T-20.
- **No hacer:** dibujo, audio, puentes. Una clase simple, sin patrones de diseño innecesarios.

## M3 — Audio mínimo

- **Objetivo:** un organismo que suena, con altura y registro correctos.
- **Leé:** ESPECIFICACION sección 4.
- **Entregables:** módulo de escalas y mapeo de altura (R-23, R-24); script que genera los placeholders sintetizados (R-25); `VoicePool` (R-29); una escena de depuración que crea un organismo, dibuja los nodos como puntos y los hace sonar al disparar.
- **Criterios:**
  - `[SCRIPT]` T-13, T-14.
  - `[OÍDO]` V-05 y V-06: las tres escalas son consonantes; el registro por N es razonable.
- **No hacer:** vista final, buses por organismo, brillo.

## M4 — Vista Micro (solo visual)

- **Objetivo:** que se lea cómo circula el pulso, sin controles todavía.
- **Leé:** DISENO secciones 5.1 y 5.2; ESPECIFICACION R-21.
- **Entregables:** dibujo orgánico del organismo (nodos con bulbos que respiran, hifas curvas), pulso con cabeza y cola, motas de flujo, anticipación y flash en los nodos, nodo origen destacado. El organismo se instancia desde el modelo de M2 y suena con M3.
- **Criterios:**
  - `[OJO]` V-01 y V-02.
  - `[SCRIPT]` T-19: el pulso dibujado coincide con la posición derivada de R-21. La función que la calcula vive en el núcleo (sin nodos); la vista solo la suaviza.
- **No hacer:** input de juego, Macro. El suavizado de R-21 es solo visual.

## M5 — Interacción Micro

- **Objetivo:** poder jugar con un organismo.
- **Leé:** DISENO sección 7 (tabla Micro); ESPECIFICACION R-19, R-22, R-26, R-30, R-31, R-32, R-35.
- **Entregables:** router de input; selección de nodos por vecindad con auto-repetición; arrastre de nodo (B1 mantenido); origen (B1 tap); cambio de variante de sonido (B2); brillo con filtro por organismo (B3 mantenido); rechazo (sonido y temblor).
- **Criterios:**
  - `[SCRIPT]` T-16 (selección por vecindad).
  - `[OÍDO]` V-07 y V-08.
  - `[OJO]` cada botón da respuesta visible y audible en menos de 1 s.
- **No hacer:** B4, Macro. (B4 todavía puede dar rechazo.)

> **Acá termina el corte mínimo.** Ver "Punto de decisión".

## M6 — Macro: varios organismos

- **Objetivo:** el mundo con varios organismos y su gestión.
- **Leé:** DISENO secciones 4, 5.3 y 7 (tabla Macro); ESPECIFICACION R-30, R-31, R-33, R-34, R-38.
- **Entregables:** vista Macro con varios organismos pulsando; selección de organismos por vecindad; siembra con N elegible en vivo y cancelación (B2 y B4); disolución (B4 mantenido); deriva cosmética; topes; vista Macro como estado alterno (con corte directo, sin animación aún).
- **Criterios:**
  - `[SCRIPT]` T-17.
  - `[OJO]` V-02 en Macro.
  - `[OÍDO]` varios organismos de distinto N se mantienen en polimetría estable (V-11 parcial).
- **No hacer:** animación de zoom, mezcla de foco, puentes.

## M7 — Zoom y mezcla por foco

- **Objetivo:** pasar entre Macro y Micro, y que el sonido acompañe.
- **Leé:** DISENO 5.3 y 6; ESPECIFICACION R-36 y `ZOOM_TIME_S`.
- **Entregables:** cámara con zoom animado (B1 en Macro, B4 en Micro); un bus de audio por organismo; mezcla por foco con fundidos.
- **Criterios:**
  - `[OJO]` V-03.
  - `[OÍDO]` V-09.
- **No hacer:** puentes.

## M8 — Puentes

- **Objetivo:** que los organismos se relacionen.
- **Leé:** DISENO secciones 4 y 7 (B3 en Macro); ESPECIFICACION R-27, R-28.
- **Entregables:** modelo de puentes con cola de ecos; creación y quita con B3 + dirección; dibujo de los filamentos tensados y del pulso de eco; limpieza al disolver organismos.
- **Criterios:**
  - `[SCRIPT]` T-11, T-12.
  - `[OJO]` el eco se ve viajar por el puente.
  - `[OÍDO]` V-10 y V-11.
- **No hacer:** contagio ni ninguna propagación del eco.

## M9 — Sesión, pulido y export

- **Objetivo:** que funcione como instalación en el arcumai.
- **Leé:** DISENO secciones 8 y 10; ESPECIFICACION R-37.
- **Entregables:** estado inicial (un organismo en Micro), reinicio por inactividad con fundido, sorteo de escala y tónica por sesión, revisión de rechazos en todos los contextos, ajuste de constantes de `config.gd` con lo que surja de las pruebas, export a Linux y prueba en el arcumai.
- **Criterios:**
  - `[SCRIPT]` toda la suite en verde.
  - `[OJO]` / `[OÍDO]` V-12 con alguien nuevo, 5 minutos.
  - El export corre en Fedora sin dependencias extra y el input del arcumai se reconoce.
- **No hacer:** nada del apartado "Fuera de alcance v1".

---

## Después de v1 (en este orden, solo si v1 funciona)

1. Reemplazar placeholders por las muestras de Maxi.
2. Probar ciclo elástico como experimento (opción en `config.gd`).
3. Puentes de contagio.
4. Metabolismo.
5. Guardar piezas.
6. Control USB adicional.
