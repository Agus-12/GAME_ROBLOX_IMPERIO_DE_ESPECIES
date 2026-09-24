# Cambios de la ronda v42

> ## 🎯 ESTA RONDA ES LA DE LA LISTA DE 8 COSAS QUE MANDO EL USUARIO
> Bici que rueda de verdad, auto del garaje que se puede SACAR Y MANEJAR, garaje con
> portones de verdad que crece con tu nivel, las parcelas vecinas llenas de bodegas
> (las sin dueño **clausuradas con oficiales afuera**), la lámpara del poste pegada al
> tubo, la cochera iluminada, el dashboard ordenado con las ⭐ del nivel de búsqueda y
> el botón de **Auto** para celular.
>
> **Nada de esto se pudo comprobar "a ojo":** esta ronda trae **3 validaciones nuevas**
> (etapas 15, 16 y 17) que revisan esto solito, y cada una se probó **metiendo el bug a
> propósito** para ver que sí lo caza.

---

## 1. 🚲 La bicicleta: "los rines se quedan ahí"

**Lo que pasaba:** la bici se mueve por código (es cinemática, no tiene física). En el
bucle de cada cuadro se reposicionaba **la goma y el aro**, y nada más. La **maza
(Hub)** y los **6 rayos** se quedaban anclados donde nació la bici: te alejabas y los
rines se quedaban "tirados" en el piso.

**Arreglo:** cada rayo guarda **su ángulo** y en el bucle se mueven **Wheel + Rim + Hub +
los 6 rayos** (cada rayo con `spin + su ángulo`, para que giren bien).

## 2. 📱 En el celular el letrero "E / Bicicleta / Manejar" no tenía sentido

**Arreglo:** el cliente ahora **avisa al servidor** si el jugador anda en celular
(atributo `Tactil` del Player). Con eso:
- en **celular**: el letrero se **apaga** y la bici te **sube sola** al acercarte
  (≤ 6 studs). Para que no te vuelva a subir cada que te bajas, se marca `BiciLejos`
  hasta que te alejas (más de 9 studs);
- en **compu**: se queda igual, con su letrero y la tecla `E`.

## 3. 🚲 "Me subo y no me deja andar"

**Causa:** el asiento de la bici tenía **`Torque = 0` y `TurnSpeed = 0`**. Con eso el
asiento **no acepta controles**: no sale el botón de manejar en celular y no acelera.
(El movimiento sigue siendo por código; esos dos números solo *habilitan* el control.)
**Arreglo:** `Torque = 40`, `TurnSpeed = 14`.

## 4. 🚗 El auto del garaje salía "con las llantas como plato" y no se dejaba sacar

- **Rin "plato":** era **un solo disco cromado del tamaño de la llanta**. Ahora cada
  rueda es **goma + aro (Rim) + maza (Hub) + 5 rayos (Spoke)**, y las piezas del rin van
  **soldadas a la LLANTA** (no al chasis), si no se quedaban quietas mientras la llanta
  giraba.
- **Sacarlo y manejarlo:** en cada auto estacionado del cajón ahora hay un botón
  **"Sacar y conducir"**: saca *ese* auto del cajón, lo pone **afuera** (en el punto de
  salida `GarageExit`, medido contra el piso del garaje) y **te sienta manejándolo**.
  Lo mismo hace el botón de la pestaña **Autos** del Teléfono (antes te dejaba parado al
  lado del auto).

## 5. 🏠 El garaje: sin puertas, y "en el primer nivel solo un auto"

- **Portones que se VEN:** antes el portón "subía" 11 studs **por encima del techo**
  (o sea, desaparecía) y el radio para abrirlo se medía **desde el centro del garaje**,
  así que estando adentro ya abrían todos. Ahora cada portón **se ENROLLA** hacia arriba
  (se encoge, guardando su tamaño original en `HomeSize`) y la apertura se mide **al
  frente de CADA cajón** (`HomeCF` del PrimaryPart), a ≤ 10 studs.
- **Nivel 1 = 1 cajón:** `GameConfig.BaysByTier = {1, 2, 3, 4}` con
  `GameConfig.BaysDelNivel(nivel)`. El nivel 1 trae **un cajón y garaje chico (26×24)**
  pero con espacio de sobra para el auto; al subir de nivel el garaje **crece y se mejora**
  (42×30, 56×34, 64×38 de alto 12→19) y hay más cajones.
- **Elegir qué auto sacar:** ya no te subes "en el primero que aparezca": cada cajón
  tiene su portón, su letrero **CAJON n** y su botón propio. Comprar un auto sin cajón
  libre se rechaza con aviso.

## 6. 🏚️ Las parcelas vecinas: "prácticamente vacía"

**Arreglo:** todo lote **sin dueño** (los primeros `VecinasMax = 5`) se amuebla con una
**bodega vecina** completa, **repintada de otro estilo** (6 paletas: acero azul, ladrillo,
verde taller, arena, lila y petróleo) y **CLAUSURADA**:
- cinta policial amarilla con rayas cruzando la entrada + tablilla **CLAUSURADA**;
- **2 oficiales afuera** (uniforme azul, chaleco, placa, gorra y radio) que **voltean a
  verte** y te dicen:
  - 1ª vez: *"Hey, ¿qué estás haciendo aquí? Esta área está clausurada."*
  - si reincides: *"Hey, estás muy sospechoso. Si te veo por aquí de nuevo, te voy a
    llevar a la cárcel."*
- adentro **no se puede tocar nada** (todos los botones quedan apagados y los portones
  cerrados, porque el sistema de portones no se engancha a las vecinas);
- **cuando el lote tiene dueño**, su bodega clausurada (con cinta y oficiales) se va sola;
  y si el jugador **se sale de la partida**, su lote vuelve a quedar clausurado.

## 7. 💡 Luces

- **Lámpara del poste "despegada del tubo":** el farol se rearmó como una pieza:
  **poste + brazo + cabeza de luz + visor** pegados (antes la cabeza flotaba).
- **Cochera oscura:** la luz del techo del cajón estaba en `0.55` **y se apagaba de día**
  (tenía la etiqueta `tagLight`). Ahora está encendida **siempre**, en `1.15` con alcance
  `24` (no quema, se ve todo el día), y la lámpara de fachada subió de `0.8/22` a `1.2/28`.

## 8. 📊 El dashboard: "se mira raro" y las estrellas del nivel de búsqueda

- La columna ahora va **en orden y explicada**: `$` efectivo → `🌿` hojas que traes →
  `🧱` bloques que traes → `🎒` mochila usada/tope → `🔒` lo que hay en la caja fuerte
  **en dos renglones** (hojas / bloques), que antes iba todo apretado en uno y se veía
  "recorrido".
- La **🚨 se fue de la columna**: el nivel de búsqueda ahora son **5 ESTRELLAS abajo del
  reloj** (arriba a la derecha). Se prenden con el heat (0 a 5), se ponen **rojas** cuando
  ya vas muy buscado y **se van apagando solas** cuando la zona segura te baja el heat.

## 9. 📱 El dashboard de abajo en celular

- Botón nuevo **Auto [Y]**: **trae tu auto donde estés** (si ya anda afuera se aparece
  adelante de ti; si está guardado, sale del cajón y luego se aparece). Es lo que pediste
  para celular: no volver caminando a la bodega.
- Los menús por cercanía ya funcionaban y siguen igual: **computadora** (mejoras) y
  **caja fuerte** abren solos al acercarte, y los botones contextuales (Cosechar, Prensar,
  Vender) aparecen nada más cuando estás junto a la máquina.

---

## 10. 🧪 Cómo se comprueba (etapas nuevas del `validate`)

| Etapa | Qué revisa | Fail-hard (se mete el bug y debe tronar) |
|---|---|---|
| **15. `tools/vecinos.py`** | que los lotes libres se amueblen, con cinta y tablilla, sin botones vivos, con 2 oficiales cada uno, y que digan **la línea 1 y luego la de la cárcel** al acercarte | se apaga el amueblado (`VecinasLots.Enabled = false`) y la prueba lo caza |
| **16. `tools/hud42.py`** | que existan las **5 estrellas** bajo el reloj y se prendan (0 / 3 / 5), que la caja fuerte se vea en **dos renglones**, y que el botón **Auto** esté en la barra (probado en **escritorio y celular**) | se fuerza `nivel = 0` y la prueba lo caza |
| **17. `tools/vehiculos42.py`** | la bici (asiento con Torque/TurnSpeed, rueda completa, letrero apagado en celular y prendido en compu) y el auto del garaje (llantas 4/4/4/20, te sienta, y queda **fuera del cajón** medido contra el piso del garaje) | asiento en `0/0` y auto puesto en el cajón: las dos veces trona |

Además, dos cosas del **simulador** que mentían y ya se arreglaron:

1. `Position` y `CFrame` **no iban juntos**: el portón guardaba su `CFrame` y el simulador
   lo veía vacío, así que la prueba del garaje pasaba sin revisar nada. Ahora van juntos,
   como en Roblox.
2. `os.clock()` era el tiempo **de CPU**: los enfriamientos ("no repitas el aviso en 14 s")
   nunca se cumplían en las pruebas y los oficiales se quedaban con la primera línea.
   Ahora va con el **reloj de la simulación** (como en Roblox, que es el tiempo del
   servidor).

---

## 11. 📁 Qué archivos se reemplazan

Los **5 de siempre** (los 4 módulos y el cliente):

| Archivo | Adónde va |
|---|---|
| `ReplicatedStorage/GameConfig.luau` | `ReplicatedStorage > GameConfig` (ModuleScript) |
| `ServerScriptService/CityGenerator.luau` | `ServerScriptService > CityGenerator` (ModuleScript) |
| `ServerScriptService/DataService.luau` | `ServerScriptService > DataService` (ModuleScript) |
| `ServerScriptService/Main.luau` | `ServerScriptService > Main` (Script) |
| `StarterPlayerScripts/ClientUI.luau` | `StarterPlayer > StarterPlayerScripts > ClientUI` (LocalScript) |

**Antes de pegar: borra las copias que ya tengas en el Explorer** (clic derecho > Delete).
Si quedan dos, gana la que diga `RONDA: v42` y la otra se borra sola, pero es más limpio
dejar una de cada una.
