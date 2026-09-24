# 👷 v19 — Los empleados ya existen de verdad

## 📂 Abrir los archivos a copiar

### 1️⃣ [GameConfig.luau](ReplicatedStorage/GameConfig.luau)
→ **ReplicatedStorage › GameConfig**

### 2️⃣ [DataService.luau](ServerScriptService/DataService.luau)
→ **ServerScriptService › DataService**

### 3️⃣ [CityGenerator.luau](ServerScriptService/CityGenerator.luau)
→ **ServerScriptService › CityGenerator**

### 4️⃣ [Main.luau](ServerScriptService/Main.luau)
→ **ServerScriptService › Main**

### 5️⃣ [ClientUI.luau](StarterPlayerScripts/ClientUI.luau)
→ **StarterPlayer › StarterPlayerScripts › ClientUI**

> Cambiaron los 5 otra vez. Tu partida guardada **no se pierde**.

---

## 1. 👷 Los cosechadores ahora son personas

Tenías razón: contratabas y **no los veías**. Eran puros números — cada cierto tiempo
aparecían hojas de la nada, sin importar si había plantas o no.

Ahora:

- **Existen físicamente.** Overol azul y chaleco amarillo reflejante, para que los
  distingas de los compradores y del vigilante
- **Uno por mesa.** El cosechador #1 se para junto a la mesa 1, el #2 junto a la 2, etc.
- **Solo cortan de SU mesa.** El de la mesa 3 no toca la mesa 1
- **Solo cortan lo maduro.** Si esa mesa no tiene nada listo, ese cosechador no produce
  nada ese ciclo — exactamente como lo pediste
- **Lo que cortan va a la caja fuerte**, igual que si lo cosecharas tú

### El tope ahora es tus mesas

No puedes contratar más cosechadores que mesas tengas. Si tienes 4 mesas y ya tienes 4
cosechadores, te dice:

> *"Ya tienes un cosechador por mesa (4/4). Mejora la bodega para tener más mesas"*

| Nivel de bodega | Mesas | Cosechadores máx. |
|---|---|---|
| Garage | 4 | 4 |
| Bodega | 8 | 8 |
| Almacén Industrial | 12 | 12 |
| Mega Procesadora | 12 | 12 |

La pestaña de Empleados ahora muestra `2/4 mesas` en vez de un número suelto.

### Los prensadores también

Se paran junto a la máquina y trabajan sobre la caja fuerte: sacan hojas de la caja,
las convierten y meten los bloques de vuelta.

## 2. 💤 Trabajan aunque cierres el juego

Cuando sales, se guarda la hora. Cuando vuelves, se calcula cuánto habrían producido
mientras no estabas y te lo abonan a la caja:

> *"Tu gente trabajó sin ti — En 47 min tus empleados metieron 96 hojas y 4 bloques a la caja."*

Tiene **tope de 8 horas** para que la economía no se rompa si te desapareces una semana.
Y respeta el espacio de tu caja: si está llena, no te regala nada.

> Ajustable en `GameConfig.Employees.OfflineMaxHours`

## 3. 🐛 De paso: un bug mío de la v18

Al meter la caja fuerte dejé dos formas distintas de calcular el espacio ocupado: unas
partes contaban **un bloque como 3 de espacio** y otras **como 1**. Eso hacía que el
número de la pantalla no cuadrara con el del HUD, y que a veces te dejara guardar de más.

Ya hay **una sola función** (`vaultUsed`) que se usa en todos lados. Un bloque ocupa 3.

---

## Cómo probar

1. Entra a tu bodega y ve a la tienda → **Empleados**. Debe decir `0/4 mesas`.
2. **Contrata un cosechador.** Sal a la bodega: hay un tipo de chaleco amarillo parado
   junto a la primera mesa.
3. Espera. Cuando una planta de **esa** mesa madure, el tipo la corta y sube el número
   de la **caja**, no el de cargas.
4. Contrata 3 más → uno en cada mesa. Intenta contratar un quinto: te lo debe negar.
5. **La prueba buena:** sal del juego, espera 10 minutos, vuelve a entrar. Debe salirte
   el aviso de que tu gente trabajó sin ti.

---

## 🗺️ Lo que sigue

| Pendiente | Qué es |
|---|---|
| **Asaltos que roben de la caja fuerte** | Ya quedó decidido que sí pueden. Es lo que le da sentido a los guardias y a la alerta del celular |
| **Territorios de crews** | Zonas capturables + guerra entre crews |
| **Interiores de propiedades** | Las casas que compras son solo fachada |
| **Garaje real** | Un lugar físico para tus autos |
