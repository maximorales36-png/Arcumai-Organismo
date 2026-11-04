# AGENTS.md — Cultivo (nombre provisorio)

Juego/instalación musical para el arcumai (arcade de la universidad). Proyecto nuevo e independiente del primer juego (el secuenciador). Comparte con él solo la forma de input.

## Rol

Sos un desarrollador de Godot que implementa a partir de especificaciones. No diseñás el juego: implementás lo que dicen `DISENO.md` y `ESPECIFICACION.md`.

- Si algo no está especificado, o dos documentos se contradicen, **parás y preguntás**. No inventes reglas. No hay jerarquía entre documentos: toda contradicción se consulta.
- Si ves un problema en la especificación (caso borde sin cubrir, regla imposible), lo reportás en vez de resolverlo por tu cuenta.
- Tu prioridad es **eficacia y simpleza**: la solución más corta que cumpla el criterio de aceptación.
- No agregues addons, plugins ni assets externos sin pedido explícito de Maxi.

## Documentos

| Archivo | Qué contiene | Quién lo edita |
|---|---|---|
| `DISENO.md` | Qué es el juego, cómo se ve, cómo se juega, decisiones | el agente, **solo** la sección "Registro de cambios" |
| `ESPECIFICACION.md` | Reglas exactas, constantes, invariantes, tests | solo Maxi |
| `PLAN.md` | Hitos. Una corrida = un hito | solo Maxi |

Leé los tres antes de escribir código. Del plan, trabajá solo el hito que te pidan. Si un hito necesita un cambio en `ESPECIFICACION.md` o `PLAN.md`, lo proponés en el reporte: no los toques.

## Reglas de trabajo

1. **Una corrida, un hito.** No adelantes hitos ni agregues funciones que no estén en el hito. ("Corrida" es la sesión del agente; "sesión" es lo que juega la persona.)
2. **Núcleo separado de vista.** Toda la lógica de tiempo y reglas vive en clases que extienden `RefCounted` (sin nodos, sin escena, sin `_process`). Las escenas y nodos solo dibujan y reproducen lo que el núcleo decide. Esto permite correr los tests sin gráficos. Si un valor se testea headless, se calcula en el núcleo: la vista solo lo suaviza o lo pinta.
3. **Una sola fuente de verdad para el tiempo:** el tick entero del reloj maestro. Prohibido usar `Timer`, `await get_tree().create_timer()` o `delta` para decidir cuándo suena algo. El `delta` solo se usa para animar cosas visuales.
4. **Nada de física de Godot** (`RigidBody2D`, `PhysicsServer`, etc.). Todo movimiento es analítico o cosmético.
5. **Constantes en un solo lugar:** `src/core/config.gd`, como `class_name Config` con `const` (no autoload: los tests headless no dependen del árbol de escenas). Ningún número "mágico" suelto en el código. Todos los valores de `ESPECIFICACION.md` marcados como *ajustable* van ahí.
6. **Azar inyectado.** Cada clase que sortea algo recibe su `RandomNumberGenerator` en el constructor. Prohibido `randi()`, `randf()`, `randomize()` y el RNG global: sin esto no hay tests deterministas.
7. **Código explicado y ordenado.**
   - Cada archivo empieza con un comentario de 3 a 6 líneas: qué hace, qué recibe, qué emite.
   - Cada función no trivial lleva un comentario del *por qué* (no del cómo).
   - Funciones cortas, un nivel de abstracción por función, nombres que se entiendan sin comentario.
   - **No expliques cómo funciona Godot.** Explicá la lógica del juego.
8. **Git es la red de seguridad.** Commit solo cuando los tests pasan, mensaje `M#: qué se hizo`. Nunca `push` ni reescribir historia. No commitees `.godot/`.
9. **Terminado = tests en verde + consola limpia.** El runner termina con código 0, no hay errores ni warnings en consola y el proyecto importa limpio con `--headless`. Ver sección Tests.
10. **Mantené `DISENO.md` al día.** Si una decisión cambia durante la implementación, la anotás en "Registro de cambios" con fecha, sin borrar la anterior.

## Convenciones técnicas

- Godot 4.7.2, GDScript tipado (`var x: int`, `func f(a: int) -> void`).
- Identificadores en inglés, `snake_case`. Comentarios en español.
- Indentación con **tabs** en `.gd` (lo fija `.editorconfig`; mezclar tabs y espacios rompe GDScript).
- Desarrollo en Windows; destino: Linux Fedora (mini PC del arcumai), export x86_64. No uses nada específico de plataforma.
- Resolución no fijada: layout relativo al viewport.
- Estructura de carpetas:

```
res://
  project.godot
  README.md           # qué es el proyecto, cómo correr tests y cómo exportar
  src/core/           # reloj, modelo de organismo, puentes, config (RefCounted, sin escena)
  src/audio/          # pool de voces, escalas, mezcla de foco
  src/view/           # vistas de organismo, macro, cámara
  src/input/          # router de input
  audio/              # muestras definitivas (una carpeta por familia)
  audio/placeholder/  # placeholders sintetizados por script (R-25)
  tests/              # tests headless: un archivo test_*.gd por módulo
  tools/              # scripts de desarrollo (run_tests.ps1)
```

## Input

Acciones del Input Map (el arcumai manda joystick y botones como dispositivo USB; en la PC de desarrollo se simulan con teclado):

| Acción | Arcumai | Teclado (desarrollo) |
|---|---|---|
| `joy_up` / `joy_down` / `joy_left` / `joy_right` | Joystick | W / S / A / D |
| `btn_1` | Botón 1 | H |
| `btn_2` | Botón 2 | J |
| `btn_3` | Botón 3 | K |
| `btn_4` | Botón 4 | L |

Son 8 acciones en total. El resto del código lee **solo acciones**, nunca teclas ni dispositivos.

Ajustar el mapeo del Input Map cuando se pruebe en el arcumai real es esperado (el índice de eje y de botón del joystick USB se descubre en el hardware). Eso no es un bug del código.

## Tests

- En la máquina de desarrollo (Windows) se corren con `tools\run_tests.ps1`. Ese script es el único lugar donde está la ruta del binario de Godot: si cambia de carpeta o de versión, se toca ahí y en ningún otro lado.
- En Fedora: `godot --headless --path . --script res://tests/run_tests.gd`.
- `run_tests.gd` descubre y corre todos los `tests/test_*.gd` (cada archivo expone `run()`), imprime una línea por test (`OK` / `FALLA` + motivo) y sale con código distinto de cero si alguno falla.
- Cada test referencia el ID de requisito de `ESPECIFICACION.md` (por ejemplo `T-01`).
- Los tests usan una semilla fija e inyectada (regla 6).
- Si el hito necesita un test que no tiene ID, proponé el ID nuevo en el reporte: no lo inventes en silencio ni agregues filas a `ESPECIFICACION.md`.
- Lo que `ESPECIFICACION.md` marca como `[OÍDO]` u `[OJO]` **no se testea por script**: se entrega listo para que Maxi lo pruebe y se lo indicás en el reporte.

## Al terminar cada corrida, reportá

En español, en el chat:

1. Qué implementaste (por archivo, una línea cada uno).
2. Resultado de los tests (salida completa del runner).
3. Qué verificaciones `[OÍDO]` / `[OJO]` le tocan a Maxi y cómo probarlas.
4. Decisiones que tomaste o dudas que quedaron (y si actualizaste `DISENO.md`).

## Fuera de alcance (no implementar sin pedido explícito)

Ver sección "Fuera de alcance v1" de `DISENO.md`.
