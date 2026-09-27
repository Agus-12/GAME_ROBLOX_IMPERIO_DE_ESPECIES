# 🔧 CAMBIOS v54 — la van que nacía encima de ti, la bici adentro y la esquina sin calle

Fecha: 27 sep 2026 · build `v54` · reporte del usuario con v53 ya pegada:
> "el portón ya quedó ✓" · "la van sigue mal y la tengo que respawnear dos
> veces para poder conducirla" · "la bici aparece adentro de la bodega" ·
> "las calles de la ciudad quedan desconectadas, como las de la esquina".

---

## 📂 Abrir los archivos a copiar

| Archivo | Dónde va en el Explorer de Studio |
|---|---|
| [`GameConfig.luau`](ReplicatedStorage/GameConfig.luau) | `ReplicatedStorage` (ModuleScript) |
| [`CityGenerator.luau`](ServerScriptService/CityGenerator.luau) | `ServerScriptService` (ModuleScript) |
| [`DataService.luau`](ServerScriptService/DataService.luau) | `ServerScriptService` (ModuleScript) |
| [`Main.luau`](ServerScriptService/Main.luau) | `ServerScriptService` (**Script**) |
| [`ClientUI.luau`](StarterPlayerScripts/ClientUI.luau) | `StarterPlayer` › `StarterPlayerScripts` (**LocalScript**) |

> Los 5 cambian de ronda (`DataService` y `ClientUI` solo el sello `RONDA: v54`).
> Usa el **HTML de la ronda** (`v54-ARCHIVOS.html`): trae el **PASO 0
> (LIMPIADOR)** para borrar las copias viejas antes de pegar.

---

## 1. "la van la tengo que respawnear dos veces para poder conducirla" — te nacía ENCIMA

**La causa (medida):** el cajón se abre con un prompt de
`MaxActivationDistance = 12`. Esos 12 studs alcanzan para que te puedas
parar **sobre el patio del cajón (BayApron)**, que es exactamente
**donde nace la van** (la van ocupa `z -649..-631` y desde el botón puedes
quedar parado en `z ≈ -644`: adentro del volumen). Al invocarla, la van se
armaba **alrededor de tu figura** (de ahí "las piezas revueltas con bloques de
aire" = verla desde DENTRO) y la figura quedaba atorada sin poder subirse. El
segundo respawn sí salía bien... porque ya estabas parado en otro lado.

**El arreglo (etapa 23, `Main.spawnVehicle`):**
- Antes de armar la van se hace un **barrido de figuras**: si algún
  `HumanoidRootPart` de cualquier jugador cae dentro del volumen de la van
  (19×11×12, con margen de 2), la van **se recorre 6 studs hacia la calle**
  hasta quedar libre (hasta 20 saltos = 120 studs; nunca pasa de la calle de
  la hilera).
- El `Sit` ahora **reintenta** (a los 0.25 s y a los 0.6 s) si el asiento
  quedó sin ocupante: en el juego real a veces el asiento tarda un frame.

**Medido (etapa 23):** con el jugador parado JUSTO en el punto de nacimiento,
la van se recorre y le nace libre. El al revés (caso 10) comprueba que si
alguien quita el corrimiento, truene.

---

## 2. "la bici aparece adentro de la bodega" — los rayos se hacían de la vista gorda

**La causa:** al entrar al juego (y en cada respawn) `placeInWarehouse` te
teletransporta **al centro de tu nave**, y la bici nace 0.6 s después. Los
rayos de "cielo abierto" (40 studs) se pasaban por libres puntos que estaban
bajo el techo de una nave vecina o dentro del rectángulo de un terreno, y la
bici amanecía adentro.

**El arreglo (etapas 22-24, `Main.spawnBike`) — verificación dura en DOS capas:**
1. **Ya no se le cree a los rayos:** `dentroDeAlgo` revisa el punto contra la
   **caja de TODAS las bodegas** (`Warehouse_*`, `BodegaVecina_*`) y contra el
   **rectángulo de TODOS los lotes** (±137 × ±82 del centro de cada lote). El
   rayo de techo pasó de 40 a **60 studs** (un techo alto ya no se pasa por
   libre).
2. **La bici SIEMPRE nace en la CALLE de su hilera** (asfalto de verdad):
   `CityGenerator.CalleDeHileraZ(slot)` da la z del centro de la calle que
   pasa al frente de tu hilera (+121 del origen de la hilera; el rectángulo
   del terreno llega a +82, o sea que la calle queda 39 studs más allá de la
   orilla de TODOS los terrenos). Da igual el nivel de tu bodega o dónde
   estés parado: la bici cae parejito sobre el asfalto.
3. **Capa de abajo (defensa en profundidad):** si un punto aún quedara dentro
   de algo, se manda directo a la calle — porque el `buscarLibre` de rayos
   solito no sirve para un pasto DENTRO del rectángulo de un lote (no tiene
   techo y los rayos lo ven "libre").

**Medido (diagbici + etapas 23/24):** la bici nace en `(-600, ~3.3, -539)` =
centro de la calle de la hilera 1, techo LIBRE, en los niveles 1-3 y con el
jugador adentro de la nave. El al revés (caso 11) mata el empujón Y el rescate
y comprueba que truene (con solo una capa fuera, la otra lo tapa — a propósito).

---

## 3. "las calles de la ciudad quedan desconectadas, como las de la esquina" — el oriente sin asfalto

**La causa (medida con el diagnóstico del grafo):** la malla urbana está 100%
conectada (10 calles, cada una toca las otras 5: `RoadZ0..4` × `RoadX0..4`)...
pero `RoadZ0` **terminaba en `x = 308`** (la esquina oriente de la ciudad) y
tu lote (el **5**, columna de más oriente, `x = 760`) quedaba a **~500 studs**
del camino de en medio: para llegar a la ciudad tenías que viajar todo eso.
Por eso "las de la esquina" se sentían desconectadas — lo estaban.

**El arreglo (etapa 26, `CityGenerator.buildLotRoads`):**
- **`RoadLotesX3`: el tercer camino norte-sur**, por el callejón que queda
  entre la 4ª y la 5ª columna (centrado en `x = 576.5`; las bodegas dejan
  ese callejón en `553..600`). Baja recto desde la calle de la ciudad hasta
  la última hilera, con su raya amarilla y sus faroles.
- **`RoadZ0Ext`:** la calle `RoadZ0` de la ciudad ahora se estira al oriente
  (de `x = 308` a `x = 598.5`) para recibir el callejón nuevo.

**Medido (etapa 26):** 3 caminos norte-sur (`x = -104`, `x = 236`, `x = 576`),
los tres tocan la calle de la ciudad; `RoadLotesX3` no toca ninguna bodega en
ningún nivel ni se mete a ningún lote. El al revés (caso 12) quita el callejón
y comprueba que truene.

---

## Cómo probar

1. Corre el **PASO 0** del HTML (limpia copias viejas) y pega los 5 archivos.
2. **Play** → la placa verde debe decir `RONDA v54  OK` y el letrero del
   servidor `SERVIDOR v54`.
3. **La van:** párate sobre el patio del cajón (donde la van, junto a la
   reja) y sácala: se recorre hacia la calle, **te nace libre y te puedes
   subir a la primera** — ya no la tienes que respawnear dos veces.
4. **La bici:** entra al juego (te aparece dentro de tu nave) y presiona el
   botón de la bici: debe aparecer **afuera, sobre la calle de tu hilera**,
   con cielo abierto. Pruébalo también muriendo/respawneando.
5. **Las calles:** desde tu lote (el 5) sube al callejón que queda a tu lado
   oriente (entre tu columna y la de al lado) y sigue derecho al norte:
   ahora desemboca directo en la calle de la ciudad, sin viajar 500 studs
   hasta el camino de en medio.
6. El mapa (`mapa-mundo-v54.png`) marca tu lote: el **5 dorado**, y la bici
   pintada sobre la calle de tu hilera.

---

## Roadmap

| Pendiente | Estado |
|---|---|
| Interiores de propiedades (casas/departamentos) | solo fachada hoy |
| Música ambiente + sonido de motor | los SFX de acciones ya están |
| Confirmar de oídos la van y el portón en el juego real | pendiente del reporte del usuario |
