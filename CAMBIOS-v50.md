# CAMBIOS v50 — ronda de SOLO BUGS (los 3 que reportaste)

Fecha: 26 sep 2026 · build `v50` · **no se agregó nada nuevo**: esta ronda es
arreglar lo que reportaste, medirlo y mandarte la vista.

---

## 1. "la puerta que no está es la del garaje" (el portón del cajón)

**Lo que encontré:** el portón SÍ existe y mide 24.3 de ancho × 10.4 de alto
(tapa completo el hueco del cajón). Lo que pasaba es que **se abre solo cuando te
acercas a 7 studs** (el radio que ya habíamos bajado en la v49), y entonces el hueco
se ve vacío: parecía que no había puerta. Además, abierto, no quedaba ninguna
parte de la cortina a la vista.

**Lo que hice:** le puse al cajón las **partes que no se mueven nunca**, aunque el
portón esté abierto:
- **2 rieles laterales** (`DoorRail`, 0.45 × 11.6 × 0.7) pegados a los lados del
  hueco, donde corre la cortina.
- **1 caja del rollo** (`DoorRollBox`, 4.2 × 2.0 × 2.2) arriba del hueco, de donde
  cuelga la cortina.

Así el cajón se lee como cochera **con su portón** de lejos, de cerca y con la
cortina subida. La placa `GARAJE DE <tu nombre>` sigue arriba (y=15.6), por encima
del techo del garaje (y=13), así que nada la tapa.

**Medido (etapa 24):**
`cajones=1 rieles=2 franjas=6 ventanas=1 manijas=1 hueco=1 pegado=1 radio=7`

---

## 2. "la bici de nuevo apareció adentro de la bodega" (3er reporte)

**Lo que encontré:** la bici nacía a **6 studs** de la orilla del patio… y entre el
patio y la calle hay pasto y la línea de los bolardos, así que 6 studs **siguen
siendo tu terreno**: se veía adentro (con razón, otra vez).

**Lo que hice (dos candados):**
1. Ahora nace **12 studs más allá de la orilla del patio**.
2. Y además se **comprueba la geometría**: si por lo que sea el punto elegido cae
   dentro del patio (`rel.Z < fondo/2 + 4`), se empuja hacia afuera a la fuerza,
   sin preguntarle a los rayos. Igual en el plan sin patio (nunca más cerca que
   media nave + 26 studs).

**Medido (etapa 24, con el lote completo puesto):**
`z=-589.0` · orilla del patio `-601.0` · nave `-632` · jugador `-660`
⇒ **12.0 studs fuera del terreno**, con cielo abierto.

---

## 3. "los carteles de la computadora y la bóveda aparecen adentro de las cosas"

**Lo que encontré (la causa raíz, medida):** el texto estaba pintado en el **cuerpo**
del objeto, y delante de ese cuerpo hay otra pieza:
- la **puerta** de la caja fuerte (7.6 × 7.6, a 3.4 studs delante) y su **rueda**
  (3.2 × 3.2, a 3.9) tapaban el texto del `VaultBody`;
- la **pantalla** del monitor (6 × 3.6, a 0.3 delante) tapaba el texto del `MonitorBody`.

O sea: el cartel **sí estaba pintado**, pero adentro de la cosa. Igual que dijiste.

**Lo que hice:**
- El rótulo de la bóveda ahora va en una **plaquita propia** (`VaultLabel`,
  6.4 × 1.3 × 0.3) **arriba de la caja** (y=12.6), fuera del alcance de la puerta y
  de la rueda. Letra de 0.88 studs (84 px), verde.
- El rótulo del monitor ahora va en otra plaquita (`MonitorLabel`, 5.6 × 1.0 × 0.18)
  **arriba del monitor** (y=11.4). Letra de 0.94 studs (90 px).
- El pintor de textos (`textoPlano`) aprendió una opción nueva (`banda`/`bandaPos`)
  para poder mover el renglón dentro de la cara sin salirse.

**Medido (etapa 24):** los 8 rótulos del lote con su letra en studs, y **ninguno
tapado** (nuevo chequeo: si *todas* las caras pintadas de una pieza quedan tapadas
por otra, truena).

---

## 4. La vista que pediste: el mundo completo

Nuevo `tools/mapa.py` → **`mapa-mundo.png`** (4 cuadros, todo medido del juego real
con el simulador):

1. **EL MUNDO COMPLETO** de arriba: el suelo (1 840 × 2 401), la ciudad con sus
   **10 calles**, sus manzanas, sus **7 tiendas** (con ★ cada una) y, abajo a la
   izquierda, la zona de los 20 lotes — con el tuyo marcado.
2. **LOS 20 LOTES** (rejilla 5 × 4): cada lote mide **271 × 160** studs y están
   separados 340 en x y 260 en z; el 1 es el tuyo.
3. **TU LOTE de arriba**, con las **550 piezas** reales: la nave, el cajón del coche,
   el patio, los bolardos, la calle y **el punto exacto donde nace la bici** (12
   studs fuera del terreno).
4. **LAS DOS FACHADAS** de frente: la nave (portón grande + letrero) y el cajón del
   coche (portón de cortina + franja roja/blanca + ventana + **los 2 rieles nuevos**).

Trucos que tuve que resolver (para que la vista no mienta):
- el simulador **no respetaba `CanCollide`** en los rayos (Roblox ignora las piezas
  no-colisionables): contaba techos decorativos y el "cielo abierto" de la bici era
  mentira. Ya lo respeta.
- el mapa salía **una mancha blanca**: los colores se estaban multiplicando ×255 dos
  veces. Corregido (y el chequeo ahora truena si vuelve a pasar).
- el marcador de la bici **se lee del código real** (`Main.luau`): si alguien mueve
  la bici en el juego, el mapa lo dice y la prueba truena.

---

## 5. Pruebas

- **etapa 24** (letra/portón/piso/mercado/bici) actualizada y verde.
- **etapa 25 NUEVA**: arma el mapa del mundo y comprueba las 4 vistas, los 20 lotes,
  los rieles, las 2 plaquitas y que la bici caiga 12 studs afuera.
- **`alreves49`**: 7 bugs inyectados (se le sumaron **2 nuevos**: el cartel tapado y
  la bici pegada a la orilla) → **7/7 truenan** la etapa 24.
- **`validate.sh` COMPLETO (1..25)**: **EXIT=0** (171 OK).
- Los chequeos nuevos se probaron **metiendo el bug** (bici a 6 studs y rieles
  renombrados): los dos los caza.
