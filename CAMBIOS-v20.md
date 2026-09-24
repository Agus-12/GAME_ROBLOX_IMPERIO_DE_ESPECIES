# 🐛 v20 — Los 5 bugs

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

## 1. 🏭 La prensa se quedaba pegada

**La causa:** el código leía la posición del pistón **en el momento de prensar** y la
guardaba como "su lugar de arriba". Si prensabas otra vez mientras seguía bajando,
guardaba la posición **ya hundida** como si fuera la de reposo. A la tercera o cuarta
prensada el pistón estaba enterrado en la máquina y ya no volvía nunca.

Dos arreglos:
- La altura de reposo ahora se **graba al construir la bodega** y nunca cambia
- Un candado impide que dos prensadas se encimen, y al final el pistón se **coloca
  exacto** en su sitio por si el tween se interrumpió

### Y el piso amarillo ya no está

Era un cuadro de neón naranja de 16×16 que encandilaba toda la zona. Ahora es un
**tapete de hule de taller** gris oscuro, con dos franjas amarillas de peligro a los
costados, como los de un taller mecánico.

## 2. 🔐 La caja fuerte contra la pared

La moví a la **pared del fondo, al lado del escritorio con la computadora**. La puerta y
el volante ahora miran hacia adentro del cuarto, y la pantallita también.

### Qué es la "zona segura"

Buena pregunta, porque **nada te lo decía**. Sí hace algo:

> **Parado ahí, tu HEAT baja mucho más rápido.** Es el escondite: cuando andas caliente
> y la Unidad de Aduanas te trae ganas, te metes ahí a que se enfríe.

Por eso está el sillón. Ahora el letrero lo dice: *"ZONA SEGURA — escóndete aquí para
bajar el HEAT"*. Y el de la caja dice *"CAJA FUERTE [C] — aquí no te la quita Aduanas"*.

## 3. 📊 El HUD te estaba mintiendo

**Este era mi bug y era feo.** Cuando metí la caja fuerte en la v18, cambié los chips de
arriba para que mostraran **lo que traes cargando**… pero el mensaje de "almacén lleno"
habla de **la caja**. Entonces veías `0` y el juego te decía que estabas lleno. Las dos
cosas eran ciertas, simplemente no te estaba enseñando el número correcto.

Ahora hay **cuatro chips**:

| Chip | Qué es |
|---|---|
| 🟢 verde | Hojas **en la caja** |
| ⬜ crema | Bloques **en la caja** |
| 🟩 menta | **Espacio de la caja** (`157/200`) — se pone rojo si está llena |
| 🎒 azul | Lo que **traes encima** (`0/80`) |

Y el texto largo ahora dice `CAJA FUERTE ... <<< LLENA` cuando se acabó el espacio.

> También corregí que el cliente contaba un bloque como 1 de espacio y el servidor como
> 3. Ahora los dos cuentan 3, así que el número por fin cuadra.

Y el mensaje cambió por uno que sí ayuda:
*"Tu caja fuerte está llena. Prensa las hojas en bloques o mejora la bodega"*.

## 4. 🛒 El mercado roto

**La causa:** al cambiar de pestaña, el código borraba lo dibujado… pero **solo los
marcos**, no los textos sueltos. Los títulos que agregué en la v18 y v19 (el de
"MOCHILAS") eran textos sueltos, así que **nunca se borraban** y se iban apilando encima
de todas las pestañas. Por eso veías "MOCHILAS" cuatro veces debajo de los autos.

Ahora borra **todo** lo que se dibujó antes.

## 5. 👷 Los cosechadores

**Ya no hablan.** Los estaba creando con la misma función que a los compradores, y se
llevaban la etiqueta de "comprador" pegada — por eso te salía *"Que onda. ¿Tienes
mercancía?"* y *"Presiona F para vender"* con un cosechador. Ahora se les quita.

**Ya no flotan.** Los estaba parando a la altura de la mesa en vez de la del piso
(3.7 studs arriba). Mismo arreglo para los prensadores.

### 🗣️ Y la vocecita

Los que **sí** hablan (compradores y el vigilante) ahora tienen voz: un blip corto que
suena **cada dos letras mientras el texto se escribe**, con el tono movido al azar en
cada golpe. Da justo ese *"guiri guiri guiri"* de los juegos viejos — hablan sin decir
nada.

El texto ya se escribía letra por letra desde antes; lo que faltaba era el sonido. Le
bajé un poquito la velocidad para que se alcance a oír.

> Ajustable en `GameConfig.Sounds.Talk` (volumen y tono base).

---

## Cómo probar

1. **Prensa:** dale a R como loco, cinco veces seguidas. El pistón debe volver siempre
   a su lugar.
2. **Piso:** ya no hay cuadro naranja; es tapete gris con franjas amarillas.
3. **Caja:** está pegada a la pared del fondo junto a la computadora.
4. **HUD:** cosecha y fíjate que suba el chip verde y el de espacio.
5. **Mercado:** cambia entre todas las pestañas varias veces. No se debe apilar nada.
6. **Cosechadores:** párate junto a uno — **no** debe salir globo de diálogo, y debe
   estar pisando el piso.
7. **Voz:** acércate a un comprador en la ciudad. Debe hablar con blips.

---

## 🗺️ Roadmap

| Pendiente | Qué es |
|---|---|
| **Asaltos que roben de la caja fuerte** | Le daría sentido a los guardias y a la alerta del celular |
| **Territorios de crews** | Zonas capturables + guerra |
| **Interiores de propiedades** | Hoy son solo fachada |
| **Garaje real** | Un lugar físico para tus autos |
