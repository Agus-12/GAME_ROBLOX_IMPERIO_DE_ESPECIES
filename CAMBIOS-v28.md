# 🔧 v28 — Reparación a fondo: computadora, caja fuerte, garaje y los anexos

## 📂 Abrir los archivos a copiar

### 1️⃣ [GameConfig.luau](ReplicatedStorage/GameConfig.luau)
→ **ReplicatedStorage › GameConfig** · tipo **ModuleScript**

### 2️⃣ [CityGenerator.luau](ServerScriptService/CityGenerator.luau)
→ **ServerScriptService › CityGenerator** · tipo **ModuleScript**

### 3️⃣ [Main.luau](ServerScriptService/Main.luau)
→ **ServerScriptService › Main** · tipo **Script**

### 4️⃣ [ClientUI.luau](StarterPlayerScripts/ClientUI.luau)
→ **StarterPlayer › StarterPlayerScripts › ClientUI** · tipo **LocalScript**

### 5️⃣ [DataService.luau](ServerScriptService/DataService.luau)
→ **ServerScriptService › DataService** · tipo **ModuleScript**

> ⚠️ **Esta ronda toca los 5 archivos.** Si te falta pegar alguno, ya no se queda la
> pantalla muerta en silencio: sale un **cartel rojo** arriba diciendo
> *"FALTA UN SCRIPT: …"* y en la consola (View › Output) sale el nombre exacto.
> Eso lo agregué a propósito, porque justo eso te estaba pasando.

---

## 🔴 1. La computadora y la caja fuerte: por qué se quedaban en blanco

Este es **el bug** que no me dejaba cerrar la ronda anterior.

En la v22 quité `StorageBonus` de `WarehouseTiers` (ahora cada nivel tiene
`VaultLeaves` y `VaultBlocks`, porque el tope de la caja es por producto).
Pero **tres lugares seguían leyendo el campo viejo**:

| Dónde | Qué pasaba |
|---|---|
| `Main.luau` (pantalla de la bodega que sube en el monitor) | `nil + número` → error |
| `ClientUI.luau` (pestaña **Bodega** del panel) | `string.format("%d", nil)` → error |

En Lua eso **no truena al compilar**: el campo que no existe simplemente vale
`nil`. El error aparece en **tiempo de ejecución**… y como todo eso corre dentro
de un `pcall` (un try/catch), **el error se traga en silencio**. Resultado: la
computadora se abría pero la pestaña salía vacía / a medias, sin nada rojo en la
consola. Exactamente lo que reportaste.

**Arreglado:** los tres lugares ahora usan `VaultLeaves` / `VaultBlocks` (los
topes reales de la caja) y se ven así:

```
Parcelas 4  |  Caja 100 hojas / 50 bloques
```

> 🛡️ Y para que no vuelva a pasar, hay una herramienta nueva que **compara
> todos los campos que lee el código contra los que de verdad tiene la config**.
> La probé metiendo un campo falso a propósito: lo caza al instante.

---

## 🚪 2. El garaje estaba SELLADO (la causa real, no un parche)

En la v26 te puse el garaje con sus 4 cajones, sus lámparas y su letrero, y ahí
se estacionan los autos que compras… pero **la pared izquierda de la bodega se
construía de una sola pieza, sin hueco**. O sea: el garaje era una caja cerrada.
Los autos se veían desde adentro de la nave, pero **no había puerta para entrar**.
Por eso "no podías hacer nada" ahí.

**Arreglado:** la pared izquierda ahora se construye **en tramos** y deja un
**hueco de 14 × 12** alineado con el garaje, con su **marco metálico** y su
letrero **TALLER**. Los estantes industriales que taparían el paso se saltan
solos (igual que ya se hacía con la puerta de la oficina).

---

## 🚙 3. El escalón del portón (y por qué la bici se quedaba afuera)

El piso de tu bodega está a **2 studs** y la calle a **0.2**: había un escalón de
**1.8 studs** justo en la entrada. El personaje lo sube de milagro, pero la bici
**no**: su límite es 1.6. Se quedaba atorada afuera (o adentro).

**Arreglado:** una **rampa de concreto** (`GateApron`) con sus guardas amarillas
en el lado libre del portón, entre el marco y el muelle de carga.

---

## 🏢 4. La oficina: verificada POR FUERA, con su puerta

Sobre tu corrección: la oficina va **afuera**, pegada a la pared derecha, y se
entra por una **puerta que atraviesa esa pared** (hueco de 8 × 11 con marco de
madera y letrero **OFICINA**). Adentro: cama con buró y lámpara, sillón, mesita,
tapete y ventana.

Esta vez **no te lo digo de palabra**: escribí una herramienta que **construye
los 4 niveles y tira un flood fill con el cuerpo de un jugador** (1.7 de radio)
para comprobar que **se puede CAMINAR** desde donde apareces hasta la oficina, la
caja, la computadora, la prensa, las mesas, el garaje y la calle. Sale así en los
4 niveles:

```
OK    oficina            OK    caja fuerte        OK    computadora
OK    prensa             OK    mesa 1             OK    garaje
OK    cajon 1            OK    la calle
OK    la oficina esta por fuera (x=52, muro en 36)
```

> Si vos todavía la ves adentro de la nave, es que te falta pegar el
> **CityGenerator** de esta ronda (o quedó el de la v26). Con el de la v28 la
> oficina es un cuarto aparte, con su propia puerta.

---

## 📏 5. Las bodegas se encimaban con la del vecino

Una bodega **no mide lo que dice su tamaño**. El nivel 4 mide 190 de ancho, pero
además se le pegan **dos anexos por fuera**: el taller (46 a la izquierda) y la
oficina (34 a la derecha). Total real: **271 studs**.

Y las bodegas se sembraban cada **140**. O sea: **la oficina de uno caía dentro
del taller del vecino** (y el taller del vecino tapaba tu puerta). Con 20
jugadores, un desmadre.

**Arreglado:** los lotes ahora son una **rejilla de 5 por fila** con espaciado
**340 × 260** (`GameConfig.WarehouseLots`, todo en un solo lugar, nada de números
sueltos por el código).

Y de paso: **el suelo ahora se estira para cubrir los 20 lotes**. Antes, con la fila larga, los últimos lotes quedaban **fuera del pasto** y al salir por el
portón te caías al vacío gris. La validación lo comprueba:

```
lotes:  x -750..910   z -1535..-565
suelo:  x -840..1000  z -1625..776
OK    los 20 lotes caen sobre el suelo
```

---

## ⏱️ 6. "No me deja hacer nada": el cliente que se colgaba en silencio

Encontré **dos** formas de que el juego quedara muerto sin decir nada:

1. El cliente esperaba los *remotes* con `WaitForChild` **sin límite de tiempo**.
   Si faltaba uno, se quedaba esperando **para siempre** y todo el código de
   abajo (el detector de cercanía, los botones, los paneles) **nunca corría**.
2. El remote `IncomingCall` se creaba **1745 líneas más abajo** del arranque del
   servidor. Si cualquier cosa fallaba antes de esa línea, el cliente se quedaba
   esperando **ese** remote… y con él, toda la interfaz.

**Arreglado:**
- Los remotes se crean **todos juntos al arranque** del servidor.
- El cliente espera **máximo 10 segundos**, y si falta algo:
  - sale un **cartel rojo** arriba con la lista de lo que falta,
  - en la consola se ve `[SpiceEmpire] FALTA ReplicatedStorage.GameConfig`,
  - y el juego **sigue funcionando** con lo que sí hay, en vez de morir.
- El servidor también avisa con el nombre exacto en vez de esperar eternamente.

### 🧟 Y uno más, del mismo estilo: el panel que no se reabría después de morir

El detector de cercanía guarda en qué máquina **estabas** para abrir el panel justo
cuando llegas (no cada 0.3 s, que sería un desastre). El detalle: si **te matan
parado junto a la computadora o a la caja fuerte**, ese "ya estabas ahí" quedaba
pegado en `true`, y al revivir el cruce **nunca volvía a disparar**: caminabas hasta
pegado a la máquina y **el panel no se abría** (solo se arreglaba si te alejabas y
volvías a acercarte). Con las redadas y la policía, esto te iba a pasar seguido.

**Arreglado:** al morir, el estado se limpia y los paneles se cierran solos.
Fue justo eso: parecía que "ya no abre la computadora ni la bóveda… hasta que
te alejas y regresas".

---

## 📐 7. El botón salía pero te rebotaba (2 studs de zona muerta)

La prensa: el **cliente** mostraba el botón a **16 studs** y el **servidor**
validaba a **14**. Entre 14 y 16 studs veías *"Prensar"*, le picabas… y te decía
*"estás muy lejos"*. Un fantasma de 2 studs de ancho.

**Arreglado de raíz:** los radios ahora **salen todos de GameConfig** (el cliente
y el servidor leen el mismo número). Agregué `GameConfig.Interact` para la
computadora, el garaje y los compradores, y la prensa / la caja / las mesas ya
usan `Press.UseRadius`, `Carry.VaultRadius` y `Growth.HarvestRadius`.

---

## 🎯 8. Dos números que no cuadraban con lo que se ve

| Qué | Antes | Ahora |
|---|---|---|
| **Tapete de la oficina** (zona segura) | radio fijo de 14 studs, pero el tapete mide 28×11 → **las esquinas del tapete no eran seguras** aunque se vieran dentro | se mide contra el tapete real |
| **Sensor del portón** | radio de 26 "a ojo" | se mide contra su propia caja |

---

## 🛡️ Validación: de 5 etapas a 8 (y con dos agujeros tapados)

`bash tools/validate.sh` ahora corre **ocho** etapas. Las tres nuevas nacieron de
los bugs de esta ronda:

| # | Etapa | Qué caza |
|---|---|---|
| 6 | `tools/fields.py` **(nueva)** | Campos que el código lee y la config **no tiene** → el bug de `StorageBonus` |
| 7 | `tools/walk.py` **(nueva)** | Que **se pueda caminar** a cada máquina y a cada anexo (nace del garaje sellado) |
| 8 | `tools/api.py` **(nueva)** | Enums, clases y propiedades contra el **API real de Roblox** (el simulador se traga cualquier typo) |
| 4 | `tools/globals.py` **arreglado** | Antes **saltaba Main.luau entero** (el archivo más grande) y su fallo se **ignoraba** con un `\|\| true`. Ahora sí audita y sí bloquea. |

Y las tres herramientas nuevas las probé **metiendo el bug a propósito** para
confirmar que lo cazan (no sirve de nada un validador que dice "todo bien" siempre).

---

## 🚨 Extra: el cartel "FALTAN SCRIPTS/REMOTES EN EL SERVIDOR"

> Esto salió de tu propia captura: te apareció el cartel con **2** remotes faltantes.

**No es un bug del juego: es la mezcla de rondas en Studio.** En una misma ronda, el
servidor tiene que crear **11** canales (`Remotes`) y el cliente pide esos mismos 11.
Si el `Main.luau` pegado en Studio es viejo, crea menos de los que el cliente nuevo pide
y sale el cartel.

Tu caso, exactamente: el `ClientUI` ya era de la v28 (por eso el cartel existe: es
nuevo) pero el `Main.luau` seguía siendo de la **v17 o v18** → faltaban **`Shoot`**
(del arma, v21) y **`TerritoryUpdate`** (de territorios, v24). Por eso decía *"FALTAN 2"*.

**Arreglo: pega los 5 archivos completos de la ronda.** Y para que nunca más quede la
duda, la v28 ahora te lo dice sola:

| Nuevo en la v28 | Qué hace |
|---|---|
| `GameConfig.Build` | La config dice su ronda (`"v28"`) |
| Sello en `Remotes` | El servidor estampa su versión y **la imprime en Output**: `========== IMPERIO DE ESPECIAS v28 ==========` + cuántos remotes creó |
| `MI_VERSION` en ClientUI | El cliente compara las 3 versiones |
| Cartel explicativo | Si no cuadran: *"ARCHIVOS VIEJOS EN STUDIO"*, qué dice cada archivo, **qué remote falta y desde qué ronda existe** |
| Aviso del CityGenerator | Si la bodega llega sin la rampa `GateApron` (v28), sale un `warn` diciendo que el CityGenerator quedó viejo |

📄 La guía completa, con la tabla de "de qué ronda es cada remote", está en
[`docs/08-SI-SALE-FALTAN-REMOTES.md`](docs/08-SI-SALE-FALTAN-REMOTES.md).

### 🕳️ Y de paso: la validación tenía otro agujero (arreglado)

Mientras probaba esto descubrí que `validate.sh` **daba por buenas dos etapas aunque
los scripts tronaran**: el test del cliente y el del servidor imprimían el error
(`!! ...`) pero **salían con código 0**, así que para el validador era "todo bien".
Justo la clase de agujero que ya nos había mordido. Ya fallan de verdad (probado
metiendo un error a propósito y confirmando que las etapas marcan FALLA), y hay una
**etapa 9** nueva que revisa el contrato cliente/servidor y que las versiones cuadren
en los 5 archivos:

```
=== 9. CONTRATO CLIENTE/SERVIDOR (remotes y versiones) ===
  OK     el servidor crea todos los remotes que el cliente pide
  OK     GameConfig.Build             v28
  OK     ClientUI MI_VERSION          v28
```

---
## 🧪 Cómo probar

1. Pega **los 5 archivos** y dale **Play**.
2. **Camina hasta la computadora** (el escritorio del fondo): suena el clic y se
   abre el panel. La pestaña **Bodega** ahora sí dice *"Cajas 100 hojas / 50 bloques"*
   (antes salía en blanco).
3. **Acércate a la caja fuerte**: se abre el panel de guardar / sacar producto.
4. **Párate en una mesa de cultivo**: sale **Cosechar**.
5. **Párate frente a la prensa**: sale **Prensar** y ahora sí te deja (ya no hay
   zona muerta).
6. **Ve a la pared derecha** y cruza la puerta del letrero **OFICINA**: adentro
   están la cama, el sillón y el tapete. Camina sobre el tapete y el Heat baja
   rápido.
7. **Ve a la pared izquierda** y cruza el hueco del letrero **TALLER**: adentro
   están los 4 cajones y ahí aparecen tus autos comprados.
8. **Sal por el portón**: ya hay **rampa**. Súbete a la bici y entra / sal sin
   quedarte atorado.
9. Si algo falta (por ejemplo no pegaste un script), sale el **cartel rojo**
   diciéndote cuál. Mándame esa captura y lo remato.

---

## 🗺️ Roadmap

| Pendiente | Nota |
|---|---|
| **Bici** | La v17 la dejó anclada y estable, pero **el usuario todavía no confirma** que se sienta bien. Con la rampa nueva ya no se atora en el portón |
| **Interiores de propiedades** | Las casas / departamentos que compras siguen siendo fachada |
| **Música ambiente** | Faltan música de fondo y sonido de motores (los SFX ya están) |

> Lo del pedido original está cubierto desde la v24. Lo de arriba es para crecer
> el juego, no deuda técnica.
