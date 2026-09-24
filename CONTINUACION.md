# 🧠 CONTINUACIÓN — Léeme primero

> **Para el siguiente asistente / desarrollador que tome este proyecto.**
> Este archivo es el cerebro. Si solo vas a leer un documento, que sea este.
> Última actualización: **v28** · 23 sep 2026

---

## 0. Lo primero que tienes que saber

| Cosa | Valor |
|---|---|
| **Qué es** | Juego de Roblox: mundo abierto estilo GTA + tycoon empresarial |
| **Cómo se entrega** | Scripts sueltos para copiar y pegar en Studio. **NO es un proyecto Rojo** |
| **Idioma con el usuario** | Español, tono casual mexicano |
| **Versión actual** | v28 |
| **Estado** | Jugable. Todo lo entregado funciona salvo lo listado en "Bugs abiertos" |

### ✅ Qué se cerró en la v28 (léelo antes de tocar geometría)

| Bug | Causa real | Estado |
|---|---|---|
| La computadora / la pestaña Bodega salía en blanco | `T.StorageBonus`: campo borrado de la config en la v22 y todavía leído en 3 lugares. Da `nil` (no error de compilación) y revienta dentro de un `pcall` → **silencio total** | ✅ v28 |
| El garaje estaba sellado | `Wall2` (pared izquierda) se construía de una pieza, sin hueco: el garaje era una caja cerrada y los autos de adentro no se podían ni ver de cerca | ✅ v28 (pared en tramos + marco + letrero TALLER) |
| Escalón de 1.8 studs en el portón | Piso de la bodega en y=2 vs calle en y=0.2; la bici tiene `MAX_STEP=1.6` y se atoraba | ✅ v28 (rampa `GateApron`) |
| Las bodegas se encimaban | Espaciado fijo de 140 studs vs ancho real del nivel 4 **con anexos** (190 + 46 taller + 34 oficina = **271**) | ✅ v28 (`GameConfig.WarehouseLots`: rejilla 5×4, 340×260) |
| Los últimos lotes caían fuera del suelo | El suelo de la ciudad no llegaba; al salir del portón, vacío | ✅ v28 (`buildGround` estira el suelo con los datos del lote) |
| El cliente se colgaba en silencio | `WaitForChild` sin timeout + `IncomingCall` creado 1745 líneas después del arranque | ✅ v28 (remotes al arranque + timeout de 10 s + cartel rojo) |
| "El botón sale pero me rebota" | Cliente 16 studs, servidor 14 en la prensa | ✅ v28 (radios desde `GameConfig.Interact` y los ya existentes) |
| El panel no se reabría al revivir | El detector guarda "ya estabas cerca" para no abrir el panel cada 0.3 s; si morías junto a la máquina ese `true` quedaba pegado y el cruce nunca volvía a disparar. Solo se arreglaba alejándose y regresando | ✅ v28 (al morir se limpia `near` y se cierran los paneles) |
| Cartel "FALTAN SCRIPTS/REMOTES" con N=2 | El usuario tenía un `Main.luau` VIEJO pegado en Studio. La v28 se sumó al final del juego: todo remote que el cliente pide ya existía desde la v21/v24, así que la única causa posible era un archivo de otra ronda | ✅ v28 (sello de versión + cartel que dice cuál archivo quedó viejo + `tools/remotes.py`) |
| Zona segura con esquinas fuera | Radio fijo 14 vs tapete de 28×11 | ✅ v28 (mide contra el tapete real) |

### 🔖 Regla de las VERSIONES (nueva en la v28)

Una ronda **solo se suma al final**: ningún remote se borra ni se renombra. Por eso, si
el cliente pide un remote que el servidor no crea, **la causa es siempre la misma**: hay
un archivo de otra ronda pegado en Studio. Para que el usuario no tenga que adivinar:

| Dónde | Qué dice |
|---|---|
| `GameConfig.Build` | La ronda de la config (`"v28"`) |
| `Main.luau`, al arrancar | Estampa la versión en la carpeta `Remotes` (atributo `Build`) y **la imprime en Output**: `========== IMPERIO DE ESPECIAS v28 ==========` + cuántos remotes creó |
| `ClientUI.luau` | `MI_VERSION` + la tabla `DESDE` (desde qué ronda existe cada remote) |
| Cartel rojo | Compara las 3 versiones y dice **qué archivo pegó viejo el usuario** |

**Al subir de ronda, cambia el número en los 5 lugares** (`GameConfig.Build`,
`MI_VERSION`, `README`, `CONTINUACION.md`, y crea `CAMBIOS-vN.md`): `tools/remotes.py`
(etapa 9) falla si se te olvida alguno. Detalle completo en
`docs/08-SI-SALE-FALTAN-REMOTES.md`.

### ⚠️ Reglas que NO puedes romper

0. **🔴 SUBE TODO AL REPO, SIEMPRE, EN CADA RONDA.**
   Este repo es el workspace en la nube del usuario y es una instrucción explícita suya.
   No termines un turno sin haber hecho commit y push de:
   los `.luau`, el `CAMBIOS-vN.md`, `CONTINUACION.md` y los `docs/` que cambien.

   ```bash
   cd /home/user/SpiceEmpire
   git config user.email "dev@spiceempire.local"   # .git/config NO persiste entre sesiones
   git config user.name  "Spice Empire Dev"
   bash tools/validate.sh                          # que salga todo verde ANTES del commit
   git add -A && git commit -m "vN — ..."
   git remote set-url origin "https://<TOKEN>@github.com/Agus-12/GAME_ROBLOX_IMPERIO_DE_ESPECIES.git"
   git push origin main
   git remote set-url origin "https://github.com/Agus-12/GAME_ROBLOX_IMPERIO_DE_ESPECIES.git"
   ```

   - El **token lo tiene que dar el usuario** en cada sesión: no se guarda (y `.git/config`
     se borra entre turnos). Pídeselo si no lo tienes.
   - **Nunca** dejes el token dentro de un archivo ni en el config al terminar.
   - Escribe mensajes de commit que expliquen **la causa** del bug, no solo el arreglo.
     Los de v20–v27 son el ejemplo a seguir.

1. **El usuario no conoce Roblox Studio a fondo.** No sabe qué es el Toolbox ni Rojo.
   → Siempre entrega **archivos separados** con instrucciones "copia esto, pégalo aquí".
   → Nunca propongas Rojo, ni línea de comandos, ni flujos de desarrollador.

2. **El tema de drogas está PROHIBIDO y ya se discutió.**
   El usuario pidió originalmente marihuana y cocaína. **Se rechazó** porque viola el
   reglamento de Roblox (ban de juego y de cuenta). El usuario **aceptó** el reskin legal.
   - ✅ "Spice Empire" / "Imperio de Especias", hojas de especia, bloques de sal prensada
   - ✅ "Sindicatos" / "Crews", "Unidad de Aduanas" (la policía)
   - ❌ Nada de: cartel, narco, coca, kilo, brick, ni nombres de drogas
   - **No vuelvas a abrir este tema.**

3. **Responde en español mexicano casual.** El usuario escribe así.

4. **Valida SIEMPRE antes de entregar.** Ver sección 4.
   - **Nunca** claves una distancia de interacción, una separación de lotes o el
     tamaño de un anexo como número suelto en el código: va en `GameConfig`
     (`Interact`, `WarehouseLots`). Dos veces ya nos mordió.
   - Si agregas una herramienta de validación, **pruébala metiendo el bug a
     propósito** y revierte. Un validador que siempre dice "OK" no vale nada.

5. **Entrega por rondas.** El usuario dijo "aviéntate todo", pero se acordó ir por
   entregas. Cada ronda = un `CAMBIOS-vN.md` + explicación en el chat.

---

## 1. Dónde está cada cosa

```
ReplicatedStorage/GameConfig.luau     ModuleScript · TODOS los números del juego
ServerScriptService/CityGenerator.luau ModuleScript · genera ciudad y bodega
ServerScriptService/DataService.luau  ModuleScript · guardado (DataStore)
ServerScriptService/Main.luau         Script      · lógica del juego
StarterPlayerScripts/ClientUI.luau    LocalScript · toda la interfaz

CAMBIOS-v2.md … CAMBIOS-v17.md        Changelog de cada ronda
LEEME.md                              Instrucciones de instalación (para el usuario)
docs/                                 Documentación técnica (para ti)
tools/                                Validadores. Corre bash tools/validate.sh
```

**Ubicación en Studio** (esto es lo que le dices al usuario):

| Archivo | Dónde va | Tipo |
|---|---|---|
| GameConfig | ReplicatedStorage | ModuleScript |
| CityGenerator | ServerScriptService | ModuleScript |
| DataService | ServerScriptService | ModuleScript |
| Main | ServerScriptService | **Script** |
| ClientUI | StarterPlayer › StarterPlayerScripts | **LocalScript** |

---

## 2. 🐛 Bugs abiertos ahora mismo

| # | Bug | Estado |
|---|---|---|
| 1 | **Bici** — historial largo de fallas, ver `docs/03-NO-HAGAS-ESTO.md` §1 | v17 la ancló por completo. **SIN CONFIRMAR por el usuario** |
| 2 | ~~Trabajadores invisibles~~ | ✅ v19 · v20 les quitó el diálogo de comprador y la flotación |
| 3 | ~~Prensa pegada / HUD mentía / mercado apilado~~ | ✅ v20 |
| 4 | ~~Raiders flotando / cosechadores duplicados~~ | ✅ v22 |
| 5 | ~~Computadora / bóveda no abrían, oficina adentro, garaje sellado~~ | ✅ v28 (ver tabla de arriba) |

## 2.2 ✅ PASE VISUAL — COMPLETADO EN v23

Los 8 puntos que el usuario mandó en una tanda quedaron cerrados entre v22 y v23:

| # | Qué pidió | Dónde quedó |
|---|---|---|
| 1 | Arma realista + sonido | v22 sonido, v23 modelo de 14 piezas + fogonazo |
| 2 | Zona segura (cuadro azul, sillón) | v23: tapete de tela y sillón por piezas |
| 3 | Bandidos flotando | v22 |
| 4 | Cosechadores dobles + animación | v22 duplicados, v23 gesto de cosecha |
| 5 | Computadora/silla + dock contextual + sonidos de proximidad | v22 dock y sonidos, v23 muebles |
| 6 | Estantes realistas pegados a la pared | v23 |
| 7 | Mochila separada de la caja, topes por producto | v22 |
| 8 | HUD de iconos siempre compacto | v22 |


## 2.1 🔨 El rediseño de producción física (decisiones ya tomadas)

El usuario pidió que la producción deje de ser "mágica". Se acordó esto y **ya no hay
que volver a preguntarlo**:

| Decisión | Acordado |
|---|---|
| Prensar | Solo estando frente a la máquina ✅ hecho en v18 |
| Caja fuerte | Todo lo producido se guarda ahí, no en el inventario ✅ hecho en v18 |
| Aduanas | Solo incauta lo que traes CARGANDO ✅ hecho en v18 |
| Capacidad de carga | Empieza en 80, sube comprando **mochilas** ✅ hecho en v18 |
| Cosechadores | **Uno por mesa.** 4 mesas = 4 cosechadores. Físicos, se paran en su mesa y cosechan solo las plantas maduras de ESA mesa | ✅ v19 |
| Producción offline | **Sí**, los trabajadores producen aunque estés desconectado. Hay que calcular al volver | ✅ v19 (tope 8 h) |
| Cosecha manual | **Sí sigue existiendo**, además de los trabajadores | ✅ ya funciona |
| Asaltos a la caja | **Sí pueden robar de la caja fuerte** — para eso sirven los guardias y la alerta del celular | ✅ v21, con asaltantes físicos y arma |

---

## 3. 🗺️ Roadmap — lo que falta

Por orden de valor sugerido:

| Pendiente | Qué implica |
|---|---|

| **Interiores de propiedades** | Las casas/departamentos que compras hoy son solo fachada. No se puede entrar |
| **Garaje real** | Un lugar físico donde aparezcan los autos comprados |
| **Música ambiente** | Los SFX ya están (v17). Falta música de fondo y sonido de motores |

Features del pedido original que **ya están hechas**: mapa procedural, policías que
persiguen, celular con alertas, PvP de robo, crews básicos, empleados, autos, casas,
bodega progresiva de 4 niveles, NPC vigilante, compradores en la ciudad, bici inicial,
plantas con crecimiento visible, prensa detallada, encargos, llamadas telefónicas,
adaptación a celular, sonido, caja fuerte, empleados físicos, arma y asaltos con
balacera, **territorios capturables entre crews**.

> ✅ **Con la v24 quedó cubierto TODO lo que el usuario pidió en su mensaje original.**
> Lo que sigue en el roadmap ya son ideas para crecer el juego, no pendientes.

---

## 4. ✅ Cómo validar (OBLIGATORIO antes de entregar)

No hay forma de correr Roblox Studio aquí. Se armó un simulador. **Úsalo siempre.**

```bash
bash tools/validate.sh
```

Eso hace **ocho** cosas:
1. **Sintaxis** — traduce Luau a Lua 5.4 y lo compila con `luac`
2. **Servidor en runtime** — corre GameConfig → CityGenerator → DataService → Main
   bajo un mock de la API de Roblox, y construye los 4 niveles de bodega
3. **Cliente en runtime** — carga ClientUI en 3 tamaños (escritorio, celular, tablet)
4. **Globales sospechosos** (`tools/globals.py`) — caza typos como `Workspace` (que en
   Roblox **no existe**, el global es `workspace`) o constantes mal escritas
5. **Partes de la bodega** (`tools/parts.py`) — construye los 4 niveles y verifica que
   sigan existiendo todas las partes que Main y ClientUI buscan por nombre
6. **Campos de la config** (`tools/fields.py`) — compara cada `Config.algo.campo` y cada
   alias (`T.VaultLeaves`, `b.Capacity`…) contra lo que la config tiene de verdad.
   Caza la clase de bug de `StorageBonus`, que **no** truena al compilar: da `nil` y
   revienta en tiempo de ejecución dentro de un `pcall`, o sea en silencio.
7. **Alcanzabilidad** (`tools/walk.py`) — construye los 4 niveles, exporta la geometría
   y tira un flood fill con el cuerpo de un jugador (radio 1.7) para comprobar que se
   pueda **caminar** desde donde apareces hasta la oficina, la caja, la computadora,
   la prensa, las mesas, el garaje (¡incluido el cajón 1!) y la calle. También revisa
   que la oficina esté por fuera del muro y que los lotes quepan en el suelo.
   Nació del garaje sellado: `parts.py` decía "todas las partes presentes" y el garaje
   seguía siendo una caja cerrada.
8. **API de Roblox** (`tools/api.py`) — valida `Enum.X.Y`, `Instance.new("Clase")`,
   `GetService` y las props de los helpers de UI contra el API-Dump oficial. El mock
   se traga cualquier typo; Studio no.

> ⚠️ Toda herramienta nueva se prueba **metiendo el bug a propósito** y revirtiendo.
> Ya van dos rondas donde un "validador verde" escondía un bug real.

> ⚠️ Las etapas 4 y 5 nacieron de bugs reales: `Workspace` nil rompía **todo** el sistema
> contextual en silencio (v22–v26), y en la v25 se borró la caja fuerte sin que ninguna
> validación lo notara. **Si agregas una parte nueva que el código busque por nombre,
> métela a la lista `REQUIRED` de `tools/parts.py`.**

Tiene que salir todo OK. Detalles en `docs/07-VALIDACION.md`.

> ⚠️ `tools/check.py` reporta `(continue)` en Main.luau. **Eso es normal**, es una
> limitación del traductor, no un error. Cualquier otro FAIL sí es real.

> ⚠️ Si el entorno borró `tools/lua/`, `bash tools/setup.sh` lo reinstala.

---

## 5. Cómo se entrega una ronda

> ⚠️ **El usuario pidió que TODO cambio se suba a este repo.** Es su workspace en la nube.
> Necesitas que te pase un Personal Access Token de GitHub (no se guarda entre sesiones).
> ```
> git remote set-url origin https://<TOKEN>@github.com/Agus-12/GAME_ROBLOX_IMPERIO_DE_ESPECIES.git
> git push origin main
> git remote set-url origin https://github.com/Agus-12/GAME_ROBLOX_IMPERIO_DE_ESPECIES.git
> ```
> Nunca dejes el token en un archivo ni en el config al terminar.

1. Haz los cambios en los `.luau`
2. `bash tools/validate.sh` → todo verde
3. Escribe `CAMBIOS-vN.md` siguiendo **exactamente** el formato de v16/v17:
   - Título con emoji
   - Sección "📂 Abrir los archivos a copiar" con **links markdown relativos**
     clickeables + la ruta en el Explorer de Studio
   - Nota de qué archivos **NO** cambiaron
   - Explicación numerada de cada arreglo, **diciendo la causa real**, no solo el fix
   - Sección "Cómo probar"
   - Roadmap actualizado
4. `present_file` del changelog
5. Explica en el chat, en español casual, **por qué** fallaba cada cosa

> ❌ **NO pegues el código completo dentro del .md.** Se probó y quedó ilegible (147 KB).
> Usa links relativos a los archivos.

---

## 6. Lo más importante que aprendimos

Está todo en `docs/03-NO-HAGAS-ESTO.md`, pero estos tres son los que más tiempo costaron:

0. **Un campo que no existe en la config NO truena al compilar.** Da `nil`, y si el
   `nil` cae en un `string.format` o en una suma, revienta en tiempo de ejecución —
   muchas veces dentro de un `pcall`, o sea **sin error visible**. Regla: si borras
   un campo de `GameConfig`, corre `tools/fields.py` antes de dar la ronda por buena.
   Y **no metas geometría nueva a `pcall`** sin dejar rastro: si algo falla ahí, imprime.
1. **La bici: nada de física.** Cuatro intentos fallaron. La única que funciona es
   anclada + CFrame a mano. No vuelvas a intentar con constraints.
2. **`Lighting.Ambient` ilumina los interiores**, `OutdoorAmbient` no. Si subes Ambient
   de día, las bodegas se lavan. Déjalo fijo.
3. **Demasiados PointLights se suman y queman la escena.** El alcance (`Range`) importa
   más que el brillo. Range 60 en un cuarto de 70 studs = todo blanco.

---

## 7. Documentos

| Archivo | Para qué |
|---|---|
| `docs/01-INSTALACION.md` | Cómo mete el usuario los scripts en Studio |
| `docs/02-ARQUITECTURA.md` | Contrato cliente↔servidor, nombres de partes, estructura interna |
| `docs/03-NO-HAGAS-ESTO.md` | **Callejones sin salida. Léelo antes de tocar código** |
| `docs/04-AJUSTES-RAPIDOS.md` | Perillas para cambiar balance, rendimiento, etc. |
| `docs/05-SONIDOS.md` | IDs verificados + cómo buscar más con la API |
| `docs/06-STUDIO-PASOS-MANUALES.md` | Lo que el usuario tiene que hacer a mano en Studio |
| `docs/07-VALIDACION.md` | Cómo funciona el simulador |
