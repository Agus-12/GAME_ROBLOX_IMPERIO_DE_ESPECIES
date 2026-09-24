# Cambios de la ronda v40

> El usuario mando captura de una leyenda: *"Encontre carpetas 'Remotes' de mas en
> Studio (2 carpetas: una con **sello v39** de 11 remotes + otra **SIN sello** de 9
> remotes)..."*. Traduccion: **quedo un `Main` VIEJO de mas corriendo**, y ese crea su
> propia carpeta `Remotes` (la que no tiene sello). Esta ronda lo caza al instante y
> deja de molestar.

---

## 1. 🕵️ Que significaba esa leyenda

* **`Remotes` con sello (11 remotes)** = la carpeta que crea **el servidor de esta
  ronda**. El juego usa ESA.
* **`Remotes` SIN sello (9 remotes)** = una carpeta creada por una **version vieja
  del juego** que sigue corriendo ahi (un `Main` de mas, de la epoca en que el juego
  tenia 9 remotes).

O sea: **no era un error del juego**. El juego funcionaba bien, pero avisaba de que
habia basura de una copia vieja.

## 2. 🔨 Lo que se arreglo

| Antes | Ahora |
|---|---|
| El servidor revisaba 3 veces (0 s, 5 s y 15 s). Si la copia vieja creaba su carpeta **mas tarde**, sobrevivia y el cliente la veia. | **Vigilante permanente**: cualquier carpeta `Remotes` que aparezca **en cualquier momento** se borra **al instante** (y se avisa una sola vez, sin llenar el Output). |
| El aviso era un rollo largo que no decia que hacer, **y se quedaba pegado** en pantalla aunque el problema ya estuviera resuelto. | Aviso **corto y con el arreglo exacto**, y si el problema desaparece **el aviso se quita solo**. |
| El simulador tenia senales (eventos) de mentiritas: `Connect` no llamaba a nadie. No se podia probar "aparece algo a media partida". | Eventos de verdad (`Connect`/`Fire`) y `ChildAdded` al poner `Parent`, como en Roblox. |

## 3. ✅ Que hacer con la carpeta vieja (1 minuto, opcional)

El juego ya la borra **en cada partida** por su cuenta. Para que **deje de aparecer
para siempre**, hay que quitarla de Studio (guardado):

1. En Studio, **sin dar Play**: pestana **View** de adentro de Studio > boton
   **Command Bar**.
2. Pega el **LIMPIADOR** (pestana 0 del HTML) y dale **Enter**. Borra:
   * las carpetas `Remotes` viejas (todas: el juego crea la suya al dar Play);
   * las copias repetidas de `Main`, `CityGenerator`, `DataService`, `GameConfig` y
     `ClientUI` (deja una de cada, la de la ronda nueva);
   y te dice **que archivo hay que volver a pegar**.

**A mano** (si prefieres): Explorer > `ServerScriptService` > deja **UN** `Main` (el que
al abrirlo diga `RONDA: v40`) y borra los demas (`Main2`, copias viejas). Y en
`ReplicatedStorage` borra **todas** las carpetas `Remotes` (clic derecho > Delete).

## 4. 🧪 Pruebas nuevas (probadas al reves)

| Prueba | Que exige |
|---|---|
| **13. carpeta Remotes a media partida** | se borra al instante y el aviso dice que hay un `Main` viejo de mas |
| **14. el aviso se quita solo** | sale cuando hay 2 carpetas y **desaparece** cuando queda 1 |

Las dos se probaron **quitando el arreglo**: **FALLAN**.

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

> **La prueba de 10 segundos**: Play. Arriba al centro tiene que decir **`RONDA v40`**.
> Si vuelve a salir el aviso de las carpetas, dale **una sola pasada** al LIMPIADOR y
> no vuelve mas.
