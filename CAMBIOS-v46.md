# Cambios de la ronda v46

> ## 🎯 TUS 5 REPORTES DE LA CAPTURA DE LA NOCHE
>
> | Lo que reportaste | Qué era | Qué se hizo |
> |---|---|---|
> | **"de noche la bodega y cochera demasiado iluminados por dentro"** | Las lámparas de adentro iban a **1.1** (nave) y **1.15** (cochera), con alcances de 42 y 24 studs; la de la **fachada del portón** estaba en 1.6 y, como está justo arriba de la puerta, metía luz al taller | Cada lámpara de interior tiene ahora **brillo de día y de noche**: nave **0.5 / 0.75**, cochera **0.45 / 0.75**, fachada **1.05**, letrero del portón **1.0**, reflector **1.8 / 66**. **Nunca se apagan**: de día se ven (lo que pediste en la v42) y de noche ya no lavan |
> | **"el garage sigue sin portón"** | El portón medía **12** de ancho (un número fijo en `GameConfig`) pero el **hueco entre pilares mide 24.6**: tapaba la mitad y a los lados quedaban dos huecos negros con vista al taller. Encima le faltaban 0.6 de alto para llegar al dintel | El ancho sale del **hueco real de cada cajón** y el alto llega **hasta el dintel**. Medido: **0.30** studs de holgura a los lados y **0.15** arriba. Ya tiene 7 duelas y la ventanita es más ancha |
> | **"los letreros aún tienen la letra demasiada pequeña"** | El tablero del garaje era de **17 × 3.6** y el texto iba con `TextWrapped`: cabía de sobra en un renglón, así que el escalado lo dejaba **chiquito** flotando en medio de un tablero enorme | El tablero baja a **13 × 3.2** y el texto va en **TextScaled SIN envolver**: crece hasta llenarlo. La letra pasa de ~0.3 a **~1.1 studs de alto** (4× más grande). También suben: placas de cajón (95 px/stud), TALLER/OFICINA (85), travesaño (80), letrero del portón (64) y CLAUSURADA (72) |
> | **"cuando me acerco a la cochera de repente se me abre el mercado"** | Se medía la distancia al **CENTRO** del piso del garaje con un radio de **26**, y ese piso mide 26 × 24: el círculo se salía por la puerta **hasta la calle**, así que pasando frente al portón ya se abría | Ahora se mide contra la **CAJA** del piso (0 si estás adentro; 2 studs de gracia en el umbral). Caminando por la calle **no** se abre; adentro del taller **sí** |
> | **"la van sigue con las ruedas al revés dentro del garaje"** | La llanta se armaba con `CFrame.Angles(0, 0, 90)` sobre un Part cilíndrico, **cuyo eje ya es el X**: la llanta quedaba **parada** (las caras redondas mirando al cielo y al piso). Vista de lado parecían discos tirados y el carro parecía flotando | Se quita esa rotación en llanta, rin, maza y rayos: el eje queda **horizontal** (medido: `ejeY = 0.00`). Esto arregla **todos** los carros, no solo la van. Además el auto estacionado ahora se apoya en la cara de arriba del cajón y se recorre 1.5 studs al fondo para no quedar pegado al portón |

---

## 1. 💡 Las luces de adentro: de día se ven, de noche no encandilan

**La causa:** en la v42 te quejaste de que la cochera se veía **negra** por dentro
(era doble: brillo bajo **y** las luces se apagaban de día). Se subieron a 1.1–1.15
y se dejaron prendidas siempre. Con la v46, de noche eso resultó **demasiado**.

**El arreglo:** una lámpara de interior ahora tiene **dos** brillos:

```lua
tagLight(nave,  0.5, 0.75)   -- (brillo de noche, brillo de día)
tagLight(cochera, 0.45, 0.75)
```

| Lámpara | Antes (noche) | Ahora (noche / día) | Alcance |
|---|---|---|---|
| Cochera (techo del cajón) | 1.15 siempre | **0.45 / 0.75** | 24 → **18** |
| Nave (3 lámparas) | 1.1 siempre | **0.50 / 0.75** | 42 → **30** |
| Fachada del portón | 1.6 | **1.05** (de noche) | 28 → **22** |
| Letrero del portón de la nave | 1.4 | **1.0** | 34 → **26** |
| Reflector del techo | 2.4 | **1.8** | 90 → **66** |

## 2. 🚪 El portón del garaje ahora tapa el hueco completo

```
ANTES (porton de 12 en un hueco de 24.6)          AHORA (ancho = hueco - 0.3)
┌──────┬──────────────┬──────┐                    ┌────┬────────────────┬────┐
│pilar │  PORTON 12   │pilar │  <- 6.3 de hueco    │pil │  PORTON 24.3   │pil │
└──────┴──────────────┴──────┘     a cada lado      └────┴────────────────┴────┘
                                    (se veia el
                                     taller)
```

* El ancho sale de **medir el hueco** de cada cajón (los pilares que lo flanquean
  comen medio ancho cada uno) menos 0.3 de holgura.
* El alto llega **hasta el dintel**: antes quedaba una franja de 0.6 abierta arriba.
* Al abrirse se sigue **enrollando** hacia arriba (como una cortina de taller).

## 3. 🪧 Letreros: la letra ahora LLENA el tablero

El problema no era el tamaño del tablero (agrandarlo fue el intento de la v45 y no
funcionó): era que **con `TextWrapped` el texto cabía de sobra en un renglón**, así
que Roblox lo escalaba al mínimo y quedaba chiquito en el centro.

Ahora el renglón se parte con `\n` y el texto va en **`TextScaled` sin envolver**:
la letra crece hasta llenar el tablero. Con `GARAJE DE <NOMBRE>` en un tablero de
13 × 3.2 studs, cada renglón mide ~1.4 y la letra queda de **~1.1 studs de alto**
(antes ~0.3). Todo a **100 px/stud** para que no salga pixelada.

## 4. 🛒 El mercado ya no se abre en la calle

```lua
-- ANTES: distancia al CENTRO del piso, radio 26  -> llegaba a la calle
-- AHORA: distancia a la CAJA del piso (0 si estas adentro)
local dx = math.max(math.abs(d.X) - piso.Size.X * 0.5, 0)
local dz = math.max(math.abs(d.Z) - piso.Size.Z * 0.5, 0)
enCochera = math.sqrt(dx * dx + dz * dz) <= 2
```

Se sigue abriendo solo (como pediste en la v43) **pero solo al entrar al taller**,
que es cuando vas a sacar o guardar un auto. Caminando por la calle, no.

## 5. 🚐 Las ruedas de la van

La llanta se armaba así:

```lua
-- ANTES: Size (1.5, 2R, 2R) + CFrame.Angles(0, 0, 90)
-- Un Part cilindrico YA tiene su eje en el X del Size: esa rotacion lo PARABA.
-- AHORA: sin rotacion (igual que las ruedas de la bici, que siempre estuvieron bien)
```

Y el auto estacionado ahora se apoya en la **cara de arriba** del cajón (`+0.08`) y se
recorre **1.5 studs al fondo**, para que la van (18 de largo, igual que el cajón) no
quede pegada al portón.

## 6. 🧪 Cómo se probó (etapa 21, corre en `tools/validate.sh`)

| Prueba | Qué mide de verdad | Resultado |
|---|---|---|
| Ruedas | arma la van y calcula el **eje** de cada llanta con la rotación anotada | 4 llantas, **eje horizontal** (`ejeY=0.00`), 4 rines en el mismo eje |
| Portón | mide el **hueco real** entre los pilares de la pared y lo compara con el portón | hueco **24.6**, portón **24.3**, holgura **0.30** a los lados y **0.15** arriba |
| Luces | **prende y apaga la noche de verdad** (llama al ciclo del juego) y mide brillos y alcances | noche **0.45 / 0.50**, día **0.75 / 0.75**, alcances 18 y 30 |
| Letreros | mide el tablero, los px/stud y si el texto llena (`TextScaled`) | 13 × 3.2, **100 px/stud**, letra **~1.07 studs**, dos renglones |
| Mercado | **arranca la ClientUI**, mueve al personaje a la calle y luego adentro | calle: **no** se abre · adentro: **sí** |

Probado **al revés** (metiendo los 4 bugs a propósito): devolviendo la llanta a 90°,
el portón a 12, las luces a 1.15/24 y la regla vieja del radio → la etapa **caza los 4**
(`paradas=4`, `ancho=12.0`, `cocheraNoche=1.15`, `calle=true`).

### ⚠️ Dos mentiras más del simulador (arregladas)

1. **`CFrame.Angles()` no rotaba nada** → no se podía probar "¿la llanta está
   parada o acostada?". Ahora se anota la rotación y se puede medir el eje.
2. **`CollectionService:AddTag` no guardaba nada y `GetTagged` devolvía vacío** →
   el sistema de luces de noche parecía perfecto **sin encender ni apagar una sola
   luz**. Ahora las etiquetas son de verdad.

Sin esos dos arreglos, esta ronda habría "pasado" con los bugs puestos.

## 7. 📋 Archivos que cambian

| Archivo | Qué trae de nuevo |
|---|---|
| `ServerScriptService/CityGenerator.luau` | luces con brillo de día/noche, portón medido por el hueco, letreros que llenan el tablero, ruedas sin la rotación de 90° |
| `ServerScriptService/Main.luau` | el auto estacionado se apoya en el cajón y se recorre al fondo |
| `StarterPlayerScripts/ClientUI.luau` | el mercado solo se abre **adentro** de la cochera |
| `ReplicatedStorage/GameConfig.luau` | `Build = "v46"` |
| `ServerScriptService/DataService.luau` | sello de ronda `v46` |
| `tools/mock.lua`, `tools/reportes46.py` | simulador más fiel + etapa 21 |

---

> **Para ti, en corto:** pega los archivos de la v46 y dale Play. De noche el taller y
> la bodega se ven bien (se ve todo, sin encandilar), el portón se ve **cerrado** de
> verdad cuando no estás cerca, los letreros se leen de lejos y el mercado solo se
> abre cuando **entras** a la cochera.
