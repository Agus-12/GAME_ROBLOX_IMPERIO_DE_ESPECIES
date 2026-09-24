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
