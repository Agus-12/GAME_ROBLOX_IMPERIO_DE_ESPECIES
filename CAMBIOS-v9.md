# 🌱 v9 — Plantas individuales, porton, llamadas al celular

## 📂 Abrir los archivos a copiar

### 1️⃣ [GameConfig.luau](ReplicatedStorage/GameConfig.luau)
→ **ReplicatedStorage › GameConfig**

### 2️⃣ [CityGenerator.luau](ServerScriptService/CityGenerator.luau)
→ **ServerScriptService › CityGenerator**

### 3️⃣ [Main.luau](ServerScriptService/Main.luau)
→ **ServerScriptService › Main**

### 4️⃣ [ClientUI.luau](StarterPlayerScripts/ClientUI.luau)
→ **StarterPlayer › StarterPlayerScripts › ClientUI**

> ⛔ `DataService` no cambió.

En cada uno: abre el script en Studio, **Ctrl+A** (o Cmd+A), borra, y pega el contenido nuevo.

---

## 1. La bodega ya tiene fachada y porton

El problema era que el frente estaba **literalmente abierto** — no había pared, por eso se veía como cochera.

Ahora tiene:
- **Pared frontal de verdad** con un hueco al centro para el portón
- **Portón de dos hojas** con nervaduras metálicas (no una tabla lisa)
- Marco de metal alrededor
- **Se abre solo** cuando te acercas a 26 studs, y se cierra cuando te vas
- Letrero con el nombre de tu nivel de bodega arriba del portón
- Dos lámparas que prenden de noche

## 2. Plantas individuales (esto era lo importante)

Antes todas las plantas eran decoración y la cosecha era un cooldown invisible. Ahora **cada maceta es una planta real con su propio estado**.

**Cómo sabes cuál está lista:**

| Etapa | Cómo se ve |
|---|---|
| Recién cosechada | Chiquita, casi transparente, amarillenta |
| Creciendo | Va **creciendo de tamaño** poco a poco y verdeando |
| Lista | Tamaño completo, **verde fuerte**, y se le prende un **foquito verde flotando encima** |

El foquito verde es la señal. Si lo ves, esa planta ya se puede cortar.

**Cosecha por cercanía:** presionas **E** y solo se cortan las plantas maduras que tengas **a 22 studs o menos**. Las de la otra mesa siguen creciendo. Si no hay ninguna cerca pero sí lejos, te dice *"Acercate a una mesa con plantas listas"*.

Cada planta tarda **24 segundos** en madurar y da **3 hojas**. Las plantas arrancan escalonadas para que no maduren todas al mismo tiempo — siempre hay algo listo mientras otras crecen.

> **Ajustes:** en `GameConfig` → `GameConfig.Growth`. `TimePerPlant` (24s), `HarvestRadius` (22), `LeavesPerPlant` (3).

## 3. Prensa que ya parece máquina

Antes eran dos cubos. Ahora lleva: base pesada, **yunque**, 4 columnas guía, cabezal, motor lateral naranja, manguera hidráulica, vástago, pistón, foco de estado y una **tarima con bloques ya prensados** al lado.

Cuando prensas con **R**, el pistón baja de golpe contra el yunque, destella naranja y sube.

## 4. Escritorio con computadora para las mejoras

Ya no es un cuadro azul en el piso donde no pasaba nada. Ahora hay un **escritorio** con:
- **Monitor encendido** que te muestra tu nivel actual y cuál sigue
- Torre con su LED azul
- Silla, tapete y lámpara

Te paras ahí y presionas **G** para abrir el menú de mejoras. La pantalla del monitor te lo recuerda.

## 5. El vigilante ya no parece tendero

El bug era que usaba **el mismo molde que los NPCs de tienda** — por eso traía mandil de comerciante.

Ahora tiene su propio look: todo de negro, **chamarra de cuero**, **lentes oscuros**, **gorra con visera**, cinturón táctico y un radio en el hombro.

## 6. Bici arreglada

Tenía dos bugs de fondo:

1. **Los ejes de las bisagras estaban mal alineados.** Roblox los agarraba en la dirección equivocada y por eso la bici se retorcía. Ahora el eje va forzado hacia el costado.
2. **No tenía motor.** El asiento no movía nada. Ahora la rueda trasera es motriz y responde a W/S, y el manubrio gira con A/D.

También le puse un estabilizador para que no se caiga de lado cuando está parada, y más fricción en las llantas para que no patine.

## 7. Las entregas calientes ahora te LLAMAN

Ya no aparecen solas de la nada. Ahora:

- Cada **5 a 10 minutos** te suena el celular (la primera llamada llega al minuto y medio para que no esperes tanto)
- Sale una pantalla de **llamada entrante de DESCONOCIDO** que vibra
- Te dice algo como *"Hey... tengo una entrega especial para ti. Las ganancias son buenas pero el riesgo es alto."*
- Abajo ves el trato completo: cuánto, para quién y cuánto pagan
- Botones **CONTESTAR** y **COLGAR**

Si cuelgas, te vuelven a marcar en 2 minutos. Si no contestas, se cuelga solo a los 20 segundos.

Hay **4 frases distintas** que van rotando.

> **Ajustes:** en `GameConfig` → `GameConfig.MissionCalls`. `MinWait`/`MaxWait` (300/600 seg), `FirstCallWait` (90), `RingSeconds` (20).

## 8. Botón de minimizar en el encargo

El panel del encargo activo ahora trae un botón **`-`** en la esquina. Lo aprietas y se colapsa a solo el título. Lo vuelves a apretar y se abre.

---

## Bug extra que encontré

Mientras validaba encontré un error que **ya estaba desde antes**: cuando un jugador salía del juego, el código intentaba limpiar variables que todavía no existían. Eso reventaba al desconectarse. Ya quedó.

---

## Controles actualizados

| Tecla | Qué hace |
|---|---|
| **E** | Cosechar plantas listas cercanas |
| **R** | Prensar |
| **F** | Vender |
| **G** | **Menú de mejoras (en la computadora)** |
| **B** | Tienda |
| **T** | Teléfono |
| **H** | Ir a la bodega |
| **M** | Minimizar HUD |

---

## Recordatorio del paso manual

**Explorer → Lighting → Properties → Technology → Future**

No se puede poner por código.

---

## Cómo probar rápido

- **Portón:** camina hacia el frente de la bodega, se abre solo.
- **Plantas:** entra y mira las macetas. Las que tienen **foquito verde** ya están. Párate junto a esa mesa y aprieta **E**. Se encogen y empiezan a crecer otra vez.
- **Mejoras:** párate en el escritorio y aprieta **G**.
- **Prensa:** junta hojas, aprieta **R**, mira el pistón golpear el yunque.
- **Bici:** **H** → pestaña Bodega → botón de bici. Sal, súbete, muévete con WASD.
- **Llamada:** espera minuto y medio desde que entras. Si quieres probarla ya, baja `FirstCallWait` a `10` en `GameConfig`.

Todo corrió completo en el simulador de la API de Roblox: ciudad generada, los 4 niveles de bodega construidos y servidor arrancado sin errores.
