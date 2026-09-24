# 🧪 Validación

No hay forma de correr Roblox Studio en el entorno de desarrollo, así que se armó un
simulador. **Úsalo antes de entregar cualquier ronda.**

## Un solo comando

```bash
bash tools/validate.sh
```

Corre **nueve etapas**. Tienen que salir todas OK.

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
| `globals.py` | Lista los globales que toca cada script (caza typos tipo `Workspace`) |
| `parts.py` | Construye los 4 niveles y verifica que existan las partes clave |
| `fields.py` | Compara los campos `Config.x.y` que lee el código contra la config real |
| `walk.py` | Flood fill con el cuerpo del jugador: ¿se puede *caminar* a cada máquina? |
| `api.py` | Valida enums, clases y props contra el API-Dump de Roblox |
| `remotes.py` | El cliente pide los mismos remotes que el servidor crea, y las versiones cuadran |
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

## Etapa 4 — globales sospechosos

```bash
python3 tools/globals.py <archivos...>
```

Compila con `luac -l -l` y lee las instrucciones `GETTABUP _ENV "nombre"`, o sea **todos
los globales que el script lee**. Los compara contra una lista blanca de globales que sí
existen en Roblox y marca el resto.

Así se encontró el bug más caro del proyecto: `Workspace` (con mayúscula) **no existe** en
Roblox. El detector de cercanía lo usaba dentro de un `pcall`, así que tronaba en cada
tick **en silencio** y ningún botón contextual aparecía nunca.

> Si agregas un global legítimo, mételo al set `OK` de `tools/globals.py`.
> `_SKIP` en Main es un artefacto del traductor de `continue`; se ignora.

## Etapa 5 — partes de la bodega

```bash
python3 tools/parts.py
```

Construye los 4 niveles bajo el mock, recorre el modelo y verifica que existan todas las
partes que Main y ClientUI buscan por nombre (`VaultBody`, `PressBase`, `UpgradeScreen`,
`Bay1`, `SafePad`…).

Nació porque en la v25, al reescribir una sección de `CityGenerator`, se borró **toda la
caja fuerte** y ninguna validación lo detectó.

> **Si agregas una parte que el código busque por nombre, métela a `REQUIRED`.**

## Lo que el simulador NO puede probar

- Física de verdad (por eso la bici falló 4 veces sin que el validador dijera nada)
- Cómo se ve la iluminación
- Layout real de la UI (solo confirma que carga sin tronar)
- Que los IDs de audio suenen bien

Para todo eso hace falta que el usuario pruebe en Studio y mande captura.

## Etapa 6 — campos de la config (`tools/fields.py`)

```bash
python3 tools/fields.py
```

Carga `GameConfig` de verdad, saca su esquema y compara **todos** los accesos
`Config.algo.campo` y de alias (`T.VaultLeaves`, `b.Capacity`, `tpl.Title`…) de los
cuatro consumidores. Sale:

```
ServerScriptService/Main.luau
   todos los campos que lee existen en GameConfig
...
OK
```

Nació del bug de `StorageBonus` (v28): un campo borrado de la config que tres
lugares seguían leyendo. En Lua eso **no** falla al compilar; da `nil`, y el error
revienta en tiempo de ejecución, muchas veces dentro de un `pcall` (silencio total).

**Pruébalo siempre con un campo falso a propósito** antes de confiar en él:

```bash
# mete 'Config.WarehouseTiers[1].CampoFalso' en Main, corre fields.py,
# confirma que lo reporta, y revierte.
```

## Etapa 7 — alcanzabilidad (`tools/walk.py`)

```bash
python3 tools/walk.py
```

Construye los 4 niveles bajo el mock, exporta **todas** las partes (nombre, tamaño,
posición, colisión) y tira un flood fill en 2D a la altura del torso del jugador,
tratando como muro toda parte con colisión que le tape el paso. Verifica que desde el
punto donde apareces se pueda **caminar** hasta:

```
oficina · caja fuerte · computadora · prensa · mesa 1 · garaje · cajón 1 · la calle
```

Además comprueba que la oficina esté **por fuera** del muro de la nave, que el ancho
total del anexo quepa en la separación entre lotes, y que **los 20 lotes caigan sobre
el suelo** de la ciudad.

`parts.py` decía "todas las partes presentes" mientras el garaje era una caja cerrada
sin puerta. Existir no es lo mismo que poder llegar.

## Etapa 8 — API de Roblox (`tools/api.py`)

```bash
python3 tools/api.py
```

Descarga (una vez, a `/tmp`) el `API-Dump.json` oficial y valida:

- `Enum.Material.AlgoQueNoExiste`
- `Instance.new("ClaseQueNoExiste")`
- `GetService("ServicioQueNoExiste")`
- propiedades en las tablas de los helpers (`part{...}`, `frame{...}`, `label{...}`)

El mock del simulador acepta cualquier cosa: un enum mal escrito solo truena al darle
Play en Studio, en inglés y sin decir en qué línea. Esta etapa lo caza antes.

> Si no hay red, avisa y se salta (no bloquea la entrega): el `validate.sh` lo llama
> con `|| true` a propósito.

## Etapa 9 — contrato cliente/servidor (`tools/remotes.py`)

```bash
python3 tools/remotes.py
```

Dos cosas:

1. **Remotes.** Saca de `Main.luau` los nombres que crea (`mkEvent` / `mkFunc`) y de
   `ClientUI.luau` los que pide (`need(Remotes, "X")`, `WaitForChild`, `FindFirstChild`).
   Si el cliente pide uno que el servidor no crea, la UI se queda sin esa función y
   aparece el cartel **"FALTAN SCRIPTS/REMOTES"** en Studio.

   > Así se cazó el caso real del usuario: `Main.luau` de la v20 + `ClientUI` de la v28
   > → faltaban `Shoot` (v21) y `TerritoryUpdate` (v24).

2. **Versiones.** `GameConfig.Build`, el `MI_VERSION` de `ClientUI`, el último
   `CAMBIOS-vN.md` de la raíz, el `README` y `CONTINUACION.md` tienen que decir el
   mismo número. Si no cuadran, la ronda no sale.

**Cuando subas de ronda:** cambia el número en `GameConfig.Build`, en `MI_VERSION` de
`ClientUI.luau` y en `README` / `CONTINUACION.md`, y esta etapa te avisa si se te olvidó
alguno.

## ⚠️ Las etapas 2 y 3 tienen que FALLAR cuando algo truena

`runmain.py` y `runclient.py` salían con código 0 aunque el script reventara, así que
`validate.sh` daba la ronda por buena con el cliente roto. Ya no: si el cliente truena
en cualquiera de los 3 tamaños, o si Main no llega al final, **la etapa marca FALLA**.
Probado a propósito:

```
runclient EXIT=1   FALLA  el cliente trono en 3 de 3 tamanos
runmain   EXIT=1   FALLA  el servidor trono en runtime (ver arriba)
```
