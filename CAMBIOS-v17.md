# 🚲🎧 v17 — Bici anclada + sonidos profesionales

## 📂 Abrir los archivos a copiar

### 1️⃣ [GameConfig.luau](ReplicatedStorage/GameConfig.luau)
→ **ReplicatedStorage › GameConfig**

### 2️⃣ [Main.luau](ServerScriptService/Main.luau)
→ **ServerScriptService › Main**

> ⛔ `CityGenerator`, `DataService` y `ClientUI` no cambiaron.

---

## 1. 🚲 Ahora sí: le quité la física por completo

En la v16 te dije que le había quitado la colisión. **Me quedé a medias**, y por eso saliste volando.

Le quité la colisión, sí — pero la bici **seguía siendo un objeto físico**. Y seguía teniendo un pasajero: tú. Tu personaje va soldado al asiento y **tu personaje sí choca con el mundo**. Entonces el motor de física seguía teniendo de dónde agarrarse: yo le escribía la posición a la bici cada frame, la física la empujaba por otro lado, y las dos fuerzas peleando acabaron disparándote al cielo.

### Lo que hice ahora

**Anclé la bici.** Todas sus piezas, incluido el chasis.

Una pieza anclada en Roblox es intocable para el motor de física — no le puede aplicar fuerza, ni gravedad, ni rebotes. Literalmente **no existe una vía por la que te pueda mandar a volar.**

El precio es que ahora tengo que mover cada pieza a mano, así que guardo la posición de cada una respecto al chasis y las reacomodo cada frame. Es el mismo truco que usan las plataformas móviles y las ruedas de la feria — y, como ellas, **sí te lleva a ti sentado encima**.

El resto sigue igual que en la v16: rayo adelante para las paredes, rayo abajo para el piso, límite de escalón de 1.6 studs y gravedad propia si no hay suelo.

| Versión | Enfoque | Resultado |
|---|---|---|
| v10 | Bisagras con motor | Temblaba |
| v12 | Velocidad directa | Trepaba edificios |
| v14 | Velocidad horizontal + rayo | Se elevaba |
| v16 | Sin colisión, pero con física | **Salías volando** |
| **v17** | **Anclada, cero física** | — |

## 2. 🎧 Sonidos de verdad

Me pediste unos más bonitos, así que fui a buscarlos y **verifiqué uno por uno** contra la base de datos de Roblox: los 6 son audio público y funcionan.

Casi todos son de **ProSoundEffects**, una biblioteca profesional que Roblox subió gratis para todos los desarrolladores. No son sonidos genéricos, son grabaciones reales:

| Acción | Sonido | Qué es realmente |
|---|---|---|
| **Cosechar** | Foliage Crunchy Rustle | Hojarasca crujiendo — justo lo que pediste |
| **Prensar** | Metal Impact Sledge Hammer | Marrazo sobre una viga de acero de 5 pies |
| **Vender** | Cash Register 1 | Caja registradora de verdad, con cajón |
| **Comprar** | button.wav | Clic de botón (oficial de Roblox) |
| **Mejorar** | Candy Machine Coin Drops | Monedas cayendo en una máquina |
| **Aduanas te agarra** | Handcuff Movement | Esposas cerrando |

El de cosechar quedó a **1.20 de tono** para que suene seco y rápido, no como pisar hojas.

> Si alguno te parece muy fuerte o muy agudo, en `GameConfig.Sounds` cada uno trae su `Volume` y su `Pitch`. Y `Enabled = false` hasta arriba apaga todo.

---

## Cómo probar

**La bici** — móntate y haz lo peor que se te ocurra:
1. Estréllate de frente contra un edificio a toda velocidad
2. Métete entre dos paredes
3. Recórrela por las banquetas
4. Bájate a media calle y vuelve a subirte

No debe volar, ni flotar, ni trepar. Si algo se mueve raro, mándame la captura.

**Los sonidos:** cosecha, prensa y vende. Los tres deben sonar claramente distintos ahora.

Todo corrió en el simulador: servidor completo, los 4 niveles de bodega, la UI en escritorio/celular/tablet, y los 6 IDs de audio verificados contra la API de Roblox.

---

## 🗺️ Roadmap

| Pendiente | Qué es |
|---|---|
| **Territorios** | Zonas que los crews capturan y pelean |
| **Interiores de propiedades** | Las casas que compras son solo fachada |
| **Garaje de verdad** | Un lugar físico donde se guardan tus autos |
| ~~Sonido~~ | ✅ listo |
