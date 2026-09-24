# 🌶️ Imperio de Especias (Spice Empire)

Juego de Roblox: **mundo abierto estilo GTA + tycoon empresarial**.

Produces hojas de especia, las prensas en bloques, las vendes por la ciudad, evitas a la
Unidad de Aduanas, defiendes tu bodega de asaltos y armas crew con tus amigos.

> **Versión actual: v24**

---

## 🧠 ¿Vienes a continuar el desarrollo?

### 👉 Lee [`CONTINUACION.md`](CONTINUACION.md) primero.

Ahí está el estado completo del proyecto: qué está hecho, qué falta, qué **no** hay que
volver a intentar, y las reglas que no se pueden romper.

---

## 🎮 ¿Vienes a instalar el juego?

### 👉 Lee [`docs/01-INSTALACION.md`](docs/01-INSTALACION.md)

Son 5 archivos que se copian y pegan en Roblox Studio. Unos 10 minutos.

---

## 📂 Qué hay aquí

```
CONTINUACION.md     🧠 El cerebro. Estado, roadmap, reglas
README.md           este archivo

ReplicatedStorage/
  GameConfig.luau       Todos los números del juego (balance, sonidos, config)
ServerScriptService/
  CityGenerator.luau    Genera la ciudad y la bodega por código
  DataService.luau      Guardado en DataStore
  Main.luau             Lógica del juego
StarterPlayerScripts/
  ClientUI.luau         Toda la interfaz

docs/
  01-INSTALACION.md         Cómo meterlo en Studio
  02-ARQUITECTURA.md        Contrato cliente↔servidor, nombres de partes, balance
  03-NO-HAGAS-ESTO.md       ⚠️ Callejones sin salida. Léelo antes de tocar código
  04-AJUSTES-RAPIDOS.md     Perillas de balance, visual y rendimiento
  05-SONIDOS.md             IDs verificados + cómo buscar más
  06-STUDIO-PASOS-MANUALES.md  Lo que hay que hacer a mano en Studio
  07-VALIDACION.md          Cómo funciona el simulador

tools/                  Validadores (ver abajo)
CAMBIOS-v2..v17.md      Changelog de cada ronda
```

---

## ✅ Validar los scripts

No se puede correr Roblox Studio desde consola, así que hay un simulador que carga los
scripts contra un mock de la API de Roblox.

```bash
bash tools/validate.sh
```

Hace tres cosas:
1. **Sintaxis** — traduce Luau → Lua 5.4 y compila con `luac` de verdad
2. **Servidor** — corre la cadena completa y construye los 4 niveles de bodega
3. **Cliente** — carga la UI en escritorio, celular y tablet

Detalles en [`docs/07-VALIDACION.md`](docs/07-VALIDACION.md).

---

## 🕹️ Qué tiene el juego

| Sistema | Estado |
|---|---|
| Ciudad generada por código (low-poly) | ✅ |
| Bodega progresiva de 4 niveles | ✅ |
| Plantas con crecimiento visible por etapas | ✅ |
| Prensa industrial con animación | ✅ |
| Compradores NPC repartidos por la ciudad | ✅ |
| Unidad de Aduanas (policía) que te persigue | ✅ |
| Celular con alertas y llamadas de encargos | ✅ |
| Encargos con recompensa y tiempo límite | ✅ |
| Empleados, autos, propiedades | ✅ |
| Crews | ✅ |
| **Territorios capturables + guerra entre crews** | ✅ |
| Bici inicial | ✅ |
| Escritorio con computadora de mejoras | ✅ |
| Caja fuerte (lo guardado no te lo incauta Aduanas) | ✅ |
| Mochilas que suben tu capacidad de carga | ✅ |
| Empleados físicos: un cosechador por mesa | ✅ |
| Producción aunque estés desconectado | ✅ |
| Arma y combate | ✅ |
| Asaltos con asaltantes físicos y balacera | ✅ |
| Guardias que pelean por ti | ✅ |
| Adaptación a celular | ✅ |
| Efectos de sonido | ✅ |
| Ciclo día/noche | ✅ |


| **Interiores de propiedades** | ⏳ pendiente |
| **Garaje real** | ⏳ pendiente |
| **Música de fondo** | ⏳ pendiente |

---

## 🎮 Controles

| Tecla | Acción |
|---|---|
| **E** | Cosechar |
| **R** | Prensar |
| **F** | Vender |
| **G** | Mejoras |
| **B** | Tienda |
| **T** | Teléfono |
| **H** | Ir a la bodega |
| **C** | Caja fuerte |
| **M** | Minimizar HUD |

En celular todos tienen botón en pantalla, menos M.
