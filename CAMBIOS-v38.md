# Cambios de la ronda v38

> **La ronda se ve en pantalla.** Ahora el juego se presenta solo: una **placa
> verde** arriba de la pantalla (cliente) y un **letrero flotando arriba del spawn**
> (servidor) dicen la ronda de los archivos que de verdad estan corriendo. Si algo
> no se pego, se ve a simple vista.

---

## 1. 🪧 TESTIGO 1: la placa del cliente

Apenas arranca el juego sale esto, arriba al centro de la pantalla:

```
┌──────────────────────────────────────────┐
│  RONDA v38  (arrancando...)              │
│  si no dice v38, lo que ves NO es de     │
│  esta ronda                              │
└──────────────────────────────────────────┘
```

y si TODO cargo bien, cambia solo a **`RONDA v38  OK`**. A los 14 segundos se
encoge a un letrerito chiquito `v38` que **se queda para siempre** (asi cualquier
captura que me mandes dice de que ronda es lo que se esta viendo).

**Como se lee:**

| Lo que sale | Que significa |
|---|---|
| `RONDA v38  OK` | perfecto: es el archivo de esta ronda y cargo completo |
| `RONDA v38  (arrancando...)` y no cambia | el archivo SI corre, pero truena algo a medio camino (mira el Output) |
| **no sale placa** | esa `ClientUI` **no es la que corre** (o no es `LocalScript`, o esta `Disabled`) |
| dice otra ronda (`v32`, `v36`...) | estas corriendo un archivo viejo |

El ScreenGui se llama `AvisoRonda` a proposito (sin la palabra "SpiceEmpire"):
asi ningun barrido de copias viejas lo puede borrar.

## 2. 🪧 TESTIGO 2: el letrero del servidor

Arriba del spawn (donde apareces) flota un letrero oscuro con letra verde:

```
SERVIDOR v38
letrero del archivo CityGenerator
```

Ese lo pone el **servidor**. Junto con la placa del cliente, una sola captura dice
**cual de los dos lados esta viejo**: si el letrero dice v38 y la placa no sale (o
sale otra ronda), el problema es el cliente; al reves, el problema es el servidor.

## 3. 🧹 El servidor ahora BORRA la basura (antes solo avisaba)

Si dentro del lugar quedo guardada una interfaz del juego (`StarterGui`), el
**servidor la destruye** al arrancar: deja de salir en pantalla en cada Play. Eso
era lo que hacia que se viera "el tablero anterior" aunque pegaras todo.

## 4. 🔎 El servidor revisa que la ClientUI DE VERDAD vaya a correr

Un `Script` normal puesto en `StarterPlayerScripts` **no corre**: no dibuja nada y
no avisa. Ahora el inventario lo canta:

```
[SpiceEmpire]  MAL    StarterPlayer > StarterPlayerScripts > ClientUI (es Script)
                       <- un Script AQUI NO CORRE: borralo y crea un LocalScript
[SpiceEmpire]  APAGAD StarterPlayer > StarterPlayerScripts > ClientUI (Disabled)
                       <- marcale la casilla Enabled para que corra
[SpiceEmpire]  CLIENT StarterPlayer > StarterPlayerScripts > ClientUI si va a correr
```

## 5. 🖼️ La interfaz nueva dibuja por ENCIMA

`DisplayOrder = 50` en la interfaz del juego (el cartel rojo sigue en 999). Antes,
una interfaz vieja podia quedar dibujada encima y parecia "no cambio nada".

## 6. 🧪 Dos pruebas nuevas (probadas al reves)

| Prueba | Que exige |
|---|---|
| **9. testigo del cliente** | que la placa exista, este **visible** y diga la **ronda** |
| **10. testigo del servidor** | que el letrero del spawn diga `SERVIDOR` + la ronda |

Las dos se probaron **rompiendo el codigo a proposito**: si se quita el testigo,
la prueba **FALLA**. (Antes de esta ronda no habia forma de que una prueba notara
que "la pantalla se ve vieja": por eso el problema duro tantas rondas.)

---

## 📦 Los archivos de esta ronda

| # | Archivo | Donde va | Tipo |
|---|---|---|---|
| 0 | **limpiar.luau** | Pestana `View` > boton `Command Bar` (NO va en el juego) | pegar y Enter |
| 1 | GameConfig | ReplicatedStorage > GameConfig | ModuleScript |
| 2 | CityGenerator | ServerScriptService > CityGenerator | ModuleScript |
| 3 | DataService | ServerScriptService > DataService | ModuleScript |
| 4 | Main | ServerScriptService > Main | Script |
| 5 | ClientUI | StarterPlayer > StarterPlayerScripts > ClientUI | **LocalScript** |

> **Prueba de 10 segundos**: dale Play. Arriba al centro tiene que salir la placa
> verde **`RONDA v38`**, y arriba en el spawn el letrero **`SERVIDOR v38`**.
> Si alguno no sale (o sale otra ronda), ese archivo no se pego: guia paso a paso en
> `docs/11-QUE-HAGO-SI-NO-CAMBIA.md`.
