# ESPECIFICACION.md — Cultivo (nombre provisorio)

Reglas exactas del juego. Si algo de acá contradice `DISENO.md`, parar y preguntar.

Etiquetas de verificación:
- `[SCRIPT]` se verifica con un test headless.
- `[OÍDO]` lo prueba Maxi escuchando.
- `[OJO]` lo prueba Maxi mirando.

## 1. Constantes (`src/core/config.gd`)

Valores iniciales. Los marcados *ajustable* se afinan a oído o a ojo, sin tocar la lógica.

| Constante | Valor | Nota |
|---|---|---|
| `BPM` | 100 | ajustable |
| `TICKS_PER_BEAT` | 4 | un tick = una semicorchea |
| `TICK_SEC` | `60 / (BPM * TICKS_PER_BEAT)` | derivada (0,15 s con los valores iniciales) |
| `N_MIN` / `N_MAX` / `N_DEFAULT` | 2 / 8 / 4 | |
| `N_SPAWN` | 2 | nodos con los que nace un organismo sembrado con B2 |
| `MIN_EDGE_TICKS` | 1 | ticks mínimos por hifa |
| `MIN_NODE_DIST` | 18 | unidades locales; distancia mínima entre nodos |
| `R_MAX(n)` | `100 + 15 * (n - 2)` | radio máximo del organismo, unidades locales |
| `MAX_ORGANISMS` | 5 | ajustable |
| `MAX_BRIDGES` | 6 | ajustable |
| `BRIDGE_DELAY_TICKS` | 2 | ajustable |
| `VOICE_CAP` | 16 | ajustable |
| `FAMILY_COUNT` / `VARIANT_COUNT` | 3 / 4 | familias de sonido y variantes por familia |
| `VARIANT_PITCHED` / `VARIANT_CROSS_STICK` / `VARIANT_KICK` / `VARIANT_SILENCE` | 0 / 1 / 2 / 3 | variantes de un nodo (R-25) |
| `PITCH_SPAN_DEGREES` | 8 | grados de escala por organismo |
| `BASE_MIDI(n)` | `round(lerp(60, 36, (n - 2) / 6))` | registro por N; más pulsos = más grave |
| `SAMPLE_ROOT_MIDI` | 60 | la variante `nota` está grabada en C4 |
| `DRAG_SPEED` | 180 | unidades/s a joystick completo |
| `NAV_REPEAT_FIRST_MS` / `NAV_REPEAT_MS` | 350 / 200 | auto-repetición de selección |
| `DISSOLVE_HOLD_MS` | 600 | |
| `SPAWN_HOLD_MS` | 1200 | carga de B2 para sembrar |
| `SPAWN_COOLDOWN_S` | 5 | espera entre siembras |
| `INACTIVITY_RESET_S` | 90 | |
| `ZOOM_TIME_S` | 0.5 | |
| `FOCUS_OTHERS_DB` | -9 | otros organismos en Micro |
| `FOCUS_OTHERS_LPF_HZ` | 1200 | idem |
| `FOCUS_FADE_S` | 0.4 | |
| `BRIGHTNESS_DEFAULT` | 0.8 | rango 0 a 1 |
| `BRIGHTNESS_SPEED` | 0.8 | por segundo con joystick a fondo |
| `WORLD_SIZE` | (2400, 1350) | unidades de mundo |
| `MIN_ORG_DISTANCE` | 350 | separación mínima entre organismos |
| `DRIFT_MAX_SPEED` | 6 | unidades de mundo/s |
| `MACRO_ORG_SCALE` | 0.3 | escala de dibujo en Macro |

Escala única (semitonos desde la tónica). Todas las notas de todos los
organismos salen de acá; la tónica se sortea por sesión:

| Escala | Notas |
|---|---|
| Pentatónica menor | 0, 3, 5, 7, 10 |

## 2. Reloj maestro

- **R-01** Existe un único contador entero `tick`, global, que avanza cada `TICK_SEC`. Es la única fuente de verdad del tiempo musical.
- **R-02** La clase `Clock` (`RefCounted`) tiene `advance(delta: float)`. Acumula `delta` y, mientras el acumulado sea `>= TICK_SEC`, resta `TICK_SEC`, incrementa `tick` y emite `tick_emitted(tick)`. **Nunca saltea un tick**, aunque un frame traiga un `delta` grande: emite los ticks atrasados en orden. Un `Node` fino llama `advance(delta)` desde `_process`.
- **R-03** Se acepta que el audio salga con un jitter de hasta un frame (~16 ms). Es una limitación conocida de v1. `[OÍDO]` verificar que no moleste. Mejora futura (fuera de v1): reloj atado a `AudioServer`.
- **R-04** Orden de evaluación dentro de cada tick `T` (para que el resultado sea determinista):
  1. Cada organismo, en orden de creación, evalúa sus disparos (R-18), nodos en orden ascendente de índice.
  2. Luego se disparan los ecos cuya cola vence en `T` (R-27), en orden de la cola.

## 3. Modelo del organismo

Clase `OrganismModel` (`RefCounted`). No conoce nodos de escena ni sonido: emite `node_fired(organism_id, node_index, tick, is_echo)`.

- **R-10** `n` está acotado a `[N_MIN, N_MAX]`; cualquier valor fuera de rango se recorta.
- **R-11** Estructura: `n` nodos en anillo, índices `0..n-1`. La hifa `e_i` va del nodo `i` al nodo `(i + 1) % n`. El pulso circula siempre en el sentido de índices crecientes.
- **R-12** Caso `n = 2`: hay dos hifas, `e_0` (nodo 0 a nodo 1) y `e_1` (nodo 1 a nodo 0). Se dibujan como dos arcos con curvatura de signo opuesto (mínimo 0,25 de la cuerda) para que el lazo se vea.
- **R-13** Longitud de hifa `L_i`: largo del arco de la curva de `e_i` en coordenadas locales (por ejemplo `Curve2D.get_baked_length()`). Cada hifa tiene un factor de curvatura propio, fijo desde su creación, y la curva se recalcula con él cuando se mueven sus nodos. Se recalcula solo cuando un nodo se mueve, no en cada tick.
- **R-14** **Reparto de ticks (ciclo fijo).** Duración del ciclo `C = n * TICKS_PER_BEAT`. Para cada hifa se calcula `t_i` (ticks que tarda el pulso en recorrerla):
  1. `R = C - n * MIN_EDGE_TICKS`.
  2. `x_i = R * L_i / sum(L)`.
  3. `t_i = MIN_EDGE_TICKS + floor(x_i)`.
  4. `resto = C - sum(t_i)`. Se suma 1 tick a las `resto` hifas con mayor parte fraccionaria (`x_i - floor(x_i)`); en empate, gana el menor índice.
  5. Si `sum(L) == 0` (caso degenerado), `t_i = C / n` para todas.
  Invariantes: `sum(t_i) == C`, `t_i >= MIN_EDGE_TICKS`, resultado determinista.
- **R-15** **Nodo origen.** Cada organismo tiene un índice `o` (nodo origen), inicialmente 0. Posición en el ciclo del nodo `i`: `p = (i - o) mod n`.
- **R-16** **Inicios de cada nodo.** `S[p] = sum_{q<p} t[(o + q) mod n]`, con `S[0] = 0` y `S[n] = C`. El nodo en la posición `p` es el nodo de índice `(o + p) mod n`.
- **R-17** **Fase.** El organismo nace con un `anchor_tick` igual al primer múltiplo de `TICKS_PER_BEAT` estrictamente posterior al tick actual. Para `T >= anchor_tick`, `phi(T) = (T - anchor_tick) mod C`. Antes del ancla, el organismo no suena. La fase está **siempre atada al reloj global**: editar nodos nunca cambia el período del ciclo.
- **R-18** **Regla de disparo.** En cada tick `T >= anchor_tick`:
  ```
  phi = (T - anchor_tick) mod C
  si phi == 0: fired = [false] * n       # nuevo ciclo
  para p en 0..n-1:
      i = (o + p) mod n
      si S[p] == phi y no fired[i]:
          fired[i] = true
          emitir node_fired(id, i, T, false)
  ```
  Consecuencias aceptadas: un nodo dispara como máximo una vez por ciclo, y si una edición mueve su inicio por detrás de `phi` antes de que suene, ese golpe se saltea en ese ciclo. El nodo origen (`p = 0`) suena siempre en `phi == 0`.
- **R-19** **Cambiar el origen** (`set_origin(i)`): efecto inmediato sobre `S`; se conservan los `fired`. La cuenta de ticks por hifa no cambia, solo cuál nodo es `p = 0`. Mantiene `sum = C` y el período `C`. `[OÍDO]` evaluar si el efecto inmediato se siente bien o si conviene diferirlo al próximo inicio de ciclo.
- **R-20** **Geometría orgánica inicial.** Los nodos se ubican sobre un anillo de radio `~0,6 * R_MAX(n)` con jitter angular y radial aleatorios (semilla controlable), respetando `MIN_NODE_DIST` y `R_MAX(n)`. Nunca polígono regular: el jitter angular mínimo evita ángulos iguales.
- **R-21** **Posición visual del pulso (derivada, no es estado).** Se calcula `phi_f = phi + fracción_de_tick` (fracción = tiempo desde el último tick / `TICK_SEC`); se busca `p` con `S[p] <= phi_f < S[p+1]` y el progreso `u = (phi_f - S[p]) / t[(o+p) mod n]`; la cabeza se dibuja a fracción `u` del largo de la hifa. La vista aplica suavizado (constante de tiempo ~80 ms) para absorber saltos por ediciones. **Este suavizado es solo visual y nunca influye en los disparos.** El cálculo de la posición derivada es una función pura del núcleo (sin nodos), para poder testearlo headless (T-19).

### Mover un nodo (Micro)

- **R-22** Arrastre: `posición += stick_vector * DRAG_SPEED * delta`, acotada al círculo de radio `R_MAX(n)` centrado en el organismo, y sin acercarse a menos de `MIN_NODE_DIST` de otro nodo (si lo viola, el movimiento se anula en ese eje). Tras cada movimiento se recalculan `L_i` de las hifas vecinas y se reaplica R-14.

## 4. Sonido

- **R-23** **Altura.** `h = clamp(-(y_local / R_MAX(n)), -1, 1)` (arriba = positivo). `grado = round((h + 1) / 2 * (PITCH_SPAN_DEGREES - 1))`. `semitonos(grado) = 12 * (grado div len(escala)) + escala[grado mod len(escala)]`. `midi = BASE_MIDI(n) + tónica + semitonos(grado)`. `pitch_scale = 2 ^ ((midi - SAMPLE_ROOT_MIDI) / 12)`.
- **R-24** **Escala y tónica.** La escala es siempre la pentatónica menor (0, 3, 5, 7, 10). La tónica se sortea entera entre 0 y 11 al iniciar la sesión y no cambia durante la sesión.
- **R-25** **Familias y variantes.** 3 familias con 4 variantes cada una, en `res://audio/<familia>/<variante>.wav`; la variante `nota` está grabada en C4. Un organismo nuevo recibe la familia siguiente en rotación; cada nodo tiene una variante (empieza en `VARIANT_PITCHED`). B2 en Micro cicla la variante del nodo seleccionado en el orden `nota → cross-stick → bombo → silencio`. La variante `nota` se afina con R-23; `cross-stick` y `bombo` suenan a altura fija; `silencio` no gasta voz y solo deja el flash visual. Hasta que Maxi aporte las muestras, el agente genera placeholders sintetizados por script y los guarda en `res://audio/placeholder/`.
- **R-26** **Brillo.** Cada organismo tiene `brillo` (0 a 1, `BRIGHTNESS_DEFAULT`). Su bus de audio lleva un filtro pasabajos con `cutoff_hz = 800 * 20 ^ brillo` (800 Hz a 16 kHz). El brillo no se resetea al cambiar de vista. El mismo valor se usa en la vista: bajarlo apaga el dibujo del organismo y subirlo por encima de 0.75 abre el halo.
- **R-29** **Voces.** Un pool de `VOICE_CAP` reproductores. Si todos están ocupados, se roba la voz más antigua. Cada disparo (nodo o eco) usa una voz.

## 5. Puentes

- **R-27** **Eco.** Un puente es dirigido: `(origen A, nodo emisor s, destino B, nodo receptor d)`. Cuando el nodo `s` de A emite `node_fired` con `is_echo == false`, se encola un evento `(tick + BRIDGE_DELAY_TICKS, B, d)`. Al vencer, se emite `node_fired(B, d, tick, true)`. Un disparo con `is_echo == true` **no** encola nuevos ecos ni afecta `fired`. Si A o B ya no existen al vencer, el evento se descarta.
- **R-28** **Creación y límites.**
  - Se crea con B3 mantenido + dirección hacia el organismo vecino (misma regla de vecindad que R-30).
  - `s` = nodo de A más cercano al centro de B; `d` = nodo de B más cercano al centro de A (en coordenadas de mundo, calculados al crear y fijos después).
  - Máximo un puente por par ordenado (A, B). Repetir el gesto sobre un puente existente lo **quita**.
  - Puentes A→B y B→A pueden coexistir. Máximo `MAX_BRIDGES` en total; si se supera, se aplica el rechazo (R-31).
  - Al disolver un organismo se eliminan sus puentes.

## 6. Input y respuesta

- **R-30** **Joystick digital, selección por vecindad.** Se lee como vector de 8 direcciones. Cada empuje mueve la selección al candidato **más cercano** cuyo ángulo respecto del joystick no supere los 60°; a igual distancia gana el de menor ángulo. Si no hay candidato, se aplica el rechazo (R-31). Mantener el joystick repite el paso: primera repetición a `NAV_REPEAT_FIRST_MS`, siguientes cada `NAV_REPEAT_MS`. La regla vale para nodos (Micro) y organismos (Macro).
- **R-31** **Rechazo.** Toda acción imposible (sin vecino, tope de organismos, tope de puentes, disolver el último organismo) produce una respuesta de rechazo: un sonido corto, grave y bajo (≈ -18 dB) y un temblor visual de 150 ms sobre el elemento seleccionado. Ningún botón puede quedar sin respuesta.
- **R-32** **Gestos con B1 en Micro.** Se decide al soltar B1: si durante la pulsación el joystick se movió, fue arrastre (R-22) y no cambia el origen; si no se movió, es un tap y el nodo seleccionado pasa a ser origen (R-19). No hay umbral de tiempo.
- **R-33** **Siembra (Macro, B2).** Al apretar B2 empieza una carga de `SPAWN_HOLD_MS` con un destello que crece en el punto de aparición y el aviso «sembrando» abajo al centro. Al completarse se crea un organismo con `N_SPAWN` y ya suena; mientras B2 siga apretado, joystick izquierda/derecha cambia `n` en pasos de 1 (recortado a `[N_MIN, N_MAX]`), regenerando la geometría con la misma semilla para que el cambio sea fluido; soltar B2 confirma. Si se suelta antes de completar la carga, no se crea nada. B4 durante la carga o la siembra cancela y, si el organismo ya apareció, lo elimina. Al cambiar `n` se recalculan `C`, `t` y `S`, el ancla se recalcula como en R-17 (próximo múltiplo de `TICKS_PER_BEAT` estrictamente posterior al tick actual) y se reinician los `fired`. Posición: entre 20 candidatas al azar dentro del mundo, la que maximiza la distancia mínima a los organismos existentes. Después de crear un organismo, B2 no puede sembrar otro durante `SPAWN_COOLDOWN_S`; durante ese enfriamiento B2 entra en modo ajuste y el joystick izquierda/derecha cambia `n` del organismo seleccionado. Si B2 sigue apretado al terminar el enfriamiento, la carga arranca sola. Si ya hay `MAX_ORGANISMS`, rechazo.
- **R-34** **Disolver (Macro, B4).** Al apretar B4, el organismo seleccionado empieza a desvanecerse; si se mantiene `DISSOLVE_HOLD_MS`, se elimina; si se suelta antes, se recupera con animación. No se puede disolver el último. Mientras se mantiene B4, la vista muestra «borrando» abajo al centro con el color del organismo.
- **R-35** **Brillo (Micro, B3 mantenido).** Joystick arriba/abajo ajusta `brillo` a `BRIGHTNESS_SPEED` por segundo, recortado a `[0, 1]`.
- **R-36** **Mezcla por foco.** Cada organismo tiene su propio bus de audio. En Micro: el organismo enfocado en 0 dB y con su `cutoff` propio; los demás en `FOCUS_OTHERS_DB` y con el `cutoff` menor entre el propio y `FOCUS_OTHERS_LPF_HZ`. En Macro: todos en 0 dB y con su `cutoff` propio. Las transiciones duran `FOCUS_FADE_S`.
- **R-37** **Reinicio por inactividad.** Si pasan `INACTIVITY_RESET_S` sin ninguna entrada, fundido de 2 s y vuelta al estado inicial: un organismo (`N_DEFAULT`, familia 0) en Micro, sin puentes, con escala y tónica sorteadas de nuevo. El reloj no se detiene.
- **R-38** **Mundo y deriva.** Los organismos se desplazan por una caminata aleatoria lenta (`DRIFT_MAX_SPEED`) dentro de `WORLD_SIZE`, manteniendo `MIN_ORG_DISTANCE`. La deriva **no** afecta el modelo temporal ni el audio; sí actualiza las posiciones usadas para vecindad y para dibujar los puentes.

## 7. Tests headless

Se ejecutan con `godot --headless --script res://tests/run_tests.gd`. Semilla fija. Cada test nombra su ID.

| ID | Requisito | Qué verifica |
|---|---|---|
| T-01 | R-14 | Para 10.000 geometrías aleatorias con `n` en 2..8, `sum(t_i) == C` |
| T-02 | R-14 | `t_i >= MIN_EDGE_TICKS` siempre |
| T-03 | R-14 | Mismo input produce el mismo reparto (determinismo) |
| T-04 | R-14 | Con todas las `L_i` iguales, `t_i == TICKS_PER_BEAT` para todo `i` |
| T-05 | R-14 | Si `L_i > L_j`, entonces `t_i >= t_j` |
| T-06 | R-16/R-18 | Sin ediciones, 3 ciclos: cada nodo dispara exactamente una vez por ciclo, en `anchor + k*C + S[p]` |
| T-07 | R-17 | El nodo origen dispara cada `C` ticks exactos tras ediciones de **posición** durante el ciclo (el cambio de origen lo cubre T-10) |
| T-08 | R-18 | Con ediciones aleatorias a mitad de ciclo: ningún nodo dispara dos veces en un ciclo; ningún tick emite el mismo nodo dos veces |
| T-09 | R-17 | Dos organismos (n=3 y n=5) con el mismo ancla: sus orígenes coinciden cada 60 ticks (`mcm(12, 20)`) |
| T-10 | R-19 | `set_origin` conserva el multiconjunto de diferencias entre disparos consecutivos del ciclo (es una rotación) y el período `C` |
| T-11 | R-27 | Un disparo no-eco de `s` produce exactamente un eco en `d` a `T + BRIDGE_DELAY_TICKS`; el eco no encola otros ecos |
| T-12 | R-27/R-28 | Disolver un organismo descarta ecos pendientes sin error; los topes (`MAX_BRIDGES`, `MAX_ORGANISMS`) se respetan |
| T-13 | R-23 | Para todo `n` y tónica: `midi` dentro de `[24, 96]`; las notas pertenecen a la escala única; el grado es monótono no decreciente respecto de la altura del nodo |
| T-14 | R-29 | Nunca hay más de `VOICE_CAP` voces activas; el robo toma la más antigua |
| T-15 | R-02 | Con deltas irregulares (incluido uno de varios ticks), el total de ticks emitidos `== floor(tiempo_total / TICK_SEC)` y llegan en orden |
| T-16 | R-30 | Selección por vecindad: casos con 0, 1 y varios candidatos, límite de 60°, gana el más cercano y todos alcanzables |
| T-17 | R-33 | Siembra: `n` recortado a `[2, 8]`; la posición elegida respeta `MIN_ORG_DISTANCE` cuando hay lugar; se crea con `N_SPAWN` al completar `SPAWN_HOLD_MS` |
| T-18 | R-22 | El arrastre nunca saca un nodo del radio ni lo acerca a otro por debajo de `MIN_NODE_DIST` |
| T-19 | R-21 | La posición derivada del pulso coincide con `S`, `t` y `phi` en todo el ciclo, incluida la fracción de tick |
| T-20 | R-13/R-20 | Geometría inicial: respeta `MIN_NODE_DIST` y `R_MAX(n)`, no es polígono regular, es determinista con la misma semilla y todas las `L_i` son > 0 |
| T-22 | R-37 | Reinicio por inactividad: umbral de `INACTIVITY_RESET_S`, fundido de 2 s con el reset en el punto negro, cancelación por entrada y reinicio de la cuenta |
| T-23 | R-33 | Carga de siembra: soltar antes de `SPAWN_HOLD_MS` cancela; durante `SPAWN_COOLDOWN_S` B2 ajusta `n` en vez de crear; al terminar el enfriamiento con B2 apretado arranca la carga |
| T-24 | R-25 | B2 en Micro recorre nota, cross-stick, bombo y silencio; el silencio es una variante válida |

## 8. Verificaciones manuales

| ID | Tipo | Qué se prueba |
|---|---|---|
| V-01 | `[OJO]` | Con el sonido apagado, 5 personas nuevas: al menos 4 señalan hacia dónde circula el pulso en menos de 10 s (DISENO 5.2) |
| V-02 | `[OJO]` | Los organismos no se leen como polígonos regulares; se lee cuántos nodos tiene cada uno |
| V-03 | `[OJO]` | La transición Macro/Micro no marea ni desorienta; se entiende qué organismo se enfoca |
| V-04 | `[OÍDO]` | Metrónomo/ciclos estables durante 3 minutos, sin deriva audible (R-03) |
| V-05 | `[OÍDO]` | La escala única (pentatónica menor) suena consonante con cualquier combinación de notas |
| V-06 | `[OÍDO]` | El registro por N separa bien las capas; N=2 no resulta chillón ni N=8 embarrado |
| V-07 | `[OÍDO]` | Arrastrar un nodo cambia el ritmo interno de forma perceptible y agradable, sin saltos molestos |
| V-08 | `[OÍDO]` | El cambio de origen inmediato (R-19) se siente bien |
| V-09 | `[OÍDO]` | La mezcla por foco hace sentir la cercanía sin que los demás desaparezcan |
| V-10 | `[OÍDO]` | El eco de los puentes se distingue como relación entre organismos y no como error de timing |
| V-11 | `[OÍDO]` | Con 5 organismos y varios puentes, la mezcla no se satura ni se vuelve barro |
| V-12 | `[OJO]` | Un testeo de 5 minutos con alguien nuevo: descubre al menos 3 de los 4 botones sin ayuda |
