# 🔊 CAMBIOS v55 — el juego ya no es mudo: motor al manejar, rodada en la bici y la ciudad de fondo

Fecha: 27 sep 2026 · build `v55` · sin reporte de bugs de la v54 (esta ronda
ataca el punto del roadmap que llevaba desde la v17: "música de fondo, sonido
de motor para los vehículos y sonido de la bici al rodar").

---

## 📂 Abrir los archivos a copiar

| Archivo | Dónde va en el Explorer de Studio |
|---|---|
| [`GameConfig.luau`](ReplicatedStorage/GameConfig.luau) | `ReplicatedStorage` (ModuleScript) |
| [`CityGenerator.luau`](ServerScriptService/CityGenerator.luau) | `ServerScriptService` (ModuleScript) |
| [`DataService.luau`](ServerScriptService/DataService.luau) | `ServerScriptService` (ModuleScript) |
| [`Main.luau`](ServerScriptService/Main.luau) | `ServerScriptService` (**Script**) |
| [`ClientUI.luau`](StarterPlayerScripts/ClientUI.luau) | `StarterPlayer` › `StarterPlayerScripts` (**LocalScript**) |

> Los 5 cambian de ronda (`DataService` y `CityGenerator` solo el sello `RONDA: v55`).
> Usa el **HTML de la ronda** (`v55-ARCHIVOS.html`): trae el **PASO 0
> (LIMPIADOR)** para borrar las copias viejas antes de pegar.

---

## 1. El sonido del motor (la van y los carros)

**Antes:** sacabas la van del cajón, manejabas... y silencio total. El motor no
existía.

**Ahora:** cada carro trae un `MotorLoop` pegado al chasis:
- **Suena solo mientras hay conductor**: te subes → idle; te bajas → silencio
  (nadie deja el motor encendido parado en el cajón).
- **El tono y el volumen suben con la velocidad**: parado suena a idle
  (0.52×), a fondo suena a toda marcha (0.91×) — la "música" de manejar.
- **Posicionado de verdad** (`RollOffMaxDistance = 160`): se oye cada vez más
  fuerte mientras te acercas, como en la calle.

Es un loop de **ProSoundEffects** (`Spacecraft Engine Idle Constant`, 63.7 s,
verificado contra la API como todos los demás; a tono 0.72 suena a camioneta y
no a nave).

## 2. La rodada de la bici

La bici no tiene motor: trae una **rodada** (gravilla constante) cuyo volumen
SIGUE a la velocidad — parada no se oye nada, pedaleando a fondo se oye rodar.
Al bajarte, silencio.

## 3. La música ambiente

`MusicaFondo`: la ciudad de fondo (tardes, tráfico lejano, una sirena a lo
lejos — "City Ambience 3", 48 s) en loop bajito (volumen 0.18) desde que
entras. Va en `SoundService` y no en la interfaz a propósito: **la interfaz se
destruye al respawnear** y la música se cortaría cada vez que mueres; en
`SoundService` sobrevive.

## 4. De paso: dos mentiras del simulador (por eso costaba probar sonido)

- **El `Disconnect` de las señales dejaba huecos**: al dispararse los
  Heartbeat, la lista se cortaba en el primer hueco — cuando la bici vieja se
  destruía al invocar la nueva, **todos los bucles conectados después de ella
  dejaban de correr, sin ningún error visible**. En Roblox real desconectar una
  conexión no apaga a las demás; ahora el simulador tampoco.
- **El `VehicleSeat` nacía sin `Throttle`/`Steer`**: en Roblox nacen en 0; en
  el simulador eran `nil` y el bucle de la bici tronaba cada frame (el error
  moría adentro de la señal y nadie lo veía).

---

## Cómo probar

1. Corre el **PASO 0** del HTML (limpia copias viejas) y pega los 5 archivos.
2. **Play** → la placa verde debe decir `RONDA v55  OK` y el letrero del
   servidor `SERVIDOR v55`.
3. **Al entrar** pon atención: se oye la ciudad de fondo, bajita, en loop.
3. **La van:** sácala del cajón y maneja — el motor arranca en idle y **sube
   de tono al acelerar**; frena y baja; **bájate y se apaga**.
4. **La bici:** pídela y pedalea — suena a rodada mientras más rápido vas, y
   calla al pararte.
5. Si quieres silencio total: en `GameConfig` → `Sounds` → `Enabled = false`
   apaga TODO el sonido del juego de un golpe.

---

## Roadmap

| Pendiente | Estado |
|---|---|
| Interiores de propiedades (casas/departamentos) | solo fachada hoy |
| Confirmar de oídos el motor/rodada/ambiente en el juego real | pendiente del reporte del usuario |
| Confirmar la van, el portón y la bici de las rondas pasadas | pendiente del reporte del usuario |
