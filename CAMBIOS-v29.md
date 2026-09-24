# 🏗️ v29 — Ventana real, HUD para teléfono, garaje que crece, carros de verdad y luces de noche

Todo lo que pediste en la lista, en una ronda. Cinco archivos cambian:

## 📂 Abrir los archivos a copiar

### 1️⃣ [GameConfig.luau](ReplicatedStorage/GameConfig.luau)
→ **ReplicatedStorage › GameConfig** · **ModuleScript**

### 2️⃣ [CityGenerator.luau](ServerScriptService/CityGenerator.luau)
→ **ServerScriptService › CityGenerator** · **ModuleScript**

### 3️⃣ [Main.luau](ServerScriptService/Main.luau)
→ **ServerScriptService › Main** · **Script**

### 4️⃣ [ClientUI.luau](StarterPlayerScripts/ClientUI.luau)
→ **StarterPlayer › StarterPlayerScripts › ClientUI** · **LocalScript**

### 5️⃣ [DataService.luau](ServerScriptService/DataService.luau)
→ **ServerScriptService › DataService** · **ModuleScript**

> 📋 **Pega SIEMPRE encima** (clic en el script → `Ctrl+A` → `Ctrl+V`). Guía con los
> links directos: [`docs/10-COPIAR-Y-PEGAR.md`](docs/10-COPIAR-Y-PEGAR.md)

---

## 1️⃣ La ventana ahora es una ventana DE VERDAD

**Antes:** era un vidrio pegado **encima** del muro, como calcomanía. Se veía raro, tal cual.

**Ahora** el muro exterior de la oficina se construye **en tramos**, dejando **dos huecos
de verdad** (8 × 4.6 studs) con:

| Pieza | Qué es |
|---|---|
| `OfficeWindowFrame` | Marco de madera en los 4 lados del hueco |
| `OfficeWindowMullion` | Los travesaños (para que se lea "ventana", no "hoyo") |
| `OfficeWindowSill` | Repisa que sobresale hacia afuera |
| `OfficeWindowGlass` | El vidrio, con reflejo |

**Y de noche se ilumina solo**: el vidrio se prende con luz cálida (como si estuvieras
la oficina) y de día vuelve a ser vidrio normal. Primero quité la ventana de encima del
muro *y* abrí el hueco: si solo pintaba algo encima, iba a seguir viéndose igual de feo.

---

## 2️⃣ HUD de teléfono (adiós barra larga)

Dijiste: *"el dashboard de arriba se me hace demasiado largo, ponlo del lado izquierdo
de arriba hacia abajo"*. Hecho:

```
┌──────────┐                    ┌──────────────────┐
│  $11.4K  │                    │   16:47 SOL      │
│ 🌿 8     │                    └──────────────────┘
│ 🧱 13    │
│ 🎒 21/80 │
│ 🔒 100/50│
│ 🚨 26%   │
└──────────┘
```

- **Columna vertical pegada al borde izquierdo**, con el ancho de un dedo.
- La barra vieja medía **casi 600 px**: en un celular eso es **media pantalla**. Ahora
  mide **112 px** (celular) y el centro de la pantalla queda libre para ver el juego.
- **Reloj arriba a la derecha**, como el de un celular.
- El **HEAT** ahora también tiene su renglón en la columna (antes solo estaba dentro de
  la barra ancha, que casi nunca se veía). Se pone verde → ámbar → rojo.
- El aviso de **BUSCADO** ya no es un texto larguísimo: es una etiqueta pegada a la columna.
- La tecla **M** (o el botoncito **–**) esconde las filas para dejar la pantalla limpia.

### Y sí: es 100% para teléfono

| Qué | Antes | Ahora |
|---|---|---|
| Botón de acción | 106 × 46 | **112 × 52** (el mínimo cómodo para un dedo es ~48 px) |
| Texto de los botones | 13 | 14 |
| Rejilla de botones | costado derecho, a media altura (no estorba el joystick ni el salto) | igual, más grande |
| Paneles (tienda, teléfono, bóveda) | ya se ajustaban al tamaño de pantalla | igual |
| HUD | barra de 590 px arriba | columna de 112 px a la izquierda |

> 💡 En Studio puedes probar el modo teléfono: **Test → Device** (arriba), elige un
> celular y dale Play. La columna se reacomoda sola.

---

## 3️⃣ El garaje: puerta de verdad, y crece con la bodega

Tenías razón en todo:

| Queja | Qué se hizo |
|---|---|
| *"no tiene ni siquiera puerta"* | **Cada cajón tiene su portón de cortina** (`GarageDoor`): duelas metálicas, ventanita, manija y umbral amarillo. Se **abre solo** cuando tú (o tu coche) se acercan a menos de 20 studs, y se cierra cuando te alejas. Suena al subir. |
| *"está muy pequeño"* + *"con ir mejorando la bodega va creciendo"* | **Crece por nivel**: ancho **44 → 52 → 60 → 68**, fondo **26 → 30 → 34 → 38**, alto **13 → 15 → 17 → 19**. Todo en `GameConfig.Garage` |
| *"los autos cómo le van"* | El coche ahora sale **por la puerta del garaje** (`GarageExit`) al piso del patio, no apareciendo junto a ti |
| *"está de mentiras"* | El taller tiene banco de trabajo, caja de herramientas, llantas de refacción apiladas y bote metálico. Cada portón tiene su **lámpara de fachada** que se prende de noche |
| Antes: el garaje era una CAJA CERRADA (problema de la v28) | La pared del frente también iba de una pieza. Ahora va **en pilares y dinteles**, con un hueco por cajón |

> ⚠️ Ojo con una cosa: **el garaje del nivel 4 ahora mide 68 de ancho**. Con la bodega
> (190) y la oficina (34) el lote total es de **297 studs**, y los lotes están cada 340 →
> cabe, **pero si le subes mucho más en `GameConfig.Garage` vas a encimar las bodegas**.
> El validador te avisa: `tools/walk.py` revisa ese número.

---

## 4️⃣ Los carros: de ladrillo con bolas a carros de verdad

**Antes** los dos modelos (el que manejas y el estacionado) eran literalmente una caja
de 8×3×16 con **4 bolas** de rueda. Por eso se veían "de mentiras".

**Ahora** hay un solo constructor con **silueta propia por tipo**:

| Tipo | Forma |
|---|---|
| **Van de Carga** | Alta y cuadrada, con baca en el techo |
| **Sedán Gris** | Bajo y largo, con cajuela |
| **Pickup Rural** | Cabina adelante + **batea abierta** atrás con paredes |
| **Deportivo** | Bajito, ancho, con **alerón** en la cola |

Y todos traen: **parabrisas y medallón inclinados**, vidrios laterales, espejos,
defensas, parrilla con barra cromada, **faros que se prenden de noche** (luz de verdad,
no solo el color), calaveras rojas, **rines** cromados (se ven por los dos lados),
placas, escape, reflejo en la pintura y **la pintura de su color**.

> 🎁 **Bonus:** el auto **estacionado en el cajón usa el mismo modelo**, así que el que
> tienes guardado se ve igualito de bonito que el que sacas a manejar.

---

## 5️⃣ Luces de noche (y que se apaguen de día)

El sistema día/noche ya existía, pero **afuera de tu bodega no había ni una luz** (por eso
de noche se veía boca de lobo). Ahora la bodega trae **luces propias**, y todas están
marcadas para **prenderse cuando anochece (18:00) y apagarse cuando amanece (6:30)**:

| Luz | Dónde |
|---|---|
| `LotWallLamp` ×2 | Esquinas de la fachada |
| `GarageWallLamp` ×4 | Arriba de cada portón del taller |
| `GarageLamp` ×4 | Techo de cada cajón |
| `NaveLamp` ×3 | Techo de la nave, por dentro |
| `RoofFloodLight` | Reflector en el techo apuntando al patio |
| `GateSignGlow` | Letrero del portón (se ilumina) |
| `LampPost` | Poste de luz del lote |
| `Headlight` ×2 | Los faros de tu carro 🚗 |

Puedes cambiar la hora y la duración del día en `GameConfig.DayNight`
(`DayLengthMinutes = 12` = día completo de 12 minutos reales).

---

## 6️⃣ Ambientación exterior (que se vea que es un negocio, no una caja)

| Adorno | Detalle |
|---|---|
| **Patio de concreto** (`LotApron`) | Frente al portón, con franjas de estacionamiento |
| **Macetas con arbustos** | A los dos lados del portón |
| **Bolardos amarillos** | 7 en la orilla del patio |
| **Toldo rojo + postes** | Sobre la puerta de la oficina, con su lámpara |
| **Botes de basura** | Contenedor verde con tapa |
| **Banca de madera** | Junto al portón |
| **Aires acondicionados y ventilas** | En el techo |
| **Poste de luz del lote** | Al costado, alumbra el patio de noche |

> 🎛️ **Todo esto se apaga con una línea**: en `GameConfig.Ambience` pon
> `Enabled = false` y la bodega queda pelona (o `Props = false` para quedarte solo con
> las luces). Nada está clavado en el código.

---

## 🧪 Cómo probar

1. Pega los 5 archivos y dale **Play**.
2. **Mira el HUD**: ahora es una **columna a la izquierda** con efectivo, hojas, bloques,
   mochila, caja y HEAT. El reloj está arriba a la derecha.
3. **Prueba en teléfono**: menú **Test → Device → (un celular) → Play**. Los botones son
   más grandes y la columna no estorba.
4. **Ve a la oficina** (puerta del muro derecho): ahora tiene **dos ventanas de verdad**
   con marco, travesaños y repisa. De noche se ven iluminadas desde afuera.
5. **Ve al taller** (puerta del muro izquierdo): **los portones se abren solos** cuando te
   acercas. Adentro hay banco, llantas y bote. Cada cajón tiene su número.
6. **Compra un carro** en la tienda (pestaña Bodega/vehículos) y sácalo: sale **por la
   puerta del garaje** y ahora tiene forma de van / sedán / pickup / deportivo.
7. **Espera a que anochezca** (12 minutos reales = 1 día): se prenden las luces del
   portón, los faroles, el poste y los faros de tu carro. De día se apagan solas.
8. **Mejora tu bodega** para ver el garaje más grande en cada nivel.

---

## 🔧 Y de paso (para que no se rompa)

- **`GameConfig.Garage`** y **`GameConfig.Ambience`**: perillas nuevas, todo el garaje y la
  ambientación salen de ahí (nada de números sueltos por el código).
- **Sonido nuevo** `Config.Sounds.Gate`: el ruido del portón al subir.
- **`tools/parts.py`** ahora revisa 18 piezas nuevas (ventanas, portones, postes,
  macetas…) para que ninguna se pueda perder sin que el validador chille.
- **Validación completa en verde**: las 9 etapas, incluida la de *"¿se puede caminar a
  todo?"* con el garaje nuevo y la de versiones.

---

## 🗺️ Roadmap

| Pendiente | Nota |
|---|---|
| **Bici** | Sigue sin que me confirmes si se siente bien |
| **Interiores de propiedades** | Las casas que compras siguen siendo fachada |
| **Música ambiente** | Falta música de fondo (los SFX ya están) |
| **Más teléfono** | Si quieres, el teléfono puede tener apps (contactos, mapa) |
