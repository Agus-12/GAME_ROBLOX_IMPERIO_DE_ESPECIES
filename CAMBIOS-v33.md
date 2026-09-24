# Cambios de la ronda v33

> Resumen: **el juego ahora te limpia las copias SOLO** (un pegado en la barra de
> comandos) y deja de asustarte con el cartel rojo cuando en realidad si se puede
> jugar. Ademas se arreglaron 2 bugs silenciosos que encontraron mis propias
> herramientas de prueba.

---

## 🧹 1. El LIMPIADOR: se acabo el andar cazando copias en el Explorer

Nuevo archivo: **`limpiar.luau`** (va como **PASO 0** en el HTML de la ronda).

**Como se usa:** en Studio, SIN dar Play, abre `View > Command Bar` (la barrita de
abajo), pega TODO el codigo del PASO 0 y dale Enter. Te dice que borro.

Hace 3 cosas:

1. Borra las **copias repetidas** de `Main`, `CityGenerator`, `DataService`,
   `GameConfig` y `ClientUI`. Se queda con la de esta ronda (la del sello
   `RONDA: v33`) y borra las viejas. Si hay una copia escondida en un lugar raro
   (por ejemplo un `Main` dentro de `Workspace`, que **tambien corre**), tambien
   la borra y te lo dice.
2. Borra **TODAS** las carpetas `Remotes`: el juego crea la suya solo al dar Play.
3. Te dice **que archivo hay que volver a pegar** (los que son de otra ronda o
   los que no encuentra).

Si algo no te gusta: `Ctrl+Z` lo deshace.

---

## 😌 2. El cartel rojo ya no sale cuando el juego SI funciona

Antes: si habia 2 carpetas `Remotes` (aunque el juego estuviera usando la buena y
todo funcionara) salia el cartel rojo gigante "HAY COPIAS PEGADAS". Mucho susto
para nada.

Ahora:

| Situacion | Que sale en pantalla |
|---|---|
| 2 carpetas, la buena es la de esta ronda y tiene todo | **Avisito azul chiquito** abajo (14 s) y se puede jugar normal |
| 2 carpetas y la que sirve esta incompleta | Cartel rojo (si hay que arreglar algo) |
| 2 carpetas y ninguna dice de que ronda es | Cartel rojo con los nombres exactos |

Y el cliente **siempre** elige la carpeta buena: la que el servidor marco con la
etiqueta `Build` de esta ronda (antes agarraba "la mas grande", que podia ser la
vieja).

El texto del cartel tambien dejo de adivinar: antes decia "eso significa que hay 2
Scripts Main pegados" aunque fueran 2 carpetas viejas sin ningun Main de mas. Ahora
dice lo que de verdad encontro, con el nombre de cada carpeta y si tiene etiqueta
o no.

---

## 🔎 3. El servidor revisa 3 veces y avisa fuerte si algo aparece despues

`Main.luau` ahora:

- al arrancar: borra las `Remotes` viejas (como antes) y **dice cuantas limpió**;
- **a los 5 y a los 15 segundos vuelve a revisar**. Si aparece otra carpeta `Remotes`,
  imprime en la consola:

  ```
  *** APARECIO OTRA CARPETA Remotes DESPUES DE ARRANCAR (a los 5 segundos):
      hay MAS DE UN Script 'Main' corriendo ***
  ```

  Eso solo puede pasar si hay otro `Main` pegadon en algun lado: con ese mensaje
  ya se sabe a donde ir.

- imprime siempre: `carpetas Remotes en ReplicatedStorage: 1 (debe ser 1)`, para
  que se pueda comprobar de un vistazo en el Output.

---

## 🐛 4. Dos bugs silenciosos que cazaron mis propias herramientas

**(a) El simulador mentia.** `tools/check.py` limpia los tipos de Luau antes de
correr el codigo, y su limpieza tambien borraba trozos de los **textos** que tienen
dos puntos. Un mensaje como `"LISTO: ahora dale Play"` llegaba al simulador como
`"LISTO dale Play"`. Ahora los textos se apartan antes de limpiar y se devuelven
intactos: **el simulador corre el codigo de verdad**.

**(b) `MI_VERSION` antes de existir.** Al escribir esta ronda, el cliente
comparaba la version contra `MI_VERSION` desde una funcion definida *arriba* de
donde se declara. En Lua eso lee un **global nil**: la comparacion nunca daba
cierto, el avisito no salia nunca y no tronaba nada. Lo cazo `tools/globals.py`
(el validador), que es justo para eso.

---

## ✅ 5. Validacion

| Etapa | Que prueba |
|---|---|
| 11 | nadie borra dentro de un bucle de `GetChildren()` (se saltaba uno) |
| **12 (nueva)** | **el caso de las carpetas `Remotes` de mas**, con 5 escenarios |

La etapa 12 (`tools/copias.py`) simula **tu caso exacto**: 3 carpetas `Remotes`,
2 Scripts `Main`, 2 bodegas guardadas en el lugar. Comprueba que el servidor deja
1 carpeta, y que el cliente se comporta distinto en cada situacion (avisito vs
cartel). Probado quitando el arreglo a proposito: **falla** (no da falsos verdes).

---

## 📦 Los archivos de esta ronda

| # | Archivo | Donde va | Tipo |
|---|---|---|---|
| 0 | **limpiar.luau** | Barra de comandos (NO va en el juego) | pegar y Enter |
| 1 | GameConfig | ReplicatedStorage > GameConfig | ModuleScript |
| 2 | CityGenerator | ServerScriptService > CityGenerator | ModuleScript |
| 3 | DataService | ServerScriptService > DataService | ModuleScript |
| 4 | Main | ServerScriptService > Main | Script |
| 5 | ClientUI | StarterPlayer > StarterPlayerScripts > ClientUI | LocalScript |

> Consejo: si tienes copias pegadas, corre PRIMERO el PASO 0 y despues pega los 5
> archivos. El limpiador te dice exactamente cuales te faltan.
