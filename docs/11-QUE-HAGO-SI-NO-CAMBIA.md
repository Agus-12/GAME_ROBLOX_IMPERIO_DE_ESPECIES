# 11. "Pegue todo y sigue igual" — guia de rescate

Esta guia es para cuando pegas los archivos y el juego se ve **igual que antes**.
Se hace EN ORDEN: cada paso dice que significa lo que ves.

---

## Paso 1. Mira la placa de ronda (10 segundos)

Dale **Play** y mira **arriba al centro** de la pantalla.

| Lo que sale | Que pasa | Que hacer |
|---|---|---|
| **`RONDA v41  OK`** | el archivo nuevo SI corre | el juego esta al dia: lo que falte es otro archivo, no la ClientUI |
| **`RONDA v41` + "borre N tablero(s) viejo(s)"** | encontro y borro una copia vieja que se veia encima | perfecto: mira que ya no quede el tablero ancho |
| **`RONDA v41  (arrancando...)`** y no cambia | la ClientUI corre pero **truena** a medio camino | paso 3 (mira el Output) |
| **no sale placa** | esa ClientUI **no corre** | pasos 2 y 4 |
| sale **otra** ronda (v32, v36...) | estas corriendo un archivo **viejo** | paso 2 |

Tambien mira el **letrero del spawn** (arriba de donde apareces): dice
`SERVIDOR v41`. Si el letrero es viejo y la placa nueva, el problema esta del lado
del servidor; si el letrero es nuevo y la placa no sale, el problema es la ClientUI.

## Paso 2. ¿La ClientUI es LocalScript y esta prendida?

En Studio, en el **Explorer**:

`StarterPlayer` > `StarterPlayerScripts` > **`ClientUI`**

1. Tiene que decir **LocalScript** (arriba del panel de codigo). Si dice `Script`,
   ese no corre ahi: borralo, y crea uno nuevo con clic derecho >
   `Insert Object` > `LocalScript`, y pega el codigo.
2. En la lista de propiedades, **`Enabled`** tiene que estar **palomeado**.
3. Tiene que haber **un solo** `ClientUI`.

El Output tambien lo dice solo (ronda v41):

```
[SpiceEmpire]  MAL    StarterPlayer > StarterPlayerScripts > ClientUI (es Script)
[SpiceEmpire]  CLIENT StarterPlayer > StarterPlayerScripts > ClientUI si va a correr
```

## Paso 3. Mira el Output

En Studio: pestana **View** (de adentro de Studio) > boton **Output**.

Ahí el juego escribe un **INVENTARIO** al arrancar. Busca las lineas que empiezan
con `[SpiceEmpire]`:

```
[SpiceEmpire] ==== INVENTARIO DE ARCHIVOS DEL JUEGO (v41, al arrancar) ====
[SpiceEmpire]   OK     ReplicatedStorage > GameConfig
[SpiceEmpire]   VIEJO  [v32] StarterPlayer > StarterPlayerScripts > ClientUI   <- es de otra ronda, pegalo de nuevo
[SpiceEmpire]   COPIA  [v41] ServerScriptService > Main   <- borra esta (clic derecho > Delete)
[SpiceEmpire]   BASURA StarterGui > SpiceEmpireUI   <- interfaz guardada en el lugar (la borro yo)
[SpiceEmpire]   FALTA  ServerScriptService > DataService   <- pegalo (falta por completo)
```

* **FALTA** = ese archivo no esta: pegalo.
* **VIEJO [vNN]** = esta, pero es de otra ronda: pegalo otra vez.
* **COPIA** = hay mas de uno: deja UNO (el que diga la ronda nueva) y borra los demas.
* **BASURA** = interfaz guardada dentro del lugar: la v41 ya la borra sola.
* **DIBUJA** = un LocalScript que puede estar dibujando interfaz por su cuenta
  (una copia vieja escondida): si no debe estar ahi, borralo.

## Paso 4. La limpieza (si de plano no cambia)

1. En el Explorer, busca **`SpiceEmpireUI`** dentro de **`StarterGui`** y borralo
   (clic derecho > `Delete`). Es una interfaz **guardada** dentro del lugar: viaja
   con el lugar y sale en pantalla en cada Play, aunque pegues todo.
   **Ojo**: no basta con mirar el primer nivel: revisa tambien **dentro de las carpetas**
   de `StarterGui` (la ronda v41 ya las borra sola, pero si quieres hacerlo a mano, ahi
   estan). El Output te da la ruta exacta con la marca `BASURA`.
2. Borra las carpetas **`Remotes`** de mas (deja una sola; el juego crea la suya).
3. Deja **un solo** `Main`, un solo `CityGenerator`, un solo `DataService`, un solo
   `GameConfig` y **un solo** `ClientUI`.
4. Vuelve a pegar los 5 archivos (y da **Enter** al limpiador en la Command Bar).

## Leyenda azul "Encontre carpetas 'Remotes' de mas"

Sale cuando hay una carpeta `Remotes` **vieja** en el lugar (sin sello, con menos
remotes). **No es un error: puedes jugar normal** (el juego usa la suya). Para que no
vuelva: pega el **LIMPIADOR** (pestana 0) en la Command Bar, o borra a mano todas las
carpetas `Remotes` de `ReplicatedStorage` y deja **un solo `Main`** en
`ServerScriptService` (el que diga `RONDA: v41`). Mas detalle: `docs/09`.

## Paso 5. Si sigue igual, mandame esto

1. Captura de la **placa de ronda** (arriba al centro) y del **letrero del spawn**.
2. Captura del **Output** con las lineas `[SpiceEmpire]`.

Con eso se sabe exactamente que archivo falta: **no hay que adivinar**.

---

## Si lo que no cambia es la BICI, el AUTO DEL GARAJE o la CLAUSURA (v42)

Estas tres cosas se pueden revisar solas, sin adivinar:

1. **Mira la placa de arriba al centro:** tiene que decir `RONDA v42  OK`. Si dice
   `(arrancando...)` o no dice `v42`, el archivo del cliente que pegaste es de otra ronda.
2. **Bici:** en compu sale el letrero `E / Bicicleta / Manejar`; **en celular NO tiene que
   salir** y al acercarte la bici te sube sola. Si te subes y **no acelera**, el `Main` en
   `ServerScriptService` es viejo (ese arreglo vive en el servidor).
3. **Auto del garaje:** en cada cajón hay un letrero `CAJON n` y un botón
   **"Sacar y conducir"**. Si el auto sale con las llantas como plato o se queda dentro del
   cajón, el archivo viejo es `CityGenerator` (las llantas) o `Main` (el punto de salida).
4. **Clausura:** afuera de tu bodega, los demás lotes tienen que tener casona de otro color,
   cinta amarilla, tablilla `CLAUSURADA` y **dos oficiales**. Si no hay nada, el `Main`
   viejo es el culpable (es el que amuebla los lotes).
5. **Luz de la cochera:** entra al garaje de día: no puede verse negro. Si se ve negro, el
   archivo viejo es `CityGenerator`.
6. **Estrellas del nivel de búsqueda:** abajo del reloj (arriba a la derecha) tienen que
   estar las 5 estrellitas. Si en su lugar sigue el 🚨 en la columna, el viejo es
   `ClientUI` (el cliente).

Recuerda: **borra las copias primero** (Explorer > clic derecho > Delete) y después pega.
