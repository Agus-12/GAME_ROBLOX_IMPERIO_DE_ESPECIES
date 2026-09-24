# 🔦 v13 — Luz de la bodega, bici que no se cae ni trepa

## 📂 Abrir los archivos a copiar

### 1️⃣ [CityGenerator.luau](ServerScriptService/CityGenerator.luau)
→ **ServerScriptService › CityGenerator**

### 2️⃣ [Main.luau](ServerScriptService/Main.luau)
→ **ServerScriptService › Main**

> ⛔ `GameConfig`, `DataService` y `ClientUI` no cambiaron.

---

## 1. 💡 Encontré el verdadero culpable de la luz

En la v11 le bajé a las luces UV y a las de la prensa, pero **me fui por el lado equivocado**. El problema real estaba en las **lámparas del techo**:

```
Brightness = 2.2
Range = 60        ← esto
```

Son 3 lámparas dentro de una bodega que mide 70 studs de ancho. Con alcance **60 cada una**, las tres cubrían absolutamente todo el espacio **y se sumaban entre ellas**. Por eso las paredes salían blancas.

Ahora:

| Luz | Antes | Ahora |
|---|---|---|
| **Lámparas del techo** | 2.2 / alcance **60** | **0.85 / alcance 26** |
| Tubos UV | 0.85 / 13 | **0.45 / 9** |
| Plafón (el neón del techo) | blanco puro | gris claro |

Lo clave es el **alcance**: bajándolo, cada lámpara ilumina su zona y ya no se encima con las vecinas. Es lo que hacía que se acumulara.

> Si te queda **muy oscura**, sube `l.Brightness = 0.85` a `1.2` en la sección "LÁMPARAS DE TECHO". Si sigue muy clara, bájalo a `0.6`.

## 2. 🚲 La bici ya no se acuesta

En tu captura estaba tirada de lado en el pasto. El estabilizador que le puse era "suave" (con torque limitado), y con el peso de la bici no alcanzaba a sostenerla.

Lo cambié a **orientación rígida**: ahora la posición vertical es exacta y es **imposible** que se caiga.

## 3. 🧱 La bici ya no se trepa a los edificios

Esta estaba buena — en tu captura ibas montado **encima de un edificio**.

La causa: la bici se mueve poniéndole velocidad directa. Cuando chocabas contra una pared, la velocidad seguía empujando, y la caja de colisión **resbalaba hacia arriba** por la pared. Básicamente escalabas.

Ahora la bici **lanza un rayo hacia adelante** cada frame. Si detecta una superficie parada (una pared) a menos de 4 studs, **frena en seco**. Las rampas y banquetas siguen funcionando, porque el rayo distingue entre una pared vertical y una subida inclinada.

## 4. 🔤 Los letreros ya no se encimaban

"MEJORAS [G]" se montaba encima de "PRENSA [R]". Les puse alturas distintas:

| Letrero | Altura |
|---|---|
| PRENSA [R] | 11 |
| ZONA SEGURA | 8 |
| MEJORAS [G] | 3 |

## 5. 🛢️ El barril ya no le estorba al vigilante

Estaba a 3.5 studs y se le encimaba. Lo moví a 6.5 y un poco atrás.

---

## Cómo probar

- **Luz:** entra a la bodega. Debe verse iluminada pero ya sin quemar. Si no te late el nivel, el número a mover te lo dejé arriba.
- **Bici:** sácala y déjala sola un rato — debe quedarse parada. Súbete y échate contra una pared: debe **frenar**, no subirse.
- **Letreros:** párate en medio de la bodega, ya se leen separados.

Todo corrió en el simulador: servidor OK, los 4 niveles de bodega OK, y el UI carga en escritorio, celular y tablet.

---

## Nota sobre el brillo

El nivel de luz depende mucho del **LightingStyle** que hayas elegido:

- **Realistic** → las luces se ven más intensas y con sombras
- **Soft** → más plano y parejo

Si cambiaste a Realistic después de la v11, eso también contribuyó a que se viera tan quemado. Con estos números ya debería estar bien en cualquiera de los dos, pero avísame si en el tuyo se ve distinto.
