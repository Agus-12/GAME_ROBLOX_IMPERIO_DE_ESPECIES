# 🧠 CONTINUACIÓN — Léeme primero

> **Para el siguiente asistente / desarrollador que tome este proyecto.**
> Este archivo es el cerebro. Si solo vas a leer un documento, que sea este.
> Última actualización: **v35** · 24 sep 2026

---

## 0. Lo primero que tienes que saber

| Cosa | Valor |
|---|---|
| **Qué es** | Juego de Roblox: mundo abierto estilo GTA + tycoon empresarial |
| **Cómo se entrega** | Scripts sueltos para copiar y pegar en Studio. **NO es un proyecto Rojo** |
| **Idioma con el usuario** | Español, tono casual mexicano |
| **Versión actual** | v35 |
| **Estado** | Jugable. Todo lo entregado funciona salvo lo listado en "Bugs abiertos" |

### ✅ Qué se cerró en la v28 (léelo antes de tocar geometría)

| Bug | Causa real | Estado |
|---|---|---|
| La computadora / la pestaña Bodega salía en blanco | `T.StorageBonus`: campo borrado de la config en la v22 y todavía leído en 3 lugares. Da `nil` (no error de compilación) y revienta dentro de un `pcall` → **silencio total** | ✅ v28 |
| El garaje estaba sellado | `Wall2` (pared izquierda) se construía de una pieza, sin hueco: el garaje era una caja cerrada y los autos de adentro no se podían ni ver de cerca | ✅ v28 (pared en tramos + marco + letrero TALLER) |
| Escalón de 1.8 studs en el portón | Piso de la bodega en y=2 vs calle en y=0.2; la bici tiene `MAX_STEP=1.6` y se atoraba | ✅ v28 (rampa `GateApron`) |
| Las bodegas se encimaban | Espaciado fijo de 140 studs vs ancho real del nivel 4 **con anexos** (190 + 46 taller + 34 oficina = **271**) | ✅ v28 (`GameConfig.WarehouseLots`: rejilla 5×4, 340×260) |
| Los últimos lotes caían fuera del suelo | El suelo de la ciudad no llegaba; al salir del portón, vacío | ✅ v28 (`buildGround` estira el suelo con los datos del lote) |
| El cliente se colgaba en silencio | `WaitForChild` sin timeout + `IncomingCall` creado 1745 líneas después del arranque | ✅ v28 (remotes al arranque + timeout de 10 s + cartel rojo) |
| "El botón sale pero me rebota" | Cliente 16 studs, servidor 14 en la prensa | ✅ v28 (radios desde `GameConfig.Interact` y los ya existentes) |
| El panel no se reabría al revivir | El detector guarda "ya estabas cerca" para no abrir el panel cada 0.3 s; si morías junto a la máquina ese `true` quedaba pegado y el cruce nunca volvía a disparar. Solo se arreglaba alejándose y regresando | ✅ v28 (al morir se limpia `near` y se cierran los paneles) |
| Cartel "FALTAN SCRIPTS/REMOTES" con N=2 | El usuario tenía un `Main.luau` VIEJO pegado en Studio. La v28 se sumó al final del juego: todo remote que el cliente pide ya existía desde la v21/v24, así que la única causa posible era un archivo de otra ronda | ✅ v28 (sello de versión + cartel que dice cuál archivo quedó viejo + `tools/remotes.py`) |
| "Todo sale doble": una bodega al lado de otra, dos interfaces, dos avisos | **Copias de scripts pegadas en Studio.** Dos `Main` = dos programas: cada uno construye la bodega del jugador, y el viejo la calcula en OTRAS coordenadas (antes de la v28: fila cada 140; ahora: rejilla de 340) -> queda una al lado de la otra. Dos `ClientUI` = dos interfaces encima | OK v28 (se detecta, se avisa en Output y en cartel, y se limpia solo: `Remotes` viejo, bodegas huerfanas, y el 2o ClientUI se apaga) |
| Zona segura con esquinas fuera | Radio fijo 14 vs tapete de 28×11 | ✅ v28 (mide contra el tapete real) |

### 🔖 Regla de las VERSIONES (nueva en la v28)

Una ronda **solo se suma al final**: ningún remote se borra ni se renombra. Por eso, si
el cliente pide un remote que el servidor no crea, **la causa es siempre la misma**: hay
un archivo de otra ronda pegado en Studio. Para que el usuario no tenga que adivinar:

| Dónde | Qué dice |
|---|---|
| `GameConfig.Build` | La ronda de la config (`"v28"`) |
| `Main.luau`, al arrancar | Estampa la versión en la carpeta `Remotes` (atributo `Build`) y **la imprime en Output**: `========== IMPERIO DE ESPECIAS v28 ==========` + cuántos remotes creó |
| `ClientUI.luau` | `MI_VERSION` + la tabla `DESDE` (desde qué ronda existe cada remote) |
| Cartel rojo | Compara las 3 versiones y dice **qué archivo pegó viejo el usuario** |

**Al subir de ronda, cambia el número en los 5 lugares** (`GameConfig.Build`,
`MI_VERSION`, `README`, `CONTINUACION.md`, y crea `CAMBIOS-vN.md`): `tools/remotes.py`
(etapa 9) falla si se te olvida alguno. Detalle completo en
`docs/08-SI-SALE-FALTAN-REMOTES.md`.

### 🧩 Regla anti-duplicados (nueva en la v28)

**Un Script pegado en Studio es un programa que corre.** Si se pega el archivo nuevo
**sin borrar el viejo**, quedan DOS programas haciendo lo mismo: dos ciudades, dos
bodegas (en coordenadas distintas si son de rondas distintas), dos interfaces y avisos
por duplicado. Y **nada truena**, que es lo peor: funciona dos veces.

- Al **pegar**: `Ctrl+A` + `Ctrl+V` **encima** del script que ya existe. Nunca crear un
  objeto nuevo con el mismo nombre, y mucho menos dejar el viejo.
- Revisar en el Explorer que haya **exactamente uno** de: `Main`, `CityGenerator`,
  `DataService`, `GameConfig`, `ClientUI`, y **una** carpeta `Remotes`. Guia para el
  usuario: `docs/09-SI-SALE-DOBLE.md`.
- El juego desde la v28 **lo detecta y se defiende** (tabla de arriba), pero eso es una
  red de seguridad, no una excusa para no borrar la copia.

### ✅ Qué se cerró en la v29 (HUD, garaje, carros, luces)

| Pedido del usuario | Qué se hizo |
|---|---|
| La ventana de la oficina se veía "pegada" encima del muro | El muro exterior va **en tramos con 2 huecos reales** (8 × 4.6) + marco, travesaños, repisa y vidrio que se ilumina de noche. Piezas: `OfficeWindowGlass/Frame/Mullion/Sill` |
| El HUD de arriba era larguísimo | **Columna vertical** a la izquierda (112 px en celular; la barra vieja medía ~590 px = media pantalla). Reloj arriba a la derecha; HEAT y BUSCADO dentro de la columna. La barra ancha vieja (`hud`) **ya no se muestra nunca** |
| Juego 100% para teléfono | Botones 112 × 52 (mínimo cómodo ~48 px), texto 14, rejilla a la derecha sin estorbar joystick/salto, paneles con `fitPanel`, columna reacomodada en móvil (`IS_MOBILE`, `COL_Y = 56`) |
| El garaje "no tiene ni siquiera puerta y está muy pequeño" | Portón de cortina **por cajón** (`GarageDoor` + duelas + ventanita + manija + umbral) que **se abre solo** a 20 studs (loop `garageOpen` en Main, tween con `HomeCF`), y el anexo **crece por nivel** (`GameConfig.Garage`: ancho 44→68, fondo 26→38, alto 13→19) |
| Los carros "están de mentiras" | `CityGenerator.BuildCar(info, cf, parked)`: **un solo constructor** con silueta por tipo (van/sedán/pickup/deportivo), vidrios inclinados, espejos, defensas, parrilla, **faros con luz real**, calaveras, rines cromados, placas, escape, alerón/baca. Lo usan el auto manejable **y** el estacionado (antes: `buildParkedCar` era otro ladrillo aparte) |
| Faltaba iluminación de noche (y que se apague de día) | Luces nuevas de la bodega, todas con `tagLight`: `LotWallLamp`, `GarageWallLamp`, `GarageLamp`, `NaveLamp`, `RoofFloodLight`, `GateSignGlow`, `LampPost`, `Headlight` del carro. Se prenden 18:00–6:30 con el ciclo de `SetupLighting` |
| Faltaba ambientación por fuera | Patio de concreto con franjas, macetas, bolardos, toldo de la oficina, botes, banca, aires acondicionados, ventilas y poste de luz. Todo gobernado por `GameConfig.Ambience` (`Enabled`/`Props`/`Roof`/`LampPosts`) |

### 🎛️ Perillas de la v29 (dónde está cada cosa)

| Qué | Dónde | Nota |
|---|---|---|
| Medidas del garaje por nivel | `GameConfig.Garage` (`Widths`, `Depths`, `Heights`, `Bays`, `DoorWidth/Height`, `OpenRadius`) | El anexo se calcula con `TIER` dentro de `BuildWarehouse` |
| Ambientación exterior | `GameConfig.Ambience` | `Enabled=false` la apaga completa; `Props=false` deja solo luces |
| Sonido del portón | `GameConfig.Sounds.Gate` | Se dispara desde el loop de portones (`sfx(pl, "Gate")`) |
| HUD | `ClientUI`, bloque "HUD: COLUMNA VERTICAL" | `COL_W/COL_X/COL_Y`, `IS_MOBILE`, `BTN_W/BTN_H` |
| Carros | `CAR_SPEC` en `CityGenerator` (arriba de `BuildCar`) | Para un tipo nuevo: agrega entrada en `CAR_SPEC` + en `Config.Vehicles` |

**Regla nueva:** si agregas un anexo o mueves el garaje, **vuelve a correr
`tools/walk.py`**: revisa que el ancho total del lote (bodega + taller + oficina) siga
cabiendo en `Config.WarehouseLots.SpacingX` (hoy 297 de 340) y que se pueda caminar a
cada cuarto.

### 📦 Herramienta nueva: `tools/pegar.py`

Arma **un solo HTML** con los 5 codigos embebidos y un boton "COPIAR TODO" por archivo
(`python3 tools/pegar.py /home/user/vNN-ARCHIVOS.html`). Existe porque **los links no se
pueden abrir desde la vista previa del usuario** (el visor corre aislado, sin red), y él
pidio copiar y pegar sin salir de ahí.

- Sin JS, el HTML **muestra los 5 archivos seguidos** (nada se pierde); con JS se vuelven
  pestanas. El boton intenta `navigator.clipboard` -> `execCommand('copy')` -> y si todo
  falla **deja el texto seleccionado**.
- Se comprueba que lo embebido sea **idéntico** al repo antes de entregarlo.
- **Regenerarlo en cada ronda** que toque alguno de los 5 archivos, y entregar el archivo
  al usuario en el workspace (no se commitea: duplicaria el codigo dentro del repo).

### ✅ Qué se cerró en la v30 (la portada)

| Bug | Causa real | Estado |
|---|---|---|
| La portada se quedaba en *"Cargando la ciudad..."* y el boton ENTRAR AL BARRIO tardaba | El cliente esperaba una respuesta del SERVIDOR (`State.Cash > 0`) con respaldo de **30 intentos x 0.4 s = 12 s**. El servidor estaba bien: la ciudad se arma en **0.2 s** y una bodega en 0.016 s (medido) | OK v30 (la portada se abre con datos LOCALES: ciudad + personaje; 0.0 s normal, tope 3 s, y tocar la pantalla entra) |
| El simulador daba verde con ese bug | `task.spawn = function() end` y `task.wait = function() end` en el mock: todo lo que corre en hilos **nunca se probaba** y las esperas pasaban al instante | OK v30 (mock con **corrutinas y reloj virtual**: `task.__sched.advance(n)`; runclient/runmain avanzan 5 s y 3 s) |

**Nueva etapa 10 del validador**: `tools/intro.py` mide en segundos cuando sale el boton
(topes 0.6 / 1.4 / 3.2 s en tres escenarios).

**Reglas nuevas:**

1. **Una pantalla de entrada se abre con datos LOCALES**, nunca con un viaje al servidor.
2. **Los topes de tiempo van por revoluciones**, no con `os.clock()`: un tope con reloj
   real no se puede medir y vuelve mentiroso al validador.
3. Al encender los hilos en el mock aparecieron 2 huecos que escondian codigo roto
   (`Lighting.ClockTime` y `InputBegan`): **si el mock no ejecuta el codigo, no lo prueba.**

### ✅ Qué se cerró en la v31 (la portada, parte 2)

| Bug | Causa real | Estado |
|---|---|---|
| La portada seguia trabada en "Cargando la ciudad..." | **Dos causas**: (1) el abridor del boton vivia al FINAL de `ClientUI` (~linea 1900 de 2200): cualquier error anterior detiene el script y el boton nunca salia; (2) `Main.sync` llamaba a `setupPlayer` EN SERIE, que hace `store:GetAsync`. Un `OnServerInvoke` que espera deja el `InvokeServer` del cliente **colgado para siempre** (no hay timeout del otro lado) -> portada trabada eternamente en Studio | OK v31 (abridor al INICIO del bloque de la portada + `sync` nunca espera: carga en segundo plano y responde ya) |

**Reglas nuevas (duras):**

1. **`OnServerInvoke` JAMAS hace esperas** (nada de `WaitForChild`, `GetAsync`, `task.wait`):
   si hay algo lento, se hace en `task.spawn` y se responde al instante.
2. **El codigo critico va ARRIBA, no al final.** Todo lo que el jugador necesita para
   entrar (portada, boton, entrada) se define ANTES de cualquier otra cosa: en un script
   largo, un error de abajo se lleva a todo lo que viene despues.
3. **Lo que se rompe, se prueba rompiendolo**: `tools/intro.py` escenario E inyecta un
   error a proposito y exige que la portada siga abriendo (escenario D simula un servidor
   que NUNCA contesta).

### ✅ Qué se cerró en la v32 (saber CUÁL copia borrar)

El usuario tenia **2 scripts `Main`** pegados (el aviso de la v28p4 lo detecto, pero no
decia **cual** borrar). En su captura se veian los letreros "CAJON CAJON" encimados y dos
bodegas: cada `Main` construye lo suyo.

| Cosa | Antes | Ahora |
|---|---|---|
| Aviso de copias | "2 x ServerScriptService.Main" | nombres exactos: "'Main' + 'Main2' en ServerScriptService" |
| Deteccion | solo nombre exacto | tambien numerados por Roblox (`Main2`, `Remotes2`, `ClientUI2`) |
| Saber cual conservar | habia que adivinar | **sello de ronda**: `Ctrl+F` -> `RONDA: vNN` arriba de los 5 archivos |
| Instrucciones | solo en chat/docs | en el **cartel rojo** y en la consola, con los 3 pasos |
| `Remotes` viejas | borraba solo las exactas | tambien `Remotes2`, `Remotes3`... |
| Validador | — | **etapa 9 exige el sello `RONDA: vNN`** en los 5 archivos |

### 🐛 Bug real encontrado al probar la v32

`Destroy()` **dentro** del bucle que recorre `GetChildren()` se salta elementos: al borrar
el primero, `ipairs` avanza al índice 2 (que ahora es el 3) y **siempre queda uno vivo**.
Con 2 carpetas `Remotes` viejas solo se borraba una -> el cliente se enganchaba a la que
sobraba y decia "faltan remotes".

Estaba en **5 lugares**: limpieza de `Remotes`, limpieza de bodegas guardadas,
`syncWorkers` (**empleados duplicados encimados**), `syncGarage` (autos encimados) y
`renderTab` (**filas pegadas en las pestañas de la tienda**). Todos arreglados juntando la
basura en una lista y borrando despues.

**Etapa 11 del validador**: `tools/loops.py` caza ese patron (probado inyectando el bug).

### ✅ Qué se cerró en la v35 (el juego limpia solo y deja de asustar)

El usuario mando captura nueva: **sigue saliendo el cartel**, pero al leerlo bien ya **no
reportaba ningun `Main` duplicado**: solo **2 carpetas `Remotes`**. O sea que el duplicado
de `Main` ya lo habia borrado, y lo que quedaba era basura de carpetas. Tres problemas:

| Problema | Arreglo v35 |
|---|---|
| Habia que cazar copias a mano en el Explorer | **`tools/limpiar.luau`**: se pega en la **Command Bar** (View > Command Bar, sin dar Play) y borra las copias solo, dice que borro y **que archivo volver a pegar**. Va como **PASO 0** del HTML |
| El cartel rojo salia aunque el juego SI funcionara (2 carpetas pero con la buena completa) | **avisito azul chiquito** 14 s en vez de cartel; el cartel rojo queda solo si de verdad hay que arreglar algo |
| El cliente agarraba "la carpeta mas grande" | agarra **la que trae la etiqueta `Build`** de esta ronda (si no hay, la de nombre exacto, y de ultimo la mas grande) |
| El cartel decia "eso significa que hay 2 Scripts Main pegados" aunque no fuera cierto | dice lo que encontro, con **el nombre de cada carpeta y si tiene etiqueta o no** |
| No habia forma de saber si una `Remotes` aparecia despues de arrancar | `Main` **revisa a los 5 s y a los 15 s**; si encuentra otra, lo imprime fuerte (eso solo pasa si hay un segundo `Main` corriendo) y siempre imprime `carpetas Remotes en ReplicatedStorage: 1 (debe ser 1)` |

### 🎯 Qué se cerró en la v35 (el juego dice DONDE esta la copia)

La captura del usuario (02:14) lo aclaro todo: el cartel decia **"esta ronda es v32"**
mientras **"el Main.luau del servidor dice 'v34'"**. O sea: su `Main` estaba bien (tenia
razon: solo hay uno) y **el que se quejaba era una `ClientUI` VIEJA (v32)** que seguia
corriendo en el lugar (en `StarterGui` o como `ClientUI2`). Y con la logica vieja, ese
cartel viejo decia cosas falsas ("hay 2 Scripts Main pegados").

| Cosa | Antes | Ahora (v35) |
|---|---|---|
| Saber DONDE esta una copia | "hay copias pegadas" y a buscar | **INVENTARIO DE ARCHIVOS** en el Output: ruta completa de cada archivo y cada copia marcada con `<- borra esta` |
| Dos `ClientUI` corriendo | dos HUD, dos carteles, uno de una ronda vieja confundiendo todo | cada copia deja un **latido** con su version: la copia que sobra **se apaga sola** y lo avisa en la consola |
| Cartel cuando el atrasado es ESTE archivo | lista neutra de diferencias | **"*** ESTA ClientUI ES LA VIEJA: el servidor ya es vNN y esta copia dice vMM ***"** + que hay mas de una ClientUI pegada |
| Simulador | no tenia `game:GetDescendants()` -> el inventario salia vacio (**falso verde**) | lo tiene, y `tools/copias.py` escenario 7 prueba las dos `ClientUI` |

### 🐛 La pestaña en blanco (misma ronda v35, reportada por el usuario)

*"el ClientUI, el 5 en el archivo, le pico y no sale nada"*. Era **la pagina de copiar**,
no el juego: el cambio de pestaña tenia el numero de paneles escrito a mano (`k<5`) y con la
pestaña nueva del PASO 0 quedaron **6**. Al picarle a la ultima, ocultaba las otras y nunca
mostraba esa: **pantalla en blanco**. Por eso el `ClientUI` del usuario se quedo viejo (v32).

Arreglado (cuenta los paneles solo), `pegar.py` ahora **se verifica al generarse** y la
**etapa 13** (`tools/pestanas.js`, con `node`) corre el JavaScript de la pagina y **da clic
en cada pestaña**; con la pagina vieja **falla** y con la nueva pasa.

**Regla dura nueva:** lo que se puede **contar** no se escribe a mano, y las herramientas
del usuario (la pagina de copiar) tambien se prueban.

**Regla dura nueva (v35):** la `ClientUI` va **solo** en `StarterPlayer > StarterPlayerScripts`
y debe haber **una sola**. Si hay otra (aunque sea en `StarterGui`), corre y confunde.

### 🚨 Qué se cerró en la v35 (remotes muertos + el cartel que asustaba de mas)

El usuario mando captura nueva: **el cartel seguia saliendo** y ademas pregunto donde
esta la Command Bar (no la encontraba). Investigandolo salieron dos cosas:

| Problema | Arreglo v35 |
|---|---|
| **Remotes MUERTOS**: el cliente arranca ANTES de que el servidor limpie. Si hay una carpeta `Remotes` vieja guardada en el lugar, el cliente se enganchaba a ESA; el servidor la borraba ~0.3 s despues y el jugador quedaba con remotes que ya no existen: **botones que no hacen nada y CERO errores en consola** | **cambio en caliente**: el cliente guarda un **intermediario** (`crearProxy`) en vez del objeto. A los **1.5 s** y **4.5 s** revisa y, en cuanto ve la carpeta del servidor (sello `Build`), se **muda solo y reconecta las señales**. Los `FireServer`/`InvokeServer` se resuelven al momento de la llamada |
| El cartel rojo salia por carpetas viejas que el servidor limpia solo (tu caso) | el diagnostico se da **a los 4.5 s**, no al instante: si las viejas ya se limpiaron, **no sale nada** (ni cartel ni avisito) |
| La Command Bar no se encontraba | NO esta en el menu `View` de la barra de arriba de la pantalla: esta en la **pestana `View`** de adentro de Studio (Home, Model, ..., View, Plugins). Y de todos modos no hace falta: a mano, clic derecho en la carpeta `Remotes` del Explorer > Delete (se pueden borrar todas) |

**Regla dura nueva (v35):** nunca guardes el **objeto** de un remote para toda la partida;
usa un intermediario re-apuntable. Y no juzgues el estado del servidor **en el instante
cero**: el cliente arranca antes y ve un mundo a medias.

### 🐛 Dos bugs silenciosos que cazaron las herramientas (v35)

1. **El simulador mentia**: `strip_luau` (en `tools/check.py`) limpiaba tipos de Luau con
   regex y de paso le borraba pedazos a los **textos con dos puntos**:
   `"===== LISTO: ahora dale Play ====="` llegaba al simulador como `"===== LISTO dale
   Play ====="`. Ahora los literales se apartan antes de limpiar y se devuelven intactos:
   el simulador corre **el codigo de verdad**.
2. **`MI_VERSION` leido antes de existir**: el cliente comparaba contra `MI_VERSION` desde
   una funcion definida arriba de su `local`. En Lua eso es un **global nil**: comparacion
   siempre falsa, avisito que nunca salia y **cero errores en consola**. Lo cazo
   `tools/globals.py` (etapa 4).

**Regla dura nueva (v35):** lo que usan las funciones de arriba se **declara arriba**
(`globals.py` lo revisa), y no se confia en el simulador hasta comprobar que corre el
codigo tal cual se entrega.

**Regla dura nueva:** al subir de ronda, **los 5 archivos llevan el sello**
`-- ===== RONDA: vNN =====` en las primeras lineas (ademas de `GameConfig.Build`,
`MI_VERSION`, README y CONTINUACION). `tools/remotes.py` falla si falta alguno: es lo que
le permite al usuario identificar cual copia borrar cuando tiene duplicados en Studio.

### ⚠️ Reglas que NO puedes romper

0. **🔴 SUBE TODO AL REPO, SIEMPRE, EN CADA RONDA.**
   Este repo es el workspace en la nube del usuario y es una instrucción explícita suya.
   No termines un turno sin haber hecho commit y push de:
   los `.luau`, el `CAMBIOS-vN.md`, `CONTINUACION.md` y los `docs/` que cambien.

   ```bash
   cd /home/user/SpiceEmpire
   git config user.email "dev@spiceempire.local"   # .git/config NO persiste entre sesiones
   git config user.name  "Spice Empire Dev"
   bash tools/validate.sh                          # que salga todo verde ANTES del commit
   git add -A && git commit -m "vN — ..."
   git remote set-url origin "https://<TOKEN>@github.com/Agus-12/GAME_ROBLOX_IMPERIO_DE_ESPECIES.git"
   git push origin main
   git remote set-url origin "https://github.com/Agus-12/GAME_ROBLOX_IMPERIO_DE_ESPECIES.git"
   ```

   - El **token lo tiene que dar el usuario** en cada sesión: no se guarda (y `.git/config`
     se borra entre turnos). Pídeselo si no lo tienes.
   - **Nunca** dejes el token dentro de un archivo ni en el config al terminar.
   - Escribe mensajes de commit que expliquen **la causa** del bug, no solo el arreglo.
     Los de v20–v27 son el ejemplo a seguir.

1. **El usuario no conoce Roblox Studio a fondo.** No sabe qué es el Toolbox ni Rojo.
   → Siempre entrega **archivos separados** con instrucciones "copia esto, pégalo aquí".
   → Nunca propongas Rojo, ni línea de comandos, ni flujos de desarrollador.

2. **El tema de drogas está PROHIBIDO y ya se discutió.**
   El usuario pidió originalmente marihuana y cocaína. **Se rechazó** porque viola el
   reglamento de Roblox (ban de juego y de cuenta). El usuario **aceptó** el reskin legal.
   - ✅ "Spice Empire" / "Imperio de Especias", hojas de especia, bloques de sal prensada
   - ✅ "Sindicatos" / "Crews", "Unidad de Aduanas" (la policía)
   - ❌ Nada de: cartel, narco, coca, kilo, brick, ni nombres de drogas
   - **No vuelvas a abrir este tema.**

3. **Responde en español mexicano casual.** El usuario escribe así.

4. **Valida SIEMPRE antes de entregar.** Ver sección 4.
   - **Nunca** claves una distancia de interacción, una separación de lotes o el
     tamaño de un anexo como número suelto en el código: va en `GameConfig`
     (`Interact`, `WarehouseLots`). Dos veces ya nos mordió.
   - Si agregas una herramienta de validación, **pruébala metiendo el bug a
     propósito** y revierte. Un validador que siempre dice "OK" no vale nada.

5. **Entrega por rondas.** El usuario dijo "aviéntate todo", pero se acordó ir por
   entregas. Cada ronda = un `CAMBIOS-vN.md` + explicación en el chat.

---

## 1. Dónde está cada cosa

```
ReplicatedStorage/GameConfig.luau     ModuleScript · TODOS los números del juego
ServerScriptService/CityGenerator.luau ModuleScript · genera ciudad y bodega
ServerScriptService/DataService.luau  ModuleScript · guardado (DataStore)
ServerScriptService/Main.luau         Script      · lógica del juego
StarterPlayerScripts/ClientUI.luau    LocalScript · toda la interfaz

CAMBIOS-v2.md … CAMBIOS-v17.md        Changelog de cada ronda
LEEME.md                              Instrucciones de instalación (para el usuario)
docs/                                 Documentación técnica (para ti)
tools/                                Validadores (10 etapas). Corre bash tools/validate.sh
tools/mock.lua                        Simulador de la API de Roblox. Destroy() borra
                                      de verdad y trae RELOJ VIRTUAL (task.spawn y
                                      task.wait con corrutinas; task.__sched.advance(n)).
                                      Antes no corria nada: media mitad del juego
                                      nunca se probaba.
tools/intro.py                        Mide en segundos cuando sale el boton ENTRAR
                                      AL BARRIO (etapa 10). Nacio de la portada que
                                      se trababa 12 s esperando al servidor.
                                      AHORA borra de verdad; antes era una funcion
                                      vacia y no se podia detectar si el juego
                                      limpiaba lo que ya no sirve (bug "todo doble")
```

**Ubicación en Studio** (esto es lo que le dices al usuario):

| Archivo | Dónde va | Tipo |
|---|---|---|
| GameConfig | ReplicatedStorage | ModuleScript |
| CityGenerator | ServerScriptService | ModuleScript |
| DataService | ServerScriptService | ModuleScript |
| Main | ServerScriptService | **Script** |
| ClientUI | StarterPlayer › StarterPlayerScripts | **LocalScript** |

---

## 2. 🐛 Bugs abiertos ahora mismo

| # | Bug | Estado |
|---|---|---|
| 1 | **Bici** — historial largo de fallas, ver `docs/03-NO-HAGAS-ESTO.md` §1 | v17 la ancló por completo. **SIN CONFIRMAR por el usuario** |
| 2 | ~~Trabajadores invisibles~~ | ✅ v19 · v20 les quitó el diálogo de comprador y la flotación |
| 3 | ~~Prensa pegada / HUD mentía / mercado apilado~~ | ✅ v20 |
| 4 | ~~Raiders flotando / cosechadores duplicados~~ | ✅ v22 |
| 5 | ~~Computadora / bóveda no abrían, oficina adentro, garaje sellado~~ | ✅ v28 (ver tabla de arriba) |

## 2.2 ✅ PASE VISUAL — COMPLETADO EN v23

Los 8 puntos que el usuario mandó en una tanda quedaron cerrados entre v22 y v23:

| # | Qué pidió | Dónde quedó |
|---|---|---|
| 1 | Arma realista + sonido | v22 sonido, v23 modelo de 14 piezas + fogonazo |
| 2 | Zona segura (cuadro azul, sillón) | v23: tapete de tela y sillón por piezas |
| 3 | Bandidos flotando | v22 |
| 4 | Cosechadores dobles + animación | v22 duplicados, v23 gesto de cosecha |
| 5 | Computadora/silla + dock contextual + sonidos de proximidad | v22 dock y sonidos, v23 muebles |
| 6 | Estantes realistas pegados a la pared | v23 |
| 7 | Mochila separada de la caja, topes por producto | v22 |
| 8 | HUD de iconos siempre compacto | v22 |


## 2.1 🔨 El rediseño de producción física (decisiones ya tomadas)

El usuario pidió que la producción deje de ser "mágica". Se acordó esto y **ya no hay
que volver a preguntarlo**:

| Decisión | Acordado |
|---|---|
| Prensar | Solo estando frente a la máquina ✅ hecho en v18 |
| Caja fuerte | Todo lo producido se guarda ahí, no en el inventario ✅ hecho en v18 |
| Aduanas | Solo incauta lo que traes CARGANDO ✅ hecho en v18 |
| Capacidad de carga | Empieza en 80, sube comprando **mochilas** ✅ hecho en v18 |
| Cosechadores | **Uno por mesa.** 4 mesas = 4 cosechadores. Físicos, se paran en su mesa y cosechan solo las plantas maduras de ESA mesa | ✅ v19 |
| Producción offline | **Sí**, los trabajadores producen aunque estés desconectado. Hay que calcular al volver | ✅ v19 (tope 8 h) |
| Cosecha manual | **Sí sigue existiendo**, además de los trabajadores | ✅ ya funciona |
| Asaltos a la caja | **Sí pueden robar de la caja fuerte** — para eso sirven los guardias y la alerta del celular | ✅ v21, con asaltantes físicos y arma |

---

## 3. 🗺️ Roadmap — lo que falta

Por orden de valor sugerido:

| Pendiente | Qué implica |
|---|---|

| **Interiores de propiedades** | Las casas/departamentos que compras hoy son solo fachada. No se puede entrar |
| **Garaje real** | Un lugar físico donde aparezcan los autos comprados |
| **Música ambiente** | Los SFX ya están (v17). Falta música de fondo y sonido de motores |

Features del pedido original que **ya están hechas**: mapa procedural, policías que
persiguen, celular con alertas, PvP de robo, crews básicos, empleados, autos, casas,
bodega progresiva de 4 niveles, NPC vigilante, compradores en la ciudad, bici inicial,
plantas con crecimiento visible, prensa detallada, encargos, llamadas telefónicas,
adaptación a celular, sonido, caja fuerte, empleados físicos, arma y asaltos con
balacera, **territorios capturables entre crews**.

> ✅ **Con la v24 quedó cubierto TODO lo que el usuario pidió en su mensaje original.**
> Lo que sigue en el roadmap ya son ideas para crecer el juego, no pendientes.

---

## 4. ✅ Cómo validar (OBLIGATORIO antes de entregar)

No hay forma de correr Roblox Studio aquí. Se armó un simulador. **Úsalo siempre.**

```bash
bash tools/validate.sh
```

Eso hace **ocho** cosas:
1. **Sintaxis** — traduce Luau a Lua 5.4 y lo compila con `luac`
2. **Servidor en runtime** — corre GameConfig → CityGenerator → DataService → Main
   bajo un mock de la API de Roblox, y construye los 4 niveles de bodega
3. **Cliente en runtime** — carga ClientUI en 3 tamaños (escritorio, celular, tablet)
4. **Globales sospechosos** (`tools/globals.py`) — caza typos como `Workspace` (que en
   Roblox **no existe**, el global es `workspace`) o constantes mal escritas
5. **Partes de la bodega** (`tools/parts.py`) — construye los 4 niveles y verifica que
   sigan existiendo todas las partes que Main y ClientUI buscan por nombre
6. **Campos de la config** (`tools/fields.py`) — compara cada `Config.algo.campo` y cada
   alias (`T.VaultLeaves`, `b.Capacity`…) contra lo que la config tiene de verdad.
   Caza la clase de bug de `StorageBonus`, que **no** truena al compilar: da `nil` y
   revienta en tiempo de ejecución dentro de un `pcall`, o sea en silencio.
7. **Alcanzabilidad** (`tools/walk.py`) — construye los 4 niveles, exporta la geometría
   y tira un flood fill con el cuerpo de un jugador (radio 1.7) para comprobar que se
   pueda **caminar** desde donde apareces hasta la oficina, la caja, la computadora,
   la prensa, las mesas, el garaje (¡incluido el cajón 1!) y la calle. También revisa
   que la oficina esté por fuera del muro y que los lotes quepan en el suelo.
   Nació del garaje sellado: `parts.py` decía "todas las partes presentes" y el garaje
   seguía siendo una caja cerrada.
8. **API de Roblox** (`tools/api.py`) — valida `Enum.X.Y`, `Instance.new("Clase")`,
   `GetService` y las props de los helpers de UI contra el API-Dump oficial. El mock
   se traga cualquier typo; Studio no.

> ⚠️ Toda herramienta nueva se prueba **metiendo el bug a propósito** y revirtiendo.
> Ya van dos rondas donde un "validador verde" escondía un bug real.

> ⚠️ Las etapas 4 y 5 nacieron de bugs reales: `Workspace` nil rompía **todo** el sistema
> contextual en silencio (v22–v26), y en la v25 se borró la caja fuerte sin que ninguna
> validación lo notara. **Si agregas una parte nueva que el código busque por nombre,
> métela a la lista `REQUIRED` de `tools/parts.py`.**

Tiene que salir todo OK. Detalles en `docs/07-VALIDACION.md`.

> ⚠️ `tools/check.py` reporta `(continue)` en Main.luau. **Eso es normal**, es una
> limitación del traductor, no un error. Cualquier otro FAIL sí es real.

> ⚠️ Si el entorno borró `tools/lua/`, `bash tools/setup.sh` lo reinstala.

---

## 5. Cómo se entrega una ronda

> ⚠️ **El usuario pidió que TODO cambio se suba a este repo.** Es su workspace en la nube.
> Necesitas que te pase un Personal Access Token de GitHub (no se guarda entre sesiones).
> ```
> git remote set-url origin https://<TOKEN>@github.com/Agus-12/GAME_ROBLOX_IMPERIO_DE_ESPECIES.git
> git push origin main
> git remote set-url origin https://github.com/Agus-12/GAME_ROBLOX_IMPERIO_DE_ESPECIES.git
> ```
> Nunca dejes el token en un archivo ni en el config al terminar.

1. Haz los cambios en los `.luau`
2. `bash tools/validate.sh` → todo verde
3. Escribe `CAMBIOS-vN.md` siguiendo **exactamente** el formato de v16/v17:
   - Título con emoji
   - Sección "📂 Abrir los archivos a copiar" con **links markdown relativos**
     clickeables + la ruta en el Explorer de Studio
   - Nota de qué archivos **NO** cambiaron
   - Explicación numerada de cada arreglo, **diciendo la causa real**, no solo el fix
   - Sección "Cómo probar"
   - Roadmap actualizado
4. `present_file` del changelog
5. Explica en el chat, en español casual, **por qué** fallaba cada cosa

> ❌ **NO pegues el código completo dentro del .md.** Se probó y quedó ilegible (147 KB).
> Usa links relativos a los archivos.

---

## 6. Lo más importante que aprendimos

Está todo en `docs/03-NO-HAGAS-ESTO.md`, pero estos tres son los que más tiempo costaron:

0. **Un campo que no existe en la config NO truena al compilar.** Da `nil`, y si el
   `nil` cae en un `string.format` o en una suma, revienta en tiempo de ejecución —
   muchas veces dentro de un `pcall`, o sea **sin error visible**. Regla: si borras
   un campo de `GameConfig`, corre `tools/fields.py` antes de dar la ronda por buena.
   Y **no metas geometría nueva a `pcall`** sin dejar rastro: si algo falla ahí, imprime.
1. **La bici: nada de física.** Cuatro intentos fallaron. La única que funciona es
   anclada + CFrame a mano. No vuelvas a intentar con constraints.
2. **`Lighting.Ambient` ilumina los interiores**, `OutdoorAmbient` no. Si subes Ambient
   de día, las bodegas se lavan. Déjalo fijo.
3. **Demasiados PointLights se suman y queman la escena.** El alcance (`Range`) importa
   más que el brillo. Range 60 en un cuarto de 70 studs = todo blanco.

---

## 7. Documentos

| Archivo | Para qué |
|---|---|
| `docs/01-INSTALACION.md` | Cómo mete el usuario los scripts en Studio |
| `docs/02-ARQUITECTURA.md` | Contrato cliente↔servidor, nombres de partes, estructura interna |
| `docs/03-NO-HAGAS-ESTO.md` | **Callejones sin salida. Léelo antes de tocar código** |
| `docs/04-AJUSTES-RAPIDOS.md` | Perillas para cambiar balance, rendimiento, etc. |
| `docs/05-SONIDOS.md` | IDs verificados + cómo buscar más con la API |
| `docs/06-STUDIO-PASOS-MANUALES.md` | Lo que el usuario tiene que hacer a mano en Studio |
| `docs/07-VALIDACION.md` | Cómo funciona el simulador |
