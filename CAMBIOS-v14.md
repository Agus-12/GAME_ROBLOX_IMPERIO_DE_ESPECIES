# 🌗 v14 — Bodega igual de día y de noche, bici derecha

## 📂 Abrir los archivos a copiar

### 1️⃣ [CityGenerator.luau](ServerScriptService/CityGenerator.luau)
→ **ServerScriptService › CityGenerator**

### 2️⃣ [Main.luau](ServerScriptService/Main.luau)
→ **ServerScriptService › Main**

> ⛔ `GameConfig`, `DataService` y `ClientUI` no cambiaron.

---

## 1. 🌗 La bodega ahora se ve así SIEMPRE

Me preguntaste si se puede dejar la iluminación de noche todo el tiempo. **Sí, y ya quedó.**

Lo curioso es que **las luces de la bodega nunca se apagaban** — ya estaban prendidas las 24 horas. Lo que cambiaba era otra cosa.

En Roblox hay dos ajustes de luz ambiental que se confunden fácil:

| Ajuste | A qué le pega |
|---|---|
| `OutdoorAmbient` | Solo a lo que **ve el cielo** |
| `Ambient` | A **TODO**, incluso dentro de cuartos cerrados |

El ciclo de día subía `Ambient` a un gris claro (120,122,130) durante el día. Como `Ambient` atraviesa techos y paredes, **inundaba la bodega de luz blanca** y se comía el efecto de los tubos UV.

Ahora `Ambient` se queda **fijo** en un tono oscuro las 24 horas, y el día/noche se maneja solo con `Brightness` y `OutdoorAmbient`.

El resultado:
- **Adentro:** siempre ese ambiente oscuro con los neones morados brillando, de día y de noche
- **Afuera:** sigue habiendo día y noche normal (de hecho subí un poco el día para compensar, porque `Ambient` ya no ayuda)

> **Si quieres ajustarlo:** busca `INTERIOR_AMBIENT` en CityGenerator. Más oscuro = `Color3.fromRGB(30, 32, 40)`. Más claro = `(60, 62, 74)`.

## 2. 🛞 Las llantas ya no están al revés

Encontré exactamente el error. En Roblox, un cilindro **ya nace con el eje en X** — o sea, las caras redondas apuntan a los lados, que es justo como va una llanta de bici.

Pero yo le estaba aplicando esto:

```lua
CFrame.Angles(0, 0, math.rad(90))
```

Eso las giraba 90° y las dejaba **acostadas como platos**. Lo quité. También corregí el giro: ahora rotan sobre su eje real al avanzar.

## 3. 🎈 La bici ya no flota

Este fue sutil. Yo movía la bici con un `LinearVelocity` en modo **Vector**, que controla **los tres ejes, incluido el vertical**. Cada frame le fijaba la velocidad vertical — y al hacer eso, la bici **peleaba contra la gravedad** y se quedaba suspendida.

Lo cambié a modo **Plane**: ahora solo mando en el plano horizontal (adelante/atrás/lados) y **la vertical se la dejo libre a la gravedad**. Así cae, se apoya en el piso y baja escalones normal.

## 4. 📞 Las llamadas ahora quedan en el historial

Sobre lo del teléfono: **sí está implementado** — es lo que ya viste funcionando con el "DESCONOCIDO". Lo que faltaba es que quedara **registrado** en la app del teléfono (tecla **T**).

Ahora:
- Cuando entra una llamada, se guarda en el teléfono con quién era, qué te ofrecían y cuánto pagaban
- Si **no contestas**, te queda una **"Llamada perdida"**

Así puedes revisar después qué te perdiste.

### ⏱️ Por qué a lo mejor no la has visto

Los tiempos actuales son:

| Ajuste | Valor |
|---|---|
| Primera llamada al entrar | **90 segundos** |
| Entre llamadas | **5 a 10 minutos** |
| Si rechazas | 2 minutos |

O sea que tienes que esperar **minuto y medio** desde que entras. Si quieres probarla de inmediato, en **GameConfig** busca `MissionCalls` y pon:

```lua
FirstCallWait = 10,
```

Y para que te lleguen seguido mientras pruebas:

```lua
MinWait = 30,
MaxWait = 60,
```

No se te olvide regresarlos a `300` / `600` cuando termines de probar, si no te van a estar chingando cada rato.

---

## Cómo probar

- **Luz:** entra a la bodega y espera a que amanezca (o adelanta la hora). Debe verse **igual** que en tu captura de noche.
- **Bici:** sácala. Las llantas deben estar **paradas**, no acostadas, y la bici **apoyada en el piso**. Súbete y avanza — las llantas giran.
- **Teléfono:** baja `FirstCallWait` a `10`, entra, espera. Después de contestar o colgar, aprieta **T** y ahí está el registro.

Todo corrió en el simulador: ciudad, los 4 niveles de bodega, `SetupLighting` y el servidor completo, sin errores.
