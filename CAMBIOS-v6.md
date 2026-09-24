# 🏗️ v6 — Bodega mejorable, NPCs visibles, tiendas integradas y bici

## 📂 Abrir los archivos a copiar

### 1️⃣ [GameConfig.luau](ReplicatedStorage/GameConfig.luau)
→ **ReplicatedStorage › GameConfig**

### 2️⃣ [CityGenerator.luau](ServerScriptService/CityGenerator.luau)
→ **ServerScriptService › CityGenerator**

### 3️⃣ [DataService.luau](ServerScriptService/DataService.luau)
→ **ServerScriptService › DataService**

### 4️⃣ [Main.luau](ServerScriptService/Main.luau)
→ **ServerScriptService › Main**

### 5️⃣ [ClientUI.luau](StarterPlayerScripts/ClientUI.luau)
→ **StarterPlayer › StarterPlayerScripts › ClientUI**

> ⚠️ Esta vez son **los 5**.

---

## 🐛 Por qué no aparecían los NPCs

Una línea faltante. Yo creaba el modelo, le soldaba todas las partes... y nunca lo
conectaba al mundo:

```lua
local npc = Instance.new("Model")
-- ...crear cabeza, torso, brazos, piernas...
-- ❌ FALTABA: npc.Parent = parent
```

Sin `Parent`, Roblox descarta el modelo. Se creaban y se borraban al instante.

**Verificado con simulación:** antes 0 NPCs, ahora los **5** + el vigilante. ✅

---

## 🏙️ Tiendas integradas a la ciudad

Antes calculaba el puesto como *"centro de la cuadra + la mitad del ancho + 16"*, lo cual
lo aventaba **a media calle**. Ahora es al revés: la cuadra le **reserva espacio**.

**Cómo funciona ahora:**

1. `buildBlock` detecta si su celda tiene mercado
2. Si sí, **empuja los edificios hacia atrás** y reserva 56 studs al frente
3. Levanta **dos edificios altos flanqueando** esa franja → se siente callejón real
4. Les pone **escaleras de incendios** en las paredes que dan al callejón
5. `buildBuyers` coloca el puesto exactamente en ese hueco reservado

Resultado: el mercado queda **metido entre edificios**, con la reja al fondo y la salida
hacia la banqueta. Ya no es una casita de juguete en medio del asfalto.

---

## 🏭 Bodega mejorable (4 niveles)

Ya no es un cuarto vacío. Ahora es una bodega **de verdad**: cortina metálica con rieles,
muelle de carga con topes de hule, vigas en el techo, estantería industrial con cajas,
línea amarilla de seguridad en el piso, y la prensa como **máquina física** con pistón.

| Nivel | Nombre | Costo | Parcelas | Almacén |
|---|---|---|---|---|
| 1 | Garage | — | 4 | +0 |
| 2 | Bodega | $15K | 8 | +150 |
| 3 | Almacén Industrial | $120K | 12 | +500 |
| 4 | **Mega Procesadora** | $600K | 12 | +1500 |

Cada nivel cambia **tamaño, colores, cantidad de estanterías y lámparas**. La bodega se
reconstruye en el mismo lugar al mejorar.

**Cómo mejorar:** tecla `B` → pestaña **Bodega** (es la primera). También hay un pad azul
al fondo de tu bodega que te dice a qué nivel sigues.

---

## 🚬 El Vigilante

Afuera de tu bodega hay un NPC **recargado en la pared** (inclinado 9°), con un cigarro
encendido, botes de basura y basura regada alrededor.

Te acercas y te habla:
- *"Todo tranquilo por aca, jefe."*
- *"Vi una patrulla dar la vuelta. Ojo."*
- *"La mercancia esta segura. Por ahora."*

---

## 🚲 Bicicleta inicial

Cada jugador recibe una **bici automáticamente** al aparecer. Cuadro, manubrio, asiento
y 2 ruedas con física real.

Si la pierdes o se atora: tecla `B` → pestaña **Bodega** → botón **Spawnear**. Es gratis
e ilimitada.

Ajustes en `GameConfig` → `StarterBike` (velocidad 42 por defecto).

---

## ✅ Checklist

- [ ] Hay un **NPC detrás de cada mostrador** (5 en total)
- [ ] Los mercados están **entre edificios**, no en la calle
- [ ] Se ven **escaleras de incendios** en las paredes del callejón
- [ ] Tu bodega tiene **cortina metálica, estantes y muelle de carga**
- [ ] Hay un **vigilante fumando** afuera de tu bodega
- [ ] Apareces con una **bicicleta** al lado
- [ ] `B` → pestaña **Bodega** muestra "Nivel 1: Garage" y el precio del 2

### Prueba rápida de la mejora

En `GameConfig` cambia `StartingCash = 500` por `StartingCash = 20000`, dale Play,
y mejora la bodega para ver el Nivel 2. Luego regrésalo a 500.
