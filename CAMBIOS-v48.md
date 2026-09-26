# Cambios de la ronda v48

> ## 🎯 TUS REPORTES DE ESTA RONDA (y la solución concreta de cada uno)
>
> | Lo que reportaste | Qué era de verdad | Qué se hizo |
> |---|---|---|
> | **"la cinta amarilla por lo menos ya se quitó"** | — | ✅ Confirmado, la v47 quedó bien |
> | **"la bici sigue apareciendo adentro"** | La cuenta de la v47 (medir desde el patio + 6) sí estaba bien, pero **nadie comprobaba que ese punto estuviera libre**: si el rayo no encontraba piso, o si el jugador estaba **adentro** del taller (que es justo donde apareces al entrar) y el lote **todavía no existía**, la bici caía **adentro** | Ahora se **comprueba el lugar** antes de soltar la bici: **cielo abierto arriba** (si hay techo, es adentro), **piso abajo** y **nada a 5 studs de cada lado**. Si el primer punto no sirve, **camina de 4 en 4 studs hasta 120** desde la orilla del patio hacia la calle; si el lote no existe todavía, busca alrededor del jugador. Medido: con lote nace en **z = −595** (6 studs más allá de la orilla del patio, 37 más allá de la pared, cielo abierto, 0 choques) y con el jugador **adentro del taller** nace en **z = −696**, también afuera |
> | **"el mercado … me gustaría más que al alejarme se quitara como el de la computadora o la bóveda"** | El panel del mercado (que ahora es tu spawn de vehículos) se abría **una sola vez por llegada**, pero **no se cerraba nunca solo**: te ibas al otro lado de la ciudad y seguía abierto | Ahora se **cierra solo al alejarte del taller** (a más de 8 studs de la placa del piso), **igual que la computadora y la bóveda**. Se abre una vez al entrar, se cierra si te vas caminando, y si vuelves a entrar se abre otra vez. Medido: `entroAbrio=true → cerroAlAlejarme=true → reentroAbrio=true → cerradoTrasCerrar=true` |
> | **"el letrero aún siguen las letras muy pequeñas"** (3er reporte) | El tablero era de **15 × 4** y, peor, el nombre iba en **DOS renglones** ("GARAJE DE" / "PEPE"): cada renglón cabía en medio tablero y la letra salía de **~1.7 studs**. Y el rótulo ya venía puesto con **100 px/stud**: pedir 120 en el código de la ronda **no servía de nada** porque solo se cambiaba el texto | Tablero de **26 × 5.4** inclinado 12° hacia la calle (para que se lea desde el patio), **UN SOLO renglón** y, al rotular, se le **sube la resolución a las dos caras** (100 → 120 px/stud). La letra pasa de **~1.7 a ~3.0 studs** de alto: casi el doble |
> | **"las bodegas … me gustaría que se vieran más realistas, unas mejores texturas"** | La bodega era una caja: paredes lisas de ladrillo, piso de concreto y el techo. Cero detalle | **17 piezas nuevas de decoración** con materiales de Roblox (no hay imágenes que subir): zócalo de concreto al pie de las paredes, **costillas metálicas** en la fachada, **franja de color** a media pared, **ventanas altas** de vidrio en los costados, **columnas de acero** con placa en la base, **viga de carga** con polipasto, **canoa** en el techo, **respiraderos**, **franjas de seguridad** amarillas en el piso, **placa de acero antiderrapante** en el andén, **manchas de aceite**, **juntas de colado** y manchas en el patio, tubería y extintor. Y las **paredes de la nave pasan de ladrillo a metal industrial** (`CorrodedMetal`), que es como son las bodegas de verdad. Medido: la bodega usa **20 materiales distintos** y las 17 piezas están |
> | **"al spawnear la van o los autos me sube sí pero no me deja conducirlo"** | **Ésta es la causa raíz de todo:** el auto era **pura física de Roblox**: un `VehicleSeat` que empujaba las ruedas por **bisagras**. Pero `Torque`, `MaxSpeed`, `TurnSpeed` del `VehicleSeat` están **OBSOLETOS** desde hace años y las `HingeConstraint` sin `ActuatorType` **no giran solas**: el asiento te sienta (te "sube") y **no mueve nada**. No era tu van, ni la altura, ni el torque: **el vehículo no tenía con qué moverse** | El auto ahora **no usa física**: el servidor **ancla el carro y lo maneja él** (el mismo truco de la bici, que sí funciona). 56 piezas del carro quedan soldadas al chasis, las 4 ruedas giran y el servidor lee `Throttle`/`Steer` (los pone Roblox solitos con W/S/A/D y con los botones del celular) y mueve el carro con **raycasts** de piso y pared. **Medido con el servidor de verdad corriendo:** con el acelerador a fondo avanza **82 studs**, el volante lo gira **180°**, al soltar frena solo, las **4 ruedas giran** y ninguna de las 56 piezas se queda atrás |

---

## 1. 🚗 "Me sube sí pero no me deja conducirlo" — el porqué, con pelos y señales

```
v47 (lo que tenías):            el asiento empuja las ruedas por BISAGRAS FÍSICAS

   VehicleSeat.Torque      = 60   <- PROPIEDAD OBSOLETA (Roblox ya no la usa)
   VehicleSeat.TurnSpeed   = 20   <- PROPIEDAD OBSOLETA
   VehicleSeat.MaxSpeed    = 60   <- PROPIEDAD OBSOLETA
   HingeConstraint (x4)    = sin ActuatorType  ->  NO GIRAN SOLAS

   Resultado: te sientas (eso sí funciona) y el carro NO se mueve. Nunca.
   (no es culpa de tus autos: le pasa a cualquier VehicleSeat así armado)

v48 (ahora):                    el servidor maneja el carro, cero física

   el servidor lee    seat.Throttle / seat.Steer   (los pone Roblox con W/S/A/D
                                                    y con los botones del celular)
   el servidor mueve  chasis + 55 piezas soldadas (CFrame, exacto, igual que la bici)
   el servidor mira   rayo al piso  (escalón máx. 1.6: banqueta sí, pared no)
                      rayo al frente (pared = se frena solo)
                      caída si no hay piso (gravedad 70)
   ruedas:            giran con el carro (spin acumulado), 4 de 4
```

**Por qué esto también arregla el "rebote" y las piezas volando:** al estar todo
anclado y soldado, el carro **no se puede desarmar**, no se atora en las esquinas y
sube la banqueta sin quedarse vibrando. Es el mismo sistema que ya usaba la bici,
que es lo único que nunca te dio problemas.

## 2. 🚲 La bici: el punto se comprueba antes de soltarla

| | v47 | v48 |
|---|---|---|
| De dónde se mide | el patio (`LotApron`) + 6 | igual |
| **¿Se comprueba el punto?** | **no** | **sí**: cielo abierto arriba, piso abajo, nada a 5 studs de los lados |
| Si el punto está tapado | cae ahí mismo (adentro) | camina de 4 en 4 studs, hasta **120**, hacia la calle |
| Si el lote todavía no existe | 7 studs a la izquierda del jugador (**= adentro** si estás en el taller) | lo busca **alrededor del jugador** con las mismas comprobaciones |

Medido con el lote en el mundo de verdad (antes las pruebas **no metían el lote en el
mundo**, así que el rayo no veía la bodega y todo pasaba "libre": eso también se
arregló):

```
con lote:      x=-600.0  z=-595.0   techo=libre  orillaPatio=-601.0  choques=0
sin lote:      x=-600.0  z=-696.0   techo=libre  (el jugador estaba ADENTRO del taller)
```

## 3. 🪧 El letrero: de ~1.7 a ~3.0 studs de letra

```
v47                                  v48
┌───────────────┐ 15 x 4             ┌──────────────────────────┐ 26 x 5.4
│   GARAJE DE   │  <- dos renglones  │      GARAJE DE PEPE      │  <- UN renglón
│      PEPE     │     letra ~1.7     └──────────────────────────┘     letra ~3.0
└───────────────┘                        inclinado 12° hacia la calle
     100 px/stud                            120 px/stud (y ahora SÍ se aplica)
```

Lo que faltaba era justo lo que se veía chiquito: **dos renglones** y un tablero que
apenas tenía 15 de ancho. Con un renglón en un tablero de 26 la letra **no tiene de
otra**: `TextScaled` la estira hasta llenar. Medidas de la etapa 22/23:

```
abajo=14.60  arriba=20.00  techo=14.40   (se para sobre el techo, con 2 postes)
ancho=26.0   alto=5.4   dosRenglones=false   px=120   letra ≈ 3.0 studs
```

## 4. 🏪 El mercado: se cierra al alejarte (como la computadora)

| | v46/v47 | v48 |
|---|---|---|
| Se abre al entrar al taller | 1 vez por llegada | igual |
| Si lo cierras a mano | se queda cerrado | igual |
| **Si te alejas** | **seguía abierto** | **se cierra solo** a más de 8 studs de la placa |
| Al volver a entrar | se abre otra vez | igual |

Las otras pestañas (Bodega, Mejoras, etc.) **no se tocan**: solo el panel del mercado
(`currentTab == "autos"`), que es el que dijiste que parecía un spawn de vehículos.

## 5. 🏭 Las bodegas ya no son una caja

```
             ANTES                              AHORA
   ┌────────────────────────┐        ┌────────────────────────┐
   │ pared lisa de ladrillo │        │ ▥▥▥ costillas metálicas │  + franja de color
   │                        │        │ ▭▭ ventanas altas ▭▭    │
   │   piso de concreto     │        │ ║ columnas de acero ║    │  + viga con polipasto
   │                        │        │ ▬▬▬ franjas amarillas   │  + placa de acero
   └────────────────────────┘        └────────────────────────┘
    techo pelón                       + canoa, respiraderos, extintor, tubería
    patio pelón                       + juntas de colado y manchas de aceite
    paredes: Brick                    paredes: CorrodedMetal (metal industrial)
                                       materiales distintos: 1 -> 20
```

Todo es **geometría con los materiales que ya trae Roblox** (`Metal`, `Concrete`,
`DiamondPlate`, `CorrodedMetal`, `Glass`, `Neon`…): no hay que **subir ninguna
imagen** ni hay ningún ID que se pueda romper. Lo decorativo va **sin colisión**
(nada estorba el paso) y las que sí chocan se probaron una por una: de hecho la
primera versión del zócalo **tapaba la puerta de la oficina y el paso al garaje** y el
validador la cazó (etapa 7: *"no se puede caminar al garaje"*), así que bajó a 0.4 y
sin colisión.

## 6. 🔬 Lo que se estudió del proyecto para llegar a esto

1. **Se levantó el API de Roblox de verdad** (`tools/api.py`, 7.3 MB) y se comprobó
   enum por enum: `VehicleSeat.Torque/TurnSpeed/MaxSpeed` salen como **deprecated** y
   los materiales que se usaron **todos existen** (`CorrugatedMetal` **no** existe:
   por eso se usa `CorrodedMetal`).
2. **Se arreglaron 5 mentiras más del simulador** (`tools/mock.lua`) para poder medir
   la conducción de verdad: `Heartbeat` (¡no había!, sin él nada que se mueva por
   cuadros podía probarse), raycasts que **excluyen los descendientes** del filtro
   (el carro se raycastaba **a sí mismo**: por eso "se frenaba solo"), `ZVector`,
   `Humanoid` con vida y **enumerados cacheados** (antes `Enum.Material.Metal` daba
   una tabla nueva cada vez, así que **nunca** era igual a sí mismo y no se podía
   contar materiales distintos).
3. **Prueba al revés** (`tools/alreves48.py`): se mete cada uno de los 5 bugs de esta
   ronda y la etapa 23 **truena** con cada uno. Los 5 chequeos sirven.

## 7. ✅ Validación

```
python3 tools/reportes48.py     (etapa 23)
  OK  el auto AVANZA 82 studs con el acelerador, gira, frena, las 4 ruedas giran
      y el carro viaja entero (sin física)
  OK  la bici nace en la calle con cielo abierto, y con el jugador adentro del
      taller TAMPOCO nace adentro
  OK  la letra de 'GARAJE DE PEPE' sale de ~3.5 studs en un tablero de 26x5.4
  OK  el mercado se abre al entrar y SE CIERRA SOLO al alejarte
  OK  la bodega trae los 17 detalles nuevos, 20 materiales distintos y las
      paredes en metal industrial

bash tools/validate.sh          (etapas 1..23, todas)
```

> **Regla de la casa:** ningún chequeo se da por bueno sin meterle el bug. La etapa 23
> se probó al revés con los 5 y los 5 truenan.
