# 11. "Pegue todo y sigue igual" — guia de rescate

Esta guia es para cuando pegas los archivos y el juego se ve **igual que antes**.
Se hace EN ORDEN: cada paso dice que significa lo que ves.

---

## Paso 1. Mira la placa de ronda (10 segundos)

Dale **Play** y mira **arriba al centro** de la pantalla.

| Lo que sale | Que pasa | Que hacer |
|---|---|---|
| **`RONDA v38  OK`** | el archivo nuevo SI corre | el juego esta al dia: lo que falte es otro archivo, no la ClientUI |
| **`RONDA v38  (arrancando...)`** y no cambia | la ClientUI corre pero **truena** a medio camino | paso 3 (mira el Output) |
| **no sale placa** | esa ClientUI **no corre** | pasos 2 y 4 |
| sale **otra** ronda (v32, v36...) | estas corriendo un archivo **viejo** | paso 2 |

Tambien mira el **letrero del spawn** (arriba de donde apareces): dice
`SERVIDOR v38`. Si el letrero es viejo y la placa nueva, el problema esta del lado
del servidor; si el letrero es nuevo y la placa no sale, el problema es la ClientUI.

## Paso 2. ¿La ClientUI es LocalScript y esta prendida?

En Studio, en el **Explorer**:

`StarterPlayer` > `StarterPlayerScripts` > **`ClientUI`**

1. Tiene que decir **LocalScript** (arriba del panel de codigo). Si dice `Script`,
   ese no corre ahi: borralo, y crea uno nuevo con clic derecho >
   `Insert Object` > `LocalScript`, y pega el codigo.
2. En la lista de propiedades, **`Enabled`** tiene que estar **palomeado**.
3. Tiene que haber **un solo** `ClientUI`.

El Output tambien lo dice solo (ronda v38):

```
[SpiceEmpire]  MAL    StarterPlayer > StarterPlayerScripts > ClientUI (es Script)
[SpiceEmpire]  CLIENT StarterPlayer > StarterPlayerScripts > ClientUI si va a correr
```

## Paso 3. Mira el Output

En Studio: pestana **View** (de adentro de Studio) > boton **Output**.

Ahí el juego escribe un **INVENTARIO** al arrancar. Busca las lineas que empiezan
con `[SpiceEmpire]`:

```
[SpiceEmpire] ==== INVENTARIO DE ARCHIVOS DEL JUEGO (v38, al arrancar) ====
[SpiceEmpire]   OK     ReplicatedStorage > GameConfig
[SpiceEmpire]   VIEJO  [v32] StarterPlayer > StarterPlayerScripts > ClientUI   <- es de otra ronda, pegalo de nuevo
[SpiceEmpire]   COPIA  [v38] ServerScriptService > Main   <- borra esta (clic derecho > Delete)
[SpiceEmpire]   BASURA StarterGui > SpiceEmpireUI   <- interfaz guardada en el lugar (la borro yo)
[SpiceEmpire]   FALTA  ServerScriptService > DataService   <- pegalo (falta por completo)
```

* **FALTA** = ese archivo no esta: pegalo.
* **VIEJO [vNN]** = esta, pero es de otra ronda: pegalo otra vez.
* **COPIA** = hay mas de uno: deja UNO (el que diga la ronda nueva) y borra los demas.
* **BASURA** = interfaz guardada dentro del lugar: la v38 ya la borra sola.

## Paso 4. La limpieza (si de plano no cambia)

1. En el Explorer, busca **`SpiceEmpireUI`** dentro de **`StarterGui`** y borralo
   (clic derecho > `Delete`). Es una interfaz **guardada** dentro del lugar: viaja
   con el lugar y sale en pantalla en cada Play, aunque pegues todo.
2. Borra las carpetas **`Remotes`** de mas (deja una sola; el juego crea la suya).
3. Deja **un solo** `Main`, un solo `CityGenerator`, un solo `DataService`, un solo
   `GameConfig` y **un solo** `ClientUI`.
4. Vuelve a pegar los 5 archivos (y da **Enter** al limpiador en la Command Bar).

## Paso 5. Si sigue igual, mandame esto

1. Captura de la **placa de ronda** (arriba al centro) y del **letrero del spawn**.
2. Captura del **Output** con las lineas `[SpiceEmpire]`.

Con eso se sabe exactamente que archivo falta: **no hay que adivinar**.
