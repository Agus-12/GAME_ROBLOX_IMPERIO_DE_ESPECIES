# 🎧 Sonidos

Todos los IDs viven en **un solo lugar**: `GameConfig.Sounds`.

## Los que están puestos (v17)

Verificados uno por uno contra la API de Roblox: los 6 son `AssetTypeId = 3` (audio) y públicos.

| Clave | ID | Nombre real | Creador |
|---|---|---|---|
| `Harvest` | `9114515257` | Foliage Crunchy Rustle 1 | ProSoundEffects |
| `Press` | `9125672726` | Metal Impact Sledge Hammer on 5ft I-Beam | ProSoundEffects |
| `Sell` | `9113728042` | Cash Register 1 | ProSoundEffects |
| `Buy` | `12221967` | button.wav | Roblox |
| `Upgrade` | `9113704038` | Candy Machine Coin Drops Insert Vending 4 | ProSoundEffects |
| `Error` | `12221967` | button.wav (a tono 0.55) | Roblox |
| `Arrest` | `9114764731` | Handcuff Movement 25 | ProSoundEffects |

**ProSoundEffects** es una biblioteca profesional que Roblox subió gratis para todos los
desarrolladores (creador id `7462895450`). Son públicos y permanentes — la apuesta más
segura frente a los IDs de listas comunitarias, que suelen estar privados o borrados.

## Cómo buscar más

`tools/findsfx.py` busca en el catálogo de Roblox y filtra solo audio de
ProSoundEffects/Roblox, con duración corta.

```bash
python3 tools/findsfx.py 2.5 "Cash Register" "Foliage" "Handcuffs"
#                        ^ duración máxima en segundos
```

Imprime `ID · duración · nombre · descripción`.

### Notas de la API

- **Búsqueda:** `https://apis.roblox.com/toolbox-service/v1/marketplace/3?keyword=X&limit=30&sortType=3`
  (el `3` de la ruta es assetType = Audio)
- **Detalles:** `https://economy.roblox.com/v2/assets/<id>/details`
  → devuelve `Name`, `Creator`, `AssetTypeId`, `Description` (los de PSE traen
  `Duration` y `Category` dentro de la descripción)
- ⚠️ **Rate limit agresivo.** Hay que ir secuencial con ~0.12s de pausa. Con
  `ThreadPoolExecutor` devuelve 429 y parece que "no encontró nada".
- ⚠️ Las búsquedas de **varias palabras** dan resultados flojos. Usa una o dos palabras.

## Cómo reproducirlos

- El servidor manda `RE_Sfx:FireClient(player, "Harvest")`
- El cliente tiene un banco de `Sound` precreados en `gui.SfxBank` y los reusa
- Se le aplica una variación de tono de ±4% para que no suene robótico al repetir
- El mapeo acción → sonido está en `SFX_BY_ACTION`, en el handler central de `Action`

## Cómo cambiarlos

En `GameConfig.Sounds`:

```lua
Sell = { Id = "rbxassetid://1234567890", Volume = 0.65, Pitch = 1.00 },
```

- `Volume` 0 a 1 · `Pitch` >1 más agudo, <1 más grave
- `Enabled = false` hasta arriba apaga todo el sonido

Para que el usuario busque los suyos: pestaña **Creador** → **Audio** → clic derecho →
**Copy Asset ID**.

## Pendiente

- Música de fondo
- Sonido de motor para los vehículos
- Sonido de la bici al rodar
