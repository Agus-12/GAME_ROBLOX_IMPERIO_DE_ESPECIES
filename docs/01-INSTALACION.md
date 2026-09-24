# 🌶️ SPICE EMPIRE — Entrega 1

Mundo abierto estilo GTA + tycoon. Produces hojas de especia, las prensas en bloques,
las vendes por la ciudad, evitas a la Unidad de Aduanas, defiendes tu bodega de asaltos
y armas crew con tus amigos.

---

## 📦 Instalación en Roblox Studio (10 minutos)

Abre Roblox Studio → **Nuevo lugar (Baseplate)**. Luego:

### 1. GameConfig
1. En el **Explorer**, clic derecho en `ReplicatedStorage` → **Insert Object** → **ModuleScript**
2. Renómbralo a **`GameConfig`** (exacto, con mayúsculas)
3. Borra lo que trae y pega TODO el contenido de `../ReplicatedStorage/GameConfig.luau`

### 2. CityGenerator
1. Clic derecho en `ServerScriptService` → **ModuleScript**
2. Nómbralo **`CityGenerator`**
3. Pega `../ServerScriptService/CityGenerator.luau`

### 3. DataService
1. Clic derecho en `ServerScriptService` → **ModuleScript**
2. Nómbralo **`DataService`**
3. Pega `../ServerScriptService/DataService.luau`

### 4. Main
1. Clic derecho en `ServerScriptService` → **Script** (¡Script normal, NO ModuleScript!)
2. Nómbralo **`Main`**
3. Pega `../ServerScriptService/Main.luau`

### 5. ClientUI
1. En el Explorer abre `StarterPlayer` → `StarterPlayerScripts`
2. Clic derecho → **LocalScript** (¡LocalScript, importante!)
3. Nómbralo **`ClientUI`**
4. Pega `../StarterPlayerScripts/ClientUI.luau`

### 6. Activar el guardado
1. Menú **Home** → **Game Settings** → pestaña **Security**
2. Activa **Enable Studio Access to API Services**
3. Guarda

### 7. Borra el Baseplate
El mapa se genera solo. Borra el `Baseplate` y el `SpawnLocation` que trae por defecto.

### ▶️ Dale Play
Deberías ver la ciudad construirse sola y aparecer en tu bodega.

En la ventana **Output** (menú **View › Output**) tiene que salir:

```
========== IMPERIO DE ESPECIAS v28 ==========
  remotes creados: 11
```

Si sale otro número, o no sale esa línea, es que un archivo quedó viejo: mira
[`08-SI-SALE-FALTAN-REMOTES.md`](08-SI-SALE-FALTAN-REMOTES.md).

---

## 📋 Cómo copiar los archivos desde GitHub

El repo es **público**, así que puedes copiar sin iniciar sesión:

👉 **https://github.com/Agus-12/GAME_ROBLOX_IMPERIO_DE_ESPECIES**

1. Entra a la carpeta (`ReplicatedStorage`, `ServerScriptService` o `StarterPlayerScripts`).
2. Haz clic en el archivo (por ejemplo `Main.luau`).
3. Arriba a la derecha del contenido hay un **ícono de copiar** 📋. Dale.
4. En Studio: selecciona el script → **`Ctrl+A`** (selecciona TODO) → **`Ctrl+V`**.

> ⚠️ **Las 5 piezas se pegan siempre juntas y de la misma ronda.** Nunca mezcles un
> archivo de una ronda con otro de otra: es la causa #1 de que "no abra nada".
> Si te sale un **cartel rojo** en pantalla, el juego te dice exactamente qué falta.

---

## 🩺 Si algo sale mal

| Síntoma | Qué pasa | Solución |
|---|---|---|
| Cartel rojo *"FALTAN SCRIPTS/REMOTES"* | Hay archivos de rondas distintas pegados en Studio | Pega los 5 de la ronda actual, completos. Ver [`08-SI-SALE-FALTAN-REMOTES.md`](08-SI-SALE-FALTAN-REMOTES.md) |
| Cartel rojo *"ARCHIVOS VIEJOS EN STUDIO"* | Igual, y además el juego te dice **cuál** archivo quedó viejo | Pega ese archivo |
| La línea `IMPERIO DE ESPECIAS vNN` no sale en Output | El `Main.luau` pegado no es el de esta ronda | Pega `Main.luau` |
| `remotes creados: 9` (o menos de 11) | Igual: `Main.luau` viejo | Pega `Main.luau` |
| No pasa nada al acercarme a la computadora | Algún script no corrió | Revisa Output y el cartel rojo |
| **Todo sale doble** (dos bodegas, dos barras de botones, dos avisos) | Hay **copias pegadas** en Studio: quedó el archivo viejo y el nuevo | [`09-SI-SALE-DOBLE.md`](09-SI-SALE-DOBLE.md): deja 1 `Main`, 1 `ClientUI`, 1 `GameConfig`, 1 `CityGenerator`, 1 `DataService` |
| Sale un `warn` con *"HAY COPIAS PEGADAS EN STUDIO"* | Igual: sobra una copia de un script | Idem |

---

## 🎮 Controles

| Tecla | Acción |
|---|---|
| **E** | Cosechar hojas |
| **R** | Prensar hojas → bloques |
| **F** | Vender (parado en un comprador) |
| **B** | Abrir tienda |
| **T** | Abrir teléfono |
| **H** | Teletransporte a tu bodega |

---

## 🔁 El loop del juego

1. **Cosecha** hojas en tu bodega (E). Más parcelas = más hojas por cosecha.
2. **Prensa** 6 hojas → 1 bloque (R). Los bloques valen 180 vs 25 de la hoja.
3. **Maneja** a la ciudad y vende en uno de los 5 compradores (F).
4. Cada venta te sube el **Heat**. Los compradores que pagan más son los que más Heat dan.
5. Si el Heat pasa de 70 → **BUSCADO**. Si te agarran: multa del 18% + decomiso del 50% + 20s en la celda.
6. Escóndete en la **Zona Segura** de tu bodega para bajar el Heat rápido.
7. Reinvierte: parcelas, prensa, empleados, autos, propiedades.

### Los 5 compradores

| Zona | Precio | Riesgo |
|---|---|---|
| Muelles | x0.85 | x0.5 |
| Mercado Viejo | x1.00 | x1.0 |
| Centro | x1.35 | x1.8 |
| Zona Alta | x1.60 | x2.4 |
| Cruce Norte | x1.90 | x3.2 |

---

## 📱 El teléfono

Te llegan alertas en tiempo real:
- 🔴 **ASALTO EN CAMINO** → tienes 25 segundos para llegar a tu bodega y defenderla
- 🔴 **TE ROBARON** → no llegaste, se llevaron el 35%
- 🟢 **BOTÍN** → mataste a alguien y le quitaste su carga
- 🟡 **RENTAS** → cobraste tus propiedades

---

## ⚔️ PvP y Crews

- Al matar a otro jugador le quitas **40% de su carga** y **10% de su efectivo**
- Los miembros de un mismo **crew** NO se roban entre sí
- Máximo 6 por crew. Se crean en Tienda → pestaña **Crew**
- Para unirte: escribe el **nombre del jugador líder** y dale "Unirme al jugador"

> ⚠️ El PvP necesita armas. Ve al **Toolbox** (View → Toolbox), busca "gun" o "sword",
> arrastra una al `StarterPack` y ya. El sistema de robo detecta el kill solo.

---

## 🏢 Progresión

**Empleados** (producen solos, sin que estés conectado en la sesión):
- Cosechador: +3 hojas cada 6s (máx 8)
- Prensador: +1 bloque cada 10s (máx 6)
- Guardia: −12% riesgo de asalto cada uno (máx 5)

**Autos:** Van $8K → Sedán $20K → Pickup $45K → Deportivo $150K

**Propiedades:** Depa $25K → Casa $90K → Bodega Extra $200K → Mansión $750K
(dan renta cada minuto + espacio de almacén)

---

## 🌅 Ciclo día/noche

Un día completo dura **12 minutos reales** por defecto. El servidor arranca a las 2 PM.

La ciudad cambia de verdad: de día el cielo es azul claro, al atardecer se pone naranja,
y de noche se encienden las ventanas de los edificios, los postes de luz, las luces rojas
de aviación en las torres altas y los haces de luz de los compradores.

Arriba a la izquierda tienes un **reloj** que marca la hora del juego.

### Ajustarlo

En `GameConfig` → sección `DayNight`:

```lua
Enabled = true,          -- false = hora fija, sin ciclo
DayLengthMinutes = 12,   -- súbelo a 30 para días más largos
StartHour = 14,          -- hora de arranque (14 = 2 PM)
FixedHour = 14,          -- se usa solo si Enabled = false
```

**¿Quieres que siempre sea de noche?** (vibe más GTA)
```lua
Enabled = false,
FixedHour = 22,
```

---

## 🛠️ Balancear el juego

Todo está en **`GameConfig`**. Toca esos números y listo:
- ¿Muy lento? Sube `BasePrice` o baja `Growth` de los costos
- ¿Muy fácil escapar de la policía? Sube `PerBlockSold` o baja `DecayPerSecond`
- ¿Muchos asaltos? Sube `CheckInterval` o baja `BaseChance`
- ¿Ciudad más grande? Sube `GridX` y `GridZ` (ojo, 8x8 ya pesa)

---

## 🚫 Nota importante sobre el tema

El juego usa **especias** y **sal prensada** a propósito. Las reglas de Roblox prohíben
drogas ilegales y su venta — si lo reskineas a eso, el juego se elimina y la cuenta
se arriesga a baneo. La moderación automática revisa nombres de items y texto de UI.

El gameplay es idéntico. No cambies el naming y estás bien.

---

## 🔜 Entrega 2 (pendiente)

- NPCs de Aduanas que te persiguen físicamente (path finding), no solo el sistema de Heat
- Misiones/encargos con timer ("entrega 20 bloques en el Centro en 3 min")
- Territorios capturables entre crews
- Interiores de las propiedades
- Garaje real con los autos guardados
