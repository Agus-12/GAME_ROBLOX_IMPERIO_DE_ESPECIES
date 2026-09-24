# 12. Lo que pediste (y en que ronda quedo)

Lista completa de los pedidos, en tus palabras, con la ronda donde se hizo. Sirve
para revisar que nada se pierda.

| # | Lo que pediste | Estado | Ronda |
|---|---|---|---|
| 1 | **La oficina**: afuera de la bodega, pegada, con **puerta real** desde adentro y **ventanas de verdad** (nada de "calcomania") | hecho | v29 |
| 2 | **El HUD**: una **columna vertical pegada al lado izquierdo** (de arriba hacia abajo), NO la barra ancha que tapaba media pantalla | hecho (v36 lo pide otra vez; **v37 lo arregla de raiz**) | v29 / v36 / v37 |
| 3 | **Que se juegue bien en el telefono** (nada de controles encimados) | hecho | v29 |
| 4 | **Garaje** con **portones de verdad** que se **vean cerrados** hasta que llegas, y que el garaje **crezca** con las mejoras | hecho (los portones siempre existieron: el radio los abria desde lejos; v36 lo baja a 13) | v29 / v36 |
| 5 | **Carros realistas** ("no de mentiras") | hecho (`BuildCar`) | v29 |
| 6 | **Bici**: que se pueda **subir a manejarla** y que las **llantas se vean bien** (no un "plato" blanco) | hecho | v36 |
| 7 | **Carros con boton "Conducir"** (y la bici "Manejar") | hecho | v36 |
| 8 | **Luces de noche** con ciclo dia/noche, que **se apaguen de dia** y **no quemen** los interiores | hecho (v36 suaviza garage y bodega) | v29 / v36 |
| 9 | **Que no salga el dashboard viejo** (la barra ancha) | **v41** (la copia vieja se caza por CONTENIDO, aunque se llame distinto o este en una carpeta) | v36 / v37 / v38 / v41 |
| 10 | **Entrega copiar-y-pegar**: los archivos "ahi al picarle" (nada de links) | HTML autocontenido con boton de copiar | v28+ |
| 11 | **Siempre** el paso "borra las copias primero" | en el HTML, el limpiador y los docs | v28+ |
| 12 | La intro **no** se queda en "Cargando la ciudad...": el boton `ENTRAR AL BARRIO` sale ya | hecho | v31 |
| 13 | **Revisar exhaustivamente y reparar todos los danos** | cada ronda: `tools/validate.sh` (13 etapas) + las pruebas de `tools/copias.py` | v28+ |
| 14 | **Poder saber que archivo esta viejo** sin adivinar | **testigos**: placa `RONDA vNN` en pantalla, letrero `SERVIDOR vNN` en el spawn, INVENTARIO en el Output | v38 / v41 |
| 15 | **Bici**: los **rines se quedan clavados** al moverla; en celular el letrero de `E` no tiene sentido; **no anda** en el garaje | rueda completa (llanta+aro+**maza**+**rayos**), `Torque`/`TurnSpeed` ya no en 0 y `AutoSubir` en celular | **v42** |
| 16 | **Bodega nivel 1**: solo **un auto** y el garaje **mas chico**; al subir de nivel **todo crece** | tamanos y cajones **por nivel** (`Bays`/`MaxCars` 1-2-3-4) + candado en `buyVehicle` | **v42** |
| 17 | **Dashboard de abajo no funciona en celular** | rejilla de **iconos** lejos del joystick/salto, `Active=true`, botones que **si** mandan su accion, y **abrir menu** al acercarte a la computadora o a la bodega | **v42** |
| 18 | **Parcela vacia**: que se vea una **bodega clausurada** (estilo distinto) y **oficiales** con los que puedas **hablar al acercarte** | nave gris con tablas+cadena+candado, letreros `CLAUSURADA`/`EN VENTA`, basura, foco que parpadea y **oficial con globo de dialogo** | **v42** |

## Lo que todavia NO esta hecho (y que nunca pediste, pero anoto)

* **Musica ambiente / sonido de motor** (los sonidos de acciones si existen).
* **Interiores de las propiedades compradas**: hoy solo tienen fachada.

## Lo que se descubrio de tu lado (por que "no cambiaba nada")

1. **v37**: el cliente **se apagaba solo** si veia una interfaz del juego ya puesta en
   pantalla (podia ser basura guardada en el lugar, no una copia corriendo).
2. **v37**: la columna del HUD **nunca se hacia visible** (nacia oculta y nadie la
   encendia): la barra ancha se escondia y en su lugar no aparecia nada.
3. **v38**: habia que **poder ver** que ronda corre -> placa + letrero + inventario.
4. **v41**: el tablero viejo se caza **por contenido** (dice "Hojas"/"HEAT"/"Espacio"),
   aunque su nombre no sea el esperado o este dentro de una carpeta.
