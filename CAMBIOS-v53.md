# 🔧 CAMBIOS v53 — el portón que se volaba, la van que peleaba y tu lote en el mapa

Fecha: 27 sep 2026 · build `v53` · reporte del usuario con v52 ya pegada:
> "me aparece v52 pero la van... cuando la spawneo aparece como que las piezas
> una arriba de la otra pero con bloques de aire" · "el portón aún no aparece,
> es el chico el del coche" · "mi lote sigue siendo el 5 y en el mapa me lo
> sigues marcando en el 1" · "falta que conectes las calles de la ciudad a las
> de los garages".

---

## 📂 Abrir los archivos a copiar

| Archivo | Dónde va en el Explorer de Studio |
|---|---|
| [`GameConfig.luau`](ReplicatedStorage/GameConfig.luau) | `ReplicatedStorage` (ModuleScript) |
| [`CityGenerator.luau`](ServerScriptService/CityGenerator.luau) | `ServerScriptService` (ModuleScript) |
| [`DataService.luau`](ServerScriptService/DataService.luau) | `ServerScriptService` (ModuleScript) |
| [`Main.luau`](ServerScriptService/Main.luau) | `ServerScriptService` (**Script**) |
| [`ClientUI.luau`](StarterPlayerScripts/ClientUI.luau) | `StarterPlayer` › `StarterPlayerScripts` (**LocalScript**) |

> Los 5 cambian de ronda (`DataService` y `ClientUI` solo el sello `RONDA: v53`).
> Usa el **HTML de la ronda** (`v53-ARCHIVOS.html`): trae el **PASO 0
> (LIMPIADOR)** para borrar las copias viejas antes de pegar.

---

## 1. "el portón aún no aparece (el chico, el del coche)" — SE VOLABA LITERALMENTE

**La causa (medida, y es el bug más viejo del juego: reportado desde la v44):**
el `HomeCF` de cada pieza del portón (la pose a la que vuelve al cerrarse) se
guardaba al construir el **template**, ANTES de que la bodega se mueva a su
lote con `PivotTo` — quedaba en **coordenadas locales**. Medido en el lote 1:
la pieza está en `(-648, 6.22, -652.4)` y su `HomeCF` apuntaba a
`(-48, 7.22, 7.7)`: **880 studs de diferencia**. Al "cerrarse", el portón se
tejía hacia ese HomeCF local... y **salía volando hasta el origen del mundo**.
En la cochera quedaban los rieles y el rollo, pero ni portón ni franjas: por
eso ningún arreglo visual (ancho v46, franja v49, rieles v50) lo "hacía
aparecer". Además el sensor de apertura medía la distancia contra ese HomeCF
local (abría/cerraba según qué tan cerca estuvieras del ORIGEN, no del cajón).

**El arreglo (`Main.resellarHome`):** después de CADA `PivotTo` de una bodega
(asignación, mejora de nivel, vecinas) se re-sellan los `HomeCF`/`HomeY` con la
pose de **verdad** en coordenadas del mundo, y cada portón guarda su `PisoY`
(la altura real de su cajón) para enrollarse a la altura correcta — antes el
rollo quedaba 1 stud arriba porque el piso se calculaba con un `2` fijito del
template.

**Medido (etapa 23):** los portones del cajón tienen su `HomeCF` clavado en su
lugar (delta 0.0) — y el al revés comprueba que si alguien quita el re-sellado,
truene.

---

## 2. "la van aparece con las piezas una arriba de la otra" — dos sistemas peleando

**La causa (reproducida en simulador):** el botón **"Auto"** del teléfono
(`summonCar`) teletransporta el carro con `PivotTo` para ponerlo enfrente de
ti... pero el bucle de manejo (`hacerConducible`) tenía la posición "de
memoria" y **lo regresaba a la bodega en el frame siguiente**. Medido tick por
tick: el carro aparece en `(100, 3.4, -118)` y 0.03 s después ya está de
regreso en `(-648, 5.2, -640)`. Esa pelea de ida y vuelta a 60 fps — con las 56
piezas re-escribiéndose cada frame — es lo que se ve como **piezas revueltas
con bloques de aire**. (La van construida en sí sale perfecta: 56 piezas,
bbox 9.6×11.4×15.1, igualita a la estacionada.)

**El arreglo (3 partes):**
- `hacerConducible` **ADOPTA** movimientos externos: si el chasis está donde
  este bucle no lo puso (PivotTo, teletransporte), se toma la nueva postura
  como punto de partida (y si quedó enterrado o al aire, se asienta al piso de
  un golpe: es teletransporte, no escalón de banqueta).
- Cuando el carro está quieto **no se escribe nada** (antes re-escribía las 56
  piezas en cada frame aunque estuviera parado).
- `summonCar` ya no usa la altura fijita `3.4`: mide el piso con un rayo.

**Medido (etapa 23, simulado de verdad):** el botón "Auto" deja el carro
contigo y **ahí se queda**, asentado al piso (medido: queda a `piso + 4.2` de
altura de chasis, ruedas apoyadas).

---

## 3. "en el mapa me lo sigues marcando en el 1" — ya marca el 5

El mapa ahora dibuja **TU lote (el 5)** en las cuatro vistas: el 5 sale
**dorado con la etiqueta "5 (TU LOTE)"**, el 1 queda azul como "1 (nuevo)" (el
que le toca a quien empieza de cero), y la vista de detalle y las fachadas
muestran **tu lote de verdad** (el de la columna oriental, con la ventana del
cajón medida desde su propio portón, ya sin números fijos del lote 1).

---

## 4. "falta que conectes las calles de la ciudad a las de los garages"

El camino **principal** (x=-104) sí tocaba la calle de la ciudad (`RoadZ0`,
medido: unido = true)... pero el **de en medio** (x=236) se quedaba corto en la
primera hilera: para los lotes del lado oriente (como el tuyo, el 5) llegar a
la ciudad obligaba a dar toda la vuelta hasta el otro extremo.

**El arreglo:** el camino de en medio ahora **también llega hasta `RoadZ0`**
(z −1319..−485; antes terminaba en −539). Medido: `RoadZ0` va de x −392 a 242,
así que el medio (x=236) empalma con 6 studs de margen. **Los dos caminos
norte-sur tocan la ciudad** — chequeo nuevo `__UNIDO2__` en la etapa 26.

---

## 5. Pruebas

- **Etapa 23 (`reportes48.py`) con 2 chequeos nuevos de FLUJO REAL:** (a) los
  `HomeCF` de los portones quedan en su lote (no se vuelan), (b) el botón
  "Auto" deja el carro donde lo invocaste (ya no regresa a la bodega).
- **Etapa 26 (`caminos51.py`):** `__UNIDO2__` — el camino de en medio toca la
  calle de la ciudad. Todo lo demás igual (TOCAN ninguna, estorbos ninguno,
  rampas 20, faroles, la van sobre su patio).
- **`tools/alreves51.py` — 9/9 truenan** (los 6 de v51/v52 más los 3 nuevos:
  sin re-sellar HomeCF, sin adoptar movimientos externos, medio corto).
- **`bash tools/validate.sh` COMPLETO (1..26): EXIT=0.**
- Los diagnósticos de esta ronda quedaron en `tools/diagvan.py`,
  `diagsummon.py` y `diagporton.py` (el estetoscopio que encontró las causas:
  reprodujo el lote del jugador, la mejora de nivel, el botón y el ciclo del
  portón contra la bodega YA colocada en su lote).
- **Lección aprendida (otra vez):** las etapas armaban el lote SIN el `PivotTo`
  a su lugar — con coordenadas locales, el `HomeCF` coincidía de casualidad y
  el chequeo salía verde. Los chequeos nuevos corren el camino completo.

---

## Cómo probar

1. Corre el **PASO 0** del HTML (limpia copias viejas) y pega los 5 archivos.
2. **Play** → la placa verde debe decir `RONDA v53  OK` y el letrero del
   servidor `SERVIDOR v53`.
3. **El portón:** párate lejos de tu cajón y míralo de frente: la cortina con
   su franja roja/blanca está CERRADA. Acércate (7 studs) y se enrolla;
   aléjate y **vuelve a bajar en su cajón** — ya no se desaparece.
4. **La van:** sácala del cajón ("Sacar y conducir") y también pruébala desde
   lejos con el botón **"Auto"** del teléfono: aparece enfrente de ti, se
   asienta al piso y **ahí se queda** — ya no regresa volando a la bodega ni
   sale revuelta.
5. **Las calles:** desde tu lote (el 5) sube al camino de en medio (hacia el
   poniente de tu calle) y sigue derecho al norte: ahora desemboca directo en
   la calle de la ciudad, sin dar la vuelta por el otro extremo.
6. El mapa (`mapa-mundo-v53.png`) marca tu lote: el **5 dorado**.

---

## Roadmap

| Pendiente | Estado |
|---|---|
| Interiores de propiedades (casas/departamentos) | solo fachada hoy |
| Música ambiente + sonido de motor | los SFX de acciones ya están |
| Confirmar de oídos la van y el portón en el juego real | pendiente del reporte del usuario |
