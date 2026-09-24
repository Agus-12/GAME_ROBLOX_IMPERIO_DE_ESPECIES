# 🎨 v23 — Pase visual

> Segunda parte de tus 8 puntos. Aquí va todo lo que se veía feo o falso.

## 📂 Abrir los archivos a copiar

### 1️⃣ [CityGenerator.luau](ServerScriptService/CityGenerator.luau)
→ **ServerScriptService › CityGenerator**

### 2️⃣ [Main.luau](ServerScriptService/Main.luau)
→ **ServerScriptService › Main**

> ⛔ `GameConfig`, `DataService` y `ClientUI` no cambiaron.

---

## 1️⃣ El arma

Era literalmente **dos cajas**: una para la cacha y otra para el cañón. Ahora es una
pistola armada con 14 piezas:

- Corredera con su tapa superior y **cañón cilíndrico** asomando
- **Guardamonte y gatillo**
- **Miras** delantera y trasera
- **Cachas de madera** a los lados
- Base del cargador

Y le puse **fogonazo**: cuando disparas, la boca del cañón se ilumina un instante.

> 🐛 De paso arreglé un bug de la v21: el cañón se soldaba **antes** de colocarlo. El
> `WeldConstraint` congela la posición en el momento de crearse, así que la pieza
> quedaba pegada donde no era. Ahora todas las piezas se colocan primero y se sueldan
> después.

## 2️⃣ La zona segura

**Fuera el cuadro azul.** Era un rectángulo de neón turquesa de 16×16 tirado en el piso.
Ahora es un **tapete de tela** morado oscuro con su orilla, y la luz de la zona pasó de
verde neón a **luz cálida de sala**.

**Y el sillón ya parece sillón.** Antes era *un solo cubo* de 9×3×4 — por eso se veía
como una caja de cartón. Ahora está armado por piezas:

- Base, respaldo y dos brazos
- Dos cojines de asiento y dos almohadas
- Cuatro patitas de madera
- Y le puse una **mesita de centro** enfrente

## 4️⃣ Los cosechadores ya se agachan

Estaban parados como maniquíes. Ahora, **cada vez que cortan**, hacen el gesto: se
inclinan hacia la mesa y bajan los brazos, y regresan solos a su posición.

Está hecho moviendo las articulaciones del muñeco (los Motor6D del rig), así que no
depende de subir ninguna animación a Roblox. Tiene un candado para que no se encime el
gesto si le toca cortar otra vez antes de terminar.

## 5️⃣ La computadora y la silla

**El escritorio ya está pegado a la pared** — estaba a 9 studs, ahora a 4.2. Como todo
el mueble se construye relativo a ese punto, el monitor, la torre y la pantalla se
movieron con él.

**La silla ya no flota.** Antes era un asiento y un respaldo suspendidos en el aire. Le
agregué:

- **Columna central**
- **Base de estrella de 5 brazos**
- **Rueditas** en cada punta

## 6️⃣ Los estantes

Este estaba curioso: el código decía `-- postes` pero **nunca los creaba**. Eran tablas
flotando, y encima a 3 studs de la pared.

Ahora el rack:

- Va **pegado al muro**
- Tiene sus **4 postes verticales** de piso a techo
- Tiene **larguero de seguridad** al frente de cada entrepaño
- Las cajas están **alineadas** en los entrepaños, no regadas al azar
- Cada caja trae **fleje y etiqueta** para que no sean cubos pelones

---

## Cómo probar

1. **Saca el arma** y mírala de cerca. Dispara: debe verse el fogonazo.
2. Ve a la **zona segura**: tapete en vez de cuadro azul, sillón con cojines y mesita.
3. Ve al **escritorio**: pegado a la pared, silla con base de estrella.
4. Mira los **estantes** de las paredes: con postes, pegados al muro, cajas alineadas.
5. Contrata un cosechador y **quédate viéndolo**. Cuando una planta de su mesa madure,
   debe agacharse a cortarla.

---

## 🗺️ Roadmap

Ya no quedan pendientes visuales de tu lista. Lo que sigue son features nuevas:

| Pendiente | Qué es |
|---|---|
| **Territorios de crews** | Zonas capturables + guerra entre crews. Es el feature grande que falta del pedido original |
| **Interiores de propiedades** | Las casas que compras son solo fachada |
| **Garaje real** | Un lugar físico para tus autos |
| **Música de fondo** | Los efectos ya están |
