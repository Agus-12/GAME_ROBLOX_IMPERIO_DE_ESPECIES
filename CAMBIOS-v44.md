# Cambios de la ronda v44

> ## 🎯 TUS 4 REPORTES DE LAS CAPTURAS
>
> | Lo que reportaste | Qué era | Qué se hizo |
> |---|---|---|
> | **"algunas de las otras parcelas: las bodegas están ENCIMA DE LA CALLE"** | El suelo se estira para cubrir los lotes de bodega… pero **las calles se dibujaban del mismo tamaño que el suelo**, así que también se estiraban y cruzaban por encima de los lotes. La bodega del lote 3 en adelante quedaba parada arriba del asfalto | La ciudad y el pasto ahora son **dos rectángulos separados**: las calles viven **dentro de la rejilla de cuadras** (X -502..308, Z -502..308) y ya no llegan a los lotes (que arrancan en Z -660) |
> | **"me salen los nombres así en grandote muy estorboso"** | Los rótulos eran `BillboardGui` de 200×50: el tamaño de un billboard **es en píxeles fijos**, así que se ven igual de enormes a un metro que a cien, y encimados tapan media pantalla (encima se sumaba el "BODEGA DE …" de 260×50 que flotaba a 30 studs) | Los rótulos ahora van **pintados en el tablero negro que ya existía** (SurfaceGui pegado a la parte: crece y se encoge con la distancia, como un letrero de verdad). El letrero gigante de la bodega **se quitó** |
> | **"pondría 'garaje de <usuario>' o 'sin propietario' los que no tienen"** | El tablero del garaje decía solo "GARAJE" | El tablero del garaje dice **`GARAJE DE <TU NOMBRE>`** y el de los lotes sin dueño **`SIN PROPIETARIO`** (función nueva `RotularGaraje`) |
> | **"vi un letrero flotante de 'caja 1': ahí ya hay uno negro, poner ahí 'caja 1' pero en texto plano"** | El número del cajón era otro billboard flotante | Ahora va **`CAJA 1`, `CAJA 2`… pintado en su tablero negro**, en texto plano |

---

## 1. 🛣️ Las bodegas ya no están encima de la calle

**La causa:** en `buildGround` el suelo se agranda para cubrir **los lotes de bodega**
(que viven detrás de la ciudad). Pero las calles se dibujaban con **el mismo ancho y
largo que el suelo**: al estirar el pasto hacia los lotes, las calles se estiraron con
él. Las calles verticales quedaban cruzando justo por donde van los lotes 3, 4 y 5.

**El arreglo:** ahora hay dos medidas distintas dentro de la misma función:

* **el suelo** (pasto) → se estira todo lo necesario para cubrir ciudad + lotes;
* **las calles** → se calculan **de dónde caen las calles de las orillas** (la rejilla
  de cuadras) para que el asfalto cubra los cruceros completos y **no se pase ni un
  centímetro** hacia los lotes.

Medido por la prueba: las 10 calles quedan en **X -502..308, Z -502..308** y el primer
lote está en **Z -660** → ya no se tocan.

## 2. 🪧 Rótulos: se acabaron los textos flotantes

```
ANTES                                   AHORA
[ BODEGA DE PEPE ]  <- flotando a 30    ┌──────────────┐
[     GARAJE     ]  <- 200x50 px        │ GARAJE DE PEPE│ <- pintado en el
[    CAJON 1     ]                      │    CAJA 1     │    tablero negro
   (se ven igual de grandes              └──────────────┘
    a 1 m que a 100 m)                    (se encoge con la distancia)
```

* **Garaje** → el tablero negro que ya estaba arriba de los portones.
* **Cajones** → `CAJA 1`, `CAJA 2`… en su tablero negro (tal cual lo pediste).
* **Taller**, **Oficina**, **el letrero del portón**, **la caja fuerte**, **el monitor
  de Mejoras**, **la torre de Aduanas** y la tablilla de **CLAUSURADA** → pintados en
  su propia parte.
* Los que **sí** deben flotar (el nombre y el precio de los compradores del mercado, el
  "PRENSA [R]") ahora son **más chicos** y con menos texto.
* En las partes altas (la torre de Aduanas) el texto va en una **banda** a media altura,
  como los rótulos de los edificios de verdad, en vez de estirarse a lo alto.
* Cada rótulo se pinta en **las dos caras** grandes, así que se lee vengas de donde
  vengas (por eso ya no hace falta que flote mirando a la cámara).

## 3. 🏷️ "GARAJE DE <NOMBRE>" / "SIN PROPIETARIO"

* Cuando entras, tu bodega rotula su tablero: **`GARAJE DE TU NOMBRE`**.
* Los lotes **sin dueño** (los que se ven con cinta y oficiales) dicen
  **`SIN PROPIETARIO`**.

## 4. 🧪 Etapa 19 nueva (y probada al revés)

`tools/reportes44.py` es ahora la **etapa 19** de `tools/validate.sh` y mide:

1. **que las calles no lleguen a los lotes** (se mide de verdad el rectángulo que
   ocupan las 10 calles contra la posición del primer lote);
2. **que no quede ningún rótulo flotante** en el garaje/cajones/taller/oficina/portón,
   y que ninguno pase de 160 píxeles de ancho;
3. que el tablero diga `GARAJE`, que los cajones digan `CAJA n`, y que
   `RotularGaraje` **reescriba** el texto (probado con "GARAJE DE PEPE");
4. el **camino real del lote sin dueño**: `VarianteVecina` + `Clausurar` + rótulo
   → tiene que decir `SIN PROPIETARIO` y la tablilla `CLAUSURADA` **pintada**.

**Probado al revés:** se regresaron las calles al tamaño del suelo, se volvió a poner
un `BillboardGui` en el tablero del garaje y en los cajones, y se le quitó el rótulo a
los lotes sin dueño → la etapa **cazó los cuatro** y volvió a pasar al restaurarlos.

## 5. ✅ Qué deberías ver ahora

1. Placa **`RONDA v44  OK`** y letrero del spawn **`SERVIDOR v44`**.
2. Maneja hacia los lotes: **ninguna bodega encima del asfalto** (la calle se queda en
   la ciudad).
3. Tu bodega: el tablero del garaje dice **`GARAJE DE <TU NOMBRE>`**; los vacíos,
   **`SIN PROPIETARIO`**.
4. Adentro: los cajones dicen **`CAJA 1`** pintado en su tablero (ya no flota).
5. Nada de textos gigantes encimados: el garaje, el taller y la oficina se leen en su
   propio letrero.

> Lo de la ronda pasada sigue igual: bici que rueda (rines completos), garaje por
> niveles con **1 cajón y 1 auto** en nivel 1, portones que abren solo el tuyo, lotes
> clausurados con oficiales, estrellas de búsqueda y el dock de celular con iconos.
