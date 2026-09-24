# 🧪 Validación

No hay forma de correr Roblox Studio en el entorno de desarrollo, así que se armó un
simulador. **Úsalo antes de entregar cualquier ronda.**

## Un solo comando

```bash
bash tools/validate.sh
```

Corre tres etapas. Tienen que salir las tres OK.

## Qué hay en `tools/`

| Archivo | Qué es |
|---|---|
| `setup.sh` | Instala Lua 5.4 real en `tools/lua/` (`apt-get download` + `dpkg -x`) |
| `check.py` | Traduce Luau → Lua 5.4 y compila con `luac5.4 -p` |
| `mock.lua` | Mock de la API de Roblox (Instance, Vector3, CFrame, Enum, servicios…) |
| `mockclient.lua` | Extiende el mock con lo del cliente (Camera, ViewportSize, LocalPlayer, Remotes) |
| `runmain.py` | Corre GameConfig → CityGenerator → DataService → Main y construye los 4 tiers |
| `runclient.py` | Carga ClientUI en 3 tamaños de pantalla |
| `findsfx.py` | Busca IDs de audio en el catálogo de Roblox |
| `validate.sh` | Corre todo lo anterior |

## Etapa 1 — sintaxis

```bash
python3 tools/check.py ReplicatedStorage/GameConfig.luau ...
```

Luau tiene anotaciones de tipo que Lua 5.4 no entiende, así que `check.py` las strippea
antes de compilar. Es una traducción aproximada, **tiene huecos** — ver
`docs/03-NO-HAGAS-ESTO.md` §4 para los falsos positivos ya conocidos.

> `OK ServerScriptService/Main.luau (continue)` es **normal**. Main usa `continue`, que
> el traductor convierte en `goto cont` sin su etiqueta. No es un error.

## Etapa 2 — servidor en runtime

Corre la cadena completa bajo el mock. Salida esperada:

```
Sounds en config: true
CityGenerator OK
DataService OK
  Warehouse tier 1 OK … 4 OK
  SetupLighting OK
[SpiceEmpire] Ciudad generada.
[SpiceEmpire] Servidor listo.
>>> Main.luau CORRIO COMPLETO <<<
```

## Etapa 3 — cliente en runtime

Carga `ClientUI.luau` en escritorio (1920×1080, teclado), celular (896×414, táctil) y
tablet (1180×820, táctil). Las tres deben decir `OK`.

Sirve sobre todo para cachar que la rama móvil del dock no truene.

## Si agregas código nuevo

Si usas una API de Roblox que el mock no implementa, vas a ver un error que **no es
real**. Agrégala a `tools/mock.lua`. Ya están: `math.clamp`, `math.round`, `Enum` global,
`Vector3.Lerp`, `CFrame.ToObjectSpace`, `CFrame.Inverse`.

## Lo que el simulador NO puede probar

- Física de verdad (por eso la bici falló 4 veces sin que el validador dijera nada)
- Cómo se ve la iluminación
- Layout real de la UI (solo confirma que carga sin tronar)
- Que los IDs de audio suenen bien

Para todo eso hace falta que el usuario pruebe en Studio y mande captura.
