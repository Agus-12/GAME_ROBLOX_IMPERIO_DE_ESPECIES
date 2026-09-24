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

---

## 7. 🪟 "Ponlo encima" casi nunca es "hazlo de verdad" (v29)

El usuario dijo de la ventana de la oficina: *"solo se ve como que está sobre la pared, se
ve raro"*. Y tenía razón: era **un vidrio pegado encima del muro**, sin hueco.

**Lo importante no fue cambiar el vidrio: fue abrir el hueco.** Si solo hubiera cambiado
el color o el material, se hubiera visto exactamente igual de raro. Para que sea una
ventana de verdad hay que:

1. construir el muro **en tramos** (antepecho abajo, dintel arriba, pilares a los lados),
2. meter **marco + travesaños + repisa** en el hueco,
3. y recién entonces el vidrio.

**Regla:** cuando el usuario dice "se ve raro/pegado/de mentiras", la solución casi nunca
es un adorno nuevo: es **reconstruir la geometría** para que la pieza exista de verdad.

---

## 8. 🚗 Un detalle que vale doble: reusar el mismo constructor (v29)

Los carros estaban "de mentiras" (un ladrillo con 4 bolas) **y encima había DOS
constructores distintos**: uno para el auto que manejas (`Main.spawnVehicle`) y otro para
el estacionado (`Main.buildParkedCar`). Arreglar uno solo hubiera dejado la mitad del
problema.

**Regla:** si dos cosas se ven iguales para el jugador, **una sola función las construye**
(`CityGenerator.BuildCar(info, cf, parked)`). Menos código, imposible que se
desincronicen, y el día que quieras un carro nuevo lo agregas en un solo lugar
(`CAR_SPEC`).

---

## 9. ⏳ Nada de "espera al servidor" en la pantalla de entrada (v30)

La portada esperaba `State.Cash > 0` **del servidor**, con respaldo de
**30 intentos × 0.4 s = 12 segundos**. El usuario se quedó atorado en *"Cargando la
ciudad..."* — y el servidor estaba perfecto (la ciudad se arma en **0.2 s**).

**Regla:** una pantalla de entrada se abre con **información LOCAL** (¿ya hay ciudad?
¿ya tengo personaje?), nunca con un viaje de ida y vuelta al servidor. El estado
(dinero, hojas) se pide **después y sin bloquear**, y siempre tiene que haber:

1. un **tope corto** (≤3 s) que abra pase lo que pase,
2. una salida manual (**tocar la pantalla**),
3. y un tope contado por **revoluciones**, no con `os.clock()` (si usas reloj real,
   la prueba no lo puede medir y el validador vuelve a mentir).

---

## 10. 🧪 Un mock que "no hace nada" también es un mock que miente (v30)

`tools/mock.lua` tenía `task.spawn = function() end` y `task.wait = function() end`. O
sea: **la mitad del juego (todo lo que corre en hilos) nunca se probaba**, y cualquier
"espera de N segundos" pasaba al instante. Por eso el bug de los 12 segundos daba verde.

Hoy el mock trae **corrutinas con reloj virtual** (`task.__sched.advance(n)`) y los tests
**avanzan el reloj**, así que los bucles de fondo sí corren. Al encenderlo aparecieron de
inmediato dos huecos (`Lighting.ClockTime` y `InputBegan`) que estaban escondiendo código
roto.

**Regla:** si una herramienta no ejecuta el código, no lo está probando. Y `function() end`
en un stub es una **mentira silenciosa**: mejor que truene (así se descubre y se tapa) a
que diga "todo bien".

---

## 11. 🚫 Un `OnServerInvoke` que espera deja al cliente colgado PARA SIEMPRE (v31)

`Main` cargaba el perfil dentro del handler de `sync`:

```lua
if not DataService.Get(player) then
    setupPlayer(player)          -- llama store:GetAsync
end
```

Si esa espera se alarga (DataStores lentos o apagados en Studio), el
`RF_Action:InvokeServer("sync")` del cliente **no regresa nunca**. Del otro lado no hay
timeout: la pantalla de entrada se queda en *"Cargando la ciudad..."* para siempre y el
jugador **no puede entrar**.

**Regla:** los handlers de `RemoteFunction` responden **siempre** y rápido. Cualquier cosa
lenta (DataStore, generación, espera de instancias) va en `task.spawn` y se responde con
`{ok = false, msg = "cargando"}` — el cliente reintenta y sigue vivo.

---

## 12. 🧱 El código crítico va ARRIBA (v31)

El abridor de la portada vivía al **final** de `ClientUI` (~1900 de 2200 líneas). Un error
en cualquier parte de en medio (un panel, el HUD, un dato raro) detenía el script y el
botón **nunca aparecía** — sin ningún mensaje, porque el error es de otra parte.

**Regla:** en un script largo, **lo que el jugador necesita para entrar va primero**
(portada, botón, entrada, resolución de pantalla). Lo demás, después. Y si algo puede
fallar, **envuelve ese bloque aparte** en vez de dejarlo tumbado todo lo de abajo.

*Prueba permanente:* `tools/intro.py` escenario E inyecta `error('falla simulada')` justo
después del bloque de la portada y exige que el botón **siga saliendo**.

---

## 13. 🗑️ Borrar dentro del bucle deja basura (v32)

```lua
for _, c in ipairs(ReplicatedStorage:GetChildren()) do
    c:Destroy()      -- MAL
end
```

Al borrar el hijo 1, la lista se encoge y `ipairs` salta al índice 2 — que ahora es el que
era el 3. **Siempre queda uno vivo.** Con **dos** carpetas `Remotes` viejas solo se borraba
una → el cliente se enganchaba a la que sobraba y decía *"faltan remotes"*. Y en Studio es
facilísimo tener dos (un `Main` viejo pegando).

El mismo patrón estaba en `syncWorkers` (empleados encimados en la mesa), `syncGarage`
(autos encimados en el cajón), `renderTab` de la tienda (filas viejas pegadas) y la limpieza
de efectos de iluminación.

**Regla:** junta en una lista y borra **después** del bucle. Lo vigila la **etapa 11**
(`tools/loops.py`), que está probada inyectando el bug.

---

## 14. 🫥 Usar una variable ANTES de declararla (y no tronar nunca)

En la v41, el cliente quedo asi:

```lua
local function carpetaRemotes()
    ...
    if tostring(todas[1]:GetAttribute("Build") or "") == MI_VERSION then  -- <- MI_VERSION todavia NO existe aqui
        copiasLeves = true
    end
end

local MI_VERSION = "v41"    -- se declara 60 lineas mas abajo
```

En Lua, leer un nombre que todavia no es local **no truena**: lee un **global que
vale nil**. Entonces la comparacion era `"v41" == nil` -> siempre falso, el avisito
no salia nunca, y en la consola no habia ni un error. Un bug invisible.

**Regla:** lo que usan las funciones de arriba se declara **arriba**. Y el
validador lo revisa: `tools/globals.py` (etapa 4) lista los nombres que el script
toca como globales; si sale uno que deberia ser local, ahi esta el bug.

---

## 15. 🧟 Guardar el objeto del remote en vez de un intermediario (v41)

```lua
-- MAL: te quedas con el objeto. Si el servidor borra esa carpeta (limpieza,
-- otro Main, un remoto reemplazado), tu variable apunta a un remote MUERTO.
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RE_Shoot = Remotes:WaitForChild("Shoot")
RE_Shoot.OnClientEvent:Connect(...)     -- nunca vuelve a dispararse
```

Sintoma: **los botones no hacen nada y en la consola no sale ni un error**. Es lo
peor de depurar, porque no hay rastro.

El caso real (v41): el cliente arranca **antes** de que el servidor termine de limpiar.
Si en el lugar habia una carpeta `Remotes` vieja guardada, el cliente se enganchaba a
esa; el servidor la borraba 0.3 s despues y el jugador se quedaba con remotes muertos.

**Regla:** guarda un **intermediario** que se pueda re-apuntar y que resuelva
`FireServer`/`InvokeServer` en el momento de la llamada. En este proyecto es
`crearProxy()` en `ClientUI.luau`, y se re-apunta a los 1.5 s y a los 4.5 s.

**Y la prueba:** `tools/copias.py` escenario 6 monta la carrera a proposito (el servidor
crea su carpeta 0.6 s despues) y **cuenta las conexiones por carpeta**. No basta con que
"no salga un error": hay que ver que los remotes esten vivos (`Remotes#true=10`) y que la
vieja quede desconectada (`Remotes#false=0`).

---

## 16. 🔢 Escribir a mano "cuantos hay" (la pestaña que se quedo en blanco, v41)

```js
for (var k = 0; k < 5; k++) {        // MAL: cuantos paneles hay, escrito a mano
  document.getElementById('panel-' + k).className = ...;
}
```

Al agregarle un panel nuevo (el PASO 0 del limpiador) quedaron **6**. El bucle seguia
recorriendo 5: al picarle a la ultima pestaña, **ocultaba las otras cinco y nunca mostraba
la sexta**. Pantalla en blanco, sin ningun error. El usuario no pudo copiar el `ClientUI`
y ese archivo se le quedo de una ronda vieja durante varias rondas — y encima le salia
con un cartel que culpaba a otro archivo.

**Regla:** lo que se puede **contar**, no se escribe a mano
(`document.querySelectorAll('.panel').length`). Y si la pagina es una herramienta que el
usuario usa para instalar, **se prueba de verdad**: `tools/pestanas.js` (etapa 13) corre el
JavaScript de la pagina y **da clic en cada pestaña**.

---

## 17. 📦 Pasarse de 200 variables locales (v41)

Luau (y Roblox) permiten **200 variables locales por funcion**, y **el nivel de arriba de
un script cuenta como una funcion**. `ClientUI.luau` andaba en **185**: al agregar un
bloque nuevo con 6 locals mas, el script **dejaba de compilar**:

```
too many local variables (limit is 200) in main function
```

Lo peor: eso **no se nota hasta que el script corre**.

**Reglas:** los bloques nuevos van dentro de **`do ... end`** (ahí sus locales se
sueltan al salir); `tools/check.py` **avisa a partir de 170** y **falla a partir de 190**;
y si hace falta mas espacio, junta los elementos de UI en **una tabla** (`UI.cash`) en vez
de una variable por elemento. Los simuladores encierran el codigo del cliente en su propia
funcion antes de agregarle instrumentacion, para no gastar los locales del guion.

---

## 18. 💀 Apagar la copia NUEVA por algo que puede ser basura (v41)

```lua
if playerGui:FindFirstChild("SpiceEmpireUI") then
    warn("HAY 2 ClientUI PEGADOS")
    return        -- MAL: apaga la interfaz NUEVA
end
```

El razonamiento era "si ya hay interfaz, hay otro script corriendo". **Falso**: tambien
puede ser un `ScreenGui` **guardado dentro del lugar** (`StarterGui`), que Roblox copia a
la pantalla al arrancar. Resultado: la copia nueva se apagaba **siempre** y el jugador se
quedaba con la vieja durante rondas enteras ("le pegue los archivos y no cambio nada").

**Reglas:**

* quien gana se decide por **version** (el latido de la v35): la mas vieja es la que se
  apaga, nunca la nueva;
* lo que parece "otra copia" puede ser **basura guardada**: se borra y se sigue;
* el barrido de interfaces va por **PREFIJO** de nombre (Roblox renombra solos los
  repetidos a `SpiceEmpireUI2`) y tambien escucha `ChildAdded` en el `PlayerGui`, para
  borrar la basura en cuanto aparezca;
* y para no volver a adivinar desde una captura: **la ronda se imprime en pantalla**
  (junto al reloj) y el servidor **reporta las interfaces guardadas en `StarterGui`**.

### Y en el simulador (v41)

`IsA("GuiObject")` comparaba el nombre exacto: **siempre daba falso**, asi que nada
verificaba que las filas del HUD se mostraran de verdad. Y `LayoutOrder` valia `nil`
(cuando en Roblox nace en `0`), asi que el simulador corria **otro** codigo. Ahora el
simulador imita a Roblox (herencia de IsA + valores por defecto de GUI).


---

## 19. 📸 Creer que "no me lo dijo" es suficiente para saber si corrio (v41)

El usuario reporto **cinco rondas seguidas** "sigue igual" y desde afuera no habia
forma de saber **que codigo estaba dibujando la pantalla**: el juego no decia su
version en ningun lado visible, y las pruebas automaticas simulaban el cliente (no la
pantalla real del jugador).

**Lo que faltaba no era un arreglo: era un TESTIGO.** Ahora el juego lo dice el solo:

* **Cliente**: placa `RONDA v41 (arrancando...)` -> `RONDA v41  OK`, y un letrerito
  `v41` que se queda para siempre en pantalla.
* **Servidor**: letrero flotando arriba del spawn con `SERVIDOR v41`.
* **Output**: inventario con la ronda **de cada archivo** (`OK [v41]`, `VIEJO [v32]`...).

**Reglas:**

1. Todo lo que el usuario tenga que verificar **debe verse desde una captura**, sin
   abrir el Output ni creerle a nadie.
2. Un testigo tiene que distinguir **tres** casos: corre y esta completo / corre y
   truena / **no corre**.
3. Los estados se pintan por **nombre** de objeto (`Placa`, `Titulo`), no por
   variables arriba, para no gastar locales (este archivo anda en 183 de 200).
4. El nombre del `ScreenGui` testigo **no** lleva el prefijo del juego, para que
   ningun barrido de copias viejas pueda borrarlo.


---

## 20. 🔎 Reconocer la basura por su NOMBRE (v41)

El barrido de interfaces viejas borraba lo que se llamaba `SpiceEmpire...`. El usuario
reporto que el tablero viejo **seguia ahi** con la version nueva corriendo. Motivo: su
copia vieja se llamaba distinto (o estaba dentro de una carpeta).

**Reglas:**

1. A un objeto que hay que cazar **no se le reconoce por el nombre** (el usuario lo puede
   renombrar, Roblox le pone `2` al final, o vive dentro de una carpeta): se le reconoce
   por **lo que dice o contiene** (aqui: los textos "Hojas", "HEAT", "Espacio").
2. Los barridos van **recursivos** (`GetDescendants`), nunca solo el primer nivel.
3. Ademas de arrancar, se limpia **cuando aparece algo nuevo** (`ChildAdded`): la copia
   vieja puede nacer tarde o renacer en cada respawn.
4. Y siempre se deja **rastro visible**: la placa dice cuantos borro, el Output dice la
   **ruta exacta**, y las pruebas (11 y 12) fallan si la limpieza deja de funcionar.

### En el simulador

* `StarterPlayer` no traia sus carpetas (`StarterPlayerScripts`, `StarterCharacterScripts`):
  los chequeos del servidor sobre la ClientUI no podian probarse. Ahora si.


---

## 21. 🔕 Dejar avisos "pegados" y arreglos que solo corren 3 veces (v41)

Dos errores de diseño de las rondas anteriores, los dos vistos por el usuario:

1. **El aviso se quedaba pegado.** El cliente avisaba "encontre carpetas `Remotes` de
   mas" y, aunque el servidor ya la hubiera borrado un segundo despues, el aviso seguia
   en pantalla. Para el jugador eso se ve igual que "sigue roto". **Si un aviso depende
   de un problema, tiene que desaparecer cuando el problema desaparece.**
2. **Las revisiones por tiempo se quedan cortas.** El servidor revisaba si alguien creaba
   una carpeta `Remotes` a los 0 s, 5 s y 15 s. Una copia vieja que arrancaba **mas
   tarde** (o que creaba su carpeta despues) se salvaba y reaparecia el aviso. **Si hay
   algo que no debe existir, se vigila SIEMPRE** (`ChildAdded`), no tres veces.

**Reglas nuevas:**

* los avisos se quitan solos cuando el problema se resuelve;
* lo que no debe existir se vigila de forma permanente y se limpia al instante;
* y en el simulador los eventos (`Connect`/`Fire`) tienen que ser **de verdad**: si
  `Connect` no llama a nadie, ninguna prueba de "aparece algo despues" es valida
  (era el caso: las senales del simulador eran de mentiritas).


---

## 22. 💀 Instance.new() con una PROPIEDAD en vez de una CLASE (v41)

```lua
local colSize = Instance.new("AutomaticSize")   -- MAL
colSize.Parent = mini
```

`AutomaticSize` **existe en Roblox… como PROPERTY** (una propiedad de los objetos de
interfaz). Como **clase** no existe. O sea que el nombre *parece* valido, no da aviso
ninguno, y en Studio **truena** con:

```
Unable to create an Instance of type "AutomaticSize"
```

Lo que hace este bug tan caro: **truena a media construccion de la interfaz**. La barra
ancha ya estaba dibujada, y el script moria **justo antes** de la linea que la esconde.
Resultado para el jugador: *"pegue todo y sigue igual"*, durante **varias rondas**.

**Reglas:**

1. Para que un panel de interfaz crezca solo: es **propiedad**, no objeto:
   `panel.AutomaticSize = Enum.AutomaticSize.Y`.
2. Todo `Instance.new("X")` tiene que estar en la **lista de clases** (`tools/clases.py`,
   etapa 13 del validate). La lista (`tools/clases-roblox.txt`) sale del API-Dump oficial.
3. **El simulador no puede aceptar cualquier nombre.** Si el simulador "crea" cosas que
   Roblox no tiene, miente con confianza y esconde bugs caros. Ahora truena igual.

### Y el error de orden que me paso escribiendo esto

```lua
function Instance_.new(cls)          -- usa CLASES_VALIDAS...
  if CLASES_VALIDAS and ... then
...
local CLASES_VALIDAS = nil           -- ...pero se declara DESPUES = global nil
```

En Lua, un `local` declarado **despues** de una funcion no existe dentro de ella: la
funcion lee un **global** (que vale `nil`) y la validacion queda **apagada sin avisar**.
Por eso existe `tools/globals.py` (etapa 4) y por eso hay que probar los chequeos
**al reves**: metiendo el bug y viendo si truena.

---

## 23. 🧊 Guardar `Position` y creer que `CFrame` también quedó (v42)

En Roblox, `part.Position` y `part.CFrame` son **la misma cosa**: mover una mueve la otra.
El simulador las tenía **separadas**, así que este código:

```lua
local slab = part({Position = ...})         -- el mock solo guardaba .Position
piece:SetAttribute("HomeCF", piece.CFrame)  -- ...y .CFrame venía NIL
```

guardaba un atributo vacío **sin tronar**, y el portón del garaje no se abría nunca. Peor:
la prueba del garaje **pasaba** porque revisaba que el código corriera, no el resultado.
**Regla:** en el mock, `Position` y `CFrame` se mueven juntos, como en Roblox.

## 24. ⏱️ `os.clock()` era el tiempo de CPU en las pruebas (v42)

El servidor usa `os.clock()` para los enfriamientos ("no repitas el aviso antes de 14 s").
En el simulador eso es el tiempo **de CPU** de Lua (¡casi cero!), no el tiempo que avanza
el reloj virtual: la espera **nunca** se cumplía, y el oficial se quedaba con la primera
línea para siempre. **Regla:** `os.clock()` en el mock devuelve el **reloj de la
simulación** (en Roblox es el tiempo desde que arrancó el servidor).

Y de paso: cuando compares contra "la última vez", el valor inicial va en **`nil`**, no en
`0` (con `0` los avisos no salen en los primeros segundos de partida).

## 25. 🔌 Señales que el mock no tenía, y el `pcall` que escondía el daño (v42)

`ProximityPrompt.Triggered` y `RemoteEvent:FireAllClients` **no existían** en el simulador.
Resultado: los botones (bici, "Sacar y conducir", portones) y los push del servidor
tronaban **dentro de un `pcall`** y quedaban **sin revisar**. Se veía solo como
`!! error en un task.spawn`, sin decir de dónde salía.

**Reglas:** (1) el mock tiene que traer las señales reales; (2) si un `pcall` envuelve un
bucle, el error **se avisa una vez** en el Output (nada de tragarse la falla);
(3) disparar un remoto en las pruebas tiene que **llegar al cliente**, si no el HUD se
prueba a ciegas.

## 26. 🔍 Revisar los COMENTARIOS hace gritar en falso (v42)

`tools/api.py` revisaba `Instance.new("X")` con expresiones regulares sobre el archivo
crudo, así que **un comentario que explicaba el bug viejo** de la v41
(`-- Antes decía: Instance.new("AutomaticSize")`) hacía fallar la validación. Un chequeo
que grita en falso es un chequeo que nadie le cree cuando grita de verdad.
**Regla:** se ignoran comentarios (respetando cadenas de texto) y, al arreglar un chequeo,
se prueba **metiendo el bug de verdad** para ver que todavía lo caza.
