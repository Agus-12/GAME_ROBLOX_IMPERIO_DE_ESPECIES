# 🔧 Actualización v2 — Arreglos visuales

## ⚡ Qué tienes que hacer

Solo **3 scripts** cambiaron. Reemplaza el contenido completo de cada uno:

| Script | Dónde está | Archivo |
|---|---|---|
| `GameConfig` | ReplicatedStorage | `ReplicatedStorage/GameConfig.luau` |
| `CityGenerator` | ServerScriptService | `ServerScriptService/CityGenerator.luau` |
| `ClientUI` | StarterPlayerScripts | `StarterPlayerScripts/ClientUI.luau` |
| `Main` | ServerScriptService | `ServerScriptService/Main.luau` *(cambio chiquito)* |

**Cómo:** abre el script en Studio → `Cmd+A` para seleccionar todo → borra → pega el nuevo.

`DataService` NO cambió, déjalo como está.

---

## ✨ Qué se arregló

### 1. Ciclo día/noche real 🌅
- Un día completo = **12 minutos reales**
- Arranca a las 2 PM (de día, se ve todo)
- Amanecer y atardecer con cielo naranja
- De noche: estrellas, luna, y la ciudad encendida
- **Reloj en pantalla** arriba a la izquierda

### 2. La ciudad ya no está a oscuras 💡
- **Postes de luz** en las 4 esquinas de cada cuadra
- **Ventanas encendidas** en los edificios (75% aleatorio, con colores variados)
- **Luces rojas de aviación** parpadeando en las torres de más de 55 studs
- **Haces de luz verticales** en cada comprador para ubicarlos de lejos

### 3. Los letreros ya no se encimaban 📋
Antes "PRENSA" y "ZONA SEGURA" se montaban uno sobre otro porque todos tenían
`AlwaysOnTop = true`. Ahora:
- Cada letrero a su propia altura
- Se ocultan detrás de las paredes como debe ser
- Distancia de visión reducida (250 studs) para no saturar

### 4. Tu bodega se ve 🏭
- **3 lámparas de techo** que iluminan todo el interior
- La prensa brilla naranja, la zona segura verde
- **Plantas visibles** en cada parcela (9 matitas por parcela) — ahora sí parece cultivo

### 5. HUD arreglado 📊
- Bajado 80px: **ya no lo tapa la barra de Roblox**
- Porcentaje de Heat en número, no solo la barra
- Reloj del juego al lado

### 6. Gráficos mejores 🎨
- `Technology = Future` → sombras e iluminación modernas
- **Atmosphere** con neblina volumétrica
- **Bloom** para que las luces brillen
- **ColorCorrection** con más contraste y saturación

---

## 🌙 ¿Lo quieres siempre de noche?

Vibe más GTA nocturno. En `GameConfig`:

```lua
GameConfig.DayNight = {
    Enabled = false,     -- apaga el ciclo
    FixedHour = 22,      -- 10 PM fijo
}
```

O al revés, días más largos:
```lua
DayLengthMinutes = 30,
```

---

## 🖥️ Nota sobre el rendimiento

Le metí bastantes luces (4 postes × 25 cuadras = 100 postes). Si te va lento:

**Opción A** — menos cuadras, en `GameConfig`:
```lua
GridX = 4,
GridZ = 4,
```

**Opción B** — quita los postes: en `CityGenerator`, busca el bloque
`-- postes de luz en las 4 esquinas` y comenta el `for` completo.

**Opción C** — gráficos más ligeros: en `CityGenerator`, cambia
`Lighting.Technology = Enum.Technology.Future` por `Enum.Technology.ShadowMap`
