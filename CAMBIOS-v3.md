# 🔧 Actualización v3 — Bugs + NPCs + edificios realistas

## ⚡ Qué reemplazar

**Los 3 scripts** (abre en Studio → `Cmd+A` → borra → pega):

| Script | Dónde |
|---|---|
| `CityGenerator` | ServerScriptService |
| `Main` | ServerScriptService |
| `ClientUI` | StarterPlayerScripts |

`GameConfig` y `DataService` **no cambiaron**.

---

## 🐛 El bug que explicaba TODO

En tu captura tu HUD decía **$0** cuando debías tener **$500**. Ese era el bug raíz,
y también la razón de que el botón **Bodega** no hiciera nada.

**Qué pasaba:** en Studio tu personaje aparece *antes* de que termine de generarse la
ciudad. Como mi script se conectaba a `PlayerAdded` después de construir el mapa,
para ti ese evento **ya había pasado** → nunca se cargó tu perfil ni se te asignó bodega.

**Arreglado:** ahora hay una función `setupPlayer` que corre tanto en `PlayerAdded`
como en un barrido de los jugadores que ya estaban conectados.

```lua
Players.PlayerAdded:Connect(setupPlayer)
for _, p in ipairs(Players:GetPlayers()) do
    task.spawn(setupPlayer, p)   -- <- esto faltaba
end
```

Ahora sí vas a ver tus **$500** y el botón Bodega te teletransporta.

---

## 🌱 El césped que parpadeaba

Era **z-fighting**: el suelo terminaba exactamente en `y = 0` y las calles empezaban
justo ahí. La GPU no sabe cuál dibujar encima y parpadea.

Separé las capas:
- Suelo → techo en `y = -0.6`
- Calles → `y = 0.55`
- Rayas amarillas → `y = 1.12`

---

## 🏙️ Edificios realistas

Antes: una caja con franjas de ventanas. Ahora hay **3 tipos** que se eligen según
altura y terreno:

**🏢 Torre (rascacielos)** — 2-3 niveles escalonados que se van angostando, cornisas
entre pisos, antena arriba.

**🏬 Departamentos** — balcones con barandal en la fachada frontal, pretil en la azotea,
tinaco de agua.

**🏪 Local comercial** — escaparate de vidrio en planta baja, toldo de colores, letrero
luminoso que ilumina la banqueta.

**Lo importante:** las ventanas ya no son franjas. Ahora son **cristales individuales
en rejilla**, calculados por piso y por columna, en las 4 fachadas. Cada uno tiene 55-60%
de probabilidad de estar encendido, con reflectancia en los apagados.

---

## 🧍 NPCs compradores

Ya no es un cuadro naranja. Cada punto de venta ahora tiene:

- **Un NPC** con cuerpo completo (torso, cabeza, gorra, brazos, piernas), tono de piel
  y color de camisa aleatorios, parado detrás del mostrador
- **Puesto de mercado**: plataforma de madera, mostrador con barra, 4 postes y lona roja
- **Cajas de mercancía** regadas en ángulos aleatorios
- **Lámpara** colgando de la lona
- **Letrero de madera** con el nombre y el multiplicador
- El pad de venta ahora es discreto y semitransparente en vez del cuadrón feo

---

## 📊 HUD minimizable

Botón **`−`** en la esquina del HUD (o tecla **`M`**).

**Expandido:** todo como antes
**Minimizado:** solo el dinero grande + 3 chips semitransparentes:

| Chip | Icono | Muestra |
|---|---|---|
| Verde redondo | hoja | cantidad de hojas |
| Beige cuadrado | bloque | cantidad de bloques |
| Azul con solapa | mochila | `usado/capacidad` |

Los chips tienen fondo negro al 45% de transparencia para que no estorben la vista.
Botón **`+`** para volver a expandir.

---

## ⌨️ Controles actualizados

| Tecla | Acción |
|---|---|
| E | Cosechar |
| R | Prensar |
| F | Vender |
| B | Tienda |
| T | Teléfono |
| H | Ir a bodega |
| **M** | **Minimizar/expandir HUD** ← nuevo |

---

## 🖥️ Rendimiento

Los edificios ahora tienen **muchas** más partes (cada ventana es una part). Si te va lento:

**Reduce la ciudad** en `GameConfig`:
```lua
GridX = 4,
GridZ = 4,
```

**O menos ventanas** — en `CityGenerator`, función `addWindowGrid`, cambia:
```lua
local floorH = 7    -->  local floorH = 12
```
Eso reduce las ventanas casi a la mitad.
