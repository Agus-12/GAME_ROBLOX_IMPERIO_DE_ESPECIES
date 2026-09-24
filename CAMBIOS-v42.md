# Cambios de la ronda v42

> ## 🎯 LOS 8 PEDIDOS DE ESTA RONDA
>
> 1. **Bici:** los rines se quedaban clavados cuando la movías.
> 2. **Bici en celular:** el letrero de `E` no tiene sentido → te subes al acercarte.
> 3. **Bici en el garaje:** no andaba (los controles salían en 0).
> 4. **Bodega nivel 1:** solo un auto y garaje más chico; al subir de nivel todo crece.
> 5. **Puertas del garaje:** que se vean y que abran.
> 6. **Dashboard de abajo:** en celular no funcionaba nada.
> 7. **Parcela vacía:** que se vea una bodega **clausurada** con estilo distinto y
>    oficiales con los que puedas hablar al acercarte.
> 8. **Mi auto aquí:** un icono para traer el auto a donde estés.

---

## 1. 🛠️ Lo que estaba mal (y por qué no lo cazaban las pruebas)

Esta ronda hubo que **arreglar el simulador primero**, porque había tres cosas que las
pruebas no podían ver y por eso los bugs te llegaban a ti:

| Lo que el simulador no tenía | Lo que eso escondía |
|---|---|
| `Players:GetPlayers()` devolvía **vacío** y `PlayerAdded` nunca se disparaba | **Ninguna** acción del servidor se probaba: comprar un auto, el límite de cajones, sacar el vehículo... todo eso se probaba "a ojo" en Studio. |
| Los remotes **no existían** en el simulador (no había `InvokeServer`) | Los botones del dock mandaban su acción dentro de un `pcall`... que se tragaba el error. El "Teléfono" y la "Tienda" parecían probados y no lo estaban. |
| Las partes nacían **sin `CFrame`** y `CFrame + Vector3` devolvía el mismo CFrame | "Trae tu auto a tu lado" parecía funcionar y no movía nada. La prueba decía 50 studs donde el juego deja 10. |

Ya están los tres arreglados, y con eso se pudieron escribir **5 pruebas nuevas** (16 a 20).

## 2. 🚲 La bici (rines, controles y el letrero de E)

- **Los rines.** La rueda se arma con 4 piezas: la llanta, el aro, la **maza** (`hub`) y
  los **rayos** (`spokes`). El bucle que sigue a la bici solo movía la llanta y el aro: la
  maza y los rayos se quedaban **clavados donde nació la bici** (y la rueda se veía como
  un plato vacío). Ahora se mueven las cuatro piezas.
- **No andaba.** El asiento salía con `Torque` y `TurnSpeed` en **0**: no giraba la
  llanta ni en el garaje (y en celular no aparecía ni el volante, porque el juego no
  dibuja controles para un vehículo sin potencia). Ahora `Torque = 20`, `TurnSpeed = 12`.
- **En celular no hay tecla E.** Los asientos llevan el atributo `AutoSubir`: en celular
  el juego te sienta solito cuando te acercas (a 7-8 studs del carro o la bici). Si te
  acabas de bajar tienes **4 segundos de gracia** para que no te vuelva a subir.
- En computadora se queda el botón de siempre, con la tecla `E` a 8 studs (carro) y 9 (bici).

## 3. 🏭 La bodega por niveles (y los portones)

| Nivel | Ancho x Fondo | Alto | Cajones |
|---|---|---|---|
| 1 | 26 x 22 | 11 | **1** |
| 2 | 44 x 26 | 14 | 2 |
| 3 | 52 x 30 | 16 | 3 |
| 4 | 68 x 34 | 18 | 4 |

- Al **comprar un auto** el servidor revisa cuántos cajones libres tienes: con la bodega
  en nivel 1 el segundo auto se rechaza con el aviso *"Tu garaje está lleno (bodega nivel
  1): mejora la bodega para tener más cajones"*.
- **Portones:** antes se medía la distancia a **un punto al centro del garaje**. Con un
  garaje de 68 de ancho ese punto queda lejísimos del cajón 1, así que ese portón **no
  abría nunca**. Ahora se mide la distancia a **cada puerta** y se abre **solo la tuya**
  (y suena el portón). Además el portón sube 10 studs (antes menos y el auto raspaba).

## 4. 📱 El dashboard en celular

- **El dock ya no vive abajo.** En celular estaba pegado al borde inferior, justo donde
  Roblox pone el **joystick** y el **botón de saltar**: esos controles se comen el toque.
  Ahora es una **rejilla de iconos grandes** (78x62) pegada al costado derecho, a media
  altura, con el nombre chiquito abajo de cada icono.
- **Iconos nuevos:** `🚗 Auto` (te trae el auto a tu lado), `📱 Teléfono`, `🏠 Bodega`
  (teletransporte a tu bodega), `🛒 Tienda`, `⚙️ Prensar`, `🌿 Cosechar`, `💰 Vender`.
- Los botones ahora van con `Active = true` y `Selectable = false`: el toque cae siempre
  en el botón y un mando no los selecciona sin querer.
- **Se abre el menú solo al acercarte:** la computadora (como antes) y ahora **la bodega**
  (te abre la pestaña de **Autos**, que es lo que vas a querer ahí). Al salir **no** se
  cierra, para que puedas moverte dentro de la lista.
- **Heat:** la sirena 🚨 se fue de la columna. Ahora son **5 estrellas ★** bajo el reloj,
  que se van encendiendo con el nivel de búsqueda (verde → ámbar → rojo) y se apagan solas
  cuando te escondes en la zona segura.

## 5. 🏚️ La parcela vacía (nuevo)

Los lotes sin dueño eran **un cuadro de pasto vacío**: parecía un mapa a medio hacer.
Ahora, cuando andas cerca de la zona de lotes, se levanta una **nave clausurada**:

- Nave chica gris (61 piezas) de lámina vieja con corrugado, techo y buhardilla.
- Portón **tapado con dos tablas cruzadas**, **cadena** y **candado** dorado.
- Letreros: **CLAUSURADA** (rojo, arriba del portón) y **EN VENTA** (al lado).
- Basura de verdad: cajas de madera, llantas viejas, bote y escombros.
- **Un foco exterior que parpadea** (adentro no hay luz: se ve abandonada).
- **Un oficial municipal** parado en la puerta: gorra con visera, placa dorada y un
  **globo de texto** que se prende cuando te acercas (17 studs) y va cambiando de frase
  cada 7 segundos. En computadora también puedes apretarle `E` para que te conteste.

> Se levantan **cuando te acercas** a la zona de lotes (una por segundo), no las 20 de
> golpe: serían ~1200 piezas tiradas en el mapa sin que nadie las vea.

## 6. 🚗 "Mi auto aquí"

El botón nuevo (`🚗` en celular, `Mi auto [Y]` en computadora):

- Si tu auto **está guardado**, lo saca del garaje y lo deja **justo a un lado tuyo**
  (10 studs, mirando hacia donde tú miras).
- Si ya **anda afuera**, te lo **trae** (teletransporte, no te hace otro).
- Si estás **sentado** en él, te dice "Bájate del vehículo primero".

## 7. ✅ Cómo saber que quedó

1. La placa de arriba dice **`RONDA v42  OK`** (con el `OK`; si no lo dice, algún archivo
   viejo se quedó pegado) y el poste de la ciudad dice `v42`.
2. Bodega nueva: **1 cajón**, nave chica, y solo te deja comprar **un** auto.
3. Pasea en bici: los rines la siguen (maza, rayos, aro y llanta).
4. En celular: rejilla de iconos a la derecha; tócale `🚗 Auto` y el carro aparece a tu lado.
5. Vete a los lotes vacíos: nave clausurada con oficial que te habla.

## 8. 🧪 Lo que se probó antes de entregarte (20 escenarios)

`tools/copias.py` ahora corre **20 escenarios** (antes 15). Los 5 nuevos:

- **16.** La bici mueve las **4 piezas** de la rueda y tiene controles (y en celular se
  sube sola, sin letrero de E).
- **17.** Los cajones y portones por nivel: `1:1/1  2:2/2  3:3/3  4:4/4`.
- **18.** Los botones del dock: se tocan de verdad y se revisa **qué acción le llegó al
  servidor** (sale `teleportHome, carAqui`, y el Teléfono abre su pantalla).
- **19.** La nave clausurada: 61 piezas, tablas + cadena + candado, letrero, oficial con
  globo **apagado** y prompt a 12 studs; y que el servidor ponga y quite la clausurada en
  el lote correcto.
- **20.** Con un **jugador de verdad** dentro del servidor: nivel 1 → 1 auto (el segundo se
  rechaza), el auto queda a **10.0 studs** de ti, pedirlo otra vez te lo trae, y al subir a
  nivel 2 ya deja el segundo.
