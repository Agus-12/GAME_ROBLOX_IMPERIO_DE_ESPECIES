# 🚲🔊 v16 — Bici rehecha desde cero + sonido

## 📂 Abrir los archivos a copiar

### 1️⃣ [GameConfig.luau](ReplicatedStorage/GameConfig.luau)
→ **ReplicatedStorage › GameConfig**

### 2️⃣ [Main.luau](ServerScriptService/Main.luau)
→ **ServerScriptService › Main**

### 3️⃣ [ClientUI.luau](StarterPlayerScripts/ClientUI.luau)
→ **StarterPlayer › StarterPlayerScripts › ClientUI**

> ⛔ `CityGenerator` y `DataService` no cambiaron.

---

## 1. 🚲 La bici: cambié de estrategia por completo

Llevo **tres intentos** arreglando esto y los tres fallaron igual. Vale la pena que sepas por qué, porque el patrón era el mismo:

| Intento | Qué hice | Cómo falló |
|---|---|---|
| v10 | Bisagras con motor | Temblaba |
| v12 | Velocidad directa | Se trepaba a los edificios |
| v14 | Velocidad solo horizontal + rayo antiparedes | **Se sigue elevando** |

### La causa de fondo

Todos los intentos tenían algo en común: **la bici chocaba físicamente con el mundo**.

Cuando empujas una caja con mucha fuerza contra una pared, el motor de física de Roblox tiene que resolver ese choque de alguna forma. Y como le estaba prohibiendo moverse hacia los lados (le fijaba la velocidad horizontal con fuerza 120,000), **la única salida que le quedaba era hacia arriba**. Por eso escalaba edificios.

Mi rayo antiparedes de la v14 sí detectaba el muro, pero llegaba tarde: para cuando frenaba, la caja ya estaba encajada y el solver ya la había empujado hacia arriba.

### La solución

**Le quité la colisión a la bici por completo** y ahora calculo su posición yo, a mano:

1. **Rayo hacia adelante** → ¿hay pared? Frena antes de tocarla.
2. **Rayo hacia abajo** → busca el piso y coloca la bici exactamente encima.
3. **Límite de escalón (1.6 studs)** → si el "piso" de adelante está más alto que eso, no es una banqueta, es una pared: no avanza **ni se sube**.
4. Si no hay piso debajo, **cae** con gravedad propia.

Esto ya no es física, es geometría. **No hay forma de que se eleve**, porque la altura la escribo yo en cada frame y siempre sale de un rayo que encontró suelo de verdad.

Efectos secundarios buenos:
- Ya no flota cuando la dejas estacionada (ahora se pega al piso aunque no la estés usando)
- Sube banquetas y rampas normal
- Ya no se atora ni tiembla
- Se inclina suave al dar vuelta

> **Si quieres que suba escalones más altos**, sube `MAX_STEP = 1.6` a `2.5`. Pero ojo: entre más alto, más fácil se vuelve trepar cosas que no debería.

## 2. 🔊 Sonido

Ya tiene efectos. Suenan cuando:

| Acción | Sonido |
|---|---|
| Cosechar hojas | Corte seco |
| Prensar | Golpe grave |
| Vender | Ping de caja registradora |
| Comprar / contratar | Clic |
| Mejorar bodega | Golpe grave agudo |
| Acción fallida | Clic apagado |
| Te agarra Aduanas | Quejido |

Le puse una variación chiquita de tono en cada reproducción para que no suene robótico cuando cosechas diez veces seguidas.

### 🎵 Cómo cambiarlos por unos mejores

Usé sonidos que **ya vienen dentro de Roblox** para que te funcionen sin subir nada. Están bien pero son básicos.

Para ponerle unos buenos, en **GameConfig** busca `GameConfig.Sounds` al final del archivo. Cada uno se ve así:

```lua
Sell = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.75, Pitch = 1.15 },
```

1. En Studio, abre la pestaña **Creador** (arriba) → **Audio**
2. Busca lo que quieras, por ejemplo "cash register"
3. Dale clic derecho al que te guste → **Copy Asset ID**
4. Pégalo así:

```lua
Sell = { Id = "rbxassetid://1234567890", Volume = 0.75, Pitch = 1.15 },
```

- `Volume` → qué tan fuerte (0 a 1)
- `Pitch` → más de 1 es más agudo, menos de 1 más grave

Y si quieres **apagar todo el sonido**, hasta arriba de esa sección:

```lua
Enabled = false,
```

---

## Cómo probar

**La bici** (esto es lo importante):
1. Sácala y **estréllate de frente contra un edificio**. Debe frenar en seco y quedarse abajo.
2. Recórrela por la banqueta — debe subirse y bajarse normal.
3. Bájate y déjala. Debe quedar **apoyada en el piso**, no flotando.
4. Intenta subirla por una pared a propósito. No debe dejarte.

**El sonido:** cosecha, prensa y vende. Cada uno suena distinto.

Todo corrió en el simulador: servidor completo, los 4 niveles de bodega, y la UI en escritorio, celular y tablet.

---

## 🗺️ Roadmap

| Pendiente | Qué es |
|---|---|
| **Territorios** | Zonas que los crews capturan y pelean |
| **Interiores de propiedades** | Las casas que compras son solo fachada |
| **Garaje de verdad** | Un lugar físico donde se guardan tus autos |
| ~~Sonido~~ | ✅ listo |
