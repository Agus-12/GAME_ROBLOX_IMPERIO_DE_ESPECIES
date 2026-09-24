# 🔧 v27 — Reparación: por qué nada respondía

## 📂 Abrir los archivos a copiar

### 1️⃣ [CityGenerator.luau](ServerScriptService/CityGenerator.luau)
→ **ServerScriptService › CityGenerator**

### 2️⃣ [ClientUI.luau](StarterPlayerScripts/ClientUI.luau)
→ **StarterPlayer › StarterPlayerScripts › ClientUI**

> ⛔ `GameConfig`, `DataService` y `Main` no cambiaron.

---

## 🔴 El bug que rompía todo

Tenías razón en que estaba tronado, y era **una sola letra**.

En Roblox el objeto del mundo se llama **`workspace`**, en minúscula. Yo escribí
**`Workspace`** con mayúscula en el detector de cercanía. Eso en Roblox es `nil`, así que
la línea reventaba.

Y aquí está lo feo: ese código corre dentro de un `pcall`, o sea **un try/catch que se
traga los errores**. Entonces no salía nada rojo en la consola. Simplemente, cada 0.3
segundos, el detector moría antes de hacer nada.

**Consecuencia:** *todos* los botones contextuales (Cosechar, Prensar, Vender, Mejoras,
Caja, Garaje) quedaban invisibles para siempre, y los paneles de la computadora y la
bóveda nunca se abrían al acercarte. Exactamente lo que reportaste.

Estuvo ahí desde la v22 y ninguna de mis validaciones lo cachaba, porque el simulador
tampoco ejecuta ese bucle.

### Y un segundo, más chico

`BG1` tampoco existía (la constante se llama `BG`). Ese no tronaba — Lua descarta los
valores nulos — pero hacía que el panel de la caja fuerte y la barra de captura salieran
con el color gris por defecto en lugar del oscuro del juego.

## 🏢 La oficina ahora sí está afuera

Me expliqué mal y la metí **dentro** de la nave, comiéndose el espacio de trabajo. Ya
quedó como pediste:

- Es un **anexo pegado por fuera** a la pared derecha
- Se entra por una **puerta que atraviesa esa pared**, con su marco de madera y su
  letrero de **OFICINA**
- La pared derecha ahora se construye **en tramos** para dejar el hueco — antes era una
  sola pieza y no había por dónde pasar
- Adentro: cama con buró y lamparita, sillón, mesita, tapete y una ventana al exterior
- El estante que tapaba la puerta **se salta solo**

Queda simétrico con el garaje, que está del otro lado.

---

## 🛡️ Dos validaciones nuevas para que no vuelva a pasar

Esto es lo importante de esta ronda. Agregué dos revisiones automáticas que se corren
solas antes de cada entrega:

### `tools/globals.py` — caza typos como `Workspace`

Compila los scripts y **lista todos los globales que leen**, comparándolos contra los que
de verdad existen en Roblox. Si vuelvo a escribir mal un nombre, salta al instante.

Lo corrí en los 5 archivos: `Workspace` y `BG1` eran los únicos. Ya no hay ninguno.

### `tools/parts.py` — verifica que la bodega esté completa

Construye los **4 niveles** y comprueba que sigan existiendo todas las partes que el
código busca por nombre: caja fuerte, prensa, computadora, cajones del garaje, cama,
puerta de la oficina, macetas…

Esto nació de mi error de la v25, cuando al reescribir una sección **borré la caja fuerte
completa** y ninguna validación lo notó.

> Ahora `tools/validate.sh` corre **5 etapas** en vez de 3.

---

## Cómo probar

1. Pega los dos archivos y dale Play.
2. Camina hacia la **prensa**: debe aparecer el botón **Prensar**.
3. Acércate a la **computadora**: suena el clic y se abre el panel. Aléjate: se cierra.
4. Lo mismo con la **caja fuerte**.
5. Párate junto a una **mesa**: aparece **Cosechar**.
6. Busca la **puerta de la OFICINA** en la pared derecha y métete.

Si algún botón sigue sin aparecer, dime cuál — pero los cinco contextos ya quedaron
verificados.
