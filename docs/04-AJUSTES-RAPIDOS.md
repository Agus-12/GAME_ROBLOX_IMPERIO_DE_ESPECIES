# 🎛️ Ajustes rápidos

Perillas para cambiar cosas sin rediseñar nada.

## Balance

| Quiero… | Dónde | Cómo |
|---|---|---|
| Probar una llamada YA | `GameConfig.MissionCalls` | `FirstCallWait = 10` |
| Llamadas más seguidas | `GameConfig.MissionCalls` | `MinWait = 30`, `MaxWait = 60` |
| Que las plantas crezcan rápido | `GameConfig.Growth` | baja `TimePerPlant = 24` |
| Cosechar desde más lejos | `GameConfig.Growth` | sube `HarvestRadius = 9` |
| Desactivar la policía | `GameConfig.Agents` | `Enabled = false` |
| Desactivar la bici inicial | `GameConfig.StarterBike` | `Enabled = false` |

## Carga y caja fuerte

| Quiero… | Dónde | Cómo |
|---|---|---|
| Que carguen más sin mochila | `GameConfig.Carry` | `BaseCapacity = 80` |
| Usar la caja desde más lejos | `GameConfig.Carry` | `VaultRadius = 16` |
| Mochilas más baratas | `GameConfig.Carry.Backpacks` | baja los `Cost` |
| Prensar desde más lejos | `GameConfig.Press` | `UseRadius = 14` |
| Que se abran los paneles desde más lejos | `GameConfig.Interact` | `Computer`, `Garage`, `Buyer` |

## Lotes de bodega (¡ojo!)

Una bodega **no mide lo que dice su `Size`**: el nivel 4 mide 190 de ancho y además se
le pegan el taller (46 a la izquierda) y la oficina (34 a la derecha) = **271 studs**.
Todo lo que se siembra en el mundo usa estos números; si los tocas, corre
`python3 tools/walk.py` (comprueba anexos, encimado y que los lotes caigan sobre el suelo).

| Quiero… | Dónde | Cómo |
|---|---|---|
| Separar más las bodegas | `GameConfig.WarehouseLots` | sube `SpacingX` / `SpacingZ` |
| Más bodegas por fila | idem | `PerRow` (hoy 5; con `MaxSlots = 20` son 4 filas) |
| Mover la fila de lotes | idem | `Origin`, `HalfWidth`, `HalfDepth` |

> El suelo de la ciudad se **estira solo** para cubrir los lotes (`buildGround` lee los
> mismos números). No hay que tocar el tamaño del pasto a mano.

## Pantalla de entrada (v30)

| Quiero… | Dónde | Cómo |
|---|---|---|
| Tope distinto para el botón de entrar | `ClientUI.luau`, bloque "CUANDO SE ABRE EL BOTON" | el `for _ = 1, 30 do ... task.wait(0.1)` = 3 s |
| Que la portada se quite sola | `ClientUI.luau` | llama `closeSplash()` al abrir (`abrirPortada`) |

## Garaje, carros y ambientación (v29)

| Quiero… | Dónde | Cómo |
|---|---|---|
| Garaje más grande | `GameConfig.Garage` | sube `Widths` / `Depths` / `Heights` (¡mira el aviso de abajo!) |
| Que el portón se abra desde más lejos | `GameConfig.Garage` | sube `OpenRadius = 20` |
| Portón más ancho o alto | `GameConfig.Garage` | `DoorWidth = 9`, `DoorHeight = 11` |
| Menos cajones | `GameConfig.Garage` | baja `Bays` (ojo: los `Bay` de `GameConfig.Vehicles` tienen que existir) |
| Quitar la ambientación de afuera | `GameConfig.Ambience` | `Enabled = false` |
| Dejar solo las luces (sin adornos) | `GameConfig.Ambience` | `Props = false` |
| Noche más corta/larga | `GameConfig.DayNight` | `DayLengthMinutes = 12` |
| Que oscurezca más tarde | `CityGenerator.SetupLighting` | el renglón `setCityLights(t >= 18 or t < 6.5)` |

> ⚠️ **Si agrandas el garaje, corre `python3 tools/walk.py`.** El ancho total del lote
> (bodega + taller + oficina) tiene que caber en `Config.WarehouseLots.SpacingX`:
> hoy son **297 de 340**. Si te pasas, la oficina de un jugador se mete en el taller del
> vecino (ya nos pasó en la v28).

## Empleados

| Quiero… | Dónde | Cómo |
|---|---|---|
| Que cosechen más rápido | `GameConfig.Employees.Harvester` | baja `Interval = 8` |
| Que corten más por vez | idem | sube `PerCycle = 2` |
| Más horas de producción offline | `GameConfig.Employees` | `OfflineMaxHours = 8` |
| Quitar el tope de un cosechador por mesa | `Main.luau`, `hire()` | borra el bloque `if role == "Harvester"` |

## Asaltos y combate

| Quiero… | Dónde | Cómo |
|---|---|---|
| Probar un asalto YA | `GameConfig.Raids` | `CheckInterval = 20`, `BaseChance = 1`, `WarnSeconds = 8` |
| Asaltos más difíciles | `GameConfig.Raids` | sube `RaidersBase` o `RaiderHealth` |
| Más tiempo para llegar | `GameConfig.Raids` | sube `CrackSeconds = 16` |
| Arma más fuerte | `GameConfig.Weapon` | `Damage = 26` |
| Quitar el arma | `GameConfig.Weapon` | `GiveOnSpawn = false` |
| Guardias más efectivos | `GameConfig.Raids` | `GuardDamage`, baja `GuardEvery` |

## Territorios

| Quiero… | Dónde | Cómo |
|---|---|---|
| Capturar más rápido (probar) | `GameConfig.Territories` | `CaptureSeconds = 25` → `5` |
| Zona de captura más grande | idem | `Radius = 46` |
| Más beneficio por plaza | idem | `PriceBonus = 0.20`, `IncomePer = 140` |
| Desactivar territorios | idem | `Enabled = false` |

## Visual

| Quiero… | Dónde | Cómo |
|---|---|---|
| Luces de la ciudad siempre prendidas | Main / consola | `CityGenerator.SetCityLights(true)` |
| Interior de la bodega más oscuro | `CityGenerator`, `SetupLighting` | `INTERIOR_AMBIENT = Color3.fromRGB(30,32,40)` |
| Interior más claro | idem | `Color3.fromRGB(60,62,74)` |
| Lámparas de techo más brillantes | `CityGenerator`, sección LÁMPARAS DE TECHO | `l.Brightness = 0.85` → `1.2` |
| Menos basura en la calle | `CityGenerator`, `scatterTrash` | baja el `26` |
| Día/noche más lento | `GameConfig.DayNight` | sube `DayLengthMinutes` |
| Congelar la hora | `GameConfig.DayNight` | `Enabled = false` |

## Rendimiento en celular

| Quiero… | Dónde | Cómo |
|---|---|---|
| Ciudad más chica | `GameConfig.City` | `GridX = 4`, `GridZ = 4` |
| Menos ventanas | `CityGenerator`, `addWindowGrid` | `floorH = 7` → `12` |
| Menos basura | `CityGenerator`, `scatterTrash` | baja el `26` |
| Apagar sonido | `GameConfig.Sounds` | `Enabled = false` |

## Bici

| Quiero… | Dónde | Cómo |
|---|---|---|
| Que suba escalones más altos | `Main`, `spawnBike` | `MAX_STEP = 1.6` → `2.5` ⚠️ entre más alto, más fácil trepa cosas que no debería |
| Más rápida | `GameConfig.StarterBike` | `Speed` |
| Que caiga más rápido | `Main`, `spawnBike` | `GRAVITY = 70` |
