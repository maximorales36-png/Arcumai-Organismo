# DISENO.md — Cultivo (nombre provisorio)

## 1. Qué es

Una instalación musical jugable para el arcumai. Un espacio oscuro donde flotan organismos tipo micelio. Cada organismo es una pequeña red cerrada por la que circula un pulso; cada vez que el pulso llega a un nodo, el nodo suena. La persona deforma los organismos, los conecta entre sí y los hace crecer, y la música emerge de cómo se relacionan.

**La idea central:** un gesto local tiene consecuencias globales. Mover un nodo cambia cómo se reparte el tiempo en todo el organismo, y a través de los puentes eso se propaga a los otros.

**Referencias:** *Electroplankton* (Toshio Iwai), en particular *Hanenbow*, de donde sale la idea de que mover una pieza cambia toda la secuencia. Las redes de micelio y el juego *Spore* para lo visual.

## 2. Contexto de uso

- Una sola persona, sesiones de 2 a 5 minutos, público mayormente estudiantes.
- Sin instrucciones: todo se descubre jugando.
- Hardware: mini PC Linux (Fedora), pantalla, parlante propio, joystick arcade + 4 botones (USB, sin drivers).
- No se premia la práctica ni el conocimiento musical. Se agarra como se agarra un juguete.

## 3. Principios de diseño

1. **Un gesto, consecuencias globales.** Cada acción debe repercutir más allá del elemento que se toca.
2. **El tiempo se ve.** La distancia entre nodos es duración. Se tiene que poder entender mirando, con el sonido apagado.
3. **Descubrir, no explicar.** Toda entrada produce una respuesta visible y audible en menos de 1 segundo. Un botón nunca "no hace nada": si la acción es imposible, hay una respuesta de rechazo (ver ESPECIFICACION, R-31).
4. **Siempre consonante.** Cualquier combinación de notas suena bien (escala fija por sesión). No hay forma de "hacerlo mal".
5. **Poco y claro.** Cuatro botones y un joystick, verbos fijos. Si una regla necesita explicación, se simplifica la regla.

## 4. Entidades

- **Mundo:** el espacio donde flotan los organismos. Fondo oscuro, partículas lentas (esporas/plancton) con parallax.
- **Organismo:** una red cerrada de N nodos, con N entre 2 y 8. N lo elige la persona al sembrarlo. Un organismo siempre dura exactamente N pulsos por vuelta (ciclo fijo).
- **Nodo:** un punto del organismo. Cuando el pulso llega, suena. Tiene un sonido (variante de la familia del organismo) y una altura (nota).
- **Hifa:** el filamento curvo entre dos nodos consecutivos. Su largo determina cuánto tiempo tarda el pulso en recorrerla (ver ESPECIFICACION, sección 3).
- **Pulso:** la señal que recorre el organismo en una dirección. Cada organismo tiene uno.
- **Nodo origen:** el nodo donde empieza cada vuelta. Cae siempre en el primer tiempo del ciclo.
- **Puente:** filamento dirigido de un organismo A a un organismo B. Cuando el nodo emisor de A suena, el nodo receptor de B suena como eco, un instante después.

## 5. Aspecto visual

### 5.1 Orgánico, no geométrico

- No hay polígonos ni formas regulares. Los nodos se ubican con irregularidad orgánica y las hifas son curvas suaves con curvatura distinta cada una.
- El organismo respira: los nodos oscilan apenas en forma cosmética (esta oscilación **no** entra en el modelo ni altera tiempos).
- El tamaño crece con N (más pulsos = organismo más grande).
- La cantidad de nodos se lee contando los bulbos.
- Cada organismo tiene un color propio (matiz) según su familia de sonido.

### 5.2 Cómo se entiende la circulación del pulso (sin formas geométricas)

El pulso es una **cabeza luminosa con cola**. La dirección se lee de cuatro maneras que se refuerzan entre sí:

1. **Cabeza y cola:** punta brillante y estela que se desvanece hacia atrás, como un cometa.
2. **Flujo en las hifas:** motas tenues que derivan por el filamento en el sentido de circulación.
3. **Anticipación en los nodos:** el nodo se hincha levemente en el tick previo a la llegada y estalla (flash y onda) al sonar.
4. **Nodo origen:** más grande y con un halo propio, para que se perciba dónde "empieza" la vuelta.

Criterio de éxito `[OJO]`: con el sonido apagado, una persona que nunca vio el juego puede señalar en menos de 10 segundos hacia dónde circula el pulso.

### 5.3 Dos escalas

- **Macro:** se ven todos los organismos flotando y pulsando. El seleccionado tiene un aura suave. Los puentes se ven como filamentos luminosos tensados entre organismos; los pulsos de eco viajan por ellos.
- **Micro:** zoom al organismo seleccionado, centrado. Los demás quedan fuera de cuadro o desenfocados al fondo.
- La transición entre ambos es una animación de cámara de 0,5 s.

## 6. Sonido

- **Motor:** audio nativo de Godot (muestras con `AudioStreamPlayer`, buses y efectos). No se usa Wwise en esta versión (ver Supuestos).
- **Familias de sonido:** cada organismo pertenece a una familia (3 al inicio, con 3 variantes cada una). Maxi aporta las muestras; hasta entonces se usan placeholders sintetizados.
- **Altura (nota):** depende de la altura vertical del nodo dentro del organismo, cuantizada a una escala. Más arriba = más agudo.
- **Registro:** más pulsos = organismo más grande = registro más grave. Esto además separa las capas en la mezcla.
- **Escala y tónica:** se sortean al iniciar la sesión (pentatónica menor, pentatónica mayor o dórica) y no cambian durante la sesión.
- **Mezcla por foco:** en Micro, el organismo enfocado suena completo y los demás quedan atrás (menos volumen, más oscuros). En Macro todos suenan por igual. La distancia visual es distancia sonora.

## 7. Controles

El joystick es un control de navegación, no de apuntado. Los botones son verbos fijos: **B1 agarrar**, **B2 crear/cambiar**, **B3 conectar/modular**, **B4 volver/soltar**.

### Macro

| Entrada | Efecto |
|---|---|
| Joystick | Selecciona el organismo vecino en esa dirección |
| B1 (tap) | Zoom in al organismo seleccionado (pasa a Micro) |
| B2 (mantener) + Joystick izq/der | Siembra un organismo nuevo. Arranca con N=4 sonando; izq/der cambia N (2 a 8) en vivo; soltar confirma |
| B3 (mantener) + Joystick dirección | Crea (o quita, si ya existe) un puente desde el organismo seleccionado hacia el vecino en esa dirección |
| B4 (mantener 1 s) | Disuelve el organismo seleccionado (no se puede disolver el último) |

### Micro

| Entrada | Efecto |
|---|---|
| Joystick | Selecciona el nodo contiguo en esa dirección |
| B1 (mantener) + Joystick | Arrastra el nodo seleccionado (cambia altura = nota, y reparte de otra forma el tiempo entre hifas) |
| B1 (tap, sin mover) | Convierte el nodo seleccionado en nodo origen (rota todo el patrón respecto del tiempo fuerte) |
| B2 (tap) | Cambia el sonido del nodo seleccionado (cicla las variantes) |
| B3 (mantener) + Joystick arriba/abajo | Brillo del organismo (más arriba = más brillante). El valor queda donde se lo dejó |
| B4 (tap o mantener) | Vuelve a Macro |

### Cancelar
Con B2 mantenido (sembrando), presionar B4 cancela la siembra.

## 8. Flujo de una sesión

1. **Estado inicial:** vista Micro, un organismo (N=4) ya vivo y sonando con una sola familia. No hay pantalla de título ni instrucciones.
2. La persona juega. No hay fin: la sesión termina cuando se va.
3. **Reinicio por inactividad:** tras 90 s sin ninguna entrada, el juego se reinicia al estado inicial con un fundido. Mientras tanto la música sigue sonando (es una instalación).
4. Cada sesión sortea de nuevo escala y tónica.

## 9. Decisiones

### Tomadas por Maxi
- Juego completamente nuevo, en proyecto nuevo, con la misma forma de input que el primero.
- Ciclo fijo: cada organismo dura siempre N pulsos; mover nodos reparte el tiempo entre tramos. El ciclo elástico queda como experimento posterior.
- Organismos de 2 a 8 pulsos, elegidos por la persona.
- Interacción entre organismos por puentes.
- Visual orgánico, sin formas geométricas.
- Mapeo de teclado para desarrollo: W A S D = joystick, H J K L = botones 1 a 4.

### Supuestos de diseño (propuestos por el análisis; confirmar o ajustar a oído)
- Audio con Godot nativo, sin Wwise.
- Altura de la nota = posición vertical del nodo (un mismo gesto cambia nota y ritmo interno).
- Arranque con un organismo ya sonando en Micro, no con pantalla vacía.
- Los puentes son de **eco** (el receptor suena pero el pulso no se propaga). El eco no dispara otros puentes.
- Tempo inicial 100 BPM, máximo 5 organismos, máximo 6 puentes, 16 voces simultáneas (todos valores ajustables, ver `config.gd`).
- Gesto "nodo origen" (B1 tap en Micro) incluido en v1.
- Reinicio por inactividad a los 90 s.

### Registro de cambios
(vacío; el agente anota acá toda decisión que cambie durante la implementación, con fecha)

## 10. Fuera de alcance v1

- Ciclo elástico (el ciclo dura lo que dicta la geometría).
- Puentes de contagio (el pulso entra y circula por el organismo receptor).
- Metabolismo (los organismos no atendidos se simplifican).
- Guardar o exportar la pieza.
- Control USB adicional (giroscopio, sensores).
- Wwise.
- Dos jugadores.

## 11. Preguntas abiertas

- ¿Se confirma el audio con Godot nativo?
- ¿La altura del nodo debe separarse del reparto de tiempo (nota con B3+Y y posición solo para tiempo)? Se decide después de probar a oído.
- ¿Familias de sonido definitivas y cantidad de variantes?
- ¿Resolución y relación de aspecto de la pantalla del arcumai?
