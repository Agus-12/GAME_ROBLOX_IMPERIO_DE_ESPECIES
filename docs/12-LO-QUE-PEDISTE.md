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

### 🆕 Ronda v42 (8 quejas nuevas, todas cerradas)

| # | Lo que pediste | Cómo quedó | Ronda |
|---|---|---|---|
| 17 | Bici: al moverse **"los rines se quedan ahí"** | la rueda completa (goma, aro, maza y 6 rayos) viaja con la bici | v42 |
| 18 | En celular el letrero **`E / Bicicleta / Manejar`** "no tiene sentido": ahí **"solo me acerco y se sube"** | en celular se apaga el letrero y la bici te sube sola (≤6 studs); en compu sigue con su tecla `E` | v42 |
| 19 | Al subirme "**no me deja andar**" | el asiento tenía `Torque = 0` (no acepta controles): ahora `40 / 14` | v42 |
| 20 | El auto del garaje sale "**con las llantas como plato**" y no se podía sacar | rines de verdad (aro + maza + 5 rayos) y botón **"Sacar y conducir"**: sale afuera y **te sienta** | v42 |
| 21 | Garaje: "**sigue sin puertas**" y "me subo y no deja andar" | los portones se **enrollan** y se abren **al frente de cada cajón** | v42 |
| 22 | Nivel 1: **solo un auto** y garaje **más chico pero con espacio**; al subir de nivel crece y se ve mejor | `BaysByTier {1,2,3,4}` + garaje 26×24 → 64×38 y más cajones por nivel | v42 |
| 23 | Poder **elegir qué auto sacar** (no subirse "en el primero que aparezca") | cada cajón tiene su portón, su letrero `CAJON n` y su botón propio | v42 |
| 24 | Que las demás parcelas tengan **las bodegas ya cargadas** (estilo diferente); sin jugador = **clausuradas con oficiales** que te digan *"¿qué estás haciendo aquí? está área está clausurada"* y *"si te veo por aquí de nuevo te voy a llevar a la cárcel"* | 6 estilos de bodega vecina + cinta, tablilla `CLAUSURADA` y **2 oficiales** con esas dos líneas (y una tercera si reincides). Cuando el lote tiene dueño se desclausura solo | v42 |
| 25 | La lámpara de afuera "**parece despegada del tubo**" | farol rearmado: poste + brazo + cabeza de luz + visor, todo pegado | v42 |
| 26 | La cochera tiene "**muy baja la iluminación por dentro**" | luz del techo encendida **siempre** en `1.15 / 24` (antes `0.55` y se apagaba de día) | v42 |
| 27 | El dashboard "**se mira raro**": abajo de la hoja el almacenamiento/bloques y la **"sirenita"** del nivel de búsqueda | columna ordenada y explicada; la caja fuerte en **dos renglones**; el nivel de búsqueda son **5 estrellas bajo el reloj** que se prenden con el heat y **se apagan solas** en zona segura | v42 |
| 28 | El dashboard de abajo "**no funciona en celular**": iconos de auto (spawnear donde estés), teléfono y bodega, y menús por proximidad (computadora/caja fuerte) | botón **Auto** (trae tu auto donde estés) + Teléfono, Bodega; computadora y caja fuerte abren solas al acercarte | v42 (**v43 lo termina**: iconos grandes, `Active` y menu al llegar a la bodega) |

## Lo que todavia NO esta hecho (y que nunca pediste, pero anoto)

* **Musica ambiente / sonido de motor** (los sonidos de acciones si existen).
* **Interiores de las propiedades compradas**: hoy solo tienen fachada.

| 33 | **"La van al spawnearla afuera sale mal"** y **"conecta los lotes con calles a la ciudad, haciendo el trazo por cada lote de manera correcta"** | patio del cajón (`BayApron` + `BayRamp`) y la van nace a la altura del patio (`sp.Y + 0.05`, ya no 2.05 fija); 4 calles de hilera (`RoadLotesZ1..4`), 2 caminos norte-sur (el principal toca la calle de la ciudad), 20 rampas de entrada y 50 faroles | **v51** |
| 34 | **"mi bodega no es la que marca el mapa (la mía vendría siendo la 5)"**, **"la (bodega vecina) de en medio está como al ras de la calle"**, el portón "sigue sin aparecer" y la van "sigue bugueada" | la calle de la v51 iba DEBAJO de los patios (que crecen con el nivel: +59/+70/+83/+101) -> calles de hilera a **+121** y rampas a z +104..+111; caminos norte-sur al **hueco real** entre columnas (x=-104 y 236: la bodega nivel 4 mide x −160..+133 de su centro); letreros **GARAJE DE <nombre> - LOTE n** (el juego recuerda tu lote del lugar guardado). El portón y la van siguen abiertos esperando los datos del usuario | **v52** |
| 35 | **"la van al spawnearla aparece con las piezas una arriba de la otra"**, **"el portón aún no aparece (el chico, el del coche)"**, **"mi lote sigue siendo el 5 y en el mapa me lo marcas en el 1"** y **"falta conectar las calles de la ciudad a las de los garages"** | el HomeCF del portón apuntaba a las coordenadas del template (880 studs de su lote: se cerraba VOLANDO al origen del mundo; bug desde la v44) -> `resellarHome` tras cada PivotTo + `PisoY` real; el botón "Auto" peleaba con el bucle de manejo (PivotTo vs posición de memoria, 60 fps) -> el bucle ADOPTA movimientos externos y se asienta al piso; el camino de en medio extendido hasta `RoadZ0` (x=236, empalme con 6 studs de margen); el mapa marca el lote **5** como suyo y el detalle/fachadas dibujan el 5 | **v53** |
| 36 | **"el portón ya quedó ✓"**, **"la van sigue mal y la tengo que respawnear dos veces para poder conducirla"**, **"la bici aparece adentro de la bodega"** y **"las calles de la ciudad quedan desconectadas, como las de la esquina"** | el prompt del cajón (12 studs) deja al jugador PARADO sobre la BayApron = donde nace la van -> le nace encima (barrido de figuras: volumen 19×11×12+2, hasta 20 saltos de 6 hacia la calle + reintento de Sit a 0.25/0.6 s); la bici se fiaba de rayos de 40 studs que pasaban naves/terrenos por libres -> verificación dura `dentroDeAlgo` (cajas de todas las bodegas + rectángulos de todos los lotes, rayo de techo a 60) y nacimiento SIEMPRE en la calle de su hilera (`CalleDeHileraZ`, +121 del origen; los terrenos llegan a +82); RoadZ0 moría en x=308 y el oriente (lote 5, x=760) quedaba a ~500 studs del asfalto -> **RoadLotesX3** (tercer camino norte-sur por el callejón x=576.5 entre las columnas 4/5) + **RoadZ0Ext** (estira RoadZ0 a x=598.5) | **v54** |
| 37 | (sin reporte del usuario: punto del roadmap en `docs/05` y el CAMBIOS de cada ronda) **"música de fondo, sonido de motor para los vehículos y sonido de la bici al rodar"** | el juego estaba mudo al manejar. Tres loops de ProSoundEffects verificados contra la API: **Engine** (9119386571, idle constante; en `hacerConducible`: Play solo con conductor, tono 0.72×→1.27× y volumen suben con la velocidad, Stop al bajarse, RollOff 160), **Rolling** (9126157444, gravilla constante; en el bucle de la bici: el volumen sigue a la velocidad, parada = silencio) y **Music** (9112758500, City Ambience; en ClientUI: `MusicaFondo` en `SoundService` a 0.18, Looped — en SoundService y no en el gui porque el gui muere al respawnear). De paso se arregló el SIMULADOR: el `Disconnect` de las señales dejaba huecos y el `ipairs` del `Fire` se cortaba — al destruir la bici vieja se apagaban TODOS los Heartbeat posteriores (en Roblox real desconectar no apaga a los demás); también el VehicleSeat del mock ahora nace con Throttle/Steer en 0 como en Roblox (el bucle de la bici tronaba cada frame con Steer nil) | **v55** |
## Lo que se descubrio de tu lado (por que "no cambiaba nada")

1. **v37**: el cliente **se apagaba solo** si veia una interfaz del juego ya puesta en
   pantalla (podia ser basura guardada en el lugar, no una copia corriendo).
2. **v37**: la columna del HUD **nunca se hacia visible** (nacia oculta y nadie la
   encendia): la barra ancha se escondia y en su lugar no aparecia nada.
3. **v38**: habia que **poder ver** que ronda corre -> placa + letrero + inventario.
4. **v41**: el tablero viejo se caza **por contenido** (dice "Hojas"/"HEAT"/"Espacio"),
   aunque su nombre no sea el esperado o este dentro de una carpeta.
| 29 | **Bodegas vecinas encima de la calle**, nombres en **texto grandote** flotando, sin decir de quien es cada garaje, y el numero de cajon flotando | calles limitadas a la ciudad; rotulos **pintados** en los tableros negros (nada flotante); **GARAJE DE <nombre>** / **SIN PROPIETARIO**; **CAJA n** en texto plano | **v44** |
| 30 | **"Siguen los mismos bugs"** (bodega vecina con cinta amarilla encima, tablillas viejas), los **letreros salen muy chicos** y la **pistola sigue viendose mal** (tubito gris flotando) | el **lugar guardaba** las obras viejas -> se borran al arrancar (`limpiarObrasViejas`) y el limpiador tambien; letreros mas grandes y `GARAJE DE <nombre>` en dos renglones; cañon **pegado** a la corredera y armas mas grandes | **v45** |
| 31 | De noche la **bodega y la cochera** salen **demasiado iluminadas por dentro**, **el garage sigue sin porton**, **los letreros siguen con la letra chica**, **se abre el mercado solo al acercarse a la cochera** y **la van sigue con las ruedas al revés** | luces de interior con brillo de dia y de noche (0.45-0.5 de noche) y menos alcance; el porton se mide por el **hueco real** entre pilares (24.6, no 12) y llega al dintel; letra que **llena el tablero** (`TextScaled` sin envolver, 100 px/stud, ~1.1 studs de alto); el mercado se abre solo **adentro** del taller; llantas sin la rotacion de 90 grados (eje horizontal) y el auto estacionado apoyado en el cajon | **v46** |
| 32 | La **cinta de clausura gigante** que va de las bodegas inactivas a la del jugador, la **bici adentro** de la bodega, la **letra del letrero** todavía chica y el **mercado que reaparece** al alejarse | la cinta se medía con `math.abs(gl.Position.X)` (con el lote en x=−600 daba 1232 de ancho) y se colocaba en x=0; la bici se medía desde el piso de la nave (cae en el patio); el tablero estaba medio **dentro** de la pared; el panel se abría en cada cruce | cinta/tablilla/oficiales medidos desde **su** portón (32 de ancho en su lote); bici medida desde el **patio** (nace en la calle); tablero **sobre el techo** (completo, letra ~1.7); el mercado se abre **una vez por llegada** (se rearma al salir del lote) | **v47** |
