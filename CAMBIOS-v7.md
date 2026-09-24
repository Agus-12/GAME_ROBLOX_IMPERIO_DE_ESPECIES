# 🚔 v7 — Policías que te persiguen + Encargos con timer

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

## 🚔 Agentes de Aduanas (lo que pediste desde el principio)

Antes el arresto era invisible: un dado que se tiraba solo y ¡pum!, estabas en la celda.
**Ahora son NPCs físicos que te cazan por la ciudad.**

### Cómo funciona

| Tu Heat | Qué pasa |
|---|---|
| < 55 | Tranquilo |
| ≥ 55 | Empiezan a aparecer agentes cerca de ti |
| ≥ 70 | Ya estás BUSCADO |

- Aparecen a **120 studs** de ti, en un punto válido del suelo (raycast)
- Usan **PathfindingService** real: rodean edificios, suben banquetas, saltan
- Caminan a **19** (tú a 16) — te alcanzan si corres en línea recta
- Recalculan tu posición constantemente
- Si te llegan a **8 studs** → arresto: multa, decomiso y celda
- Máximo **3 agentes** a la vez

### Cómo escapar

1. **Aléjate 320 studs** → se rinden
2. **Aguanta 45 segundos** → se rinden
3. **Baja tu Heat** a menos de 35 → dejan de buscarte
4. **Métete a tu Zona Segura** → el Heat baja rapidísimo
5. **Mátalos** 🔫 → tienen 120 de vida. Bajas 18 de Heat, pero mandan más

### Cómo se ven

Uniforme azul marino, chaleco táctico, gorra con visera, lentes oscuros, placa dorada
en la espalda y un **faro azul parpadeante** sobre la cabeza para que los ubiques de lejos.
Letrero flotante que dice **ADUANAS**.

Al rendirse se **desvanecen** en vez de desaparecer de golpe.

---

## 📋 Encargos con timer

Cada cierto rato te llega un encargo al teléfono. Aparece un **panel arriba a la derecha**
con cuenta regresiva.

### Los 3 tipos

| Encargo | Qué pide | Tiempo | Paga | Heat |
|---|---|---|---|---|
| **Entrega urgente** | 3-8 bloques | 3 min | x2.2 | ↓ 0.6 |
| **Pedido a granel** | 40-120 hojas | 4 min | x1.9 | ↓ 0.5 |
| **Entrega caliente** | 5-12 bloques | 2.5 min | **x3.4** | ⚠️ x1.8 |

El encargo te dice **a qué comprador** llevarlo. Si vendes ahí la cantidad pedida antes
de que acabe el tiempo, cobras el bono **encima** del precio normal.

La *Entrega caliente* paga muchísimo pero te sube el Heat casi al doble — o sea que
probablemente termines con agentes encima. Ese es el punto. 😈

El timer se pone **rojo** en los últimos 30 segundos.

---

## 🎛️ Ajustes

En `GameConfig` → sección `Agents`:

```lua
Enabled = true,          -- false los apaga por completo
MaxActive = 3,           -- cuántos a la vez
SpawnHeat = 55,          -- a qué Heat empiezan a salir
WalkSpeed = 19,          -- súbelo a 24 para modo pesadilla
CatchDistance = 8,       -- qué tan cerca deben llegar
GiveUpDistance = 320,    -- a qué distancia se rinden
GiveUpTime = 45,         -- o a los cuántos segundos
Health = 120,            -- qué tan duros son
```

Y en `Missions`:
```lua
Enabled = true,
CooldownAfterFinish = 25,   -- pausa entre encargos
```

---

## ✅ Cómo probarlo rápido

Los agentes necesitan Heat alto, así que:

1. En `GameConfig` pon `StartingCash = 50000`
2. Dale Play, cosecha (E) y prensa (R) varias veces
3. Ve al **Cruce Norte** (el que paga x1.90) y vende — sube muchísimo el Heat
4. Cuando pases de 55, **empiezan a aparecer agentes**
5. Corre 🏃

Para el PvP contra ellos necesitas un arma del **Toolbox** (View → Toolbox → busca "gun"
→ arrástrala a `StarterPack`).

---

## 🔜 Lo que falta de la Entrega 2

- [ ] Territorios capturables entre crews
- [ ] Interiores de las propiedades
- [ ] Garaje real con tus autos guardados
- [ ] Sistema de sonido (sirenas, ambiente urbano)

Dime cuál sigue.
