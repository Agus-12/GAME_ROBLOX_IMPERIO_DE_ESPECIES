# 🔐 v18 — Caja fuerte y mochilas

## 📂 Abrir los archivos a copiar

### 1️⃣ [GameConfig.luau](ReplicatedStorage/GameConfig.luau)
→ **ReplicatedStorage › GameConfig**

### 2️⃣ [DataService.luau](ServerScriptService/DataService.luau)
→ **ServerScriptService › DataService**

### 3️⃣ [CityGenerator.luau](ServerScriptService/CityGenerator.luau)
→ **ServerScriptService › CityGenerator**

### 4️⃣ [Main.luau](ServerScriptService/Main.luau)
→ **ServerScriptService › Main**

### 5️⃣ [ClientUI.luau](StarterPlayerScripts/ClientUI.luau)
→ **StarterPlayer › StarterPlayerScripts › ClientUI**

> Esta vez cambiaron **los 5**. Tu partida guardada **no se pierde** — el sistema de
> guardado rellena los campos nuevos solo.

---

## 1. 🏭 Prensar solo frente a la máquina

Tenías toda la razón: `doPress()` **nunca checaba distancia**. Podías prensar desde la
otra punta del mapa, lo cual volvía la prensa un adorno caro.

Ahora mide qué tan lejos estás de la máquina. Si no estás cerca:
*"Acércate a la prensa para poder prensar"*.

> Radio configurable: `Config.Press.UseRadius = 14`

## 2. 🔐 La caja fuerte

Este es el cambio grande. **Ahora hay dos bolsas distintas:**

| Dónde | Qué es | ¿Aduanas te lo quita? |
|---|---|---|
| **La caja fuerte** | Lo que produces se guarda aquí | ❌ **No** |
| **Encima de ti** | Lo que sacaste para ir a vender | ✅ **Sí** |

Exactamente como lo planteaste: si te agarran con todo en el inventario no tenía sentido
que no te incautaran nada. Ahora **solo pierdes lo que traes cargando**.

### Dónde está

En la **zona segura** de tu bodega. Es una caja de acero con puerta redonda, volante
giratorio y una pantalla que te dice qué tienes adentro y cuánto espacio te queda.

### Cómo se usa

- **Te paras en el tapete verde** de enfrente y se abre sola
- O aprietas **C** / el botón **Caja** del dock desde cualquier lado de la bodega

El panel tiene una fila para **hojas** y otra para **bloques**, cada una con **SACAR** y
**GUARDAR**, y arriba eliges la cantidad: **10 · 25 · 100 · TODO**.

### Qué cambió en la práctica

- Cosechar y prensar → va **a la caja**
- Vender → gasta **lo que traes encima**. Si vas con las manos vacías te dice
  *"No traes nada encima. Saca producto de tu caja fuerte"*
- Te agarra Aduanas → solo se llevan **lo cargado**

## 3. 🎒 Mochilas

Como no puedes cargar todo de un viaje, ahora la capacidad se mejora. Están en la
tienda, pestaña **Bodega**:

| Mochila | Costo | Cargas |
|---|---|---|
| Bolsillos (inicial) | — | 80 |
| Morral | $2,500 | 180 |
| Maleta de lona | $12,000 | 400 |
| Diablito de carga | $55,000 | 900 |
| Contenedor rodante | $250,000 | 2,000 |

Cada una reemplaza a la anterior, y no te deja comprar una más chica que la que traes.

## 4. 📊 El HUD ahora muestra las dos cosas

La barra de arriba cambió a:

```
CAJA  133 hojas / 8 bloques  (141/200)     CARGAS  25/80
```

Y los chips de colores ahora muestran **lo que traes cargando**, que es lo que de verdad
está en riesgo cuando andas en la calle.

---

## Cómo probar

1. Entra a tu bodega y **cosecha**. Fíjate que el número sube en **CAJA**, no en CARGAS.
2. Intenta **prensar lejos** de la máquina → te lo debe negar.
3. Acércate a la prensa y prensa → funciona.
4. **Párate en el tapete verde** de la caja fuerte → se abre el panel.
5. Saca 25 hojas. Ahora dice `CARGAS 25/80`.
6. Ve a vender. Solo debe vender esas 25.
7. **La prueba buena:** sube tu Heat hasta que te agarre Aduanas trayendo poquito encima.
   Debes conservar todo lo de la caja.

---

## 🗺️ Lo que sigue (v19)

Ya está decidido, solo falta construirlo:

- **Cosechadores físicos, uno por mesa.** 4 mesas = 4 cosechadores. Se van a parar en su
  mesa, los vas a ver, y cosechan solo las plantas maduras de *esa* mesa
- **Producción aunque estés desconectado** — llegas y la caja tiene producto
- **Los asaltos sí podrán robar de la caja fuerte** — para eso sirven los guardias y la
  alerta del celular

> Hice la caja primero **a propósito**: los trabajadores necesitan un lugar dónde
> depositar lo que cosechan, y ese lugar es la caja. Sin ella no tenía dónde dejarlo.
