# Cambios de la ronda v45

> ## 🎯 TUS 3 REPORTES DE LA CAPTURA DE LAS 7:19
>
> | Lo que reportaste | Qué era | Qué se hizo |
> |---|---|---|
> | **"siguen los mismos bugs"** (la bodega vecina con su **cinta amarilla y negra** cruzada encima de tu patio, tablillas viejas) | **No eran bugs nuevos: eran OBRAS VIEJAS GUARDADAS EN TU LUGAR.** El archivo del lugar (.rbxl) guarda TODO el Workspace, así que las bodegas vecinas, su cinta de clausura y la carpeta `Oficiales` de partidas anteriores se quedaban pegadas en el mapa. El generador solo borraba la carpeta `City`, así que reconstruía la ciudad **encima** de lo viejo | **`limpiarObrasViejas()`**: al dar Play el servidor borra esas obras (y te dice en el Output cuántas). También el **limpiador** (`tools/limpiar.luau`, paso 9) lo hace sin dar Play, y `docs/11` enseña a **guardar el lugar sin la ciudad** para que no vuelva a pasar |
> | **"sale muy pequeño en los letreros creo"** | Los tableros negros medían poco y el texto iba con menos píxeles por stud, así que a la distancia no se leía | Letreros y texto **más grandes**: `GARAJE`/`CAJAS` **17 × 3.6** a 70 px por stud, placas de cajón **6 × 2.6** a 75, `TALLER`/`OFICINA` a 65, el travesaño a 62, la placa de la tienda a 48. Y el garaje ahora dice **`GARAJE DE <TU NOMBRE>` en DOS RENGLONES** para que se lea grandote sin cortarse |
> | **"la escuadra la pistola se sigue viendo así"** (el **tubito gris flotando** delante del arma) | El cañón estaba puesto **a mano** en (0, 0.78, -1.28): eso lo dejaba **0.30 studs arriba y 0.58 adelante** de la corredera —literal, un tubito flotando en el aire—. Y encima estaba mal armado: en Roblox **el largo de un cilindro va en el eje X del Size**, y estaba en Z, así que al acostarlo quedaba un **disco chato** | El cañón ahora **se calcula desde la corredera** (`canonTope`) y su boca queda **pegada** (hueco medido: 0.000). Se endereza con `Size = (largo, 0.13, 0.13)` acostado con la rotación. Además miras, cachas y cargador **más grandes**, y el arma se agarra **centrada** (`GripPos (0, -0.06, 0.16)`) |

---

## 1. 🧱 "Siguen los mismos bugs" — el lugar guarda lo que construiste antes

**La causa real (esto explica por qué "no cambiaba" aunque los archivos ya fueran nuevos):**

* El juego **no guarda la ciudad en los scripts**: la construye al dar Play.
* Pero **el lugar SÍ guarda el Workspace completo** cuando guardas en Studio.
* `CityGenerator.Build` solo borra la carpeta **`City`**. Las bodegas vecinas
  (`BodegaVecina_*`), las clausuradas (`BodegaClausurada_*`) y la carpeta
  **`Oficiales`** NO viven dentro de `City`: se crean con `Parent = Workspace`.
  Así que quedaron **guardadas en el lugar** y el servidor construía lo nuevo
  **encima** de ellas.

De ahí que vieras en la captura la **bodega vecina pegada a tu patio con la cinta
amarilla/negra cruzada** y tablillas de partidas viejas: no eran cosas nuevas.

**El arreglo (v45):** antes de crear nada, el servidor limpia:

```
local function limpiarObrasViejas()
  -- borra por NOMBRE: BodegaVecina_*, BodegaClausurada_*, Warehouse_*, Oficiales
  -- y por ATRIBUTO: Vecina / Clausurada / Lote
limpiarObrasViejas()   -- se llama justo antes de crear la carpeta Oficiales
```

Salida en el Output al dar Play:

```
[SpiceEmpire] Borre 6 obra(s) vieja(s) de los lotes que habian quedado guardadas
en el lugar (bodegas vecinas, cintas, oficiales). Si vuelven a salir: en Studio
corre el LIMPIADOR (tools/limpiar.luau) y guarda el lugar sin la ciudad.
```

> **Truco de conteo de letras:** `"BodegaClausurada_"` mide **17**, no 18. La
> primera versión comparaba `string.sub(n, 1, 18)`, y con eso **esa** obra vieja
> nunca se borraba (el bug a medias). Ahora se compara contra `#prefijo`, que no
> se puede contar mal.

**Nunca más:** la ciudad se reconstruye sola al dar Play, así que **no hace falta
guardarla**. En Studio (sin dar Play): Explorer → `Workspace` → carpeta `City` →
Suprimir → `Ctrl+S`. Queda documentado en `docs/11` (Paso 4-bis).

## 2. 🪧 Los letreros se leen de lejos

| Letrero | Antes | Ahora |
|---|---|---|
| `GARAJE` (tablero del garaje) | 12 × 2.8 @ 52 px | **17 × 3.6 @ 70 px** y **dos renglones** |
| Placas de cajón (`CAJA n`) | 4.4 × 2.1 @ 60 | **6 × 2.6 @ 75** |
| `TALLER` / `OFICINA` | 50 | **65** |
| Travesaño del portón (lintel) | 44 | **62** |
| Placa de la tienda | 38 | **48** |

El garaje pasa de `GARAJE` a:

```
┌───────────────┐
│  GARAJE DE    │   <- renglón 1 (chico, sirve de etiqueta)
│  AGUS         │   <- renglón 2 (el nombre, grandote)
└───────────────┘
```

`RotularGaraje` parte el texto solo si trae `" DE "`: los lotes sin dueño siguen
diciendo **`SIN PROPIETARIO`** en un renglón.

## 3. 🔫 La pistola: el cañón ya va PEGADO a la corredera

**Lo que se veía mal:** frente al arma salía un **tubito gris separado**, como
flotando.

**Dos causas, las dos arregladas:**

1. **El cañón estaba puesto a mano:**
   `handle.CFrame * CFrame.new(0, 0.78, -1.28)`. La corredera vive en
   `y = 0.484, z = -0.186`, así que ese 0.78 lo dejaba **0.30 studs arriba** y el
   −1.28 lo dejaba **0.58 studs adelante**. Literal: un tubito flotando.
   Ahora **se calcula**: `canonTope = slideZ - slideLargo * 0.5` y el cañón se
   centra en `canonTope - canonLargo * 0.5`, con la boca pegada a la corredera.
2. **El cilindro estaba mal armado:** en Roblox **un Part cilíndrico tiene su
   largo en el eje X del Size**. Estaba `(0.12, 0.12, largo)` con una rotación de
   90° en Y → quedaba un **disco chato** de canto. Ahora es
   `Size = (largo, 0.13, 0.13)` acostado con `CFrame.Angles(0, rad(90), 0)`.

**De paso, el arma se ve mejor en la mano:** miras 0.15/0.05, cachas
0.05 × 0.6 × 0.36 a los lados, cargador 0.26 × 0.07 × 0.43, `GripPos` centrado
`(0, -0.06, 0.16)`.

### ⚠️ Ojo: el simulador de pruebas mentía

`tools/mock.lua` tenía tres trampas que dejaban pasar el bug:

* las piezas nuevas nacían **sin `CFrame` ni `Size`** (en Roblox nacen con ellos);
* `CFrame * CFrame` devolvía **el mismo CFrame** (no componía nada);
* `CFrame + Vector3` devolvía **el mismo CFrame** (mover una pieza "funcionaba"
  sin mover nada).

Con eso, el cañón flotando se veía como "correcto". **Ya se corrigieron las tres**,
y por eso ahora la prueba mide de verdad el hueco entre el cañón y la corredera:
**exige ≤ 0.02 studs** (hoy da **0.000**).

## 4. 🧪 Cómo se probó

Etapa **20** de `tools/reportes44.py` (corre en `tools/validate.sh`):

| Prueba | Qué mide | Resultado |
|---|---|---|
| 5a · obras viejas | mete al Workspace 3 obras viejas (una vecina, una clausurada, una carpeta `Oficiales`) **y una casa ajena** y arranca el servidor completo | `ok` — borra las 3 + los oficiales y **no toca** la casa ajena |
| 5b · la pistola | llama a `makeWeapon()` de verdad y mide las piezas | `12 piezas`, hueco cañón-corredera **0.000**, arma 1.24 × 1.18, con agarre |

Probado **al revés** (metiendo los bugs a propósito):

* cañón de vuelta en (0, 0.78, −1.28) → *"el CAÑÓN está separado de la corredera
  por 0.433 studs (eso es el tubito gris flotando)"* ✅ lo caza;
* sin `limpiarObrasViejas()` → *"quedaron 3 obra(s) vieja(s) en el mapa"* ✅ lo caza.

## 5. 📋 Archivos que cambian

| Archivo | Qué trae de nuevo |
|---|---|
| `ServerScriptService/Main.luau` | `limpiarObrasViejas()` + pistola corregida |
| `ServerScriptService/CityGenerator.luau` | letreros y textos más grandes, `RotularGaraje` en dos renglones |
| `ReplicatedStorage/GameConfig.luau` | `Build = "v45"` |
| `StarterPlayerScripts/ClientUI.luau` | `MI_VERSION = "v45"` |
| `ServerScriptService/DataService.luau` | sello de ronda `v45` |
| `tools/limpiar.luau` | **paso 9 nuevo**: borra las obras viejas de los lotes |
| `tools/mock.lua`, `tools/reportes44.py` | simulador más fiel + etapa 20 |

---

> **Para ti, en corto:** pega los archivos de la v45, dale Play. Si en el Output
> sale `Borre N obra(s) vieja(s)`, esas eran las que veías "de más". Y para que no
> vuelvan: borra la carpeta `City` de tu Workspace y guarda el lugar (Paso 4-bis de
> `docs/11`).
