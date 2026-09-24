# 🔧 v11 — Luces, portón, bici en el piso, cerca

## 📂 Abrir los archivos a copiar

### 1️⃣ [CityGenerator.luau](ServerScriptService/CityGenerator.luau)
→ **ServerScriptService › CityGenerator**

### 2️⃣ [Main.luau](ServerScriptService/Main.luau)
→ **ServerScriptService › Main**

### 3️⃣ [ClientUI.luau](StarterPlayerScripts/ClientUI.luau)
→ **StarterPlayer › StarterPlayerScripts › ClientUI**

> ⛔ `GameConfig` y `DataService` no cambiaron.

---

## 1. 🔆 La bodega ya no encandila

El problema era **acumulación**: cada mesa de cultivo tenía su luz UV con alcance 26, y con 12 mesas todas se encimaban. Más la prensa, la zona segura, el escritorio, las lámparas del portón y el foquito de cada planta madura. Todo junto reventaba la exposición.

Bajé todo:

| Luz | Antes | Ahora |
|---|---|---|
| Tubo UV (por mesa) | 3.2 / alcance 26 | **0.85 / alcance 13** |
| Prensa | 2.0 / 28 | **0.9 / 16** |
| Zona segura | 2.0 / 28 | **0.9 / 16** |
| Escritorio | 2.2 / 24 | **0.9 / 14** |
| Lámparas del portón | 2.0 / 26 | **1.1 / 18** |
| Planta madura | 2.5 / 10 | **1.1 / 7** |

Lo importante es que bajé sobre todo el **alcance**, no solo el brillo — así cada luz ilumina su zona y ya no se suman entre ellas. Las plantas listas se siguen distinguiendo, pero sin cegarte.

## 2. 🚪 Portón: las nervaduras ya no se quedan pegadas

Bug clásico de Roblox y fue culpa mía: las barras horizontales estaban **soldadas** a la hoja del portón, pero la hoja se mueve cambiándole el CFrame directamente. Las soldaduras no siguen ese tipo de movimiento — solo funcionan con física. Por eso la puerta se abría y las barras se quedaban flotando en el aire.

Ahora las nervaduras van **sueltas**, guardan su posición relativa a la hoja, y se mueven **junto con ella** en la misma animación.

## 3. 🚲 La bici ya no flota

Encontré el número exacto: la caja de colisión medía **1 stud de alto**, pero las ruedas cuelgan hasta **2.25 studs abajo**. Entonces la caja tocaba el suelo primero y dejaba las llantas colgando en el aire.

Subí la caja a **4.5 de alto**, que es justo la distancia desde arriba del asiento hasta abajo de las llantas. Ahora las ruedas apoyan en el piso.

## 4. 🕴️ El vigilante ya no flota

Mismo tipo de problema: estaba parado **afuera** de la bodega, donde ya no hay piso — el terreno ahí está más abajo, y él se quedaba a la altura del piso interior.

Le puse una **banqueta de concreto** con su bordillo. Ahora está parado en algo sólido, y de paso la entrada se ve mejor (el barril y la basura también quedan sobre la banqueta).

## 5. 🚧 La cerca ya no atraviesa las tiendas

La reja del callejón se metía en los edificios por los lados. La **acorté 6 studs de cada lado**, la **empujé hasta la pared del fondo** y le bajé la altura de 13 a 11.

También le quité la colisión a la malla: antes podías **atorarte** en ella caminando por el callejón. Los postes siguen siendo sólidos, así que se sigue sintiendo como una reja.

## 6. 📱 El teléfono ya no se ve flotando

Estaba a media altura de la pantalla, en el aire. Ahora:

- Está **pegado a la esquina inferior derecha**, justo arriba de la barra de botones — se lee como notificación del celular, no como una ventana suelta
- Le puse una **sombra** detrás que se despega del fondo
- Un poco más chico (290×330)
- La sombra **acompaña** el deslizamiento y la vibración

---

## Cómo probar

- **Luces:** entra a la bodega. Debe verse iluminada pero ya sin quemarte la vista. Las plantas listas se notan por su foquito verde.
- **Portón:** camina hacia la entrada. Las hojas y sus barras se abren **juntas**.
- **Bici:** **H** → Bodega → botón de bici. Las llantas deben tocar el piso.
- **Vigilante:** sal de la bodega, voltea a la izquierda. Parado en su banqueta.
- **Cerca:** ve a cualquier mercado y camina hacia el fondo del callejón. Ya no te atoras ni la ves metida en las paredes.
- **Teléfono:** espera la llamada. Debe entrar por la derecha, abajo.

Todo corrió completo en el simulador: ciudad generada, los 4 niveles de bodega y servidor arrancado sin errores.
