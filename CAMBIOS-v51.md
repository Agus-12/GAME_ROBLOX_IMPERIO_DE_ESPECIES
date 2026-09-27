# 🛣️ CAMBIOS v51 — las calles de los lotes y la van que sale bien

Fecha: 27 sep 2026 · build `v51` · dos pedidos del usuario: la van que salía
mal y conectar los lotes con calles a la ciudad.

---

## 📂 Abrir los archivos a copiar

| Archivo | Dónde va en el Explorer de Studio |
|---|---|
| [`GameConfig.luau`](ReplicatedStorage/GameConfig.luau) | `ReplicatedStorage` (ModuleScript) |
| [`CityGenerator.luau`](ServerScriptService/CityGenerator.luau) | `ServerScriptService` (ModuleScript) |
| [`DataService.luau`](ServerScriptService/DataService.luau) | `ServerScriptService` (ModuleScript) |
| [`Main.luau`](ServerScriptService/Main.luau) | `ServerScriptService` (**Script**) |
| [`ClientUI.luau`](StarterPlayerScripts/ClientUI.luau) | `StarterPlayer` › `StarterPlayerScripts` (**LocalScript**) |

> Los 5 cambian de ronda (aunque `DataService` y `ClientUI` solo cambian el
> sello `RONDA: v51`, para que la placa y el letrero digan la ronda correcta).
> Usa el **HTML de la ronda** (`v51-ARCHIVOS.html`): trae el **PASO 0
> (LIMPIADOR)** para borrar las copias viejas antes de pegar.

---

## 1. "la van al spawnearla afuera sale mal"

**La causa (medida):** dos cosas juntas.
- El cajón del taller NO tenía piso enfrente: su piso (top `y=1.00`) termina
  en la orilla del cajón y afuera solo está el pasto del patio, **1.5 studs
  más abajo** (`y=-0.49`).
- `Main` nacía la van a una **altura fija** (`CFrame.new(sp.X, 2.05, sp.Z)`):
  las ruedas quedaban a `2.05`, o sea **colgando 1 stud encima** de todo.

**El arreglo:**
- **`BayApron`** — el patio del cajón: concreto de `GAR_W + 2 × 26`, top
  `y=1.00` (la MISMA altura del piso del taller), pegado a su orilla. Ahí se
  apoya la van completa al salir.
- **`BayRamp`** — rampa del patio al pasto (baja 1.5 en 8 de largo, con sus
  dos guardas amarillas), para sacar el coche sin brinco.
- **`Main`** ya no usa altura fija: `CFrame.new(sp.X, sp.Y + 0.05, sp.Z)` —
  la altura del propio `GarageExit`, que cae a nivel del patio nuevo.

**Medido (etapa 26):** ruedas `y=1.10` contra tope del patio `1.00` (0.10 de
holgura, ya no 1.05 colgado) · la van ENTERA sobre el patio
(`z -648.0..-632.3` contra `-652.5..-626.5`) · su parte trasera (`-648.0`)
afuera del portón (`-652.4`).

---

## 2. "quiero que los conectes con calles a la ciudad... haciendo el trazo por cada lote"

**El trazo (todo medido contra el mundo real, ni un número a mano):**

| Pieza | Qué es | Medida |
|---|---|---|
| `RoadLotesZ1..Z4` | **4 calles de hilera**, una justo en la línea de enfrente de cada hilera de 5 lotes | a `+71` del centro de SU hilera (z -589, -849, -1109, -1369), de 20 de ancho, cubriendo las 5 columnas (x -740..900) |
| `RoadLotesX` | **el camino principal norte-sur**: baja derecho desde la calle más al sur de la ciudad (`RoadZ0`) por el callejón entre la 2a y 3a columna | x=-90, z -485..-1369 — **la toca** (medido: unido = true) |
| `RoadLotesX2` | **el de en medio**, cierra el circuito entre las 4 hileras | x=250, z -589..-1369 |
| `RoadLoteRamp` ×20 | **una rampa de entrada por lote**, frente al cajón de su taller (por ahí sale la van) | sube del pasto (-0.49) a la calle (1.05) en 7 de largo |
| faroles | **50 faroles nuevos** a lo largo de los caminos (146 en todo el juego) | uno cada 160 studs |

**La regla que se respeta (medida):** las calles SÍ pasan por el frente del
lote (donde están el patio y los bolardos), pero **ni una entra a la parte de
adentro** (la nave, el taller o el patio del fondo): estorbos medidos =
**ninguno**, en los 20 lotes.

Y la bici que nace "en la calle" (desde la v47) ahora nace sobre asfalto de
verdad: su punto (z=-589) es el centro de la calle de la primera hilera.

---

## 3. Pruebas

- **Etapa 26 nueva** (`tools/caminos51.py`): cuenta las 4+2 calles, las 20
  rampas y los faroles; mide la posición exacta de cada calle de hilera, que
  cubran los 5 lotes, que el principal TOQUE la calle de la ciudad, que
  ninguna calle se meta en un lote, y que la van salga apoyada en su patio,
  completa y fuera del portón.
- **`tools/alreves51.py`**: los 5 bugs de la ronda (la altura fija, el patio
  chiquito, la calle de hilera metida al lote, la rampa que falta y los
  caminos que desaparecen) se meten UNO POR UNO al código real y la etapa 26
  tiene que TRONAR cada vez. **5/5 truenan.**
- El alreves destapó un punto ciego: la etapa armaba la van POR SU CUENTA y
  no probaba que Main la pusiera a la altura del patio. Ahora la etapa 26
  también **lee el código real de Main** (como mapa.py lee a la bici) y
  truena si alguien regresa a la altura fija.
- **`bash tools/validate.sh` COMPLETO (1..26): EXIT=0.**
- La etapa 26 se recuperó del chat anterior: venía rota de fábrica (un `do`
  donde iba un `then`) y por eso nunca corría.

---

## Cómo probar

1. Corre el **PASO 0** del HTML (limpia copias viejas) y pega los 5 archivos.
2. **Play** → la placa verde debe decir `RONDA v51  OK` y el letrero del
   servidor `SERVIDOR v51`.
3. Del spawn, mira al sur: la calle nueva baja derecho hacia los lotes.
4. Llega a tu lote: hay una calle asfaltada justo al frente de tu bodega,
   con su raya amarilla y faroles.
5. Saca la van del cajón (**"Sacar y conducir"**): nace apoyada en su patio
   de concreto gris — ya no cae al pasto. Baja la rampa del patio, cruza el
   patio del frente, sube la rampa de tu lote y ya estás en la calle.
6. Date una vuelta: el circuito cierra por el camino de en medio sin
   regresarte por el principal.

---

## Roadmap

| Pendiente | Estado |
|---|---|
| Interiores de propiedades (casas/departamentos) | solo fachada hoy |
| Música ambiente + sonido de motor | los SFX de acciones ya están |
