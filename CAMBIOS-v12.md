# 📱 v12 — Adaptado para celular

## 📂 Abrir el archivo a copiar

### 1️⃣ [ClientUI.luau](StarterPlayerScripts/ClientUI.luau)
→ **StarterPlayer › StarterPlayerScripts › ClientUI**

> ⛔ Los otros 4 archivos **no cambiaron**. Solo reemplaza este.

---

## Lo que estaba mal

Revisé el UI y encontré esto:

| Problema | Por qué importa |
|---|---|
| 81 medidas en píxeles fijos | La tienda medía 620×460. Un celular acostado tiene ~414 de alto → **no cabía** |
| Botones abajo al centro | Ahí Roblox pone **su joystick** (abajo-izq) y el **botón de saltar** (abajo-der) |
| Botones de 38px de alto | Muy chicos para dedo (lo cómodo son ~44+) |
| Decían "Cosechar **[E]**" | No hay teclado en un celular |
| **Faltaba el botón de Mejoras** | Solo existía la tecla **G** → en celular era **imposible** usar la computadora |
| El teléfono se salía | Estaba posicionado a 540px del fondo, más que la altura de la pantalla |

---

## Lo que hice

### Detección automática

El juego ahora **detecta solo** si estás en táctil o en compu, y acomoda todo. **No tienes que hacer nada.** Un mismo script sirve para los dos.

### Los botones se van al costado derecho

En celular, los botones ya no están abajo. Ahora son una **rejilla de 2 columnas pegada al costado derecho, a media altura**. Ahí no estorban el joystick ni el salto.

También:
- Botones más altos (**46px** en vez de 38)
- Sin las letras de teclas: dice **"Cosechar"**, no "Cosechar [E]"
- **Se agregó el botón "Mejoras"** que faltaba

En compu todo sigue igual que antes, con su barra abajo y las teclas.

### Los paneles ahora siempre caben

Le metí un sistema que **mide la pantalla real** y encoge los paneles grandes lo necesario para que quepan, re-centrándolos. Se recalcula solo si giras el teléfono.

Aplicado a la **tienda** y al **teléfono**.

### Todo reacomodado para no encimarse

Como en celular el lado derecho ya lo ocupan los botones:

| Elemento | En celular |
|---|---|
| Llamada entrante | Se pasa al **lado izquierdo** y entra deslizándose desde ahí |
| Panel de encargo | Se va **arriba al centro** |
| Teléfono | Se **centra** en la pantalla |
| Diálogo de NPCs | Abajo al centro, un poco más arriba |
| Botones de la llamada | Más altos (54px) |

---

## 📲 Cómo probarlo

### Rápido, sin celular (dentro de Studio)

1. Pestaña **TEST** arriba
2. Botón **Device**
3. Arriba eliges el modelo (iPhone, iPad...) y la orientación
4. Le das **Play**

Así ves los controles táctiles y si algo se sale. Es lo más rápido para ir corrigiendo.

> Ojo: el emulador simula el **tamaño de pantalla y el táctil**, pero no el rendimiento real del teléfono.

### En tu celular de verdad

Tienes que **publicar** el juego. No hay forma de probarlo desde el teléfono sin subirlo.

1. En Studio: **File → Publish to Roblox As...**
2. Le pones nombre y le das crear
3. Ya publicado, ve a **create.roblox.com** → tu juego
4. Si quieres que solo entres tú, déjalo **privado**. Si quieres que entren amigos, ponlo **público**
5. Abre la **app de Roblox** en el celular con **tu misma cuenta**
6. Ve a tu perfil → **Creaciones**, o búscalo por nombre, y dale jugar

Cada vez que hagas un cambio en Studio tienes que darle **File → Publish to Roblox** otra vez para que se actualice en el teléfono.

---

## Cómo verifiqué esto

Corrí el UI completo en tres resoluciones simuladas:

| Dispositivo | Resultado |
|---|---|
| Escritorio 1920×1080 | ✅ carga, botones con `[E]` |
| Celular 896×414 | ✅ carga, botones sin teclas |
| Tablet 1180×820 | ✅ carga |

Y confirmé que el botón **Mejoras** aparece en ambos modos, y que el servidor sigue arrancando sin errores.

---

## Un consejo de rendimiento

Los celulares baratos pueden batallar con la ciudad completa. Si notas que va lento en tu teléfono, en **GameConfig** puedes:

- Bajar `GridX` / `GridZ` a **4** (ciudad más chica)
- En `addWindowGrid`, cambiar `floorH = 7` a `12` (menos ventanas)
- Reducir el `26` de `scatterTrash` (menos basura)

Pruébalo primero tal cual — puede que jale bien.
