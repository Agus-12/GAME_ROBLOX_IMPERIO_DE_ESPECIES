# 🎒 v22 — Mochila vs caja fuerte, HUD de iconos y dock contextual

> **Esta es la primera de dos rondas.** De tus 8 puntos, aquí van los que cambian
> *cómo funciona* el juego. La siguiente ronda es el pase visual (arma realista, zona
> segura, estantes, la computadora pegada a la pared, animación de cosechar).
> Te explico el porqué del corte al final.

## 📂 Abrir los archivos a copiar

### 1️⃣ [GameConfig.luau](ReplicatedStorage/GameConfig.luau)
→ **ReplicatedStorage › GameConfig**

### 2️⃣ [Main.luau](ServerScriptService/Main.luau)
→ **ServerScriptService › Main**

### 3️⃣ [ClientUI.luau](StarterPlayerScripts/ClientUI.luau)
→ **StarterPlayer › StarterPlayerScripts › ClientUI**

> ⛔ `CityGenerator` y `DataService` no cambiaron.

---

## 7️⃣ Tu mochila y la caja fuerte ya son cosas distintas

Tenías razón, y esto arregla de raíz lo que te estaba confundiendo.

### Cómo funciona ahora

| | Para qué sirve | Tope |
|---|---|---|
| 🎒 **Tu mochila** | Aquí cae lo que **tú** cosechas y prensas. Es tu inventario de trabajo | **80** compartido |
| 🔒 **La caja fuerte** | Es el **banco**. Solo se llena si tú depositas o si tus empleados guardan | **separado por producto** |

**Puedes cosechar y prensar mientras te quepa en la mochila.** Ya no te bloquea el
almacén de la bodega — eran dos cosas que no tenían por qué estar pegadas.

### Topes separados en la caja

Como pediste, hojas y bloques ya no compiten por el mismo espacio:

| Nivel de bodega | 🌿 Hojas | 🧱 Bloques |
|---|---|---|
| Garage | 100 | 50 |
| Bodega | 250 | 120 |
| Almacén Industrial | 600 | 300 |
| Mega Procesadora | 1,500 | 800 |

También quité la regla rara de que "un bloque ocupa 3" — ya no hace falta, cada producto
tiene su propio cajón.

### El circuito completo

```
cosechas → 🎒 mochila → prensas → 🎒 mochila → vendes
                ↓ guardas
           🔒 caja fuerte ← aquí depositan tus empleados
```

Tus empleados siguen guardando **directo en la caja** (están en la bodega, no traen
mochila), y los prensadores ya no producen bloques de más si el cajón está lleno.

## 8️⃣ HUD de iconos, siempre compacto

Ya no hay barra grande ni botón de minimizar: se queda chiquito siempre, con cuatro
iconos:

| | Qué muestra |
|---|---|
| 🌿 | Hojas que **traes encima** |
| 🧱 | Bloques que **traes encima** |
| 🎒 | Espacio de mochila (`6/80`) — se pone **rojo** si vas lleno |
| 🔒 | Lo que hay en la **caja** (`8/100  64/50`) |

Los iconos son emojis a propósito: se ven igual en PC y en celular, y no hay que subir
imágenes a Roblox.

## 5️⃣ (parte 1) El dock ya no tapa media pantalla

Quité los ocho botones fijos. Ahora **solo aparecen cuando sirven**:

| Botón | Aparece cuando… |
|---|---|
| **Cosechar** | estás junto a una mesa |
| **Prensar** | estás junto a la prensa |
| **Vender** | estás junto a un comprador |
| **Mejoras** | estás junto a la computadora |
| **Caja** | estás junto a la caja fuerte |

Tienda, Teléfono y Bodega se quedan siempre porque son menús generales.

### Y los menús se abren y cierran solos

- Te acercas a la **computadora** → suena un *clic* y se abre el panel de mejoras
- Te acercas a la **caja fuerte** → suena el mecanismo metálico y se abre
- **Te alejas → se cierran solos**

## 3️⃣ Los asaltantes ya no flotan

Los estaba spawneando tomando como referencia el sensor del portón, que tiene su centro
a **8 studs de altura**. Aparecían por los aires. Ahora se calcula el piso real de la
bodega. Mismo arreglo para los guardias.

## 4️⃣ Los cosechadores dobles

**La causa:** `syncWorkers` se llama desde tres lados (al entrar, al contratar, al
mejorar la bodega). Si dos corrían casi al mismo tiempo, el primero perdía su lista a
medias y sus empleados quedaban huérfanos — ahí estaban los duplicados encimados.

Ahora, en vez de confiar en la lista, **barre la bodega completa** buscando empleados por
atributo y los borra. Es a prueba de carreras.

> La **animación de cosechar** va en la siguiente ronda, con el resto de lo visual.

## 1️⃣ (parte 1) El disparo ya suena

Le puse estampido, discreto como pediste, y **posicional** — o sea que los demás lo oyen
desde donde disparaste. El modelo del arma sigue viéndose falso; eso va en la siguiente.

---

## Por qué lo partí en dos

Me pediste 8 cosas y cuatro de ellas son rediseños, no arreglos. Si las metía todas de
un jalón, la mitad iba a salir con bugs — y ya llevamos varias rondas donde un cambio
grande arrastra otro (la bici me llevó cuatro intentos, la caja fuerte dejó el HUD
mintiendo dos versiones).

Metí primero lo estructural porque **condiciona lo visual**: no tenía caso rediseñar la
zona segura y los estantes sin saber antes que el almacén se iba a partir en dos.

### Lo que va en la v23

| # | Qué |
|---|---|
| 1 | Arma con modelo realista |
| 2 | Zona segura: quitar el cuadro azul, sillón que parezca sillón |
| 4 | Animación de cosechar |
| 5 | Computadora pegada a la pared, silla con soporte |
| 6 | Estantes con cajas realistas, pegados a la pared |

---

## Cómo probar

1. **Cosecha con la caja llena.** Antes te bloqueaba; ahora debe caer en tu mochila.
2. **Llena la mochila** (80). Ahora sí te dice que la guardes.
3. Ve a la caja, **guarda todo**, y fíjate que el chip 🔒 suba con topes separados.
4. **Camina por la bodega:** los botones deben aparecer y desaparecer solos, y los menús
   de la computadora y la caja abrirse y cerrarse con sonido.
5. Provoca un asalto (`BaseChance = 1`) y checa que los asaltantes **pisen el piso**.
6. Contrata cosechadores y verifica que no haya dos en la misma mesa.
