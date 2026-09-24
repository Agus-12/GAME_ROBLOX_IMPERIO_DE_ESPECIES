# 🖥️ v15 — La computadora del escritorio ya sirve

## 📂 Abrir los archivos a copiar

### 1️⃣ [Main.luau](ServerScriptService/Main.luau)
→ **ServerScriptService › Main**

### 2️⃣ [ClientUI.luau](StarterPlayerScripts/ClientUI.luau)
→ **StarterPlayer › StarterPlayerScripts › ClientUI**

> ⛔ `GameConfig`, `CityGenerator` y `DataService` no cambiaron.

---

## El pendiente más viejo que traía

Desde la v9 te construí el escritorio con la computadora, el monitor, la silla y el tapete amarillo… pero **era puro adorno**. El monitor tenía un texto fijo que nunca cambiaba y el tapete no hacía absolutamente nada.

Ya quedó funcional.

## 1. 📺 El monitor ahora muestra información real

La pantalla se actualiza sola cada vez que cambia tu dinero o tu nivel de bodega. Muestra:

- **Título:** `BODEGA - NIVEL 2/4`
- Tu nivel actual y cómo se llama
- **Cuál es el siguiente** y cuánto cuesta
- **Cuánto te falta** para poder pagarlo

Y cambia de color según tu situación:

| Estado | Qué ves |
|---|---|
| Te falta dinero | Azul — *"Te faltan $8.5K"* |
| Ya puedes pagar | **Verde** — *"YA PUEDES MEJORAR. Párate en el tapete."* |
| Nivel máximo | **Verde** — *"NIVEL MAXIMO ALCANZADO"* |

Así ya no tienes que abrir el menú para saber cómo vas: te asomas al escritorio y ahí está.

## 2. 🟨 El tapete amarillo ya funciona

Ahora **te paras en el tapete y se abre solo el panel de mejoras**, directo en la pestaña de Bodega. Nada de teclas.

Esto importa sobre todo en **celular**, donde antes tenías que buscar el botón. Ahora el escritorio se comporta como uno esperaría: te acercas, te paras enfrente, y la computadora te atiende.

Le puse **histéresis** para que no parpadee: se abre cuando estás a menos de 5 studs, y no se vuelve a disparar hasta que te alejas más de 9. Si te quedas justo en la orilla no se abre y cierra sin parar. Y si lo cierras a mano, no te lo vuelve a abrir hasta que te salgas y regreses.

---

## Cómo probar

1. Entra a tu bodega y camina hacia el escritorio del fondo.
2. **Antes de pisar el tapete**, mira el monitor — debe decir tu nivel y cuánto te falta.
3. **Písalo.** Se abre el panel de mejoras en la pestaña Bodega.
4. Sal del tapete, cierra el panel, y vuelve a pisarlo — se abre otra vez.
5. Vende producto hasta juntar los $15,000 del nivel 2 y checa el monitor: debe ponerse **verde**.

Todo corrió en el simulador: servidor completo, los 4 niveles de bodega, y la UI carga bien en escritorio, celular y tablet.

---

## 🗺️ Lo que queda en el roadmap

Ya con esto no hay features a medias. Lo que sigue son cosas nuevas:

| Pendiente | Qué es |
|---|---|
| **Territorios** | Zonas de la ciudad que los crews capturan y pelean |
| **Interiores de propiedades** | Ahorita las casas que compras son solo fachada |
| **Garaje de verdad** | Un lugar físico donde se guardan tus autos |
| **Sonido** | Música, motores, la prensa, los disparos |

Dime cuál te late más y me aviento esa.
