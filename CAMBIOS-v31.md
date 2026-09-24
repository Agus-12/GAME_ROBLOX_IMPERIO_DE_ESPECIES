# 🚪 v31 — La portada ahora **no se puede** quedar atorada (y si pasa, te dice por qué)

Esta ronda es la continuación de la v30: el botón **seguía** tardando. Encontré **dos
causas** más y les puse un candado a cada una.

## 📂 Los archivos (un clic y copiar)

📦 **Los 5 códigos juntos:** **`v31-ARCHIVOS.html`** (pestañas + botón **COPIAR TODO**).

> ⚠️ **Pega los 5, no unos cuantos.** Si pegas solo dos, el juego te va a avisar con un
> **cartel rojo**: *"ARCHIVOS VIEJOS EN STUDIO"*. Eso no es un error nuevo: es el aviso
> que te puse a propósito para que no se mezclen rondas.

| # | Archivo | Dónde se pega | Tipo |
|---|---|---|---|
| 1 | [GameConfig.luau](ReplicatedStorage/GameConfig.luau) | `ReplicatedStorage` › **GameConfig** | ModuleScript |
| 2 | [CityGenerator.luau](ServerScriptService/CityGenerator.luau) | `ServerScriptService` › **CityGenerator** | ModuleScript |
| 3 | [DataService.luau](ServerScriptService/DataService.luau) | `ServerScriptService` › **DataService** | ModuleScript |
| 4 | [Main.luau](ServerScriptService/Main.luau) | `ServerScriptService` › **Main** | **Script** |
| 5 | [ClientUI.luau](StarterPlayerScripts/ClientUI.luau) | `StarterPlayer › StarterPlayerScripts` › **ClientUI** | LocalScript |

---

## 🐛 Causa #1: el abridor de la portada estaba **al final** del archivo

Esto era una trampa de diseño. El código que abría el botón vivía en la **última parte**
de `ClientUI` (por la línea 1900 de 2200). En Roblox, si **cualquier** cosa truena antes de
esa línea, el script se detiene ahí y **lo de abajo ya no corre** → la portada se queda en
*"Cargando la ciudad..."* para siempre. Y como el error es de **otra** parte del script, en
la portada no se ve nada raro.

**Arreglado:** el abridor **se mudó al inicio**, justo donde se construye la portada
(línea ~415). Así, aunque todo lo demás truene, el botón **sale de todos modos**.

> 🧪 Y lo probé **rompiendo el script a propósito** (una prueba que ahora corre sola):
> inyecto un error después de la portada y el botón **sigue apareciendo**.

## 🐛 Causa #2: el servidor podía dejar colgado al cliente **para siempre**

Aquí está la más grave. Cuando el cliente pedía su estado al servidor
(`InvokeServer("sync")`), el servidor hacía esto:

```lua
if not DataService.Get(player) then
    setupPlayer(player)      -- <-- esto llama store:GetAsync  ¡QUE PUEDE TARDAR MUCHO!
end
```

**Regla de oro de Roblox:** si un `OnServerInvoke` **se queda esperando**, la llamada del
cliente **se cuelga para siempre** (no hay timeout del otro lado). Y en Studio, con los
DataStores desactivados o lentos, `GetAsync` puede tardar **muchísimo**. Resultado: el
cliente se quedaba esperando eternamente → portada trabada y nada de dinero.

**Arreglado:**

- `sync` **ya nunca espera**: si el perfil no está listo, lo carga **en segundo plano** y
  responde al instante. La misión también va en segundo plano.
- **Regla nueva del proyecto:** `OnServerInvoke` **jamás** hace esperas.

## 🔎 Y ahora, si de todos modos se atora, te lo DICE

Ya no hay que adivinar. En la portada:

- El texto cambia a: **"Cargando...  (esperando la ciudad)"**, **"(esperando a tu
  personaje)"** o **"(el servidor no contestó todavía)"**.
- En la consola (**View › Output**) sale: `[SpiceEmpire] portada abierta (motivo)`.
- **Tocar la pantalla** también te deja entrar, siempre.
- Tope máximo: **3 segundos**. Ni uno más.

---

## 🧪 La prueba que faltaba (y que ahora corre en cada ronda)

`tools/intro.py` (etapa 10 del validador) mide **en segundos** cuánto tarda el botón, en
**cinco** escenarios:

| Escenario | Tope | Resultado |
|---|---|---|
| A) Todo listo | 0.6 s | ✅ 0.00 s |
| B) El personaje tarda 0.8 s | 1.4 s | ✅ 0.90 s |
| C) El servidor no tiene la ciudad | 3.2 s | ✅ 3.00 s |
| D) **El servidor NUNCA contesta** (DataStore colgado) | 0.6 s | ✅ 0.00 s |
| E) **El script truena más abajo** (falla inyectada) | 0.6 s | ✅ 0.00 s |

Los escenarios D y E son **copia exacta de lo que te pasó**: sin ellos, el validador
seguía diciendo "todo bien".

---

## 🧪 Cómo probar

1. Pega **los 5** archivos (uno por uno: clic en el script → `Ctrl+A` → `Ctrl+V`).
2. Dale **Play**.
3. El botón **ENTRAR AL BARRIO** debe salir en **menos de 3 segundos** (normalmente al
   instante). Si tarda, mira **qué dice la línea de abajo** y mándame el dato.
4. Revisa la consola: debe decir `[SpiceEmpire] portada abierta (...)`. Ese motivo me dice
   exactamente qué estaba esperando.

> 💡 Si vuelve a salir *"Cargando la ciudad..."* más de 3 segundos, es que **no se pegó el
> `ClientUI` nuevo** (o quedó una copia vieja). Revisa en el Explorer que haya **un solo
> ClientUI** y que adentro tenga el texto `MI_VERSION = "v31"`.
