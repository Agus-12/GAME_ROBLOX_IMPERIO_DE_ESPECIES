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

### RemoteEvents (servidor → cliente)

| Evento | Carga |
|---|---|
| `StateUpdate` | `{Cash, Leaves, Blocks, Plots, PressLevel, Employees, Vehicles, Properties, Heat, TotalEarned, Storage, WarehouseTier, CrewName, Wanted}` |
| `PhoneAlert` | `{Title, Body, Kind, Time}` · Kind = `info`\|`danger`\|`good`\|`money` |
| `Toast` | `(text, kind)` |
| `MissionUpdate` | `nil` o `{Title, Text, BuyerName, Item, Amount, Reward, EndsAt}` · EndsAt es `os.time()` absoluto |
| `IncomingCall` | `nil` o `{Caller, Line, Title, Text, BuyerName, Item, Amount, Reward, Seconds}` |
| `OpenUpgrades` | — · se dispara al pisar el tapete del escritorio (v15) |
| `Sfx` | `(key)` · nombre del sonido en `Config.Sounds` (v16) |

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

**7 botones:** Cosechar E · Prensar R · Vender F · Tienda B · Teléfono T · Bodega H · Mejoras G

**Paneles:** `shop` 620×460 · `phone` 300×440 · `missionPanel` 300×86 · `dialog` 520×92
· `callGui` 290×330 + `callShadow`

**Controles de teclado:** E cosechar · R prensar · F vender · G mejoras · B tienda ·
T teléfono · H bodega · **M minimizar HUD** (único sin botón en el dock)

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
