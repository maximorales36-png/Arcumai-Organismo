# Cultivo — qué pasa y cómo se juega

Texto de referencia de la instalación. No es una pantalla de instrucciones: el
juego se descubre jugando. Sirve para entender qué hace cada cosa y para
explicarlo a quien se acerque.

## En una frase

Un organismo de luz y sonido: un pulso recorre una red de nodos, cada nodo suena
al recibirlo, y la persona cambia la forma, el tiempo y las conexiones para que
la música cambie con ella.

## Versión corta (para cartel o para explicar de pie)

Un pulso recorre organismos de luz y cada nodo suena al recibirlo. No hay puntaje
ni forma de perder: la pieza cambia con lo que hacés.

- **Micro:** el joystick elige nodos; **B1** arrastra (o marca el origen con un
  tap); **B2** cambia el timbre; **B3 + arriba/abajo** cambia el brillo; **B4**
  vuelve a Macro.
- **Macro:** el joystick elige organismos; **B1** entra a uno; **B2** siembra uno
  nuevo (izquierda/derecha elige cuántos nodos); **B3 + dirección** crea o quita
  un puente; **B4 mantenido** disuelve.

Después de 90 s sin tocar nada, vuelve solo al inicio con otra escala.

## Qué es

Una instalación musical para el arcumai. En una pantalla oscura flotan
organismos parecidos a redes de micelio. Cada organismo es un anillo cerrado de
nodos unidos por hifas curvas. Un pulso luminoso recorre ese anillo; cuando llega
a un nodo, el nodo suena.

La persona no toca un instrumento: **deforma los organismos, los conecta y los
hace crecer**. La música sale de cómo se relacionan entre sí.

La idea central es que **un gesto local tiene consecuencias globales**: mover un
nodo cambia cómo se reparte el tiempo en todo el organismo, y a través de los
puentes ese cambio se propaga a los demás.

## Qué se ve

- **Organismo:** una red de 2 a 8 nodos. Cuantos más nodos, más grande es y más
  grave suena.
- **Hifa:** el filamento curvo entre dos nodos. Su largo decide cuánto tarda el
  pulso en recorrerla.
- **Pulso:** una cabeza luminosa con cola que circula por el anillo. La dirección
  se lee por la cabeza, la cola, las motas que avanzan por las hifas y el flash
  del nodo al sonar.
- **Nodo origen:** el nodo más grande, con un halo. Es donde empieza cada vuelta
  y cae siempre en el primer tiempo del ciclo.
- **Aura:** el organismo seleccionado tiene un resplandor suave.
- **Color:** cada organismo tiene un color propio según su familia de sonido.
- **Puente:** un filamento luminoso y dirigido entre dos organismos. Cuando el
  nodo emisor de uno suena, el nodo receptor del otro suena como eco un instante
  después, y el eco se ve viajar por el filamento.

Hay dos escalas de cámara:

- **Micro:** zoom al organismo seleccionado. Los demás quedan fuera de cuadro o
  al fondo, más bajos y más opacos.
- **Macro:** se ven todos los organismos flotando, con sus puentes.

La transición entre las dos es un zoom de medio segundo.

## Cómo suena

- Cada nodo tiene una nota. La altura depende de su posición vertical dentro del
  organismo: **más arriba, más agudo**.
- La nota está cuantizada a una escala. La escala puede ser pentatónica menor,
  pentatónica mayor o dórica; la tónica es una nota al azar. Las dos se sortean al
  empezar la sesión y no cambian mientras dura. Por eso cualquier combinación
  suena consonante: no hay forma de "hacerlo mal".
- Cada organismo pertenece a una **familia** de sonido (hay 3, con 3 variantes
  cada una). La familia le da el timbre y el color; la variante se puede cambiar
  nodo por nodo.
- **Registro:** más nodos = organismo más grande = registro más grave. Eso ayuda
  a separar las capas en la mezcla.
- **Mezcla por foco:** en Micro el organismo enfocado suena completo y los demás
  quedan atrás (más bajos y más oscuros). En Macro todos suenan por igual. La
  distancia visual es distancia sonora.
- **Puentes:** el eco no es una nota nueva del organismo receptor: es el mismo
  nodo receptor sonando un instante después. El eco no dispara otros puentes, así
  que no hay contagio.
- Hay un click muy bajo que marca el pulso de referencia (100 BPM). Las notas de
  los organismos van por encima.

## Los controles

El joystick no apunta: **navega**. Los botones son verbos fijos:

- **B1: agarrar.**
- **B2: crear o cambiar.**
- **B3: conectar o modular.**
- **B4: volver o soltar.**

### En Micro (un organismo)

| Entrada | Qué hace |
|---|---|
| Joystick | Selecciona el nodo vecino en esa dirección. Mantenerlo repite el paso. |
| B1 mantener + joystick | Arrastra el nodo seleccionado. Cambia su altura (la nota) y el largo de las hifas vecinas (el reparto del tiempo). |
| B1 tap, sin mover | Convierte el nodo seleccionado en nodo origen. El patrón rota respecto del tiempo fuerte. |
| B2 tap | Cambia el sonido del nodo seleccionado: cicla las 3 variantes de la familia. |
| B3 mantener + joystick arriba/abajo | Brillo del organismo. Arriba = más brillante (más agudos). El valor queda donde se lo dejó. |
| B4 | Vuelve a Macro. |

### En Macro (todos los organismos)

| Entrada | Qué hace |
|---|---|
| Joystick | Selecciona el organismo vecino en esa dirección. Mantenerlo repite el paso. |
| B1 tap | Entra a Micro, con zoom al organismo seleccionado. |
| B2 mantener | Siembra un organismo nuevo, que ya empieza a sonar con N=4. Izquierda/derecha cambia su N (2 a 8) en vivo. Soltar confirma. |
| B4 durante la siembra | Cancela y elimina el organismo que se estaba sembrando. |
| B3 mantener + cambio de dirección | Crea un puente desde el organismo seleccionado hacia el vecino en esa dirección. Si el puente ya existe, lo quita. |
| B4 mantener 1 s | Disuelve el organismo seleccionado. Si se suelta antes, se recupera. No se puede disolver el último. |

Mientras B3 está apretado, el joystick no cambia la selección: cada cambio de
dirección crea o quita un puente. Mientras B2 está apretado (siembra),
izquierda/derecha cambia N y el joystick no navega.

## Qué puede cambiar el jugador

No hay un menú ni parámetros numéricos: todo se cambia con el cuerpo del
organismo. Estas son las palancas disponibles:

1. **La forma.** Arrastrar un nodo cambia la geometría y, con ella, el tiempo y
   la nota. Es el gesto más importante: un solo movimiento altera el ritmo
   interno y la altura de ese nodo.
2. **El origen.** Cambiar el nodo origen hace que la vuelta empiece en otro lado.
   El ciclo dura lo mismo, pero el patrón se corre respecto del tiempo fuerte.
3. **El timbre.** Cada nodo puede usar una de las 3 variantes de la familia. Se
   ciclan con B2 en Micro.
4. **El brillo.** Abre o cierra el filtro del organismo: de opaco y redondo a
   brillante y filoso. Se cambia con B3 + arriba/abajo en Micro y queda fijo.
5. **El tamaño.** Al sembrar, izquierda/derecha elige N entre 2 y 8. Más nodos =
   más pulsos por vuelta, organismo más grande y más grave.
6. **La cantidad.** Se pueden tener hasta 5 organismos. Cada uno aporta su propia
   capa rítmica y armónica.
7. **Las relaciones.** Los puentes hacen que un organismo "responda" a otro. Se
   pueden tener hasta 6 puentes; A→B y B→A pueden coexistir.
8. **La sustracción.** Disolver un organismo (B4 mantenido 1 s) también es una
   forma de componer: cambia lo que queda sonando.

## Cómo se reparte el tiempo

- El tempo es 100 BPM. Cada beat dura 0,6 s y se divide en 4 ticks de 0,15 s.
- Cada organismo dura **exactamente N beats por vuelta**. Si tiene 4 nodos, el
  ciclo dura 4 beats; si tiene 8, dura 8 beats.
- Las hifas se reparten esos N beats en proporción a su largo. Si se estira una
  hifa, el pulso tarda más en recorrerla y menos en las demás; el total no cambia.
- El nodo origen cae siempre en el primer tiempo del ciclo.
- El pulso nunca se detiene. La música es continua, incluso cuando la persona no
  toca nada.

## La sesión

- **Estado inicial:** vista Micro, un organismo de 4 nodos, familia 0, ya sonando
  y sin puentes. No hay pantalla de título ni instrucciones.
- **No hay fin, puntaje ni derrota.** La sesión termina cuando la persona se va.
- Cada sesión sortea de nuevo la escala y la tónica.
- **Reinicio por inactividad:** después de 90 s sin ninguna entrada, la pantalla
  hace un fundido de 2 s y vuelve al estado inicial, con escala y tónica nuevas.
  La música sigue sonando durante la espera; el reloj no se detiene.
- **Ningún botón queda sin respuesta:** si una acción es imposible (no hay vecino
  en esa dirección, ya hay 5 organismos, ya hay 6 puentes, se quiere disolver el
  último), suena un rechazo corto y grave y el elemento seleccionado tiembla.

## Primeros pasos (para probar)

1. En Micro, mové el joystick para seleccionar nodos.
2. Mantené B1 y mové el joystick: arrastrá un nodo y escuchá cómo cambia la nota
   y el ritmo.
3. Hacé un tap con B1, sin mover el joystick: el nodo seleccionado pasa a ser el
   origen.
4. Apretá B2: cambiá el timbre de ese nodo.
5. Mantené B3 y mové arriba/abajo: abrí o cerrá el brillo del organismo.
6. Apretá B4 para volver a Macro. Movete con el joystick entre organismos.
7. Mantené B2 para sembrar uno nuevo; con izquierda/derecha elegí cuántos nodos
   tiene; soltá para confirmar.
8. Mantené B3 y cambiá la dirección del joystick hacia un vecino: creá un puente
   y escuchá el eco.
9. Mantené B4 1 s sobre un organismo: disolvelo.

## Límites y detalles

- Hasta **5 organismos**, **6 puentes** y **16 voces simultáneas**.
- Cada organismo tiene entre **2 y 8 nodos**.
- Un puente va de un organismo A a un organismo B. El emisor es el nodo de A más
  cercano al centro de B; el receptor es el nodo de B más cercano al centro de A.
  Esos nodos quedan fijos al crear el puente.
- El eco llega **2 ticks después** (0,3 s). No dispara otros ecos.
- Quitar un puente cancela sus ecos pendientes. Disolver un organismo elimina sus
  puentes y sus ecos.
- El brillo de cada organismo es independiente y no se resetea al cambiar de
  vista.

## Teclado (solo desarrollo)

En la PC de desarrollo, el joystick y los botones se simulan con teclado:

| Acción | Tecla |
|---|---|
| Joystick | W / A / S / D |
| B1 | H |
| B2 | J |
| B3 | K |
| B4 | L |

En el arcumai, el joystick y los botones llegan como un dispositivo USB. El
mapeo de ejes y botones se ajusta cuando se prueba en el hardware.

## Glosario

- **Organismo:** la red cerrada de nodos y hifas. Tiene familia, color, brillo y
  un ciclo propio.
- **Nodo:** un punto del organismo. Suena cuando el pulso llega.
- **Hifa:** el filamento curvo entre dos nodos consecutivos.
- **Pulso:** la señal que recorre el organismo en una dirección.
- **Origen:** el nodo donde empieza cada vuelta. Cae en el primer tiempo.
- **Siembra:** crear un organismo nuevo con B2 en Macro.
- **Disolución:** eliminar un organismo con B4 mantenido en Macro.
- **Puente:** filamento dirigido de A a B que hace sonar un nodo de B como eco.
- **Familia:** uno de los 3 timbres base. Define el color del organismo.
- **Variante:** una de las 3 versiones de sonido dentro de una familia.
- **Brillo:** cuánto de los agudos del organismo pasa por el filtro.
