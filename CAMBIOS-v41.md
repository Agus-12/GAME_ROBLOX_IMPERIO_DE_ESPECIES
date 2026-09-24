# Cambios de la ronda v41

> ## 🎯 ESTA ES LA RONDA QUE ARREGLA EL PROBLEMA DE FONDO
>
> **El bug:** el cliente hacia `Instance.new("AutomaticSize")` y **`AutomaticSize` no es
> una clase de Roblox** (es una *propiedad*). En Studio eso **truena ahí mismo**: la barra
> ancha ya estaba dibujada y el script **moría antes de esconderla**. Por eso el juego
> "seguía igual" aunque pegaras todo: **la interfaz nueva nunca se terminaba de dibujar**.
>
> **Y por eso el simulador no lo veía:** aceptaba cualquier nombre de clase inventado
> (decía "AutomaticSize" y creaba un objeto como si nada). Desde esta ronda, el
> simulador **truena igual que Studio** y hay un chequeo nuevo que lo caza antes de
> entregarte nada.

---

## 1. 🔎 Cómo se encontró (por que costo tantas rondas)

La captura del usuario fue la clave: arriba al centro se leía **`RONDA v41 (arrancando...)`**
(sin el `OK` final). Eso solo puede pasar de una manera: **el archivo nuevo SI corre, pero
se muere a medio camino**. Y como la barra ancha se alcanza a ver y la columna no, el
error estaba justo **entre** las dos (crear la barra ancha y mostrar la columna).

En ese tramo estaba:

```lua
local colSize = Instance.new("AutomaticSize")   -- MAL: AutomaticSize no es una clase
colSize.Parent = mini
```

Lo correcto es una **propiedad** del panel:

```lua
mini.AutomaticSize = Enum.AutomaticSize.Y       -- BIEN: el panel crece solo
```

## 2. 🧪 Por que el simulador no lo cazaba (y ahora si)

| Antes | Ahora |
|---|---|
| `Instance.new("lo-que-sea")` creaba un objeto sin chistar. Cualquier clase inventada pasaba las pruebas. | Se compara contra la **lista real de clases de Roblox** (920, sacada del API-Dump oficial): si no está, **truena igual que Studio**. |
| No existía ningún chequeo de esto. | **`tools/clases.py`** revisa los 6 archivos y **falla** si algún `Instance.new` usa un nombre inventado (y avisa si es un error de mayúsculas, tipo `Textlabel` en vez de `TextLabel`). |
| — | Es la **etapa 13** de `tools/validate.sh` (ahora 14 etapas) y el **escenario 15** de `tools/copias.py`. |

**Probado al revés**: se volvió a meter el bug y tanto el chequeo como el simulador lo
cazaron (antes: los dos lo dejaban pasar).

## 3. 🐛 Y un error mio de camino (que se cazo a tiempo)

Al escribir la validación en el simulador, puse la lista de clases **después** de la
función que la usa. En Lua eso la vuelve un *global* (que vale `nil`) y la validación
quedaba apagada sin avisar: parecía que funcionaba, pero no cazaba nada. Ya está en su
lugar (antes de la función) y probado.

## 4. ✅ Que deberias ver ahora

1. La placa dice **`RONDA v41  OK`** (con el `OK` — antes se quedaba en "arrancando...").
2. La columna **vertical a la izquierda**: `$0`, hojas, bloques, mochila, caja, heat.
3. **Sin** la barra ancha vieja.
4. El reloj arriba a la derecha y el letrerito `v41`.

---

## 📦 Los archivos de esta ronda

| # | Archivo | Donde va | Tipo |
|---|---|---|---|
| 0 | **limpiar.luau** | Pestana `View` > boton `Command Bar` (NO va en el juego) | pegar y Enter |
| 1 | GameConfig | ReplicatedStorage > GameConfig | ModuleScript |
| 2 | CityGenerator | ServerScriptService > CityGenerator | ModuleScript |
| 3 | DataService | ServerScriptService > DataService | ModuleScript |
| 4 | Main | ServerScriptService > Main | Script |
| 5 | ClientUI | StarterPlayer > StarterPlayerScripts > ClientUI | **LocalScript** |

> **La prueba de 10 segundos**: Play. Arriba al centro tiene que decir **`RONDA v41  OK`**.
> Si dice solo `(arrancando...)`, todavia truena algo: mandame esa captura.
