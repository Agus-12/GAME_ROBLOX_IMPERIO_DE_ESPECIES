# 👯 "Sale todo doble" — dos bodegas, dos interfaces, dos avisos

Si ves **una bodega al lado de otra bodega**, **dos barras de botones**, o cosas que
pasan dos veces (dos avisos, dos letreros, el dinero que sube doble), la causa es
**siempre la misma**: en Studio hay **scripts repetidos** (la copia vieja y la nueva).

No es un daño del juego: es que al pegar los archivos quedó el viejo **y** el nuevo.

---

## 🧠 Por qué se ve doble

Cada Script pegado en Studio **es un programa que corre**. Si hay dos `Main`, hay dos
programas haciendo lo mismo:

| Con dos `Main` pasa esto | Por qué |
|---|---|
| **Dos bodegas**, una al lado de otra | Cada `Main` construye la bodega del jugador. Si el viejo es de otra ronda, calcula **otras coordenadas** (antes de la v28 los lotes se sembraban cada 140 studs; ahora es una rejilla de 340), así que la tuya aparece **al lado** de la otra |
| Dos ciudades / dos veces los NPC | Cada uno llama a generar el mapa |
| Dos carpetas `Remotes` | Y entonces el cliente puede engancharse a la **vieja** → *"faltan remotes"* |
| Dos avisos, dos sonidos, dos letreros | Cada `Main` manda los suyos |

Con dos `ClientUI` (LocalScript) pasa lo mismo pero en tu pantalla: **dos interfaces
encima**, con botones y paneles dibujados dos veces.

---

## 🏷️ ¿Cuál de las copias conservo? (sello de ronda, v32)

Los 5 archivos traen **arriba** una línea así:

```lua
-- ===== RONDA: v32 =====
```

Para saber cuál copia es la buena:

1. Abre **cada** copia (por ejemplo los dos `Main`).
2. En la ventana de código: **`Ctrl+F`** y escribe **`RONDA: v32`**.
3. El que **lo tenga** es el nuevo: **quédate con ese** y borra el otro.
4. Si **no** lo tiene, es viejo: bórralo.

> 💡 **Camino más seguro si te da flojera comparar:** borra **las dos** copias y crea una
> nueva: clic derecho en la carpeta → **Insert Object** → el tipo que toca → nómbrala
> exacto → pega el código de `vNN-ARCHIVOS.html`.

## ✅ Cómo se arregla (1 minuto)

En el **Explorer** de Studio, abre estas tres carpetas y cuenta:

| Carpeta | Tiene que haber EXACTAMENTE | Qué borrar si hay más |
|---|---|---|
| `ReplicatedStorage` | 1 `GameConfig` y 1 carpeta `Remotes` | clic derecho en la copia extra → **Delete** |
| `ServerScriptService` | 1 `Main`, 1 `CityGenerator`, 1 `DataService` | idem |
| `StarterPlayer` › `StarterPlayerScripts` | 1 `ClientUI` | idem |

> ⚠️ **Ojo con las copias que Roblox numera solo:** a veces aparecen como
> `Main` y `Main2`, o `ClientUI` y `ClientUI2`. También cuentan como copias.

**La regla de oro:** antes de pegar un archivo nuevo, borra el viejo (o pega **encima**
de él con `Ctrl+A` + `Ctrl+V`), pero **nunca** crees un objeto nuevo con el mismo nombre.

Después de borrar las copias: **Play** y revisa la ventana **Output**
(menú **View › Output**). Tiene que decir:

```
========== IMPERIO DE ESPECIAS v28 ==========
  remotes creados: 11
```

---

## 🛡️ Lo que hace el juego desde la v28 para ayudarte

Estos blindajes son nuevos (antes el juego **no decía nada**: simplemente funcionaba
todo dos veces, que es lo más difícil de diagnosticar):

| Blindaje | Qué hace |
|---|---|
| **Detecta nombres numerados** | `Main2`, `Remotes2`, `ClientUI2`… (Roblox los numera solo) también cuentan como copias |
| **Cuenta las copias al arrancar** | Si hay 2 `Main`, 2 `CityGenerator`, 2 `DataService`, 2 `GameConfig` o 2 carpetas `Remotes`, sale este aviso en el **Output**: *"*** HAY COPIAS PEGADAS EN STUDIO: 2 x ServerScriptService.Main *** Eso hace que TODO salga doble"* |
| **Cartel en pantalla** | Si el cliente encuentra 2 carpetas `Remotes`, el cartel rojo dice *"HAY COPIAS PEGADAS EN STUDIO (todo sale doble)"* |
| **Dos `ClientUI`** | El segundo `ClientUI` se **apaga solo** y avisa: *"HAY 2 ClientUI PEGADOS"* — así no se dibujan dos interfaces encima |
| **Limpia las carpetas `Remotes` viejas** | Al arrancar borra cualquier `Remotes` que haya quedado, y crea la suya con los 11 remotes correctos: el cliente ya no puede engancharse a una vieja |
| **Una sola bodega por jugador** | Antes de construir tu bodega, borra cualquier `Warehouse_<tuID>` que exista (por ejemplo si el **lugar guardado** ya traía el mapa generado). Además un vigilante revisa cada 6 segundos y borra bodegas extra |
| **Lotes fijos** | La bodega guarda su número de lote, así que al mejorarla o reconstruirla **siempre te quedas en el mismo lugar** |

---

## 🧪 Truco: ¿mi lugar guardó el mapa sin querer?

Si en Studio le diste **Run** (F8) o guardaste el lugar después de una prueba, es
posible que el mapa generado **se haya quedado guardado dentro del lugar**. En el
Explorer mira `Workspace`: si ves una carpeta `City` o modelos `Warehouse_...` con el
juego **cerrado**, están guardados.

Desde la **v28** el juego los limpia solo al arrancar, pero si quieres limpiarlo a mano:
clic derecho → **Delete** en esa carpeta `City` y en los `Warehouse_...`, y guarda.

---

## 📋 ¿Quieres los archivos ya listos para copiar y pegar?

Los 5 links directos (texto plano, se copia con `Ctrl+A` + `Ctrl+C`) y el paso a paso
para pegar encima sin crear copias: [`10-COPIAR-Y-PEGAR.md`](10-COPIAR-Y-PEGAR.md).

## 📌 Resumen

1. **Doble = copias pegadas en Studio.** No hay que tocar el repo.
2. El Explorer: 1 `Main`, 1 `ClientUI`, 1 `GameConfig`, 1 `CityGenerator`, 1 `DataService`, 1 `Remotes`.
3. Desde la v28, si se te cuela una copia, **el juego te avisa** (Output + cartel rojo).

---

## 🧹 Que se puede hacer mas rapido: el LIMPIADOR (v34)

Todo lo de arriba se hace a mano en el Explorer. Si quieres que se haga solo:

1. En Studio, **sin dar Play**, abre la pestaña **`View`** (las de adentro de Studio:
   Home, Model, Avatar, Terrain, Test, **View**, Plugins) y prende el botón **`Command Bar`**.
   > OJO: el menú `View` de arriba de la pantalla (el de la manzanita en Mac) **no** es ese:
   > es otro menú distinto que se llama igual. La Command Bar vive en la **pestaña** `View`.
   >
   > Si no la encuentras, no hace falta: **en el Explorer, clic derecho sobre cada carpeta
   > `Remotes` → Delete**. Se pueden borrar TODAS (el juego crea la suya al dar Play).
2. Pega el codigo del **PASO 0** del HTML de la ronda y dale Enter.

Hace esto:

* borra las copias repetidas de los 5 archivos y se queda con la de la ronda (la
  del sello `RONDA: vNN`), aunque la copia este escondida en un lugar raro (un
  `Main` dentro de `Workspace` **tambien corre**, por eso tambien se revisa);
* borra **todas** las carpetas `Remotes` (el juego crea la suya al dar Play);
* te dice **que archivo hay que volver a pegar** si el que tienes es de otra ronda.

**Y desde la v34 el cartel rojo ya no sale cuando el juego en realidad si
funciona** (la carpeta buena es de esta ronda y tiene los 11 remotes): en ese caso
sale un **avisito azul chiquito** abajo durante 14 segundos y puedes jugar normal.
El cartel rojo queda solo para cuando de verdad hay que arreglar algo.
