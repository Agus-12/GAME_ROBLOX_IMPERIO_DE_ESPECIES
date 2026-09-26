# Cambios de la ronda v49

> ## 🎯 TUS REPORTES DE ESTA RONDA
>
> | Lo que reportaste | Qué era de verdad | Qué se hizo |
> |---|---|---|
> | **"el mercado de la cochera se sigue quedando pegado no importa cuanto me aleje"** | El cierre estaba **atado a la marca "una vez por entrada"** y vivía **dentro del detector de cruce** del garaje: si lo abrías con el **botón Auto [Y]** o la **tecla V**, ese detector nunca se cruzaba y **no había nada que lo cerrara** | Ahora es **exactamente el patrón de la computadora y la bóveda**: se abre al **cruzar** la entrada del cajón y el **cierre va aparte** (a más de 12 studs del cajón, sin `enLote`, sin marcas, sin condiciones raras). Da igual cómo lo hayas abierto. Medido: `abrio=true → alSalir=false → cerroLejos=true` (me fui a 400 studs) |
> | **"los letreros la letra sigue quedando re chiquita"** (4º reporte) | **Dos causas de fondo.** (1) Los rótulos se pintaban en las caras **Back/Front** aunque la pieza fuera larga en Z: la placa del paso al garaje mide **3.2 × 2.0 × 16.4**, así que "TALLER" se pintaba en la cara de **3.2** y salía de **0.80 studs**… y **no había forma de agrandarlo más**: el texto ya llenaba esa cara. (2) El tamaño se dejaba a **`TextScaled`**, o sea al motor de Roblox, y **no se podía medir** | `textoPlano` ahora pinta en **las caras GRANDES** de cada pieza y acepta **`letra = <studs>`**: el tamaño se **calcula** (píxeles = studs × px/stud) en vez de dejarlo al motor, y `RotularGaraje` ya no fuerza `TextScaled`. La placa de la cochera mide **4.13** studs de letra (**antes 0.2**), TALLER/OFICINA **1.64** (antes 0.80/0.65), CAJA n 1.64, la caja fuerte 1.38, el letrero de la fachada 2.31. **Los 8 rótulos del lote se MIDEN** en la etapa 24 |
> | **"sigue sin aparecer el porton de la cochera"** | El portón **sí existía y estaba bien** (24.3 × 10.4, tapando el hueco completo, a la altura del piso). Lo que pasaba es que **(a) se abría a 10 studs**: parado en el patio ya estaba abierto, así que **nunca lo veías cerrado**; y **(b) era una hoja gris** sobre un hueco oscuro, sin nada que dijera "portón" | `OpenRadius` **10 → 7** (ahora se ve cerrado y se abre justo al llegar), **franja de seguridad roja/blanca** de 6 tramos abajo, ventanita de **2.2** y **manija de 2.6**. Y el **letrero de la cochera bajó a descansar sobre el techo del garaje (14.4..18.8)**, justo arriba del portón, en vez de estar 10 studs más arriba escondido entre el techo y el árbol |
> | **"en el piso aparecen como unos palitos negros creo que son los de las luces uv"** | Eran **las manchas de aceite** que puse en la v48. Un `Part` cilíndrico tiene su **eje en X** (el largo va en X, el diámetro en Y y Z) y el `CFrame` se aplica **después**: con `size (4.6, 0.1, 4.6)` el "disco" era un **tubo de 4.6** de largo y 0.1 de grueso, y el giro de 90° en Z lo dejaba **parado**. Un palito negro de 4.6 studs. (Y mi primer intento de arreglo **seguía mal**: puse el grosor en Y, que es el **radio** del cilindro) | Grosor **(0.12) en X** y diámetro (4.6) en Y y Z, con el mismo giro: **disco plano tirado en el piso**. La etapa 24 comprueba que el **eje X de cada cilindro quede vertical** (aplastado contra el piso) |
> | **"no podemos hacer mas facil esto? que tu de verdad veas el juego en vivo?"** | No puedo ver tu Studio (no tengo acceso), pero **sí puedo ver el lote** | Nuevo **`tools/mirar.py`**: arma el lote con el simulador, saca las medidas **reales** de las 545 piezas y dibuja **la fachada de frente** (el portón, la franja, la placa con su letra, el techo) y **la planta** (cochera, patio, calle y dónde nace la bici). Te lo mando como imagen: **`/home/user/mirar-lote.png`** |

---

## 1. 🚪 El portón: por qué "no aparecía" (y las cuentas)

```
EL PORTON SI EXISTIA...              ...PERO SE ABRIA SOLO, TODO EL TIEMPO

  patio          patio               apertura a 10 studs (v48)
   |              |                  al caminar por el patio: ABIERTO
   |   ┌──────┐   |                  al acercarte:               ABIERTO
   |   │      │   |                  al llegar al cajon:         ABIERTO
   |   │      │   |                  -> nunca lo veias cerrado
   |   └──────┘   |
   +----10------- llegar
                                             v49: 7 studs
   cerrado de lejos  ->  se abre al llegar  ->  se ve la franja roja/blanca
```

## 2. 🪧 La letra: de 0.2 a 4.1 studs (y por qué las 3 rondas anteriores fallaron)

```
v46:  nombre en DOS renglones + TextWrapped        -> ~0.3 studs
v47:  tablero mas grande, dos renglones            -> ~1.7
v48:  tablero 26x5.4 en UN renglon, TextScaled     -> ~3.0  (pero el motor decide)
v49:  la letra se PIDE en studs y se calcula       ->  4.13 (medida, no estimada)

Y la placa que NADIE podia agrandar (su texto ya llenaba la cara donde se pintaba):

        "TALLER" pintado en la cara de 3.2         pintado en la cara de 16.4
        ┌──3.2──┐                                 ┌─────────16.4─────────┐
        │ TALLER │  -> 0.80 studs                   │       TALLER         │ -> 1.64
        └────────┘  (ya no cabia mas)              └──────────────────────┘
              ↑ textura "Back": la cara CORTA            ↑ la cara LARGA
```

## 3. 🌫️ Los "palitos negros" del piso

```
Un Part cilindrico:  el EJE (el largo) va en X, y el diametro en Y y Z

   MAL (v48):  Size = (4.6, 0.1, 4.6)  + girar 90 en Z
               eje X horizontal  ->  TUBO de 4.6 PARADO  =  el "palito negro"

   BIEN (v49): Size = (0.12, 4.6, 4.6) + girar 90 en Z
               eje X vertical    ->  disco de 4.6 ACOSTADO en el piso
```

## 4. 🏪 El mercado: ahora sí, igualito a la computadora

| | v47 | v48 | **v49** |
|---|---|---|---|
| Se abre | al cruzar (1 vez por entrada) | igual | al **cruzar** la entrada del cajón |
| Botón Auto [Y] / tecla V | abría, **nunca cerraba** | cerraba solo si… | **cerraba solo** (a 12 studs) |
| Cierre al alejarse | no | atado a `enLote` + marca | **sin marcas ni `enLote`**: solo la caja del cajón |
| Otras pestañas (bodega…) | no se tocan | no se tocan | **no se tocan** |

## 5. 👀 "¿Que tú veas el juego en vivo?"

No puedo entrar a tu Studio, pero **sí puedo ver el lote**. `tools/mirar.py` lo arma
con el simulador y dibuja:

* **la fachada**, de frente: el portón con su franja, la placa **GARAJE DE PEPE** con
  su letra de 4.1 studs, el techo a 14.4, y las medidas de cada cosa;
* **la planta**, de arriba: la cochera, el patio, la calle y el punto exacto donde
  nace la bici (6 studs más allá del patio).

Te lo mando en **`/home/user/mirar-lote.png`** (y el SVG en `mirar-lote.svg`, que se
puede abrir en el navegador y hacer zoom). De aquí en adelante, cada ronda la reviso
ahí antes de entregártela.

## 6. ✅ Validación

```
python3 tools/reportes49.py          (etapa 24, nueva)
  GarageDoorHead   16.4x2.0   letra=1.64 studs   'TALLER'
  OfficeDoorHead   10.4x2.0   letra=1.64 studs   'OFICINA'
  FrontWall        23.8x4.0   letra=3.14 studs   'GARAJE'
  VaultBody        10.0x11.0  letra=1.38 studs   'CAJA FUERTE [C]'
  BayPlate          5.4x2.3   letra=1.64 studs   'CAJA 1'
  GarageSign       24.0x4.4   letra=4.13 studs   'GARAJE DE PEPE'
  MonitorBody       6.4x4.0   letra=1.20 studs   'MEJORAS [G]'
  GateSign         26.0x4.2   letra=2.31 studs   'IMPERIO DE ESPECIAS'
  OK  el porton existe, tapa el hueco, trae franja roja/blanca, ventana y manija,
      se abre a 7 studs y no hay ningun cilindro mal hecho
  OK  el panel se abre en el cajon y SE CIERRA al alejarte (400 studs)

bash tools/validate.sh               (etapas 1..24, todas)
```

> **Prueba al revés** (`tools/alreves49.py`): se metió cada uno de los 6 bugs (la
> letra en la cara angosta, la letra otra vez a `TextScaled`, el portón a 10 studs,
> el portón sin franja, la mancha como tubo, y el mercado que no se cierra) y la
> etapa **truena con los 6**. Los chequeos sirven.
