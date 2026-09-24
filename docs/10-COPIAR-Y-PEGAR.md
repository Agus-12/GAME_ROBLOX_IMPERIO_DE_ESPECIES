# 📋 COPIAR Y PEGAR LOS 5 ARCHIVOS (ronda v33)

> **PASO 0 (recomendado): LIMPIAR STUDIO ANTES DE PEGAR.**
> Si tu juego alguna vez dijo *"HAY COPIAS PEGADAS EN STUDIO"* o *"faltan remotes"*,
> primero limpia. Abre `View > Command Bar` en Studio (la barrita de abajo, **sin dar
> Play**), pega el código del **PASO 0** del HTML de la ronda y dale Enter: él borra
> las copias solo y te dice qué archivo te falta pegar.

Guía corta: aquí están los **5 archivos con su link directo** para copiar el texto completo
y pegarlo en Studio. Sirve igual para **reemplazar** los que ya tienes (por ejemplo si
salió todo doble) o para instalarlos de cero.

---

## 📦 OPCIÓN RÁPIDA: un solo archivo con los 5 códigos adentro

Hay un archivo llamado **`v33-ARCHIVOS.html`** (vive en el workspace, no en el repo) que
trae **los 5 códigos completos embebidos**, en 5 pestañas, cada una con su botón
**COPIAR TODO**.

- **No pide nada a internet**: el código viaja dentro del archivo (por eso funciona
  aunque la vista previa esté aislada).
- Si tu navegador bloquea el copiado automático, el botón **deja el texto ya
  seleccionado**: nomas toca **Copiar** (o `Ctrl+C`).
- Cada pestaña te dice **dónde se pega** en Studio y **qué tipo** de objeto es.

Se regenera con: `python3 tools/pegar.py [salida.html]`

> 💡 **¿Por qué los links de GitHub no abren en la vista previa?** Porque la vista previa
> del workspace corre **aislada y sin internet**: los links son para abrirlos en el
> navegador de verdad. Los links `raw` sí funcionan en Chrome/Safari normal.

---

## ⚠️ PASO 0 — PRIMERO borra lo que sobra (1 minuto)

**Si no borras las copias, da igual cuántas veces pegues: va a seguir saliendo doble.**
Un Script pegado en Studio es un programa que corre: si hay dos `Main`, hay dos juegos
corriendo a la vez.

### Cómo encontrar los repetidos en 5 segundos

En el **Explorer** (la ventana de árbol a la derecha), arriba hay una **cajita de
búsqueda** (dice *"Filter workspace..."* o solo un 🔍). Ahí escribe el nombre y el
Explorer te muestra **todas** las cosas que se llaman así, aunque estén en carpetas
distintas.

Búscalos uno por uno y borra las copias:

| Escribe en el filtro | Tiene que quedar | Qué hacer con las copias |
|---|---|---|
| `Main` | **1** en `ServerScriptService` | clic derecho → **Delete** |
| `CityGenerator` | **1** en `ServerScriptService` | idem |
| `DataService` | **1** en `ServerScriptService` | idem |
| `GameConfig` | **1** en `ReplicatedStorage` | idem |
| `Remotes` | **1** carpeta en `ReplicatedStorage` | idem (el juego la vuelve a crear sola) |
| `ClientUI` | **1** en `StarterPlayer › StarterPlayerScripts` | idem |

> 🏷️ **¿Cuál conservo?** Abre cada copia y busca con **`Ctrl+F`** el texto
> **`RONDA: v33`**: la que lo tenga es la buena. (Los 5 archivos traen ese sello arriba.)

> ⚠️ Ojo con los que Roblox numera solo: `Main` y **`Main2`**, o `ClientUI` y
> **`ClientUI2`**. También son copias.

> 💡 Si no sabes cuál es el bueno: el que tiene **el código más nuevo** es el que ya trae
> el texto `MI_VERSION = "v33"`. Los viejos no. (Y si borras el bueno por error, no pasa
> nada: se pega otra vez con esta guía.)

---

## 📂 PASO 1 — Los 5 archivos (copiar y pegar)

**Cómo se copia:** abre el link → **`Ctrl+A`** (selecciona todo) → **`Ctrl+C`**.
El link `raw` es texto plano: no tiene botones ni adornos, solo el código.

| # | Archivo | Link para copiar (raw) | Dónde se pega en Studio | Tipo |
|---|---|---|---|---|
| 1 | **GameConfig** | https://raw.githubusercontent.com/Agus-12/GAME_ROBLOX_IMPERIO_DE_ESPECIES/main/ReplicatedStorage/GameConfig.luau | `ReplicatedStorage` › **GameConfig** | **ModuleScript** |
| 2 | **CityGenerator** | https://raw.githubusercontent.com/Agus-12/GAME_ROBLOX_IMPERIO_DE_ESPECIES/main/ServerScriptService/CityGenerator.luau | `ServerScriptService` › **CityGenerator** | **ModuleScript** |
| 3 | **DataService** | https://raw.githubusercontent.com/Agus-12/GAME_ROBLOX_IMPERIO_DE_ESPECIES/main/ServerScriptService/DataService.luau | `ServerScriptService` › **DataService** | **ModuleScript** |
| 4 | **Main** | https://raw.githubusercontent.com/Agus-12/GAME_ROBLOX_IMPERIO_DE_ESPECIES/main/ServerScriptService/Main.luau | `ServerScriptService` › **Main** | **Script** (¡no ModuleScript!) |
| 5 | **ClientUI** | https://raw.githubusercontent.com/Agus-12/GAME_ROBLOX_IMPERIO_DE_ESPECIES/main/StarterPlayerScripts/ClientUI.luau | `StarterPlayer` › `StarterPlayerScripts` › **ClientUI** | **LocalScript** |

### Versión "bonita" (por si prefieres el botón de copiar de GitHub)

Abre el archivo en la página normal y usa el **ícono de copiar** 📋 de arriba a la derecha
(el que parece dos hojitas):

| # | Archivo |
|---|---|
| 1 | https://github.com/Agus-12/GAME_ROBLOX_IMPERIO_DE_ESPECIES/blob/main/ReplicatedStorage/GameConfig.luau |
| 2 | https://github.com/Agus-12/GAME_ROBLOX_IMPERIO_DE_ESPECIES/blob/main/ServerScriptService/CityGenerator.luau |
| 3 | https://github.com/Agus-12/GAME_ROBLOX_IMPERIO_DE_ESPECIES/blob/main/ServerScriptService/DataService.luau |
| 4 | https://github.com/Agus-12/GAME_ROBLOX_IMPERIO_DE_ESPECIES/blob/main/ServerScriptService/Main.luau |
| 5 | https://github.com/Agus-12/GAME_ROBLOX_IMPERIO_DE_ESPECIES/blob/main/StarterPlayerScripts/ClientUI.luau |

---

## ✍️ PASO 2 — Cómo pegar cada uno (muy importante)

**En Studio, siempre pega ENCIMA del script que ya existe.** Nunca crees uno nuevo si ya
hay uno con ese nombre:

1. En el Explorer, **clic en el script** (por ejemplo `Main`).
2. En la ventana de código: **clic dentro** y **`Ctrl+A`** → *selecciona TODO el código viejo*.
3. **`Ctrl+V`** → se reemplaza completo. ✅

> 🚫 **Nunca** hagas *"Insert Object → Script"* con el mismo nombre. Eso es lo que crea la
> copia y hace que todo salga doble.

Si el script **no existe todavía** (instalación desde cero): clic derecho en la carpeta →
Insert Object → el tipo que dice la tabla → renómbralo **exacto** como dice la tabla.

---

## ✅ PASO 3 — Comprobar que quedó bien

### A) En pantalla

Dale **Play**. **No** debe salir ningún cartel rojo.

### B) En la consola (Output)

Menú **View › Output**. Tiene que decir **una sola vez**:

```
========== IMPERIO DE ESPECIAS v33 ==========
  remotes creados: 11
[SpiceEmpire] Ciudad generada.
[SpiceEmpire] Servidor listo.
```

- ¿Dice `remotes creados: 11` pero **dos veces** todo el bloque? → todavía hay **dos `Main`**.
- ¿Dice un número **menor a 11**? → el `Main` que pegaste es viejo: vuelve a pegarlo (link 4).
- ¿Sale *"HAY COPIAS PEGADAS EN STUDIO"*? → te dice exactamente qué sobra: bórralo.

### C) En el Explorer

`ReplicatedStorage` → carpeta **`Remotes`** → debe tener **11 cosas**:

```
RemoteEvent:    StateUpdate  PhoneAlert  Toast  MissionUpdate  OpenUpgrades
                Sfx  OpenVault  Shoot  TerritoryUpdate  IncomingCall
RemoteFunction: Action
```

---

## 🆘 Si después de todo sigue raro

| Lo que ves | Qué es | Solución |
|---|---|---|
| Todo doble otra vez | Quedó una copia de un script | Filtra por nombre en el Explorer y borra la copia (PASO 0) |
| Cartel rojo *"FALTAN REMOTES"* | Un archivo quedó viejo | Pega los 5 (PASO 1) |
| *"ARCHIVOS VIEJOS EN STUDIO"* | Igual, y te dice cuál | Pega el archivo que menciona |
| El mapa se ve raro / hay cosas encimadas | El lugar guardó un mapa viejo | El juego lo limpia solo al arrancar; si sigue, borra la carpeta `City` en `Workspace` a mano |
| No veo la carpeta `Remotes` | El servidor no está corriendo | Revisa que `Main` sea **Script** (no ModuleScript) y el Output |

---

## 📌 En una línea

**Un link → `Ctrl+A` → `Ctrl+C` → clic en el script de Studio → `Ctrl+A` → `Ctrl+V`.**
Los 5, en el mismo orden de la tabla. Y antes: **borra las copias**.
