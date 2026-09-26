# Cambios de la ronda v47

> ## 🎯 TUS REPORTES DE LA CAPTURA DE LA 1:17/1:18 a.m.
>
> | Lo que reportaste | Qué era | Qué se hizo |
> |---|---|---|
> | **"la cinta sigue una otra gigante desde las bodegas inactivas hasta mi bodega"** | **La cinta medía `math.abs(gl.Position.X)`**: eso solo da bien si la bodega está en el origen (como en las pruebas). En el juego la bodega vecina vive en **x = −600**, así que la "mitad del portón" salía **600** y la cinta medía **1232 studs**: cruzaba toda la ciudad y caía sobre **tu patio**. Peor: la cinta, los postes y la **tablilla de CLAUSURADA** se colocaban en **x = 0**, o sea literalmente frente a tu bodega (y uno de los oficiales también) | Ahora **todo se mide desde las hojas del portón** de ESA bodega (que ya están en coordenadas del mundo). Medido con un lote vecino real: la cinta queda en **x −616..−584** (su lote es −600) y mide **32**. La tablilla y los oficiales quedan en **su** lote |
> | **"la bici aparece adentro de la bodega y no afuera"** | La cuenta era "centro del piso de la nave + media profundidad + 18", y esa cuenta cae **todavía dentro del patio** (el patio llega 29 studs más allá de la pared) | Ahora se mide desde el **patio** (`LotApron`) y se suma 6: la bici nace **en la calle, 6 studs más allá de la orilla del patio** (37 más allá de la pared de la nave) |
> | **"la bodega aún la letra se ve super pequeña"** | El tablero del garaje estaba en **y = 14.5** (o sea de 12.9 a 16.1) y la pared del frente **llega a 14**: más de un tercio del tablero quedaba **metido en la pared y el techo**, así que la letra salía **cortada** | El tablero ahora **se para sobre el techo** (14.4 a 18.4), agarrado con **dos postes**: se ve **completo** de frente y de lejos, es más grande (15 × 4) y la letra pasa de ~1.0 a **~1.7 studs** de alto |
> | **"si no quiero spawnear nada y me alejo el menú sigue ahí apareciendo"** | El mercado se abría cada vez que **volvías a cruzar** la entrada del taller, y como el panel no se cierra al salir, te lo encontrabas otra vez abierto cada vez que entrabas y salías | Ahora se abre **una sola vez por llegada**: si lo cierras, **se queda cerrado todo el rato que andes en tu lote** (taller o patio). Solo se vuelve a "armar" cuando **sales del lote a la calle**; al volver a entrar, se abre una vez más |

---

## 1. 🟡 La cinta gigante (y por qué "seguía" ahí)

```
LA CINTA DE UN LOTE VECINO (lote en x = -600)

ANTES:  halfGate = |GateLeft.Position.X|          -> 608   (¡la mitad medía 600!)
        cinta en x = 0                            -> encima de TU bodega
        ancho de la cinta = 608*2 + 2 = 1218 studs

        ├──────────────────── cinta de 1218 ────────────────────┤
   vecino                                                        TU CASA
   x=-600                                                          x=0

AHORA:  halfGate = |GateIzq.X - GateDer.X| / 2 + ancho/2  -> 15.5
        cinta centrada en SU portón (x = -600) y de 32 de ancho

        ├─32─┤
   vecino
   x=-600                                                          TU CASA (limpia)
```

Lo mismo pasaba con la **tablilla de CLAUSURADA** y con los **oficiales**: se
colocaban en `x = 0`, o sea en tu patio. Eso explica también las "tablillas viejas"
que veías pegadas a tu casa en rondas pasadas.

> Ojo: esto NO se veía en las pruebas porque el simulador **ignoraba el segundo
> argumento de `FindFirstChild`** (`FindFirstChild("GateLeft", true)` devolvía `nil`
> porque las hojas viven dentro de una carpeta) y porque **`PivotTo` no movía las
> piezas**: la bodega "colocada" en su lote seguía midiendo en el origen. Las dos
> mentiras del simulador se arreglaron en esta ronda.

## 2. 🚲 La bici ya nace en la calle

| | Antes | Ahora |
|---|---|---|
| De dónde se mide | centro del **piso de la nave** | el **patio** (`LotApron`) |
| Cuánto se suma | media profundidad + 18 | media profundidad del patio + **6** |
| Dónde cae | **dentro del patio**, entre las mesas de plantas | **en la calle**, 6 studs más allá de la orilla |

## 3. 🪧 El letrero del garaje, completo y más grande

```
ANTES                                   AHORA
┌───────────────┐  <- tablero (12.9..16.1)
│  GARAJE DE    │
│▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒│  <- 12.9..14 queda DENTRO de la pared y el techo
└───────────────┘     (la letra salía cortada)

                                        ┌───────────────┐
                                        │  GARAJE DE    │  <- 14.4..18.4:
                                        │  AGUS         │     completo, arriba del techo
                                        └───┬───────┬───┘
                                          ▓▓▓▓▓▓▓▓▓▓▓  <- 2 postes al techo
```

* Tablero de **15 × 4** (antes 13 × 3.2), texto en `TextScaled` a 100 px/stud.
* Letra de **~1.7 studs** de alto (antes ~1.0) y **completa** (antes se veía la mitad).
* Los postes lo agarran a la losa del techo, así no parece flotando.

## 4. 🛒 El mercado: una sola vez por llegada

```lua
-- Antes: cada cruce del borde del taller lo abría otra vez
-- Ahora:  la marca "ya me abrió" SOLO se rearma cuando sales del LOTE (a la calle)
if not enLote then cocheraAuto = false end
if v and not cocheraAuto and not shop.Visible then ... abrir ... end
```

Medido en la prueba: entras → se abre solo ✓ · lo cierras → caminas por el taller y
por el patio → **sigue cerrado** ✓ · te vas a la calle y vuelves → se abre **una vez** ✓.

## 5. 🧪 Cómo se probó (etapa 22, corre en `tools/validate.sh`)

| Prueba | Qué mide de verdad | Resultado |
|---|---|---|
| Cinta | arma un lote **vecino real** (nivel 2, colocado en x = −600), llama a `Clausurar` y mide dónde cayó cada pieza | cinta **32** de ancho en **x −616..−584**; tablilla y oficiales en su lote |
| Bici | **ejecuta el pedazo de código real de `Main.spawnBike`** con una bodega de verdad | nace 6 studs más allá de la orilla del patio (usa `LotApron` ✓) |
| Letrero | mide el tablero contra el techo y el dintel | **14.4..18.4** (techo 14.4), letra ~1.7, 2 postes |
| Mercado | **arranca la ClientUI**, entra, cierra el panel, camina por el taller y el patio, sale a la calle y vuelve | no reaparece adentro; se abre al entrar y al volver de la calle |

Probado **al revés**: devolviendo la cinta a `math.abs(gl.Position.X)`, la bici al piso
de la nave, el letrero a y = 14.5 y el auto-abrir sin la marca del lote → la etapa
**caza los 4** (cinta de **1232** cruzando tu lote, bici en z = −613 adentro, tablero
**12.5..16.5** enterrado, y el panel reapareciendo).

### ⚠️ Dos mentiras más del simulador (arregladas)

1. **`FindFirstChild(nombre, true)` ignoraba el "buscar en descendientes"** → devolvía
   `nil` para piezas dentro de carpetas, así que el código caía en sus caminos de
   respaldo y las pruebas medían otra cosa.
2. **`PivotTo` no movía las piezas** → una bodega "colocada" en su lote seguía en el
   origen; la cinta gigante pasaba como si estuviera bien.

## 6. 📋 Archivos que cambian

| Archivo | Qué trae de nuevo |
|---|---|
| `ServerScriptService/CityGenerator.luau` | la cinta/tablilla/oficiales medidos desde SU portón; letrero del garaje sobre el techo |
| `ServerScriptService/Main.luau` | la bici nace en la calle (medida desde el patio) |
| `StarterPlayerScripts/ClientUI.luau` | el mercado se abre una vez por llegada (se rearma al salir del lote) |
| `ReplicatedStorage/GameConfig.luau` | `Build = "v47"` |
| `ServerScriptService/DataService.luau` | sello de ronda `v47` |
| `tools/mock.lua`, `tools/reportes47.py` | simulador más fiel + etapa 22 |

---

> **Para ti, en corto:** pega los archivos de la v47 y dale Play. La cinta amarilla
> vuelve a estar **solo** en las bodegas clausuradas (ya no cruza tu patio ni tu
> calle), la bici aparece **en la banqueta**, el letrero del garaje se lee **completo
> y más grande** desde la calle, y el mercado solo te recibe **una vez** cuando entras
> a la cochera (si lo cierras, se queda cerrado mientras andes en tu lote).
