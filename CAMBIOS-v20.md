# 🧹 v20 — Los 5 bugs

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

## 1. 🏭 La prensa atorada + el piso amarillo

### El pistón

Bug bueno. El código leía la posición del pistón **al empezar cada animación** para saber
a dónde regresarlo:

```lua
local top = piston.Position   -- ← aquí estaba el problema
```

Si prensabas otra vez mientras el pistón iba bajando, esa lectura agarraba la posición
**de abajo** y la tomaba como "arriba". Entonces bajaba otros 3 studs desde ahí. Prensa
tras prensa se iba hundiendo hasta quedarse pegado.

Ahora la altura de reposo se guarda **una sola vez** cuando se construye la máquina, y
hay una bandera para que dos animaciones no se encimen. Al terminar, el pistón se
reposiciona a la fuerza por si el tween quedó a medias.

### El piso

Era un cuadro neón naranja gigante. Lo cambié por un **tapete de taller**: hule gris
oscuro con **franjas de peligro amarillas y negras** en las cuatro orillas, como las que
marcan zona de maquinaria en un taller de verdad.

## 2. 🔐 La caja fuerte se mudó

Tienes razón, estaba plantada en medio de la nada. Ahora va **pegada a la pared del
fondo, al lado del escritorio** — todo el centro de operaciones junto. La puerta mira
hacia adentro del cuarto y el tapete verde está enfrente.

### Y qué es la "zona segura"

Buena pregunta, porque el letrero no lo decía. **Es donde te escondes cuando traes mucho
Heat**: parado ahí tu Heat baja mucho más rápido que en cualquier otro lado. Es tu
escondite para cuando Aduanas te anda buscando.

Ya lo dice el letrero: **"ZONA SEGURA - escóndete aquí para bajar tu HEAT"**.

## 3. 📦 "Almacén lleno" pero se veía 0

Este fue culpa mía de la v18. Cuando metí la caja fuerte cambié los tres chips del HUD
para que mostraran **lo que traes cargando**. Como la carga empieza en 0 y todo lo que
produces se va directo a la caja, veías `0 · 0 · 0/80` **con la caja a reventar**.

Y cuando intentabas guardar, te decía "no tienes nada" — porque era cierto: no traías
nada encima, ya estaba todo guardado.

Arreglado:
- Los chips ahora muestran **lo que tienes en la caja** (que es lo que te importa)
- El chip de la mochila sigue mostrando lo que cargas
- El mensaje de lleno ahora dice el número: *"Tu caja fuerte está llena (450/450). Saca
  producto y véndelo, o mejora la bodega"*
- El de guardar aclara: *"No traes hojas encima. Lo que produces ya se guarda solo en la caja"*
- **Subí el almacén base de 200 a 450**, porque con 4 mesas se llenaba en nada

## 4. 🛒 El mercado roto

El limpiador de la tienda borraba solo los `Frame`:

```lua
if c:IsA("Frame") then c:Destroy() end
```

Los títulos de sección son `TextLabel`, no `Frame` — así que **nunca se borraban**. Cada
vez que abrías el mercado se apilaba otro "MOCHILAS · actual: Bolsillos (80)" encima del
contenido. Por eso viste cuatro.

Ahora borra todo lo que sea `GuiObject`.

## 5. 👷 Los cosechadores

### Ya no hablan

Los creaba con la misma función que a los compradores, y esa función les pone el tag
`BuyerNPC`. Por eso te salía *"Que onda. ¿Tienes mercancía?"* y el *"Presiona F para
vender"* — el juego los trataba como vendedores. Ya se les quita el tag.

### Ya no flotan

Los rigs de Roblox se colocan **por los pies**, no por el centro. Yo estaba usando la
altura de la mesa (que está elevada), así que quedaban 3 studs en el aire. Ahora se
paran en el piso.

### 🗣️ Guiri guiri guiri

Jajaja sí te entendí. Cuando un NPC te habla, ahora suena un **blip corto por cada par
de letras** mientras el texto se va escribiendo, y el tono cambia al azar en cada uno.
El resultado es que parece que están balbuceando algo — pero no dicen nada.

No suena en los espacios, para que se escuche por sílabas y no como metralleta. El texto
ya se escribía dinámicamente desde antes; ahora también se oye.

> Ajustable en `GameConfig.Sounds.Blip` (volumen y tono).

---

## Cómo probar

1. **Prensa:** dale a prensar **cinco veces seguidas rápido**. El pistón debe volver
   siempre arriba y nunca hundirse. De paso mira el tapete nuevo.
2. **Caja:** entra a la bodega, debe estar junto al escritorio pegada a la pared.
3. **Almacén:** cosecha. Los chips de arriba deben subir. Cuando se llene te va a decir
   el número exacto.
4. **Mercado:** ábrelo y ciérralo **cinco veces**. No se debe apilar nada.
5. **Cosechadores:** contrata uno. Debe estar **parado en el piso**, junto a su mesa, y
   **no** debe salirte diálogo de venta al acercarte.
6. **Guiri guiri:** acércate a un comprador en la ciudad y escucha el globo de texto.

---

## 🗺️ Lo que sigue

| Pendiente | Qué es |
|---|---|
| **Asaltos que roben de la caja fuerte** | Le daría sentido real a los guardias y a la alerta del celular |
| **Territorios de crews** | Zonas capturables + guerra entre crews |
| **Interiores de propiedades** | Las casas que compras son solo fachada |
| **Garaje real** | Un lugar físico para tus autos |
