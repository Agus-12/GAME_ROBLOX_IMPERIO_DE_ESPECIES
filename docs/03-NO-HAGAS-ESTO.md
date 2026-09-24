# 🚫 No hagas esto — callejones sin salida

> Cada entrada aquí costó al menos una ronda de trabajo. **Léelo antes de tocar código.**

---

## 1. 🚲 La bici: NO uses física. Punto.

Este fue el bug más caro del proyecto — **cuatro intentos fallidos**.

| Versión | Enfoque | Cómo falló |
|---|---|---|
| v10 | `HingeConstraint` con motor en las ruedas | Temblaba y se retorcía |
| v12 | Chasis con colisión + `LinearVelocity` (modo Vector) | **Trepaba edificios** |
| v14 | `LinearVelocity` modo Plane + raycast antiparedes | **Se elevaba sola** |
| v16 | `CanCollide = false`, CFrame a mano, pero **sin anclar** | **Lanzaba al jugador al cielo** |
| **v17** | **Todo anclado + CFrame a mano** | ✅ (sin confirmar por el usuario) |

### La causa raíz

Mientras la bici sea un **cuerpo físico**, el solver de Roblox tiene una vía para
moverla, y va a usarla:

- Si le fijas la velocidad horizontal con fuerza alta y la empujas contra una pared,
  la única salida que le queda al solver es **hacia arriba** → trepa edificios.
- Si le fijas la velocidad vertical, **pelea contra la gravedad** → flota.
- Si le escribes el CFrame cada frame mientras sigue siendo física, tus escrituras y
  el solver **se pelean** → energía acumulada → sale disparada.
- Y aunque le quites la colisión a la bici, **el jugador sentido encima sí colisiona**,
  y va soldado a ella. Por ahí se cuela la física otra vez. (Esto fue la v16.)

### Lo que sí funciona (v17)

- **Todas** las partes con `Anchored = true`, incluido el chasis
- `CanCollide = false` en todo
- Se guarda el offset de cada pieza respecto al chasis (`spawnCF:ToObjectSpace(...)`)
  y se reacomodan a mano cada Heartbeat
- Movimiento por raycast: uno adelante (paredes), uno abajo (piso)
- Límite de escalón `MAX_STEP = 1.6` — banquetas sí, paredes no
- Gravedad propia (`GRAVITY = 70`) cuando no hay piso debajo

Una parte anclada es **intocable** para el motor de física. Es el mismo patrón que usan
las plataformas móviles y las ruedas de la feria, y **sí arrastra al jugador sentado**.

> ❌ No "mejores" esto volviendo a meter constraints. Ya se intentó cuatro veces.

---

## 2. 💡 Iluminación

### `Lighting.Ambient` ilumina los INTERIORES

Esta confusión hizo que la bodega se viera blanca durante varias rondas.

| Propiedad | A qué le pega |
|---|---|
| `OutdoorAmbient` | Solo a lo que **ve el cielo** |
| `Ambient` | A **TODO**, incluso dentro de cuartos cerrados con techo |

El ciclo día/noche subía `Ambient` de día → la luz atravesaba el techo de la bodega y
se comía el efecto de los neones. **Solución (v14):** `Ambient` queda **fijo**
(`INTERIOR_AMBIENT`, en CityGenerator) las 24 horas, y el día/noche se maneja solo con
`Brightness` y `OutdoorAmbient`.

### Demasiados PointLights se SUMAN

La bodega quedó quemada con ~20 luces de Range 26–40 y Brightness 2–3.2.
El culpable real resultó ser las lámparas del techo: **Brightness 2.2 con Range 60**,
tres de ellas en un cuarto de 70 studs de ancho.

**El `Range` importa más que el `Brightness`.** Bajar el alcance evita que se encimen.
Valores actuales que se ven bien: techo 0.85/26, UV 0.45/9, prensa 0.9/16,
zona segura 0.9/16, escritorio 0.9/14, gate lamps 1.1/18, RipeLight 1.1/7.

### `Lighting.Technology` ya no existe

Fue reemplazada por **`LightingStyle`** (Unified Lighting):
Future→**Realistic**, ShadowMap→Soft con sombras, Voxel→Soft sin sombras.

Es **solo lectura desde scripts** → es un paso manual del usuario.
Si no le aparece la propiedad: File → Beta Features → activar "Unified Lighting".
Si el juego se ve distinto que en Studio: Studio Settings → Rendering → Graphics Mode →
**Direct3D11** (OpenGL lo rompe).

---

## 3. ⚙️ Trampas de la API de Roblox

### `WeldConstraint` + cambiar el `CFrame` cada frame = no se mueve

Si le vas a escribir el CFrame a una parte cada frame, **no sueldes** cosas a ella
esperando que la sigan. Usa `Anchored = true` y reposiciona cada pieza a mano.

Esto mordió dos veces: en las `GateRib` del portón (el tween de la puerta no arrastraba
las costillas) y en la bici.

### `PivotTo` con `CFrame.new(pos) * CFrame.Angles(...)` destruye la orientación

Usa `CFrame.lookAt(pos, pos + dir) * CFrame.Angles(0, 0, tilt)`.

### No confíes en `Model.PrimaryPart` justo después de construir un rig

Usa la posición calculada + `pcall`.

### La animación idle oficial sobreescribe poses de Motor6D

`rbxassetid://180435571`. **No la cargues** en NPCs con pose custom (el vigilante).

### Los cilindros ya traen el eje en X

Las caras redondas de un `Enum.PartType.Cylinder` apuntan a ±X. Para una llanta de bici
**no hay que rotarlo**. Un `CFrame.Angles(0, 0, math.rad(90))` de más las deja acostadas
como platos (bug de la v13).

### Billboards cercanos se encinan

Usa alturas distintas y `AlwaysOnTop = false`. Actuales: PRENSA 11, ZONA SEGURA 8,
MEJORAS 3.

---

## 4. 🧪 Sobre la validación

### El parser `luaparser` de Python: descartado

Daba falsos positivos con las anotaciones de tipo de Luau. Se usa `tools/check.py`, que
traduce a Lua 5.4 y compila con `luac5.4` de verdad.

### Contar `end` con grep o regex: NO FUNCIONA

Se intentó. No lo vuelvas a intentar. Usa `tools/check.py`.

### `tools/check.py` tiene falsos positivos conocidos

Antes de "arreglar" un error que reporte, **verifica si el error es del traductor**.
Ya están parcheados estos cuatro:

| Hueco | Síntoma | Parche |
|---|---|---|
| `continue` → `goto cont` sin `::cont::` | Main siempre reporta `(continue)` | Se ignora ese mensaje |
| `+=` `-=` `*=` se tragaban el `end` | `if x then a += b end` rompía | Lookahead `TAIL` |
| `?` suelto tras `props: {[string]: any}?` | Error de sintaxis falso | Regex extra |
| Tipos-función `cb: () -> ()` en params | Rompía la regex de parámetros | Se strippean antes |

### El mock necesita cosas a mano

`tools/mock.lua` implementa `math.clamp`, `math.round`, el global `Enum`, `Vector3.Lerp`,
`CFrame.ToObjectSpace` e `Inverse`. Si agregas código que use una API de Roblox que el
mock no tiene, **agrégala al mock** — si no, vas a ver un "ERROR generando la ciudad"
que no es real.

### Escribe el archivo UNA SOLA VEZ

En los scripts de Python que hacen varios reemplazos: verifica **todos** los marcadores
con `assert ... in s` **antes** de escribir. Si escribes a medias y algo falla, dejas el
archivo corrupto.

### Bug recurrente de orden de definición en Main.luau

Patrón usado: `local nombre` arriba, `function nombre(...)` abajo.
**Siempre haz `grep -n` después de agregar una función** para confirmar que quedó
declarada antes de su primer uso.

---

## 4.1 🖼️ Trampas de la UI (aprendidas en v20)

### `renderTab` tiene que borrar TODO, no solo los `Frame`

El código original hacía `if c:IsA("Frame") then c:Destroy() end`. Los `TextLabel`
sueltos **nunca se borraban** y se apilaban en todas las pestañas de la tienda.
Ahora usa `IsA("GuiObject")` (el `UIListLayout` no es GuiObject, así que sobrevive).

> Si agregas un elemento a una pestaña, comprueba que se destruya al cambiar de pestaña.

### El cliente y el servidor tienen que contar el espacio igual

En v18 el servidor contaba un bloque como **3** de espacio y el cliente como **1**.
El HUD mostraba un número y el servidor rechazaba con otro. Usa siempre
`vaultUsed` (servidor) y la misma fórmula `Leaves + Blocks * 3` en el cliente.

### No leas la posición "de reposo" de algo que estás animando

La prensa guardaba `local top = piston.Position` al momento de prensar. Si prensabas
dos veces seguidas, la segunda leía la posición **ya hundida** y la tomaba como reposo
→ el pistón se enterraba para siempre. Graba la posición de reposo **al construir**
(atributo `HomeY`) y pon un candado (`Pressing`) para que dos animaciones no se encimen.

## 4.2 👷 NPCs

`makeBuyerNPC` le pone el tag `"BuyerNPC"` y los atributos `BuyerId`/`BuyerName` a
**todo** lo que crea. Si lo reutilizas para algo que no es comprador (el vigilante, los
empleados), **quita el tag** o el cliente les sacará el globo de "¿tienes mercancía?".

Las alturas dentro de la bodega, para no dejar NPCs flotando:

| Referencia | Y local | Piso está… |
|---|---|---|
| `Floor` (centro 1, alto 2) | tope en **2** | — |
| `Plot<i>` | 5.7 | 3.7 abajo |
| `PressBase` | 3.1 | 1.1 abajo |

Los NPC se posicionan con el pie en el piso: usa **Y = 2** local.

## 4.3 🔁 Crear rigs CEDE EL HILO

`makeBuyerNPC` (y por tanto `MakeWorker`) **yield**: construir el rig deja correr otras
tareas. Cualquier función que borre-y-recree NPCs tiene que ser **no reentrante**, o dos
llamadas se intercalan y dejan duplicados huérfanos.

`syncWorkers` se llama desde tres lados (entrar, contratar, mejorar bodega). Lleva un
candado `syncingWorkers[player]`; **no lo quites**. Barrer por atributo *antes* de crear
no alcanza — eso ya se intentó en v22 y siguió duplicando.

## 4.4 🌱 Distancias: mide al MUEBLE, no a la pieza

La cosecha medía maceta por maceta con radio 9, pero la mesa mide 12 de ancho: las
macetas del fondo quedaban fuera estando pegado a la mesa. Ahora se busca el `Plot<i>`
más cercano y se cosechan todas las plantas con ese `PlotIndex`.

> Regla general: para interactuar con un mueble, mide al **centro del mueble** y opera
> sobre todo lo que le pertenece, no pieza por pieza.

## 4.5 ✂️ Cuidado al reemplazar secciones grandes de CityGenerator

Al reescribir la sección "ZONA SEGURA" en v25 se borró sin querer **toda la caja fuerte**,
que en v18 se había insertado entre esa sección y las lámparas de techo. Después de un
reemplazo por rangos, **verifica con grep que siguen existiendo las partes clave**
(`VaultBody`, `PressBase`, `UpgradeScreen`, `Plot1`…).

## 4.6 🔴 `Workspace` NO EXISTE en Roblox

El global es **`workspace`** en minúscula (o `game.Workspace`). Escribir `Workspace` da
`nil`, y `nil:FindFirstChild(...)` truena.

Esto rompió el sistema contextual completo durante 4 versiones (v22–v26) **sin dar la
cara**: el código estaba dentro de un `pcall`, así que fallaba en silencio cada 0.3 s y el
síntoma era "no aparece ningún botón y no se abren los paneles".

> Corre `python3 tools/globals.py` (va incluido en `tools/validate.sh`) para cazar esto.
> Mismo caso con constantes mal escritas: `BG1` no existía (era `BG`), y como Lua descarta
> las claves con valor `nil`, ni siquiera daba error — solo salía el color equivocado.

## 5. 📄 Formato de los changelogs

**NO pegues el código completo de los scripts dentro de los `CAMBIOS-*.md`.**
Se probó en la v6 y quedó ilegible (147 KB de markdown).
Usa links markdown relativos clickeables, estilo v7 en adelante.

---

## 6. ❌ Descartado definitivamente

- **Tema de drogas ilícitas** — viola el reglamento de Roblox. Ya se acordó el reskin.
- **Proyecto Rojo** — el usuario no sabe usarlo.
- **Bisagras físicas para la bici** — ver §1.

---

## 5. 🔇 El patrón más caro del proyecto: el error que se traga el `pcall`

Tres bugs distintos de este proyecto fueron **la misma cosa**:

| Ronda | Síntoma del usuario | Causa |
|---|---|---|
| v22–v26 | "Ningún botón contextual sale nunca" | `Workspace` (con mayúscula) es `nil`; el bucle de cercanía corría dentro de un `pcall` → moría en silencio cada 0.3 s |
| v28 | "La computadora no me abre / sale en blanco" | `T.StorageBonus` ya no existía en la config: `string.format("%d", nil)` revienta; estaba dentro de un `pcall` |
| v28 | "No me deja hacer nada" | `WaitForChild` sin timeout esperando un remote que se creaba 1745 líneas después |

**Reglas que salen de esto:**

1. **Un campo que no existe en la config no truena al compilar**: vale `nil`. Si ese
   `nil` entra en `string.format`, en una suma o en un índice, revienta **en tiempo de
   ejecución**. Corre `tools/fields.py`.
2. **Si metes un bloque nuevo dentro de un `pcall`, deja rastro.** El `pcall` está bien
   para no tirar el servidor, pero el error hay que **imprimirlo** (`warn`), no tragarlo.
3. **Nada de `WaitForChild` sin timeout** para dependencias críticas: un script que no
   se pegó debe dar un mensaje claro, no una pantalla muerta. Ya está resuelto en
   `ClientUI` (cartel rojo + lista) y en `Main`/`DataService` (`need()` con `error`).
4. **Los remotes se crean todos al arranque del servidor**, en un solo bloque, antes de
   cualquier código que pueda fallar. El cliente espera máximo 10 s y avisa.

---

## 6. 🧱 Anécdotas de geometría (v28)

1. **Existir no es poder llegar.** El garaje de la v26 tenía piso, 4 cajones, lámparas,
   letrero y los autos estacionados… y **cero puertas**: la pared izquierda se construía
   de una sola pieza. Cualquier validación de "¿existe la parte?" pasa feliz. Por eso
   ahora existe `tools/walk.py` (flood fill con el cuerpo del jugador).
2. **Una bodega no mide lo que dice su `Size`.** El nivel 4 mide 190 de ancho, pero con
   el taller (46) y la oficina (34) pegados por fuera son **271**. Con las bodegas
   sembradas cada 140 studs, tu oficina caía dentro del taller del vecino. Si agregas un
   anexo, **actualiza `GameConfig.WarehouseLots.SpacingX`**.
3. **Los anexos necesitan saber dónde van ANTES de construir la pared.** El hueco de la
   puerta se calcula arriba, en las constantes del anexo (`GAR_Z`, `OFF_CZ`…), y la
   pared se construye en tramos con ese dato. Si mueves el anexo, mueve también el hueco
   (o el cuarto queda sellado otra vez).
4. **Un radio fijo no cuadra con una caja.** La zona segura usaba "14 studs de radio"
   sobre un tapete de 28×11: las esquinas del tapete **no** eran seguras aunque se
   vieran dentro. Cuando el área tiene forma, mide contra su tamaño (`safe.Size`), no
   contra un radio inventado.
5. **El piso de la bodega está a 2 studs y la calle a 0.2.** Sin rampa, la bici
   (`MAX_STEP = 1.6`) se atora en el portón. Ya hay `GateApron`.
