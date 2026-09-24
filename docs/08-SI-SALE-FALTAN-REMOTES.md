# 🚨 "FALTAN SCRIPTS/REMOTES EN EL SERVIDOR" — qué significa y cómo se arregla

Este cartel **no** es un bug del juego: es el juego avisándote que **en Studio tienes
mezclados archivos de rondas distintas**. Se arregla pegando los 5 archivos de la
misma ronda. Toma 3 minutos.

---

## 🧠 Por qué pasa

Al juego le hablan dos programas: el **servidor** y el **cliente**. Se hablan por unos
"canales" (los *remotes*). El servidor los **crea** y el cliente los **pide**.

Si en Studio tienes un `Main.luau` viejo, ese `Main` crea menos canales que los que el
cliente nuevo pide → el cliente avisa cuáles faltan.

> **Ejemplo real:** `Main.luau` de la **v20** (que creaba 9 canales) + `ClientUI.luau`
> de la **v30** (que pide 11) → faltaban **`Shoot`** (del arma, v21) y
> **`TerritoryUpdate`** (de los territorios, v24). El cartel decía *"FALTAN 2"*.

Cada ronda se **suma** al final: nadie borra canales viejos, así que esto **solo** puede
significar una cosa: **quedó un archivo viejo pegado**.

---

## ✅ Cómo se arregla (paso a paso)

### 1. Abre el repo en el navegador

👉 **https://github.com/Agus-12/GAME_ROBLOX_IMPERIO_DE_ESPECIES**

(Es un repo **público**: no necesitas iniciar sesión ni token para copiar los archivos.)

### 2. Copia cada archivo así (botón de copiar de GitHub)

| Archivo en GitHub | El botón | En Studio pégalo en |
|---|---|---|
| `ReplicatedStorage/GameConfig.luau` | arriba a la derecha del archivo hay un ícono de **copiar** 📋 | `ReplicatedStorage` › **GameConfig** (ModuleScript) |
| `ServerScriptService/CityGenerator.luau` | idem | `ServerScriptService` › **CityGenerator** (ModuleScript) |
| `ServerScriptService/DataService.luau` | idem | `ServerScriptService` › **DataService** (ModuleScript) |
| `ServerScriptService/Main.luau` | idem | `ServerScriptService` › **Main** (**Script**, no ModuleScript) |
| `StarterPlayerScripts/ClientUI.luau` | idem | `StarterPlayer` › `StarterPlayerScripts` › **ClientUI** (LocalScript) |

> ⚠️ **En Studio, en cada script: `Ctrl+A` primero y luego `Ctrl+V`.**
> Si pegas sin seleccionar todo, quedan pedazos de la ronda vieja al final del
> archivo y el desmadre es peor.

### 3. Dale Play y mira estas dos cosas

**a) La ventana Output** (menú **View › Output**) debe decir:

```
========== IMPERIO DE ESPECIAS v30 ==========
  remotes creados: 11
```

Ese número **11** tiene que coincidir con los 11 remotes. Si dice 9, o no sale esa
línea, el `Main.luau` que tienes pegado **no es el de esta ronda**.

**b) En pantalla** no debe salir ningún cartel rojo.

---

## 🧾 De qué ronda es cada remote (para saber QUÉ archivo pegar)

Si el cartel te dice que falta un remote, con esta tabla sabes qué archivo quedó viejo:

| Remote | Existe desde | Así que el archivo viejo es… |
|---|---|---|
| `StateUpdate` `PhoneAlert` `Toast` `MissionUpdate` `OpenUpgrades` `Sfx` `Action` | v17 | **algún** archivo es de antes de la v17 (o no pegaste nada) |
| `OpenVault` | v18 | el `Main.luau` es de la v17 o antes |
| `Shoot` | v21 | el `Main.luau` es de la v20 o antes |
| `TerritoryUpdate` | v24 | el `Main.luau` es de la v23 o antes |
| `IncomingCall` | v30 | el `Main.luau` es de la v27 o antes |

Y desde la **v30** el cartel ya te lo dice él solito, sin tabla:

```
ARCHIVOS VIEJOS EN STUDIO  --  esta ronda es v30
 - Main.luau del servidor dice NADA (es viejo, ni siquiera dice version); esta ronda es v30
 - GameConfig dice 'v20'; esta ronda es v30
 - el servidor NO creo: Remotes.Shoot (existe desde v21) , Remotes.TerritoryUpdate (existe desde v24)
Pega los 5 archivos de la ronda COMPLETOS (Ctrl+A y Ctrl+V) y vuelve a dar Play.
```

O sea: en la **v30** el servidor **estampa su versión** en la carpeta `Remotes`, y el
cliente compara esa versión contra la suya y contra la de `GameConfig`. Si una de las
tres no cuadra, te dice **cuál archivo** quedó viejo.

---

## 🧪 Truco para verificar en 5 segundos sin dar Play

En el **Explorer** de Studio, mira la carpeta `ReplicatedStorage › Remotes`:

- Si **no existe** → el servidor es viejísimo o no está corriendo. Pega `Main.luau`.
- Si existe y adentro hay **11 cosas** (10 RemoteEvent + 1 RemoteFunction `Action`) → estás en v30. ✅
- Si hay menos → falta pegar el `Main.luau` de esta ronda.

Y esta es la lista completa de la v30 (los 11):

```
RemoteEvent:    StateUpdate  PhoneAlert  Toast  MissionUpdate  OpenUpgrades
                Sfx  OpenVault  Shoot  TerritoryUpdate  IncomingCall
RemoteFunction: Action
```

---

## 📌 Regla de oro

**Las 5 piezas son un solo juego: se pegan siempre juntas, de la misma ronda.**
Si un cartel rojo aparece, casi siempre es que faltó pegar uno — y ahora el juego te
dice cuál.
