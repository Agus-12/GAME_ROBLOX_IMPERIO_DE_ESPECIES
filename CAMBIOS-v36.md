# Cambios de la ronda v36

> Resumen: se arreglo el **tablero viejo que salia encima** (habia otra `ClientUI`
> corriendo), las **llantas de la bici**, que **no te podias subir** a la bici ni al
> carro, y la **luz quemada** de adentro del garaje y la bodega. Ademas el
> **INVENTARIO** ahora dice de que RONDA es cada archivo, para que se vea de un
> golpe cual quedo viejo.

---

## 1. 🖥️ "Se me aparece el dashboard anterior"

**Por que pasaba:** no era que hubieramos retrocedido. En tu Studio habia **otra
`ClientUI` corriendo** (una copia vieja). Las dos dibujaban su interfaz, y la vieja
dibujaba **su** tablero ancho (`$0 | HEAT 0% | Hojas | Bloques | Espacio`) encima.

**Arreglado (v36):** al arrancar, esta copia **borra las interfaces del juego que no
son suyas** (las de las otras copias). Se repite a los 1.5 s y a los 4 s, por si la
copia vieja arranca un instante despues. En la consola sale:

```
[SpiceEmpire] limpie 1 interfaz(es) de otra copia del juego (habia mas de una ClientUI corriendo)
```

Y la version nueva ya se apagaba sola desde la v35 (el "latido"); esto es el segundo
cerrojo: aunque la copia vieja sea mas vieja y no sepa apagarse, **su interfaz se borra**.

## 2. 🔎 El INVENTARIO ahora dice la RONDA de cada archivo

```
[SpiceEmpire] ==== INVENTARIO DE ARCHIVOS DEL JUEGO (v36, al arrancar) ====
[SpiceEmpire]  OK     [v36] ServerScriptService > Main
[SpiceEmpire]  VIEJO  [v29] ServerScriptService > CityGenerator   <- es de otra ronda, pegalo de nuevo
[SpiceEmpire]  VIEJO  [v32] StarterPlayer > StarterPlayerScripts > ClientUI   <- ...
[SpiceEmpire]  COPIA  [v32] StarterGui > ClientUI2   <- borra esta (clic derecho > Delete)
```

En Studio el servidor **puede leer el codigo** de cada script, asi que lee el sello
`RONDA: vNN` y te dice exactamente cual quedo viejo. Ya no hay que adivinar nada.

## 3. 🚲 La bici: llantas y como subirse

* **Las llantas**: la ORIENTACION estaba bien (el cilindro de Roblox ya trae el eje a
  los lados). Lo que se veia mal era el **aro**: un disco blanco grandote que parecia
  un plato pegado. Ahora la rueda es: goma oscura + aro gris mas chico + maza + **6
  rayos** que sobresalen un poquito. Se ve como rueda.
* **Subirse**: el asiento era un `VehicleSeat` sin colision y la bici es un cuerpo
  **cinematico** (sin fisica): caminando encima no pasaba nada, y en un **celular**
  menos. Ahora tiene un **boton de verdad**: te acercas y le picas **"Manejar"**
  (en compu tambien sirve la tecla **E**).

## 4. 🚗 Los carros: boton "Conducir"

Mismo problema (habia que "tocar" el asiento y en celular eso casi no funciona).
Ahora cada vehiculo tiene su boton **"Conducir"** al acercarte.

## 5. 🚪 El garaje: si tiene puertas

Las 4 puertas **si existen** (una cortina metalica por cajon, con duelas, ventanilla y
manija) y se abren solas. Lo que pasaba es que se abrian **desde 20 studs**, o sea que
desde adentro de la bodega **nunca las veias cerradas**. Bajado a **13**: se abren justo
cuando llegas al frente, como un porton de verdad.

## 6. 💡 La luz quemandose de adentro

Con tantas luces encendidas de noche (la bodega sola tiene ~20) y encima Bloom 0.5, el
interior salia **blanco, quemado**. Ajustado:

| Que | Antes | Ahora |
|---|---|---|
| Bloom (intensidad / tamano / umbral) | 0.5 / 22 / 1.1 | **0.22 / 16 / 1.45** |
| ColorCorrection (saturacion / contraste) | 0.08 / 0.12 | **0.04 / 0.05** |
| ExposureCompensation | 0.15 | **0** |
| Luz del porton | 1.1 (r=18) | **0.7 (r=15)** |
| Lampara del cajon | 1.6 (r=24) | **0.55 (r=18)** |
| Lampara de pared del garaje | 1.6 (r=30) | **0.8 (r=22)** |

## 7. 🐛 Y dos defectos MAS del simulador (que daban falsos verdes)

* `game:GetDescendants()` no existia en el simulador (ya se agrego en la v35).
* **`GetDescendants()` de las piezas devolvia solo los hijos directos**: los scripts
  que recorren a fondo (limpieza de empleados, inventario, conteo de luces) se estaban
  probando **un solo nivel**. Ahora baja de verdad.

---

## 📦 Los archivos de esta ronda

| # | Archivo | Donde va | Tipo |
|---|---|---|---|
| 0 | **limpiar.luau** | Pestana `View` > boton `Command Bar` (NO va en el juego) | pegar y Enter |
| 1 | GameConfig | ReplicatedStorage > GameConfig | ModuleScript |
| 2 | CityGenerator | ServerScriptService > CityGenerator | ModuleScript |
| 3 | DataService | ServerScriptService > DataService | ModuleScript |
| 4 | Main | ServerScriptService > Main | Script |
| 5 | ClientUI | StarterPlayer > StarterPlayerScripts > ClientUI | LocalScript |
