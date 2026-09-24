# 🚨 Fix v5 — El bug que borró la ciudad

## 📂 Abrir los archivos a copiar

### 1️⃣ [CityGenerator.luau](ServerScriptService/CityGenerator.luau)
→ **ServerScriptService › CityGenerator**

### 2️⃣ [Main.luau](ServerScriptService/Main.luau)
→ **ServerScriptService › Main**

### 3️⃣ [ClientUI.luau](StarterPlayerScripts/ClientUI.luau)
→ **StarterPlayer › StarterPlayerScripts › ClientUI**

> ⛔ `GameConfig` y `DataService` **no los toques**.

---

## 🔍 No copiaste mal nada — era mi error

Monté un simulador de la API de Roblox y corrí tu `CityGenerator` línea por línea
hasta que tronó. El culpable:

```lua
Lighting.Technology = Enum.Technology.Future   -- ❌ SOLO-LECTURA
```

**`Lighting.Technology` no se puede cambiar desde un script.** Roblox la bloquea.
Yo la metí en la v3 y nunca se había ejecutado esa ruta hasta ahora.

### Por qué desapareció TODO

Esa línea vive dentro de `SetupLighting()`, que se llama al final de `Build()`.
Y `Build()` está en la línea 43 de `Main`:

```lua
local city = CityGenerator.Build()   -- ← truena aquí
-- ...todo lo de abajo NUNCA se ejecuta:
--    registro de jugadores  → por eso $0
--    asignación de bodega   → por eso botón H muerto
--    sistema de venta, heat, asaltos...
```

Un error en un `Script` de Roblox **detiene el script completo** desde ese punto.
Por eso el $0 y la ciudad vacía eran **el mismo bug**. Mis "arreglos" del $0 en v3 y v4
eran correctos, pero nunca llegaban a ejecutarse.

---

## ✅ Qué cambié

**1. Quité la línea prohibida.** Ya no se asigna `Technology` por código.

**2. Setter seguro.** Las demás propiedades de Lighting ahora usan `safeSet()`, que
usa `pcall` y si falla solo avisa en el Output en vez de matar el script.

**3. Red de seguridad en Main.** La generación del mapa va envuelta en `pcall`:

```lua
local ok, result = pcall(CityGenerator.Build)
if not ok then
    warn("[SpiceEmpire] ERROR generando la ciudad: " .. tostring(result))
    -- pero el juego SIGUE: perfiles, dinero, tienda, todo funciona
end
```

**Aunque el mapa falle, ya nunca te vas a quedar sin dinero ni sin bodega.**

**4. Portada empalmada.** El "Cargando la ciudad..." y el TIP estaban ambos como al 62%
de la pantalla. Ya separé: título arriba, botón al centro, TIP hasta abajo.

---

## 🎨 Opcional: gráficos Future

Como ya no se puede por código, si quieres la iluminación bonita hazlo a mano
(es permanente, una sola vez):

1. En el **Explorer**, clic en **`Lighting`**
2. En **Properties**, busca la propiedad **`Technology`**
3. Cámbiala de `ShadowMap` a **`Future`**

Se ve bastante mejor, pero pide más GPU. Si te va lento, déjalo en `ShadowMap`.

---

## ✅ Checklist al darle Play

- [ ] **La ciudad existe** (edificios, calles, césped)
- [ ] El HUD dice **$500**
- [ ] Portada sin textos encimados
- [ ] Es de día y las ventanas están apagadas
- [ ] Diálogo al acercarte a un NPC
- [ ] **Bodega [H]** te teletransporta

### Si algo falla

Abre **View → Output** y mándame captura. Ahora los errores salen con la etiqueta
`[SpiceEmpire]` así que son fáciles de ubicar.
