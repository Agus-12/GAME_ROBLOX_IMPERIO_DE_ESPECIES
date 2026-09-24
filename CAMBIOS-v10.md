# 📞 v10 — Balance, celular deslizante, bici estable

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

---

## 1. Balance de hojas arreglado

Tenías razón, estaba roto. Eran **dos errores juntos**:

- Cada planta daba **3 hojas** (6 macetas × 3 = 18 por mesa)
- El radio de cosecha era **22 studs**, pero las mesas están a **18 studs** una de otra → agarrabas **varias mesas de un solo golpe**

Por eso te daba 50 de un jalón.

Ahora:
- **1 hoja por maceta** → **6 hojas por mesa**, justo como dijiste
- Radio bajado a **9 studs** → solo cosechas **la mesa en la que estás parado**

---

## 2. El celular ahora entra por la derecha, timbra y vibra

Ya no aparece un cuadrote en medio de la pantalla. Ahora:

- **Se desliza suave desde la derecha** con rebote, y queda pegado al borde
- **Timbra de verdad** con sonido (usa sonidos que Roblox ya trae, no tienes que subir nada)
- **Vibra**: se sacude cada segundo mientras nadie contesta, con su sonidito
- Cuando contestas o cuelgas, **se desliza de regreso** hacia afuera

Es más chico (300×340) y ya no te tapa el juego.

---

## 3. Bici: la reescribí con otro método

El problema de fondo eran las **bisagras con física**. Roblox las resuelve mal cuando hay muchas partes soldadas encima y por eso la bici se retorcía, se caía de lado y se enterraba en el piso.

Cambié el enfoque completo:

- Ahora hay un **chasis invisible** que es lo único con masa y colisión — la bici es **un solo cuerpo sólido**, imposible que se desarme
- Las piezas visibles van soldadas encima, sin peso ni colisión
- El movimiento ya **no depende de física de ruedas**: se controla con velocidad directa + un estabilizador que la mantiene siempre derecha
- Las ruedas **giran visualmente** según la velocidad
- Acelera y frena **suave** (no de golpe)
- **Solo gira si vas avanzando**, como una bici de verdad
- **Se inclina un poco al doblar**
- Aparece siempre **derecha**, sin importar la inclinación del piso

Controles: **W/S** para avanzar y frenar, **A/D** para girar.

---

## 4. Vigilante: ahora sí está recargado

Antes estaba parado tieso con los brazos colgando. Le puse **postura de verdad** moviendo las articulaciones:

- **Brazos cruzados** sobre el pecho
- Una **pierna flexionada**, apoyada en la pared
- La cabeza **voltea lento de un lado a otro**, vigilando (ya no la animación genérica que le desarmaba la pose)

Más lo que ya traía: todo de negro, chamarra de cuero, lentes, gorra y radio.

---

## 5. 💡 Lo de la luz — te faltaba abrir un panel

Encontré el problema en tu captura: **no tienes abierto el panel de Properties**. Le picaste al `+` de Lighting, y eso es para *insertar objetos*, no para ver propiedades.

Haz esto:

1. Arriba en la pestaña **VIEW** (View / Vista)
2. Le picas al botón **Properties**
3. Se te abre un panel nuevo, normalmente abajo a la derecha
4. **Ahora sí** le picas una vez a `Lighting` en el Explorer
5. En el panel de Properties buscas **Technology**
6. Lo cambias a **Future**

> Si no encuentras "Technology" en la lista, escribe `tech` en la barra de **Filter Properties** que está hasta arriba del panel.

**Esto es opcional.** Solo hace que las luces se vean más bonitas (sombras reales). El juego funciona igual sin eso.

---

## Ajustes rápidos

En **GameConfig**:

| Quiero... | Cambia |
|---|---|
| Más/menos hojas por maceta | `Growth.LeavesPerPlant` (ahora 1) |
| Que las plantas crezcan más rápido | `Growth.TimePerPlant` (ahora 24 seg) |
| Cosechar más mesas de un golpe | `Growth.HarvestRadius` (ahora 9 — **no lo subas arriba de 17**) |
| Que te llamen más seguido | `MissionCalls.MinWait` / `MaxWait` (ahora 300/600 seg) |
| Probar la llamada ya | `MissionCalls.FirstCallWait` → ponlo en `10` |

---

## Cómo probar

- **Balance:** párate en UNA mesa, aprieta **E**. Deben ser ~6 hojas, no 50.
- **Celular:** baja `FirstCallWait` a `10`, entra y espera. Debe deslizarse por la derecha timbrando y vibrando.
- **Bici:** **H** → Bodega → botón de bici. Sal, súbete, muévete con WASD. Ya no debe temblar ni caerse.
- **Vigilante:** sal de la bodega y voltea a la izquierda. Brazos cruzados, volteando lento.

Todo corrió completo en el simulador: ciudad generada, los 4 niveles de bodega y servidor arrancado sin errores.
