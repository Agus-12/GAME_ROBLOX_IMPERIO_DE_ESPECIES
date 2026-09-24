# Cambios de la ronda v37

> Resumen: **encontre la causa de "le pegue los archivos y no cambio nada"**. Eran
> dos bugs mios en el cliente: (1) la columna del HUD nunca se hacia visible, y
> (2) el cliente **se apagaba a si mismo** si veia una interfaz vieja guardada en
> el lugar. Ahora borra la basura y dibuja la suya. Ademas, la ronda **se ve en la
> esquina** junto al reloj.

---

## 1. 🛑 EL BUG GORDO: el cliente se apagaba solo

Desde la v28 el cliente tenia esto:

```lua
if playerGui:FindFirstChild("SpiceEmpireUI") then
    warn("HAY 2 ClientUI PEGADOS...")
    cartelDeError({...})
    return            -- <-- SE APAGA TODA LA INTERFAZ NUEVA
end
```

Ese chequeo asumia que, si ya hay una interfaz del juego en pantalla, es que hay
**dos ClientUI pegados**. Pero esa interfaz puede ser **basura guardada dentro del
lugar** (un `ScreenGui` que quedo en `StarterGui`: Roblox lo mete en la pantalla al
arrancar). En ese caso:

* la copia **nueva** se apagaba **siempre** (y encima dibujaba un cartel rojo), y
* el jugador se quedaba viendo **la interfaz vieja para siempre**.

O sea: **pegabas los archivos nuevos y no cambiaba nada**. Exactamente lo que reporto
el usuario.

**Arreglado**: la copia que gana se decide por **RONDA** (el latido solo apaga a la
mas vieja). Si al llegar ahi todavia hay una interfaz, es basura guardada: **se borra
y se sigue dibujando la nueva**.

## 2. 👻 La columna del HUD nunca aparecia

```lua
local mini = frame(gui, { ..., Visible = false })   -- nace oculta
...
local function setHud(expanded)
    hud.Visible = false      -- esconde la barra ancha  (esto si pasaba)
    -- FALTA: mini.Visible = true    <-- NADIE la encendia
end
```

La barra ancha se escondia bien… y en su lugar **no aparecia nada**. Ahora
`setHud` pone `mini.Visible = true`. (Esto tambien explica por que el usuario veia
el tablero viejo: el suyo no dibujaba absolutamente nada.)

## 3. 🧹 El barrido ahora caza los nombres renombrados

El barrido de interfaces comparaba el nombre **exacto** (`"SpiceEmpireUI"`) y Roblox
renombra sola los repetidos a **`SpiceEmpireUI2`**. Ahora compara por **prefijo**
(`"SpiceEmpire"`), asi que tambien borra esas. Y ademas: si aparece una interfaz de
otra copia **en cualquier momento**, se borra al instante (`PlayerGui.ChildAdded`).

## 4. 🏷️ La ronda se ve en la esquina

Junto al reloj ahora sale la ronda de la interfaz que estas viendo:

```
14:32  SOL  v37
```

Sirve justo para lo de esta semana: desde una captura ya se sabe si el codigo
dibujando es el nuevo o una copia vieja. **Si no dice `v37`, el archivo que estas
viendo NO es el de esta ronda.**

## 5. 🗑️ El servidor tambien reporta la basura guardada

El **INVENTARIO** ahora revisa `StarterGui` y avisa:

```
[SpiceEmpire]  BASURA StarterGui > SpiceEmpireUI   <- interfaz guardada en el lugar, borrala
```

## 6. 🐛 Tres defectos MAS del simulador (que escondian estos bugs)

| Defecto | Que escondia |
|---|---|
| `IsA("GuiObject")` comparaba el nombre **exacto** (siempre daba falso) | ninguna prueba verificaba de verdad que las filas del HUD se mostraran |
| `LayoutOrder` valia `nil` (en Roblox nace en **0**) | el codigo `c.LayoutOrder >= 2` tronaba en el simulador, pero no en Roblox: o sea que ahi se probaba **otro** codigo |
| sin valores por defecto de GUI (`Visible`, `Text`, `Enabled`…) | el "que se ve en pantalla" no se podia comprobar |

Ahora el simulador imita a Roblox. **Con eso, la prueba nueva reproduce el caso del
usuario**: interfaz vieja guardada + nombre renombrado -> exige que el cliente
**llegue al final**, que quede **1 sola** interfaz y que su contenido este **visible**.

Probado devolviendo el comportamiento viejo (`return`): **falla**.

---

## 📦 Los archivos de esta ronda

| # | Archivo | Donde va | Tipo |
|---|---|---|---|
| 0 | **limpiar.luau** | Pestana `View` > boton `Command Bar` (NO va en el juego) | pegar y Enter |
| 1 | GameConfig | ReplicatedStorage > GameConfig | ModuleScript |
| 2 | CityGenerator | ServerScriptService > CityGenerator | ModuleScript |
| 3 | DataService | ServerScriptService > DataService | ModuleScript |
| 4 | Main | ServerScriptService > Main | Script |
| 5 | ClientUI | StarterPlayer > StarterPlayerScripts > ClientUI | LocalScript |

> **Como saber si quedo bien**: dale Play y mira la esquina de arriba a la derecha.
> Si dice **`v37`**, estas corriendo la ronda nueva. Si no lo dice, ese archivo no se
> pego (o hay otra copia).
