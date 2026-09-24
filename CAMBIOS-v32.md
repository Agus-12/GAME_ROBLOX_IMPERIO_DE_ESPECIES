# 🏷️ v32 — El juego te dice **cuál copia borrar** (y tú tienes 2 `Main` pegados)

## 🚨 Lo que te salió en la captura es **mi aviso funcionando**, no un bug nuevo

> *"HAY COPIAS PEGADAS EN STUDIO (todo sale doble)"* + *"2 Scripts Main pegados"*

Es exactamente lo que detecté: en tu Studio hay **dos scripts `Main`**. Y se nota en tu
propia captura: los letreros del taller salen **"CAJON CAJON"** encimados y hay **dos
bodegas** una sobre otra, porque **cada `Main` construye lo suyo**.

**Nada de eso es daño del juego: es que sobra una copia.** Y buenas noticias: la portada
ya abrió (estás adentro), o sea el arreglo de la v31 sí funcionó.

---

## ✅ CÓMO ARREGLARLO (lo único que hay que hacer)

### Paso 1 — Encuentra los repetidos

En el **Explorer**, hay una **cajita de búsqueda** arriba (el 🔍). Escribe **`Main`** y te
muestra todos los que se llaman así (aunque estén en carpetas distintas).

### Paso 2 — Deja **UNO** de cada cosa

Esto es lo que tiene que quedar (borra lo demás: clic derecho → **Delete**):

| En… | Debe haber | Si hay más |
|---|---|---|
| `ServerScriptService` | **1** `Main`, **1** `CityGenerator`, **1** `DataService` | borra las copias |
| `ReplicatedStorage` | **1** `GameConfig`, **1** carpeta `Remotes` | borra las copias |
| `StarterPlayer › StarterPlayerScripts` | **1** `ClientUI` | borra las copias |

> ⚠️ Roblox renombra solos los repetidos: pueden aparecer como **`Main2`**, **`Remotes2`**,
> **`ClientUI2`**… También cuentan como copias.

### 👉 ¿Cuál de los dos `Main` conservo? (esto es lo nuevo de esta ronda)

**Busca la etiqueta de ronda.** Desde hoy, los 5 archivos traen arriba una línea así:

```lua
-- ===== RONDA: v32 =====
```

1. Abre uno de los dos `Main` (clic en él).
2. En la ventana de código, **`Ctrl+F`** y escribe: **`RONDA: v32`**
3. Si **lo encuentra** → ese es el bueno, **quédate con él** y borra el otro.
4. Si **no lo encuentra** → ese es el viejo: bórralo.

Lo mismo sirve para `ClientUI`, `CityGenerator`, `DataService` y `GameConfig`.

> 💡 **El camino más seguro** (si te da flojera comparar): borra **los dos** `Main` y crea uno
> nuevo: clic derecho en `ServerScriptService` → **Insert Object** → **Script** → nómbralo
> exactamente **`Main`** → pega el código de `v32-ARCHIVOS.html`. Listo, sin ambigüedad.

### Paso 3 — Play y revisa

En la consola (**View › Output**) tiene que salir **una sola vez**:

```
========== IMPERIO DE ESPECIAS v32 ==========
  remotes creados: 11
```

Si el bloque sale **dos veces**, todavía hay dos `Main`. Si sale un aviso de copias, dice
**los nombres exactos** de las que sobran.

---

## 🆕 Qué cambió en esta ronda (v32)

| Cosa | Antes | Ahora |
|---|---|---|
| Aviso de copias | decía *"2 x ServerScriptService.Main"* | dice **los nombres exactos**: *"'Main' + 'Main2' en ServerScriptService"* |
| Detección | solo nombres **exactos** (`Main`) | también **numerados** por Roblox (`Main2`, `Main3`…) y `Remotes2`, `ClientUI2` |
| ¿Cuál borrar? | no había forma de saberlo | **sello de ronda**: `Ctrl+F` → **`RONDA: v32`** en los 5 archivos |
| Instrucciones | solo salían en el chat/docs | **salen en pantalla** (cartel rojo) y en la consola, con los 3 pasos |
| Carpetas `Remotes` viejas | solo borraba las que se llamaban exacto `Remotes` | borra también `Remotes2`, `Remotes3`… |
| Validador | — | **etapa 9** ahora exige el sello `RONDA: vNN` en los 5 archivos (si se me olvida, no entrego) |
| Borrar dentro de un bucle | quedaba siempre uno vivo | **etapa 11** (`tools/loops.py`): junta y borra después |

---

## 🐛 Y de paso: un bug real que salió al probar esto

Mientras probaba la limpieza encontré un error **mío** que explicaba cosas raras:

```lua
-- MAL: borrar dentro del mismo bucle que recorre los hijos
for _, c in ipairs(ReplicatedStorage:GetChildren()) do
    c:Destroy()          -- <- se salta al siguiente
end
```

Cuando borras el primero, la lista se encoge y `ipairs` avanza al índice 2 (que ahora es
el que era el 3)… **siempre queda uno vivo**. ¡Y con **dos** carpetas `Remotes` viejas solo
se borraba una! Por eso el cliente se enganchaba a la que sobraba y decía *"faltan
remotes"*.

**Aparecía en 4 lugares más** (todos arreglados: se juntan en una lista y se borran después):

| Dónde | Lo que causaba |
|---|---|
| Limpieza de carpetas `Remotes` | Quedaba una vieja viva → "faltan remotes" |
| Limpieza de bodegas guardadas en el lugar | Quedaba una bodega de más |
| **`syncWorkers`** (los empleados) | **Empleados duplicados encimados en la misma mesa** |
| **`syncGarage`** (los autos estacionados) | Autos encimados en el cajón |
| **`renderTab`** de la tienda | **Filas viejas pegadas en las pestañas** (el "mercado roto") |
| Efectos de iluminación | Efectos duplicados encimados |

> 🔎 **Y ahora el validador lo caza solo**: `tools/loops.py` es la **etapa 11** y detecta
> cualquier `Destroy()` dentro de un bucle de `GetChildren()`/`GetDescendants()`. Lo probé
> metiendo el bug a propósito y **lo caza**.

---

## 📦 Los archivos

📦 **Los 5 códigos juntos:** **`v32-ARCHIVOS.html`**

| # | Archivo | Dónde se pega | Tipo |
|---|---|---|---|
| 1 | [GameConfig.luau](ReplicatedStorage/GameConfig.luau) | `ReplicatedStorage` › **GameConfig** | ModuleScript |
| 2 | [CityGenerator.luau](ServerScriptService/CityGenerator.luau) | `ServerScriptService` › **CityGenerator** | ModuleScript |
| 3 | [DataService.luau](ServerScriptService/DataService.luau) | `ServerScriptService` › **DataService** | ModuleScript |
| 4 | [Main.luau](ServerScriptService/Main.luau) | `ServerScriptService` › **Main** | **Script** |
| 5 | [ClientUI.luau](StarterPlayerScripts/ClientUI.luau) | `StarterPlayer › StarterPlayerScripts` › **ClientUI** | LocalScript |

> 🧹 **Orden recomendado:** primero **borra las copias** (paso 2 de arriba) y luego pega
> los 5 archivos. Así pegas en el script que queda y no creas uno nuevo.

---

## 📌 Y ojo con esto

En tu captura se ve el HUD ancho viejo (*"Hojas 0 | Bloques 0 | Espacio 0/200"*), así que
tu `ClientUI` también es de una ronda anterior (el nuevo es una **columna vertical** a la
izquierda, con el reloj arriba a la derecha). Al pegar los 5 de esta ronda queda todo
igual: HUD en columna, garaje con portones que se abren solos, carros nuevos y luces de
noche.
