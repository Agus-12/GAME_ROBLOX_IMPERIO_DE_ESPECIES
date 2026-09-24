# 🔧 Actualización v4 — NPCs vivos, callejón y pantalla de inicio

## 📂 Abrir los archivos a copiar

Dale clic a cada uno para abrirlo, luego `Cmd+A` → `Cmd+C` y pégalo en Studio.

### 1️⃣ [GameConfig.luau](ReplicatedStorage/GameConfig.luau)
→ pégalo en **ReplicatedStorage › GameConfig**

### 2️⃣ [CityGenerator.luau](ServerScriptService/CityGenerator.luau)
→ pégalo en **ServerScriptService › CityGenerator**

### 3️⃣ [Main.luau](ServerScriptService/Main.luau)
→ pégalo en **ServerScriptService › Main**

### 4️⃣ [ClientUI.luau](StarterPlayerScripts/ClientUI.luau)
→ pégalo en **StarterPlayer › StarterPlayerScripts › ClientUI**

> ⛔ **`DataService` NO lo toques**, no cambió.

> 💡 Si los enlaces no te abren nada, los archivos están en la barra lateral del
> workspace, en la carpeta `SpiceEmpire`. También puedes pedirme *"ábreme el CityGenerator"*
> y te lo pongo en pantalla.

---

## ⚡ Resumen de qué reemplazar

| Script | Dónde va en Studio |
|---|---|
| `GameConfig` | ReplicatedStorage |
| `CityGenerator` | ServerScriptService |
| `Main` | ServerScriptService |
| `ClientUI` | StarterPlayerScripts |

---

## 💰 El $0 — por fin resuelto

Mi arreglo anterior estaba incompleto. El problema real era de **timing en dos direcciones**:

El servidor mandaba tu dinero con `FireClient`, pero en Studio el `ClientUI` todavía
no había terminado de cargar. El mensaje se enviaba **al vacío** y se perdía para siempre.

**Ahora el cliente lo pide activamente.** Al cargar, manda `sync` al servidor hasta 30 veces
hasta recibir respuesta. Y el servidor re-sincroniza a todos cada 5 segundos como respaldo.

Ahora sí vas a ver tus **$500**.

---

## 🌱 El césped — ahora sí

Lo tenía en `y = -0.6`, o sea **enterrado** bajo las banquetas. Por eso desapareció.

Además el suelo era del tamaño exacto de la ciudad, así que ni asomaba por los bordes.

**Arreglado:** suelo más grande que la ciudad (sobresale 1.5 cuadras por lado), color
verde más vivo, y a una altura que no pelea con nada.

---

## 💡 Luces que se apagan de día

Tenías toda la razón: de día se veía **saturadísimo** con las ventanas encendidas.

Metí un sistema con `CollectionService`: cada luz se registra con un tag al crearse,
y el ciclo día/noche las prende y apaga automáticamente.

| Hora | Estado |
|---|---|
| 18:00 – 06:30 | 🌙 Todo encendido |
| 06:30 – 18:00 | ☀️ Todo apagado |

Las ventanas encendidas vuelven a ser **vidrio con reflejo** durante el día, en vez de
neón blanco quemado. Los postes de calle, letreros y lámparas también se apagan.

---

## 🧍 NPCs de verdad

Antes eran 6 cubos. Ahora cada comprador tiene:

- **Cuerpo completo**: cabeza con forma humana, cuello, cabello (adelante y atrás), **ojos**,
  torso, brazos con **manos separadas**, piernas con **zapatos**
- **4 apariencias** distintas: tonos de piel, camisa, pantalón y cabello combinados
- **Respiración animada** — el torso se expande y contrae sutilmente, ya no parece estatua
- Orientado para **mirarte** cuando te acercas

---

## 💬 Sistema de diálogo

Te acercas a menos de 22 studs y aparece una caja de diálogo con **efecto máquina de
escribir**. Lo que dice depende de tu situación:

| Situación | Ejemplo |
|---|---|
| Traes mercancía | *"Hey... traes algo para mi?"* |
| Vienes vacío | *"Vienes con las manos vacias? Largate."* |
| Estás BUSCADO | *"Traes a la Aduana encima. Vete de aqui."* |
| Después de vender | *"Buen material. Aqui esta tu parte."* |

Hay 3-5 frases por situación, elegidas al azar. Las puedes editar en `GameConfig` →
sección `Dialogue`.

---

## 🏚️ El callejón

Movi los puestos de la banqueta abierta a un **callejón al costado de cada cuadra**:

- **Rejas de alambre** cerrando el callejón por 3 lados
- **Contenedor de basura** verde con la tapa medio abierta
- **3 botes de basura** metálicos con tapas chuecas
- **22 pedazos de basura** regados: papeles, latas, bolsas, en ángulos aleatorios
- **Manchas de humedad** en el concreto
- **Tarimas de madera** recargadas contra la pared
- Piso de concreto sucio, más oscuro que la calle

Se ve mucho más turbio. 👌

---

## 🎬 Pantalla de inicio

Al entrar sale una pantalla con:
- Título **SPICE EMPIRE** en dorado sobre degradado
- Subtítulo: *"Cultiva. Prensa. Vende. Sobrevive."*
- **Tips rotativos** cada 3.5 segundos (6 tips distintos)
- Botón **ENTRAR AL BARRIO** que aparece cuando el juego terminó de cargar
- Se cierra sola a los 12 segundos si algo falla

---

## ⌨️ Controles

| Tecla | Acción |
|---|---|
| E / R / F | Cosechar / Prensar / Vender |
| B / T / H | Tienda / Teléfono / Bodega |
| M | Minimizar HUD |

---

## 🎛️ Ajustes rápidos

**¿Quieres las luces siempre prendidas?** En `CityGenerator`, busca:
```lua
setCityLights(t >= 18 or t < 6.5)
```
y cámbialo por `setCityLights(true)`.

**¿Diálogos personalizados?** En `GameConfig` → `Dialogue`. Agrega las frases que quieras
a cada lista.

**¿Más o menos basura?** En `CityGenerator`, busca `scatterTrash(props, ..., 22)` y cambia
el 22.

---

## ✅ Checklist al darle Play

Ve marcando. Si algo falla, dime cuál y lo arreglamos:

- [ ] Sale la **pantalla de inicio** dorada con el botón *ENTRAR AL BARRIO*
- [ ] El HUD muestra **$500** (no $0) ← *lo más importante*
- [ ] Se ve **césped verde** alrededor de la ciudad
- [ ] Es de día (14:30) y las ventanas **NO** están encendidas
- [ ] Al acercarte a un comprador sale el **diálogo escribiéndose**
- [ ] El NPC se ve como persona, no como cubos
- [ ] El puesto está en un **callejón con rejas y basura**
- [ ] El botón **Bodega [H]** te teletransporta
- [ ] Presionas **M** y el HUD se hace chiquito

### Si algo sale mal

Abre **View → Output** en Studio y mándame captura de lo que salga en **rojo**.
