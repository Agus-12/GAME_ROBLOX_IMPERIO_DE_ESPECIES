# Cambios de la ronda v34

> Resumen: **el cartel rojo ya no sale aunque tengas carpetas viejas pegadas**, y
> de paso se arreglo un bug GORDISIMO que encontre investigando: si el cliente
> arrancaba antes que el servidor, se quedaba enganchado a una carpeta `Remotes`
> vieja que el servidor borraba un instante despues. Resultado: **botones que no
> hacian nada y ningun error en consola**.

---

## 🚨 El bug de verdad: remotes MUERTOS al arrancar

Escenario real (el tuyo): en el lugar quedo guardada una carpeta `Remotes` vieja.

```
 t = 0.0 s   el cliente arranca, ve la carpeta VIEJA y se engancha a ESA
 t = 0.3 s   el servidor borra las carpetas viejas y crea la suya (con sello)
 t = 0.4 s   el cliente sigue enganchado a remotes que YA NO EXISTEN
             -> los botones no hacen nada, y en la consola NO sale ni un error
```

Eso explica perfectamente el clasico **"no me deja hacer nada"**.

### Como quedo arreglado (cambio de carpeta EN CALIENTE)

El cliente ya no guarda el remote, guarda un **intermediario**:

* arranca enganchado a lo que haya (no espera ni un segundo: la portada sigue saliendo al instante);
* a los **1.5 s** y a los **4.5 s** vuelve a mirar;
* en cuanto aparece la carpeta del servidor (la que trae el sello `Build`),
  **se muda a esa y reconecta solo las señales**: los paneles siguen funcionando;
* los que envian (`FireServer` / `InvokeServer`) se resuelven al momento de la llamada,
  asi que tambien van a la carpeta correcta (y si el remote ya no existe, avisan en vez de tronar).

En la consola se ve:

```
[SpiceEmpire] remotes enganchados a la carpeta 'Remotes' (sello v34)
```

---

## 🤫 Y el cartel rojo ya (casi) no sale

Antes: bastaba con que hubiera 2 carpetas `Remotes` en un instante para que saliera el
cartel rojo gigante *"HAY COPIAS PEGADAS EN STUDIO"*.

Ahora el diagnostico se hace **a los 4.5 s** (cuando el servidor ya termino su limpieza)
y solo se queja si de verdad queda algo raro:

| Situacion | Que sale |
|---|---|
| Habia carpetas viejas y el servidor las limpio (tu caso) | **nada**: se puede jugar y no molesta |
| Carpetas viejas que NO se limpian (hay 2 `Main` corriendo) | cartel rojo + warn en la consola |
| La carpeta que sirve esta incompleta o es de otra ronda | cartel rojo (si hay que arreglar algo) |

---

## 🖱️ La Command Bar: donde esta de verdad

El **menu `View` de arriba de la pantalla (el de la manzanita en Mac) NO es** el que
tiene la Command Bar. Son dos cosas distintas con el mismo nombre:

* **Pestana `View`** (las de adentro de Studio: Home, Model, Avatar, Terrain, Test, **View**, Plugins):
  ahi esta el **boton `Command Bar`**.
* Si no la encuentras, no hace falta: en el **Explorer**, clic derecho sobre la carpeta
  `Remotes` (o las que sobren) → **Delete**. El juego crea la suya sola al dar Play.
  Se pueden borrar **TODAS** las carpetas `Remotes` sin miedo.

---

## ✅ Validacion

La etapa 12 (`tools/copias.py`) ahora tiene **6 escenarios**. El nuevo es **la carrera**:

| Escenario | Que prueba |
|---|---|
| 6. la carrera | la carpeta del servidor aparece **0.6 s DESPUES**: el cliente tiene que mudarse solo, sin cartel, y quedar escuchando la carpeta del servidor |

Se comprueba **contando conexiones por carpeta** (`Remotes#true=10` y `Remotes#false=0`): no
basta con que "no salga el cartel", hay que ver que los remotes esten vivos y sean los buenos.

Probado desactivando el cambio en caliente: **el escenario 6 falla**. No da falsos verdes.

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
