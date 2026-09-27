# 🛣️ CAMBIOS v52 — la calle FUERA de las bodegas (y letreros con tu lote)

Fecha: 27 sep 2026 · build `v52` · reporte del usuario tras probar la v51:
> "mi bodega no es la que marca el mapa (la mía vendría siendo la 5)" ·
> "la (bodega vecina) de en medio está como al ras de la calle" ·
> el portón "sigue sin aparecer" y la van "sigue bugueada".

---

## 📂 Abrir los archivos a copiar

| Archivo | Dónde va en el Explorer de Studio |
|---|---|
| [`GameConfig.luau`](ReplicatedStorage/GameConfig.luau) | `ReplicatedStorage` (ModuleScript) |
| [`CityGenerator.luau`](ServerScriptService/CityGenerator.luau) | `ServerScriptService` (ModuleScript) |
| [`DataService.luau`](ServerScriptService/DataService.luau) | `ServerScriptService` (ModuleScript) |
| [`Main.luau`](ServerScriptService/Main.luau) | `ServerScriptService` (**Script**) |
| [`ClientUI.luau`](StarterPlayerScripts/ClientUI.luau) | `StarterPlayer` › `StarterPlayerScripts` (**LocalScript**) |

> Los 5 cambian de ronda (`DataService` y `ClientUI` solo el sello `RONDA: v52`).
> Usa el **HTML de la ronda** (`v52-ARCHIVOS.html`): trae el **PASO 0
> (LIMPIADOR)** para borrar las copias viejas antes de pegar.

---

## 1. "la bodega de en medio está al ras de la calle" — la calle iba DEBAJO de las bodegas

**La causa (medida):** el patio del frente **crece con el nivel** de la
bodega, y la v51 puso la calle a una distancia fija que solo le servía al
nivel 1:

| Nivel de bodega | Hasta dónde llega su patio (desde el centro del lote) |
|---|---|
| 1 (tuya al empezar) | `+59` |
| 2 | `+70` |
| 3 (la vecina "de en medio") | `+83` |
| 4 (la más grande) | `+101` (su muro frontal queda a `+71`) |

La calle de la v51 iba a `+61..+81`: quedaba **debajo de los patios** de los
niveles 2, 3 y 4 — por eso la bodega mejorada "estaba al ras de la calle": la
calle se metía bajo su patio. Y las rampas de la v51 (`+54..+61`) quedaban
**dentro** de esas bodegas grandes.

**El arreglo:** la calle de cada hilera pasa a **`+121` del centro de su
hilera** (franja `z +111..+131`): le sobran **10 studs de pasto** hasta el
patio más grande (`+101`). La rampa de cada lote (frente al cajón del taller,
`x lx-48`) ahora sube del pasto a la calle en `z +104..+111` (7 de largo,
bajando 0.85): queda **afuera** de cualquier bodega, hasta nivel 4.

**Medido (etapa 26, nuevo chequeo `__TOCAN__`):** se construyen bodegas de
NIVEL 1, 2, 3 y 4 en los lotes 1-4 y se comprueba pieza por pieza que **ni
una calle ni una rampa las toque** (con 2 studs de margen): **TOCAN =
ninguna**.

---

## 2. los caminos norte-sur pegaban con las bodegas nivel 4

**La causa (medida):** la bodega nivel 4 **no está centrada** en su lote: mide
`x -160..+133` desde el centro del lote. El callejón real entre columnas
queda **13.5 studs al poniente** de donde la v51 lo suponía, así que el camino
principal (v51: `x=-90`) pegaba justo con la orilla de las bodegas grandes.

**El arreglo:** ambos caminos se recorren al hueco REAL entre columnas:

| Camino | v51 | v52 |
|---|---|---|
| principal (baja de la ciudad) | `x=-90` | **`x=-104`**, z `-1319..-485` (toca la calle de la ciudad: unido = true) |
| el de en medio | `x=250` | **`x=236`**, z `-1319..-539` |

**Medido:** el chequeo `__TOCAN__` también truena si el camino se pega a la
línea vieja: la bodega nivel 4 del lote 3 llega a `x=-80` y el camino nuevo
pasa a 24 studs de distancia.

---

## 3. "mi bodega no es la que marca el mapa" — el juego te RECUERDA tu lote

**Qué pasa:** el mapa de la ronda dibuja el mundo de un jugador NUEVO (lote
1). Pero si ya tienes partida guardada, el juego te devuelve **el mismo lote
de antes** (queda guardado en `Warehouse_<tu UserId>.Slot` del lugar). Si
entraste cuando ya había vecinos, tu lote puede ser el 3, el 5, el que sea —
por eso tu bodega "vendría siendo la 5": **es la tuya de verdad**, no está
mal puesta.

**El arreglo (para que se vea a simple vista):** los letreros de los garajes
ahora dicen el lote:

- el tuyo: **`GARAJE DE <TU NOMBRE> - LOTE 5`** (el número que sea)
- los vecinales: **`SIN PROPIETARIO - LOTE n`**

Así ya no hay que adivinar cuál bodega es de quién: se lee en la fachada.

---

## 4. lo que sigue abierto (preguntas para el usuario)

- **El portón que "sigue sin aparecer"**: ¿es el portón **chico del cajón**
  (el del coche, con franja roja/blanca) o el **portón grande de la nave**?
  Los dos se abren solos al acercarse (7 studs) y a medio abrir parecen
  "no haber puerta".
- **La van "bugueada"**: ¿qué hace exactamente (cae, se medio-hunde, tiembla,
  no sale)? Y lo más importante: **¿qué ronda dice la placa verde y el
  letrero del servidor?** — si dice `v51` o menos, el arreglo de la van
  (patio `BayApron` + altura del `GarageExit`) todavía no está pegado en
  Studio y eso explicaría todo.

---

## 5. Pruebas

- **Etapa 26 (`tools/caminos51.py`) actualizada a la v52:** posición esperada
  `+121`, y **chequeo nuevo `__TOCAN__`** que construye bodegas nivel 1-4 en
  los lotes 1-4 y exige que ni calles ni rampas las toquen (margen 2 studs).
  PASS: TOCAN ninguna · principal `x=-104` · medio `x=236` · unido true ·
  estorbos ninguno · 4 calles de hilera · 20 rampas · 146 faroles · la van
  igual que la v51 (ruedas `y=1.10` sobre su patio, trasera fuera del
  portón).
- **`tools/alreves51.py` — 6/6 truenan:** los 5 bugs de la v51 más el nuevo:
  regresar la calle a `+71` (la v51 de verdad) y pegar el camino principal a
  la línea vieja — los dos truenan con el mensaje de la causa real.
- **`bash tools/validate.sh` COMPLETO (1..26): EXIT=0.**
- El chequeo `__TOCAN__` se ganó el puesto a pulso: cazó MI propia rampa al
  primer intento (quedaba a 1 stud del patio nivel 4) y por eso la calle
  terminó en `+121`.

---

## Cómo probar

1. Corre el **PASO 0** del HTML (limpia copias viejas) y pega los 5 archivos.
2. **Play** → la placa verde debe decir `RONDA v52  OK` y el letrero del
   servidor `SERVIDOR v52`. Si no dicen v52, algo viejo quedó pegado.
3. Mira el letrero de tu garaje: ahora dice **`- LOTE n`** con tu número.
4. Ve a la bodega vecina "de en medio" (la mediana mejorada): su patio termina
   y **después hay pasto y LUEGO la calle** — ya no está encima.
5. Las bodegas más grandes (nivel 4) tampoco tienen nada de asfalto debajo: la
   calle pasa a 10 studs de su patio y el camino principal ya no raspa su
   pared.
6. Saca la van (**"Sacar y conducir"**): baja su rampa, el patio del frente y
   la rampa de tu lote a la calle.

---

## Roadmap

| Pendiente | Estado |
|---|---|
| Interiores de propiedades (casas/departamentos) | solo fachada hoy |
| Música ambiente + sonido de motor | los SFX de acciones ya están |
| El portón y la van reportados | esperando las respuestas de arriba |
