# Cambios de la ronda v35

> Resumen: el juego **te dice la direccion exacta** de las copias (INVENTARIO con rutas) y,
> si hay dos `ClientUI` corriendo, **la que sobra se apaga sola**. Se acabo el cartel
> confuso que no decia de quien era el problema.

---

## 🔍 Lo que pasaba en tu Studio (con la captura se ve claro)

```
ARCHIVOS VIEJOS EN STUDIO -- esta ronda es v32     <-- EL QUE AVISA ES VIEJO
 - el Main.luau del servidor dice 'v34'            <-- tu Main esta BIEN
 - GameConfig dice 'v34'                           <-- tu GameConfig esta BIEN
 - 2 carpetas Remotes ('Remotes' + 'Remotes2')
```

Ese cartel lo estaba mostrando **una `ClientUI` VIEJA (v32)** que todavia estaba
corriendo en el lugar. Tenias razon: **no hay dos `Main`**. Lo que hay es **mas de una
`ClientUI`**: la ronda nueva quedo pegada, pero una copia v32 seguia ejecutandose (en
`StarterGui`, o como `ClientUI2`) y era ella la que "se quejaba". Y como era vieja,
tambien decia cosas de la version vieja ("eso significa que hay 2 Scripts Main pegados"),
que ya no son ciertas en la ronda nueva.

---

## 🧾 1. INVENTARIO DE ARCHIVOS: ahora sale la direccion exacta

El servidor recorre todo el lugar al arrancar (y a los 5 s) e imprime esto en el Output:

```
[SpiceEmpire] ==== INVENTARIO DE ARCHIVOS DEL JUEGO (v35, al arrancar) ====
[SpiceEmpire]  OK     ServerScriptService > Main
[SpiceEmpire]  OK     ServerScriptService > CityGenerator
[SpiceEmpire]  OK     ServerScriptService > DataService
[SpiceEmpire]  OK     ReplicatedStorage > GameConfig
[SpiceEmpire]  OK     StarterPlayer > StarterPlayerScripts > ClientUI
[SpiceEmpire]  COPIA  StarterGui > ClientUI   <- borra esta (clic derecho > Delete)
[SpiceEmpire]  CARP.  ReplicatedStorage > Remotes   (la del juego)
[SpiceEmpire] ==== 1 archivo(s) de mas: borralos en el Explorer (...) ====
```

Ya no hay que adivinar: **sale la ruta completa** de cada copia y de cada archivo que
falte. Vigila los 5 nombres (`Main`, `CityGenerator`, `DataService`, `GameConfig`,
`ClientUI`, contando los numerados tipo `Main2`) y las carpetas `Remotes*`.

---

## 🤐 2. Dos `ClientUI` = la copia se apaga sola

Cada copia deja un "latido" con su version en el `PlayerGui`. Si al arrancar ve el latido
de **otra copia igual o mas nueva**, esta se apaga sola y avisa:

```
[SpiceEmpire] *** HAY OTRA ClientUI CORRIENDO (v35) *** esta copia (v35) se apaga sola para que no salga todo doble.
[SpiceEmpire] En el Explorer tiene que quedar UNA sola ClientUI, dentro de StarterPlayer > StarterPlayerScripts...
```

Asi no vuelven a salir **dos HUD** ni carteles de una copia vieja confundiendo el
diagnostico.

---

## 😬 3. El cartel ahora se delata

Si el servidor esta al dia y el que se queda atras es **este** archivo, el cartel lo dice
de frente:

```
*** ESTA ClientUI ES LA VIEJA: el servidor ya es v35 y esta copia dice v32 ***
Hay MAS DE UNA ClientUI pegada. Deja UNA sola, en StarterPlayer > StarterPlayerScripts,
y borra las demas.
```

---

## ✅ 4. Validacion

`tools/copias.py` ahora tiene **7 escenarios**. El nuevo:

| Escenario | Que prueba |
|---|---|
| 7. dos `ClientUI` corriendo | el juego sale **una sola vez** (1 "UI cargada") y la copia avisa que se apago |

Probado quitando el vigilante a proposito: **el escenario 7 falla**. Tambien se arreglo el
simulador, que **no tenia `game:GetDescendants()`** (el juego real si), asi que el
inventario salia vacio en las pruebas (falso verde). Ahora el simulador si recorre el lugar.

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

> Lo importante de esta ronda: **debe quedar UNA sola `ClientUI`** y tiene que estar en
> `StarterPlayer > StarterPlayerScripts` (no en `StarterGui`).

---

## 🐛 Correccion (mismo dia): la pestaña del ClientUI mostraba la pantalla en blanco

El usuario reporto: *"el ClientUI, el 5 en el archivo, le pico y no sale nada"*.

**Era un bug de la pagina de copiar (mio), no del juego.** El cambio de pestaña tenia el
numero de paneles **escrito a mano**:

```js
for (var k=0;k<5;k++){    // MAL: son 6 pestanas desde que se agrego el PASO 0
```

Al picarle a la **pestaña 5 (ClientUI)**, el bucle ocultaba las otras cinco y **nunca
mostraba la sexta**: pantalla en blanco, sin ningun error. Por eso el ClientUI del usuario
se quedo viejo (v32) y era el que le salia con el cartel.

**Arreglado**: ahora el numero de paneles se **cuenta solo**
(`document.querySelectorAll('.panel').length`), y la herramienta **se verifica al
generarse**: si las pestañas, los paneles y los botones de copiar no cuadran, `pegar.py`
falla en vez de entregar una pagina rota.

**Y hay prueba real** (etapa 13 del validador): `tools/pestanas.js` corre el JavaScript de
la pagina TAL CUAL sobre un DOM de mentiras y **da clic en cada pestaña**, comprobando que
se vea solo su panel. Con la pagina vieja **falla** ("al picar la pestaña 5: el panel 5
quedo oculto", justo lo que le paso al usuario); con la nueva pasa.
