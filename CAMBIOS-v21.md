# 🔫 v21 — La balacera

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

## Esto es lo que pediste desde el primer mensaje

> *"un celular in-game que te avisa cuando atacan tu bodega, para que llegues y
> **se arme la balacera**"*

El celular ya te avisaba desde hace rato… pero cuando llegabas **no había nada**. El
asalto era un dado invisible: te descontaba producto y ya. Y de paso descubrí que
**el jugador ni siquiera podía disparar** — no existía ninguna arma en todo el juego.

Ya existe todo.

## 1. 🔫 Tienes arma

Todos traen una **Escuadra** desde que entran, y se repone sola cada vez que revives.
Sale en la barra de abajo de Roblox; la equipas y **clic para disparar**.

- En **celular** se apunta con la cámara y se dispara con el botón de la Tool
- Se ve la trayectoria del balazo
- 26 de daño, alcance 260, con su cadencia

> **Cómo está hecha, por seguridad:** el cliente solo dice *hacia dónde* apuntas. Quien
> traza el disparo y reparte el daño es **el servidor**, que además verifica que
> traigas el arma equipada y respeta la cadencia. Así nadie puede inventarse impactos
> desde el cliente.

## 2. 🥷 Los asaltantes son de verdad

Cuando suena la alerta, **a los 25 segundos llegan encapuchados** a tu bodega:

- Vienen **2 + 1 por cada nivel de bodega** (entre más grande, más jugosa)
- **Caminan hacia tu caja fuerte**
- Si te les pones enfrente, **te disparan**
- Si les bajas la vida, caen

### La cuenta regresiva

Si llegan a la caja, **no te roban al instante**: la tienen que abrir.

> *"ESTÁN EN LA CAJA — Llegaron a tu caja fuerte. Tienes 16 segundos."*

Ahí es donde se decide. Si los bajas a todos antes de que la abran, **no pierdes nada**
y encima te quedas con lo que traían:

> *"ASALTO REPELIDO — Los bajaste a todos. Te quedaste con $1.2K de lo que traían."*

Si no llegas, te vacían el 35% de la caja.

## 3. 🛡️ Los guardias por fin sirven

Antes un guardia solo bajaba un número de probabilidad, invisible. Ahora, **cuando hay
asalto, tus guardias contratados aparecen plantados junto a la caja fuerte y disparan
solos** al asaltante más cercano.

Siguen bajando la probabilidad de que te asalten, pero ahora además **pelean por ti**.
Si no estás en línea para defender, ellos son tu única esperanza.

| | Daño | Alcance | Cada |
|---|---|---|---|
| Tú | 26 | 260 | 0.26s |
| Guardia | 12 | 70 | 1.3s |
| Asaltante | 9 | 12 | 1.4s |

---

## Cómo probar sin esperar

En **GameConfig**, sección `Raids`:

```lua
CheckInterval = 20,    -- en vez de 90
BaseChance = 1,        -- asalto garantizado
WarnSeconds = 8,       -- que no tarde tanto en llegar
```

Entra, espera unos segundos y prepárate. **No se te olvide regresarlos** a `90`, `0.18`
y `25` cuando acabes de probar.

Para probar a los guardias: contrata 2 o 3 y **quédate lejos de la bodega** a ver si
aguantan solos.

---

## Detalles

- Solo puede haber **un asalto a la vez** por jugador
- Hay una red de seguridad a los **2 minutos**: si algo se atora, el asalto se resuelve
  y se limpia todo, para que no queden asaltantes vagando por el mapa
- Al salirte del juego se limpian tus asaltantes y guardias

> Todo ajustable en `GameConfig.Raids` y `GameConfig.Weapon`.

---

## 🗺️ Roadmap

| Pendiente | Qué es |
|---|---|
| **Territorios de crews** | Zonas capturables + guerra entre crews |
| **Interiores de propiedades** | Hoy son solo fachada |
| **Garaje real** | Un lugar físico para tus autos |
| **Música de fondo** | Los efectos ya están |
