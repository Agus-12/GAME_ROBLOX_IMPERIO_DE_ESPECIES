# 🚗 v26 — El garaje

## 📂 Abrir los archivos a copiar

### 1️⃣ [GameConfig.luau](ReplicatedStorage/GameConfig.luau)
→ **ReplicatedStorage › GameConfig**

### 2️⃣ [CityGenerator.luau](ServerScriptService/CityGenerator.luau)
→ **ServerScriptService › CityGenerator**

### 3️⃣ [Main.luau](ServerScriptService/Main.luau)
→ **ServerScriptService › Main**

### 4️⃣ [ClientUI.luau](StarterPlayerScripts/ClientUI.luau)
→ **StarterPlayer › StarterPlayerScripts › ClientUI**

> ⛔ `DataService` no cambió.

---

## El problema

Comprabas un auto de $150,000 y **no pasaba nada visible**. Se guardaba un `true` en tu
perfil, y cuando lo sacabas aparecía de la nada junto a ti. No había forma de ver lo que
tenías, ni de sentir que lo tenías.

## 🏠 Ahora tu bodega tiene garaje

Es un **anexo pegado al costado izquierdo** de la nave, abierto hacia adentro para que
puedas pasar. Trae:

- **4 cajones numerados**, uno por vehículo, con sus líneas amarillas pintadas
- **Lámpara sobre cada cajón**
- Letrero de **GARAJE** y su rampa de salida

## 🚗 Tus autos están ahí, estacionados

Cada vehículo tiene su cajón asignado y **su propio color**:

| Cajón | Vehículo | Color |
|---|---|---|
| 1 | Van de Carga | Blanco |
| 2 | Sedán Gris | Gris |
| 3 | Pickup Rural | Verde |
| 4 | Deportivo | Rojo |

Los autos estacionados están armados con carrocería, cabina, cristales, cofre, faros,
calaveras y llantas — no son cubos.

**Cuando compras uno, aparece parado en su cajón inmediatamente.** Puedes ir a verlo.

## 🔑 Sacarlo y guardarlo

- Al sacar un auto, **el cajón se queda vacío** (ahí anda el coche, tiene sentido)
- El auto **sale por la rampa del garaje**, no de la nada junto a ti
- Cuando sacas otro, el anterior se guarda y su cajón se vuelve a llenar

## 🎮 Cómo se abre

Te acercas al garaje y sale el botón **Garaje** (tecla **V**), que abre directo la
pestaña de Autos para que saques el que quieras.

Es el mismo sistema contextual de la prensa y la caja: solo aparece cuando estás cerca.

---

## Cómo probar

1. Sal de tu bodega por el lado izquierdo — ahí está el garaje.
2. Compra la Van ($8,000). Ve al garaje: debe estar en el **cajón 1**.
3. Acércate: sale el botón **Garaje**. Sácala.
4. El cajón 1 queda vacío y la van aparece en la rampa.
5. Compra otro y checa que cada uno se va a su cajón.

---

## 🗺️ Roadmap

| Pendiente | Qué es |
|---|---|
| **Interiores de propiedades** | Las casas que compras siguen siendo solo un número |
| **Música de fondo** | Los efectos ya están |
| **Tabla de crews** | Ranking de quién domina más plazas |
