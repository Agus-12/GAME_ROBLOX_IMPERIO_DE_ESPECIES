# 🏗️ Arquitectura

## Contrato cliente ↔ servidor

Todo vive en `ReplicatedStorage/Remotes` (lo crea `Main.luau` al arrancar).

### RemoteFunction `Action`

```lua
Action:InvokeServer(action, arg1, arg2)  -->  { ok = boolean, msg = string }
```

| Acción | arg1 | Qué hace |
|---|---|---|
| `sync` | — | Pide el estado completo |
| `harvest` | — | Cosecha las plantas maduras cercanas |
| `press` | — | Convierte hojas en bloques |
| `sell` | buyerId | Vende al comprador |
| `buyPlot` | — | Compra una maceta más |
| `upgradePress` | — | Sube el nivel de la prensa |
| `hire` | `"Harvester"` \| `"Presser"` \| `"Guard"` | Contrata empleado |
| `buyVehicle` | id | Compra vehículo |
| `buyProperty` | id | Compra propiedad |
| `spawnVehicle` | id | Saca el vehículo |
| `upgradeWarehouse` | — | Sube el nivel de bodega |
| `spawnBike` | — | Saca la bici |
| `answerCall` | bool | Contesta/rechaza la llamada |
| `hangUp` | — | Cuelga |
| `createCrew` / `joinCrew` / `leaveCrew` | nombre | Crews |
| `teleportHome` | — | Te lleva a tu bodega |
| `withdraw` | `"leaves"`\|`"blocks"`, cantidad | Saca de la caja fuerte a tu carga |
| `deposit` | `"leaves"`\|`"blocks"`, cantidad | Guarda tu carga en la caja fuerte |
| `buyBackpack` | id | Compra mochila (sube capacidad de carga) |

### RemoteEvents (servidor → cliente)

| Evento | Carga |
|---|---|
| `StateUpdate` | `{Cash, Leaves, Blocks, CarryLeaves, CarryBlocks, CarryCap, Backpack, BackpackName, Plots, PressLevel, Employees, Vehicles, Properties, Heat, TotalEarned, Storage, WarehouseTier, CrewName, Wanted}` · **`Leaves`/`Blocks` = lo GUARDADO en la caja; `Carry*` = lo que trae encima** |
| `PhoneAlert` | `{Title, Body, Kind, Time}` · Kind = `info`\|`danger`\|`good`\|`money` |
| `Toast` | `(text, kind)` |
| `MissionUpdate` | `nil` o `{Title, Text, BuyerName, Item, Amount, Reward, EndsAt}` · EndsAt es `os.time()` absoluto |
| `IncomingCall` | `nil` o `{Caller, Line, Title, Text, BuyerName, Item, Amount, Reward, Seconds}` |
| `OpenUpgrades` | — · se dispara al pisar el tapete del escritorio (v15) |
| `Sfx` | `(key)` · nombre del sonido en `Config.Sounds` (v16) |
| `OpenVault` | — · se dispara al pisar el tapete de la caja fuerte (v18) |
| `TerritoryUpdate` | lista `{Id, Name, CrewName, Contested, Progress}` · a todos (v24) |

### Cliente → servidor

| Evento | Carga |
|---|---|
| `Shoot` | `dir: Vector3` · dirección de puntería; el servidor hace el raycast (v21) |

---

## Estructura de `CityGenerator.luau`

Orden de las funciones (los números de línea se mueven, usa los nombres):

```
tagLight / tagNeon          marcan luces y neones para el ciclo día/noche
makeBillboard
addWindowGrid
BUYER_CELLS / MARKET_DEPTH=56 / buildBlock
makeBuyerNPC(style)         rig R6; style="guard" para el vigilante
makeTrashCan / scatterTrash
buildBuyers
CityGenerator.BuildWarehouse(tierIndex)
    PISO → PAREDES → FACHADA CON PORTÓN → TECHO → CORTINA → MUELLE
    → ZONA DE PRENSA → ZONA SEGURA → MESAS DE CULTIVO → PAD DE MEJORA → VIGILANTE
buildWarehouseTemplate
CityGenerator.BuildAgent()
CityGenerator.Build()
CityGenerator.SetupLighting()   <- aquí vive INTERIOR_AMBIENT y el ciclo día/noche
```

## Estructura de `Main.luau`

```
mkEvent(...)                crea los RemoteEvents
warehouses / warehouseSlots
assignWarehouse
storageCap / push           push() = manda StateUpdate + actualiza la pantalla del escritorio
toast / alert / sfx
updateWarehouseScreen       escribe en el monitor del escritorio
playHarvestFX / doHarvest / doPress / doSell / checkMissionOnSell
arrest
spawnBike                   <- bici cinemática, ver docs/03
sección ENCARGOS / MISIONES
sección AGENTES DE ADUANAS
sección LLAMADAS
handler central de Action   <- aquí se mapea acción -> sonido
loop del TAPETE DE MEJORAS
loop de re-sync cada 5s
```

---

## Nombres de partes (para buscar en el código)

**Plantas** — Models `Plant` en folder `Plots`, PrimaryPart `Pot`.
Hijos: `Soil`, `Stem`, 3× `Leaf` (attrs `FullX`/`FullY`/`BaseY`), `RipeGlow`, `RipeLight`.
Attrs del Model: `PlotIndex`, `Ripe`, `Growth`, `PlantedAt`. 6 macetas por mesa, mesas a 18 studs.

**Prensa** — `Piston`, `PressBase`, `PressAnvil`, `PressPost`×4, `PressHead`, `PressMotor`,
`PressHose`, `PressRod`, `PressStatus`, `Pallet`, `StackedBlock`.

**Portón** — folder `Gate` con `GateLeft`/`GateRight` (attrs `ClosedX`/`OpenX`/`HomeX`),
cada hoja con folder hijo `Ribs` cuyas `GateRib` llevan `OffX`/`OffY`/`OffZ`.
También `GateSensor`, `GateFrame`, `GateLamp`, `FrontWall`.

**Caja fuerte** — `VaultBody`, `VaultFrame`, `VaultDoor`, `VaultWheel`, `VaultSpoke`,
`VaultHinge`, `VaultScreen` (SurfaceGui → `VaultText`), `VaultPad`. Va en la zona segura.

**Escritorio** — `UpgradePad`, `Desk`, `DeskLeg`, `PCTower`, `PCLed`, `MonitorStand`,
`MonitorPost`, `MonitorBody`, `UpgradeScreen` (SurfaceGui → `ScreenTitle`/`ScreenBody`),
`DeskChair`, `ChairBack`, `DeskRug`.

**Bici** — Model `Bike_<UserId>`, PrimaryPart `Chassis` (invisible 1.9×4.5×5,
**anclado y sin colisión**). Decorativas: `TopTube`, `DownTube`, `Stem`, `Handlebar`,
`Grip`, `Crank`, `Pedal`, `Seat` (VehicleSeat), `WheelFront`/`WheelRear` + `Rim`.
**Todas ancladas**, se reposicionan por CFrame cada frame.

**Vigilante** — `Lookout`, tag `LookoutNPC`, accesorios `Jacket`/`Shades`/`Cap`/
`CapBrim`/`Belt`/`Radio`. Pose vía Motor6D. Parado sobre `GuardCurb`.

**Reja** — `makeChainFence(parent, from, to, height?)` → `FenceMesh` (CanCollide false),
`FencePost`, `FenceRail`.

---

## UI (`ClientUI.luau`)

`gui` es un ScreenGui con `IgnoreGuiInset = true`.
Helpers: `frame` / `label` / `button` / `corner` / `stroke`.

**Capa móvil (v12):**
- `IS_MOBILE = TouchEnabled and not KeyboardEnabled`
- `fitPanel(panel, designW, designH, center?)` — mete un `UIScale` recalculado cuando
  cambia el `ViewportSize`. Margen 24 horizontal, 24 móvil / 90 desktop vertical,
  escala mínima 0.45. Si `center ~= false` fuerza AnchorPoint (0.5, 0.5).

**Dock ramificado:**
- Móvil: `UIGridLayout` 2 columnas, pegado al costado **derecho** a media altura
  (evita el joystick abajo-izquierda y el salto abajo-derecha). Botones 106×46, sin `[tecla]`
- Desktop: barra horizontal 660×56 abajo-centro, botones 100×38, con `[tecla]`

**Dock contextual (v22).** `dockBtn(name, key, cb, ctx?)`: si lleva `ctx`, el botón
arranca oculto y lo prende/apaga `setCtx(ctx, on)`. Un loop cliente cada 0.3 s mide
distancias contra la bodega del jugador (`Workspace.Warehouse_<UserId>`):

| ctx | Referencia | Radio |
|---|---|---|
| `harvest` | cualquier `Plot*` | 12 |
| `press` | `PressBase` | 16 |
| `computer` | `UpgradeScreen` | 13 |
| `vault` | `VaultBody` | 16 |
| `sell` | pads de `City.Buyers` | 30 |

Sin `ctx` (siempre visibles): Tienda B · Teléfono T · Bodega H.
Al **entrar** al radio de `computer` o `vault` se abre el panel con sonido; al **salir**
se cierra solo.

**HUD (v22):** siempre compacto, 4 chips con emoji — 🌿 hojas que cargas, 🧱 bloques que
cargas, 🎒 espacio de mochila, 🔒 contenido de la caja. La barra grande y los botones
`+`/`-` siguen en el código pero arrancan con `Visible = false`.

**Paneles:** `shop` 620×460 · `phone` 300×440 · `missionPanel` 300×86 · `dialog` 520×92
· `callGui` 290×330 + `callShadow`

**Controles de teclado:** E cosechar · R prensar · F vender · G mejoras · B tienda ·
T teléfono · H bodega · **C caja fuerte** · **M minimizar HUD** (único sin botón en el dock)

## Territorios (v24)

Estado en memoria (no se persiste; se recalcula cada sesión):
`territories[buyerId] = {CrewId, CrewName, Color, Progress, ByCrew, Contested}`

- Las 5 zonas de `Config.Buyers` son los territorios. El mástil lo construye
  `buildBuyers` junto al pad: `FlagBase`, `FlagPole`, `Flag_<buyerId>` (con `ZoneLight`
  y un `OwnerSign` → `OwnerText`).
- Bucle de 1 s: cuenta jugadores vivos dentro de `TR.Radius` del pad, agrupados por crew.
  - 2+ crews (o 1 crew + alguien sin crew que no sea el dueño) → `Contested`, se congela
  - 1 solo crew y no es el dueño → `Progress += 1`; al llegar a `CaptureSeconds`, captura
  - nadie → `Progress` baja por `DecayPerSecond`
- `paintFlag(buyerId)` pinta bandera, luz y letrero.
- `pushTerritories()` manda el snapshot por `RE_Terr` (`TerritoryUpdate`) a **todos**.
- `territoryBonus(player, buyerId)` da `TR.PriceBonus` si tu crew domina esa plaza;
  `doSell` lo multiplica sobre `buyer.PriceMult`.
- Renta cada `IncomeInterval` a todos los miembros del crew dueño.
- El color del crew se asigna al crearlo, rotando `TR.CrewColors`.

> ⚠️ `territoryBonus` está **forward-declared** arriba: `doSell` la usa y se define al
> final del archivo.

## Combate y asaltos (v21)

**Arma** — `makeWeapon()` crea una `Tool` server-side; `giveWeapon(player)` la repone en
cada `CharacterAdded`. El cliente **solo manda la dirección**: `RE_Shoot:FireServer(dir)`.
El servidor valida cadencia (`Config.Weapon.Cooldown`), que el arma esté equipada
(`char:FindFirstChild(W.Name)`), hace el `Raycast` y aplica `TakeDamage`. Nunca confíes
en el cliente para los impactos.

**Asalto** (`runRaid`) — `activeRaid[player]` garantiza uno a la vez; `raidMobs[player]`
guarda asaltantes y guardias para poder limpiarlos.

1. Alerta → espera `WarnSeconds`
2. Spawnea `RaidersBase + tier * RaidersPerTier` asaltantes afuera del portón
3. Cada uno hace `Humanoid:MoveTo(vault.Position)` en bucle y dispara al jugador si
   está a `RaiderAttackRange`
4. El primero que llega a menos de 9 studs de la caja arranca la cuenta `CrackSeconds`
5. `finish(true)` si `alive <= 0`; `finish(false)` si vence la cuenta
6. Red de seguridad a `MaxRaidSeconds` para que nunca quede colgado

Los guardias contratados (`Employees.Guard`) se spawnean junto a la caja y le pegan al
asaltante vivo más cercano cada `GuardEvery`. **No se mueven** — a propósito, para no
meter pathing y repetir los problemas de la bici.

> Los NPCs de asalto usan `Humanoid:MoveTo`, que es pathing nativo de Roblox. **No les
> metas física custom.**

## Garaje (v26)

- `CityGenerator` levanta un anexo al costado izquierdo de la nave:
  `GarageFloor`, `GarageWall`, `GarageCeiling`, `Bay1..Bay4` (con attr `BayIndex`),
  `BayLine`, `BayPlate`, `GarageLamp`, `GarageExit`, `GarageSign`.
- `Config.Vehicles[i].Bay` dice en qué cajón va cada auto, y `.Color` su pintura.
- `syncGarage(player)` borra los `Parked_*` y vuelve a armar uno por vehículo
  poseído, **menos el que ande fuera** (se compara con el attr `VehicleId` del
  `Car_<UserId>` que esté en Workspace). Se llama al entrar, al comprar y al sacar.
- `buildParkedCar(info, cf)` arma la carrocería decorativa (anclada, sin colisión).
- `spawnVehicle` ahora coloca el auto manejable en `GarageExit`.
- ⚠️ `syncGarage` va **forward-declared**: `setupPlayer` y `buyVehicle` la usan antes.

## Empleados físicos (v19)

- `CityGenerator.MakeWorker(parent, pos, facing, tag)` crea el NPC (estilo `"worker"`:
  chaleco amarillo + overol azul)
- `workerModels[player]` guarda los Models vivos
- `syncWorkers(player)` **borra y repone** todos los NPCs para que cuadren con
  `profile.Employees`. Se llama al entrar, al contratar y al mejorar la bodega
  (la bodega se reconstruye, así que hay que reponerlos)
- **Un cosechador por mesa.** El cosechador `i` se para junto a `Plot<i>` y solo corta
  plantas cuyo `PlotIndex == i`. El tope de contratación es `WarehouseTiers[tier].Plots`
- `applyOfflineProduction(player)` acredita al entrar lo que produjeron mientras no
  estabas, usando `profile.LastSeen` (lo sella `DataService.Save`), con tope
  `Config.Employees.OfflineMaxHours`
- ⚠️ `syncWorkers` y `applyOfflineProduction` están **forward-declared** arriba del
  archivo porque `setupPlayer` y `hire` las usan antes de que existan

> ⚠️ `vaultUsed(profile)` = `Leaves + Blocks * 3`. **Un bloque ocupa 3 de espacio.**
> Úsalo siempre; no recalcules el espacio a mano (en la v18 quedó inconsistente y se
> arregló en la v19).

## Economía de dos bolsas (v22 — reescrita)

| Dónde | Campo | Quién la llena | Tope | ¿Aduanas? |
|---|---|---|---|---|
| 🎒 Mochila | `CarryLeaves` / `CarryBlocks` | **Tú**, al cosechar y prensar | `carryCap()` compartido | ✅ te la quita |
| 🔒 Caja fuerte | `Leaves` / `Blocks` | Tus depósitos y **tus empleados** | `vaultLeafCap()` y `vaultBlockCap()`, **separados** | ❌ a salvo |

- `addLeaves(player, n)` → **mochila** (lo que cosechas tú)
- `addLeavesToVault(player, n)` → **caja** (lo que cosechan tus empleados y lo offline)
- `doPress` consume `CarryLeaves` y produce `CarryBlocks`
- `doSell` consume la mochila
- Los topes de la caja salen de `WarehouseTiers[t].VaultLeaves` / `.VaultBlocks`
- `storageCap()` quedó solo como suma informativa para textos
- ⚠️ Ya **no** existe la regla "un bloque ocupa 3" — cada producto tiene su propio cajón

## Economía de dos bolsas (v18 — histórico)

| Dónde | Campo del perfil | ¿Aduanas lo puede quitar? |
|---|---|---|
| Caja fuerte de la bodega | `Leaves` / `Blocks` | ❌ No |
| Encima del jugador | `CarryLeaves` / `CarryBlocks` | ✅ Sí |

- Cosechar y prensar depositan en la **caja**
- Vender consume lo **cargado**
- `carryCap(profile)` = `Config.Carry.BaseCapacity` o la capacidad de la mochila comprada
- `storageCap(profile)` = límite de la caja (sube con el nivel de bodega y propiedades)

---

## Balance (todo en `GameConfig.luau`)

**Bodegas:**
| Nivel | Nombre | Costo | Tamaño | Plots | Bonus almacén |
|---|---|---|---|---|---|
| 1 | Garage | $0 | 70×20×56 | 4 | — |
| 2 | Bodega | $15,000 | 100×26×78 | 8 | +150 |
| 3 | Almacén Industrial | $120,000 | 140×34×104 | 12 | +500 |
| 4 | Mega Procesadora | $600,000 | 190×46×140 | 12 | +1500 |

**Compradores:** `docks` ×0.85 · `market` ×1.00 · `downtown` ×1.35 · `uptown` ×1.60 ·
`border` ×1.90. Celdas (0,0) (4,0) (2,2) (0,4) (4,4).

**Misiones:** `rush_blocks` (3–8 bloques / 180s / ×2.2 / heat ×0.6) ·
`bulk_leaves` (40–120 hojas / 240s / ×1.9 / heat ×0.5) ·
`hot_run` (5–12 bloques / 150s / ×3.4 / heat ×1.8).
Bono = `amount × BasePrice × buyer.PriceMult × RewardMult`.

**Agentes de Aduanas:** aparecen desde Heat 55. Probabilidad por tick de 6s =
`0.25 + over*0.5`. Se rinden si Heat < 35, a 320 studs, o a los 45s.
Te agarran a 8 studs → `arrest()`. Matarlos = −18 Heat.

**Crecimiento:** `Growth.TimePerPlant = 24`, `HarvestRadius = 9`, `LeavesPerPlant = 1`,
`StageColors` (4 etapas).

**Llamadas:** `MinWait = 300`, `MaxWait = 600`, `FirstCallWait = 90`, `RingSeconds = 20`,
`RejectPenalty = 120`, `CallerName = "DESCONOCIDO"`, 4 `Lines`.

**Tags de CollectionService:** `"NightLight"` (attrs `NightBrightness`, `LitColor`/
`OffColor`/`IsWindow`) · `"BuyerNPC"` (`BuyerId`/`BuyerName`) · `"LookoutNPC"`.
Es de noche cuando `t >= 18 or t < 6.5`.
