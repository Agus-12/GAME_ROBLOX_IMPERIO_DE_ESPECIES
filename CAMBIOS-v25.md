# 🏢 v25 — La oficina, y los bugs que seguían vivos

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

## 1️⃣ Por qué no podías cosechar

Este era el bueno, y explica las dos cosas que notaste.

**La causa:** el juego medía la distancia **maceta por maceta**, con un radio de 9. Pero
la mesa mide 12 de ancho y las macetas están repartidas por todo el tablero. Parado
enfrente, **las macetas del fondo quedaban a más de 9** — o sea fuera de alcance. Si las
únicas maduras eran ésas, te decía *"Acércate a una mesa con plantas listas"*… estando
pegado a la mesa.

Y como nunca lograbas cosechar, **las plantas nunca se reseteaban**. Por eso "no volvían
a su estado de cortadas": no es que la animación fallara, es que **el corte nunca pasaba**.

**Ahora se cosecha por MESA.** El juego busca la mesa más cercana y corta todo lo maduro
de *esa* mesa, sin importar en qué maceta esté. El radio ahora se mide al centro de la
mesa (14).

Los mensajes también cambiaron para que digan la verdad:
- *"Acércate a una mesa de cultivo"* (no estás junto a ninguna)
- *"Esta mesa no tiene nada listo todavía"* (estás junto a una, pero está verde)

### Y la animación de los empleados

Tu caja fuerte estaba **llena** (100/100 y 50/50). Los cosechadores no pueden depositar
si no hay espacio, así que no cortaban — y por eso no los viste agacharse.

De paso arreglé lo contrario: antes hacían el gesto **aunque la caja estuviera llena**,
o sea la mímica sin producir nada. Ahora solo se agachan si de verdad van a guardar algo.

## 2️⃣ Los cosechadores dobles (de verdad esta vez)

En la v22 pensé que bastaba con barrer la bodega antes de recrearlos. No bastó.

**La causa real:** crear un muñeco **cede el hilo** en Roblox. `syncWorkers` se llama
desde tres lados, así que dos llamadas se intercalan: la segunda barre y empieza a crear
mientras la primera **sigue creando** los suyos. Los de la primera ya nadie los borra.

Ahora la función tiene **candado**: si ya se está ejecutando, la segunda llamada se
ignora. Y además barre por nombre, no solo por atributo, por si algún rig quedó suelto.

## 4️⃣ La oficina

Le hice caso a tu idea, y quedó mucho mejor que el cuadro tirado en el piso.

**La zona segura ahora es un cuarto de verdad** en la esquina trasera derecha, con:

- **Paredes y techo** propios
- **Puerta** con marco de madera y dintel, y un letrero que dice
  *"OFICINA — aquí baja tu HEAT"*
- **Piso de duela**
- **Cama** completa: base, colchón, cobija, almohada y cabecera
- **Buró con lamparita** encendida
- **Sillón** con cojines y **mesita de centro**, ya separados de la cama
- Luz cálida de techo

**Fuera los dos cuadros neón.** El tapete de la caja fuerte también dejó de ser el
cuadrito azul: ahora es un tapete gris de hule.

> Los estantes que caerían dentro de la oficina **se saltan solos**, así que el cuarto
> queda limpio en los cuatro niveles de bodega.

## 5️⃣ El chip de la caja se salía

El recuadro medía 86 px pero el texto trae los dos topes (`83/100 33/50`), así que los
bloques se pintaban **fuera** de la pastilla. Le di 150 px y le puse sus iconitos:
`83/100 🌿  33/50 🧱`. También ensanché la fila para que quepan los cuatro.

## 6️⃣ La pistola

Tenías razón, estaba enorme. **La reduje al 62%** y reacomodé el agarre para que se vea
proporcionada con el personaje.

---

## Cómo probar

1. **Vacía tu caja fuerte** (saca producto o véndelo) — si está llena nada funciona bien.
2. Párate frente a una mesa con plantas maduras y dale **E**. Debe cortar y las plantas
   deben encogerse y empezar de nuevo.
3. Contrata cosechadores y mira que **no haya dos en la misma mesa**. Cuando corten,
   deben agacharse.
4. Busca la **puerta de la oficina** en la esquina trasera derecha y métete.
5. Saca la pistola y compárala contigo.

---

## 🗺️ Roadmap

| Pendiente | Qué es |
|---|---|
| **Interiores de propiedades** | Las casas que compras son solo fachada |
| **Garaje real** | Un lugar físico para tus autos |
| **Música de fondo** | Los efectos ya están |
| **Tabla de crews** | Ranking de quién domina más plazas |
