# 🎨 v8 — Pulido visual (bici, cultivos, NPCs)

## 📂 Abrir los archivos a copiar

### 1️⃣ [CityGenerator.luau](ServerScriptService/CityGenerator.luau)
→ **ServerScriptService › CityGenerator**

### 2️⃣ [Main.luau](ServerScriptService/Main.luau)
→ **ServerScriptService › Main**

### 3️⃣ [ClientUI.luau](StarterPlayerScripts/ClientUI.luau)
→ **StarterPlayer › StarterPlayerScripts › ClientUI**

> ⛔ `GameConfig` y `DataService` no cambiaron.

En cada uno: abre el script en Studio, **Ctrl+A** (o Cmd+A), borra, y pega el contenido nuevo.

---

## 1. La portada ya no se cierra sola

Tenía un temporizador de 12 segundos que la cerraba aunque no hicieras nada. Lo quité: ahora **solo se cierra con el botón**. Te puedes tomar tu tiempo leyendo.

## 2. El panel de encargo ya no se encima con el leaderboard

Lo bajé de 96 a 250 píxeles desde arriba. Ahora queda debajo de la lista de jugadores, sin taparla.

## 3. Bicicleta nueva (y ya no aparece dentro de la bodega)

La anterior era literalmente unos cubos. La rehice:

- Cuadro de **tubos delgados** de verdad (tubo superior, tubo inferior, tubo del asiento, horquilla)
- Asiento propio de 1.4 × 0.4 × 1.8
- Manubrio con **puños de goma** negros
- **Bielas y pedales** que se ven
- Ruedas **cilíndricas delgadas** (0.35 de grosor, 2.8 de diámetro) con rin metálico, montadas con bisagra real para que giren

Y lo importante: ahora aparece **afuera** de la bodega, 16 studs enfrente de la puerta, no atorada adentro. El mensaje dice "Tu bicicleta esta afuera de la bodega".

## 4. Cultivos: ahora son mesas de cultivo con luz UV

Esto era lo más feo — cubos verdes gigantes. Lo cambié completo por una **mesa de cultivo** por cada parcela:

- Mesa metálica de 12 × 0.4 × 8 con sus 4 patas
- **6 macetas de barro** con tierra, tallo y 3 capas de hojas cada una (en vez de un cubo)
- 2 postes con carcasa y un **tubo de luz UV morado neón** encima, con reflector apuntando hacia abajo
- Su cablecito

La zona donde presionas **E** sigue funcionando igual (es una zona invisible sobre la mesa).

### Y ya tienen animación

Cuando cosechas con **E**:
1. Las hojas se **encogen** y se ponen amarillentas (0.2s)
2. Vuelven a **crecer** de golpe con rebote y color verde fresco (0.9s)
3. Cada mesa suelta un **destello verde**

Cuando prensas con **R**:
1. El **pistón baja** de golpe
2. **Destello naranja** de calor
3. El pistón **sube** lento

Las animaciones las corre el servidor, así que **todos los jugadores las ven**, no solo tú.

## 5. El NPC comprador ya se ve como persona

Antes era un montón de partes sueltas. Ahora es un **muñeco R6 de verdad**:

- Partes con los nombres exactos que Roblox espera (Torso, Left Arm, Right Leg, etc.)
- **Humanoid** configurado (no camina, no rota solo)
- **Motor6D** en cuello, hombros y caderas — que es lo que permite animar
- **Cara** con la textura oficial de Roblox
- Pelo y mandil soldados encima
- **Animación idle oficial** de Roblox reproduciéndose (ese balanceo sutil de respiración). Si por lo que sea no carga el asset, hay un respaldo que le mueve el cuello a mano

## 6. El vigilante ya no mira a la pared

El bug era este: el código lo orientaba bien, pero **después** le aplicaba una inclinación con `CFrame.Angles`, y eso **borraba la orientación anterior**. Clásico.

Arreglado: ahora se calcula la posición y la dirección juntas, y la inclinación se aplica **encima** sin perder hacia dónde ve. Está recargado en la pared mirando a la calle, como debe.

De pilón le puse:
- Un **barril** al lado donde se recarga
- Una **luz naranja** en el cigarro

Y moví la basura y el bote de basura al mismo lado para que la escena se vea armada, no con cosas regadas.

---

## Recordatorio del paso manual

Si todavía no lo haces, para que las luces se vean bien:

**Explorer → Lighting → Properties → Technology → Future**

Eso no se puede poner por código, tiene que ser a mano.

---

## Cómo probar rápido

- **La bici:** entra y presiona **H** → pestaña Bodega → botón de bici. Sal de la bodega, ahí está.
- **Los cultivos:** párate en una mesa y aprieta **E** varias veces seguidas para ver la animación.
- **La prensa:** junta hojas y aprieta **R**, mira el pistón.
- **El vigilante:** sal de la bodega y voltea a la izquierda, debe estar recargado viendo hacia la calle.
- **Los compradores:** ve a cualquier tienda, el NPC debe estar respirando y viéndose como persona.

Todo esto ya lo corrí completo en un simulador de la API de Roblox: la ciudad se genera, los 4 niveles de bodega se construyen y el servidor arranca sin un solo error.
