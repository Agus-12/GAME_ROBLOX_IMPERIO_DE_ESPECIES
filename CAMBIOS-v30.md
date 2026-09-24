# 🚪 v30 — Arreglado: la portada ya no se queda en "Cargando la ciudad..."

**Este fue un bug de verdad y era del cliente, no del servidor.** Tres archivos cambian:
`GameConfig`, `ClientUI` y `Main` (los otros dos van igual para que los tengas juntos).

## 📂 Los archivos (un clic y copiar)

📦 **Los 5 códigos juntos en un solo archivo:** **`v30-ARCHIVOS.html`** (pestañas + botón
**COPIAR TODO**, sin salir de aquí).

| # | Archivo | Dónde se pega | Tipo |
|---|---|---|---|
| 1 | [GameConfig.luau](ReplicatedStorage/GameConfig.luau) | `ReplicatedStorage` › **GameConfig** | ModuleScript |
| 2 | [CityGenerator.luau](ServerScriptService/CityGenerator.luau) | `ServerScriptService` › **CityGenerator** | ModuleScript |
| 3 | [DataService.luau](ServerScriptService/DataService.luau) | `ServerScriptService` › **DataService** | ModuleScript |
| 4 | [Main.luau](ServerScriptService/Main.luau) | `ServerScriptService` › **Main** | **Script** |
| 5 | [ClientUI.luau](StarterPlayerScripts/ClientUI.luau) | `StarterPlayer › StarterPlayerScripts` › **ClientUI** | LocalScript |

> ⚠️ Pega **siempre encima** (clic en el script → `Ctrl+A` → `Ctrl+V`).

---

## 🐢 Qué pasaba (y no era el servidor)

Medí el arranque del servidor: **la ciudad entera se construye en 0.2 segundos** y una
bodega en 0.016 s. El servidor estaba bien.

El problema era **cómo el cliente mostraba la portada**. El código decía esto:

```lua
for i = 1, 30 do
    RF_Action:InvokeServer("sync")     -- pregunta al servidor
    task.wait(0.4)
    if State.Cash > 0 then ...        -- y SOLO abre si le contestó
end
-- si nadie contestó: 30 x 0.4 = 12 SEGUNDOS mirando "Cargando la ciudad..."
```

O sea: **el botón "ENTRAR AL BARRIO" dependía de una respuesta del servidor.** Si esa
respuesta tardaba, faltaba o el servidor estaba ocupado, te quedabas **hasta 12 segundos**
viendo la portada. Y si algo fallaba en el camino… más.

## ✅ Cómo quedó

La portada **ya no le pregunta nada al servidor**. Se abre en cuanto el cliente puede ver
lo suyo, que es instantáneo:

| Situación | Antes | Ahora |
|---|---|---|
| Todo cargó (lo normal) | abría cuando llegara la respuesta | **abre al instante** (0.00 s) |
| Tu personaje tarda en aparecer | esperaba igual | **abre en cuanto aparece** (≈0.9 s) |
| Servidor lento / sin ciudad | 12 s | **tope duro de 3 s** |

Y además:

- **Toca la pantalla** (o el botón) y entras, aunque el cartel siga ahí.
- El dinero y las hojas se siguen pidiendo al servidor **aparte, sin bloquear la entrada**.
- El texto cambia a *"Toca la pantalla o el botón para entrar"* cuando ya se puede pasar.

---

## 🕵️ Cómo encontré esto (y por qué mis pruebas no lo veían)

Aquí está lo interesante y lo que más me sirve para el futuro: **mi simulador no podía
ver este bug.**

> En el simulador, `task.spawn` **no corría nada** y `task.wait` **no esperaba nada**.
> Resultado: aquel bucle de 30 × 0.4 s se recorría **al instante**, así que el bug de los
> 12 segundos **pasaba perfecto todas las pruebas**. El simulador mentía.

Lo arreglé de raíz: el simulador ahora tiene **reloj virtual** (las tareas corren de
verdad, en corrutinas, y `task.wait` avanza el reloj). Con eso armé una prueba nueva,
**etapa 10** del validador, que **mide en segundos** cuánto tarda en salir el botón:

```
=== 10. LA PORTADA ABRE RAPIDO? ===
A) servidor listo (ciudad + personaje)     OK  abre a los 0.00 s
B) el personaje tarda 0.8 s en aparecer     OK  abre a los 0.90 s
C) servidor lento (sin ciudad todavia)      OK  abre a los 3.00 s
```

### Y de paso salieron dos cosas más

Al poner las tareas a correr de verdad, apareció código que **nunca se ejecutaba en las
pruebas**:

1. **El reloj del HUD** (`16:47 SOL`) tronaba en el simulador porque al `Lighting` del
   simulador **le faltaba `ClockTime`**. Tapado.
2. **`InputBegan`** (que es lo que uso para "toca la pantalla") no existía en el
   simulador. Tapado.

Y encontré **un error mío**: puse el tope de 3 segundos con `os.clock()` (reloj real), y
eso **no se puede medir en una prueba** → lo cambié a un **contador de 30 revoluciones**,
que es igual de exacto y sí es verificable. (Si no, la prueba de la portada habría vuelto
a mentir, que es justo el bug que estaba arreglando.)

---

## 🧪 Cómo probar

1. Pega los 5 archivos y dale **Play**.
2. La pantalla de título: el botón **ENTRAR AL BARRIO** debe salir **casi al instante**
   (si tardas mucho en Studio cargando la ciudad, máximo 3 segundos).
3. Si quieres, **toca la pantalla** en vez del botón: entra igual.
4. Adentro, revisa que el **HUD en columna** (izquierda) y el **reloj** funcionen.

> 💡 **En Studio el arranque tarda más que en el celular de tus jugadores**: al dar Play,
> Studio carga el servidor y el cliente a la vez. Aun así, la portada ya no depende de eso.

---

## 📊 Estado de la ronda

- Validación: **10 etapas, todas en verde** (se agregó la de la portada).
- Los bucles de fondo del **servidor y del cliente** ahora **sí corren** en las pruebas
  (antes no se ejecutaban nunca): no aparecieron errores.
- Sigue pendiente que me confirmes la **bici** y los **interiores de propiedades**.
