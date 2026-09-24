# 🚩 v24 — Territorios: los crews ya tienen por qué pelear

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

## Este era el último feature grande de tu lista original

Pediste **"crews/equipos con amigos y guerra entre crews"**. Los crews existían desde
hace rato, pero solo servían para no dispararte con tus amigos. **No había nada por qué
pelear.** Ya lo hay.

## 🚩 Las 5 zonas ahora son territorios

Cada zona de compradores (Muelles, Mercado Viejo, Centro, Zona Alta, Cruce Norte) es
una **plaza que se puede tomar**.

En cada una hay un **mástil con bandera**. La bandera está gris cuando la plaza no tiene
dueño, y se pinta **del color del crew** que la domina. Abajo tiene un letrero que dice
quién manda ahí.

### Cómo se toma

1. Te paras dentro de la zona (46 studs alrededor del punto de venta)
2. **Aguantas 25 segundos**
3. La plaza es de tu crew

Te sale una **barra arriba de la pantalla** con el avance.

### Y aquí está la guerra

> **Si hay gente de otro crew dentro de la zona, la plaza queda EN DISPUTA y el avance
> se congela.**

Nadie captura nada mientras haya bronca. Tienen que correrse a balazos primero — para
eso está la Escuadra de la v21.

Si te sales de la zona a medio capturar, el avance **se va bajando solo**, así que no
puedes ir de a poquito.

## 💰 Para qué sirve tener plazas

| Beneficio | Cuánto |
|---|---|
| **Vendes más caro en tu propia plaza** | **+20%** encima del precio de la zona |
| **Renta pasiva** | **$140 por plaza**, cada 2 minutos, a todos los del crew |

Lo del +20% es lo interesante: el Cruce Norte ya paga ×1.90 de por sí. Si tu crew lo
controla, se vuelve la mejor zona del mapa por mucho — y por eso mismo todos van a
querer quitártela.

Cuando vendes en tu plaza el mensaje te lo dice: *"...por $4.2K **[+20% plaza propia]**"*.

## 📋 Pestaña "Plazas"

En la tienda hay una pestaña nueva con las cinco zonas: quién las tiene, cuáles están
en disputa y cuáles estás capturando.

## 🔔 Avisos

- Tu crew toma una plaza → *"TERRITORIO TOMADO"*
- Otro crew toma una → *"PERDIERON UNA PLAZA"*

---

## Cómo probar

Necesitas al menos **dos jugadores** para ver la disputa. En Studio: pestaña **TEST** →
**Clients and Servers** → 2 jugadores → Start.

1. Con el jugador 1, crea un crew (tienda → pestaña Crew)
2. Ve a una zona de compradores y **quédate parado** junto al mástil
3. Debe salir la barra de captura. A los 25 segundos la bandera cambia de color
4. Vende ahí: el mensaje debe traer el `[+20% plaza propia]`
5. Mete al jugador 2 (sin crew o con otro) a la misma zona → **EN DISPUTA**, el avance
   se congela

> Para probar más rápido, en `GameConfig.Territories` baja `CaptureSeconds = 25` a `5`.

---

## 🗺️ Roadmap

Con esto ya está **todo lo que pediste en el mensaje original**. Lo que queda son ideas
para crecerlo:

| Pendiente | Qué es |
|---|---|
| **Interiores de propiedades** | Las casas que compras son solo fachada |
| **Garaje real** | Un lugar físico para tus autos |
| **Música de fondo** | Los efectos ya están |
| **Tabla de crews** | Un ranking de quién domina más plazas |
