# Cambios de la ronda v39

> El usuario reporto (ya con la **placa nueva** en pantalla): *"siguen sin salir los
> cambios que te pedi... lo del dashboard, porque se sigue viendo el viejo?"*.
> Traduccion: la ClientUI nueva **si corria** (por eso salio la placa), pero el
> **tablero ancho viejo** seguia dibujado encima. Esta ronda lo caza **por contenido**,
> se llame como se llame y este donde este.

---

## 1. 🎯 El tablero viejo se reconoce por lo que DICE, no por su nombre

El barrido anterior solo borraba interfaces con nombre que empieza con
`SpiceEmpire`. Si la copia vieja se llama distinto (`MiUI`, `Hud`, `Pantalla`...) o
esta **dentro de una carpeta**, no la tocaba.

Ahora se reconoce el tablero por sus textos: si una interfaz dice **"Hojas"**,
**"HEAT"** o **"Espacio"** y no es la mia -> es el tablero viejo y se borra.

* **Cliente**: revisa TODO el `PlayerGui` (`GetDescendants`, no solo el primer nivel)
  al arrancar, varias veces despues, y **en el instante** en que aparezca algo nuevo.
* **Servidor**: revisa `StarterGui` **recursivo** (carpetas incluidas) y borra lo que
  encuentre, con la ruta exacta en el Output.

## 2. 🪧 La placa ahora DICE cuantos borro

Debajo de `RONDA v39` aparece:

```
borre 2 tablero(s) viejo(s) que estaban pegados
```

Asi se ve **en la pantalla** que la limpieza si paso (antes solo salia en el Output,
y el usuario no tiene por que abrirlo).

## 3. 🕵️ El servidor lista los LocalScripts que pueden estar dibujando interfaz

Si hay una copia vieja escondida (por ejemplo en `StarterCharacterScripts`), el
INVENTARIO la canta:

```
[SpiceEmpire]  DIBUJA StarterPlayer > StarterCharacterScripts > OldHud (LocalScript)
                       <- si aqui no debe haber interfaz, borralo (deja solo la ClientUI)
```

La `ClientUI` legitima **no** se marca.

## 4. 🧪 Pruebas nuevas (probadas al reves)

| Prueba | Que exige |
|---|---|
| **11. tablero con otro nombre** (uno suelto + uno dentro de una carpeta) | los dos se borran y la placa lo dice |
| **12. el servidor y la basura escondida** | la carpeta queda vacia, se reporta la `BASURA` y el `DIBUJA`, y **no** se marca la ClientUI buena |

Probadas quitando la limpieza por contenido: **FALLAN**. (Con eso se asegura que este
bug no pueda volver sin que salte la alarma.)

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

> **La prueba de 10 segundos**: Play. Arriba al centro tiene que decir **`RONDA v39`**
> (y `OK` cuando termine de cargar). Si dice `borre N tablero(s) viejo(s)`, mejor
> todavia: encontro y borro la copia vieja. Si la placa sale pero el tablero ancho
> sigue, mandame captura del **Output** completo.
